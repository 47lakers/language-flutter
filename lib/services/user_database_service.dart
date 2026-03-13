import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

class VerbDetails {
  final int total;
  final Map<String, int> tenses; // tense -> count
  final String language; // language the verb is from
  final String verbTranslation; // e.g. "to eat" — populated once backend returns it
  final Map<String, List<Map<String, String>>> phrases; // tense -> [{p: phrase, t: translation}]

  VerbDetails({
    this.total = 0,
    Map<String, int>? tenses,
    this.language = '',
    this.verbTranslation = '',
    Map<String, List<Map<String, String>>>? phrases,
  })  : tenses = tenses ?? {},
        phrases = phrases ?? {};

  Map<String, dynamic> toMap() {
    return {
      'total': total,
      'tenses': tenses,
      'language': language,
      'verbTranslation': verbTranslation,
      'phrases': phrases,
    };
  }

  factory VerbDetails.fromMap(Map<String, dynamic> map) {
    final phrasesRaw = map['phrases'] as Map<String, dynamic>? ?? {};
    final phrases = phrasesRaw.map((k, v) {
      final list = (v as List<dynamic>? ?? []).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return {'p': (m['p'] ?? '') as String, 't': (m['t'] ?? '') as String};
      }).toList();
      return MapEntry(k, list);
    });
    return VerbDetails(
      total: map['total'] ?? 0,
      tenses: Map<String, int>.from(map['tenses'] ?? {}),
      language: map['language'] ?? '',
      verbTranslation: map['verbTranslation'] as String? ?? '',
      phrases: phrases,
    );
  }
}

class UserData {
  final String uid;
  final String email;
  final int totalSentences;
  final Map<String, VerbDetails> verbsLearned; // verb -> VerbDetails
  final DateTime lastUpdated;
  final int currentStreak;
  final String lastActiveDate; // 'YYYY-MM-DD'

  UserData({
    required this.uid,
    required this.email,
    this.totalSentences = 0,
    Map<String, VerbDetails>? verbsLearned,
    DateTime? lastUpdated,
    this.currentStreak = 0,
    this.lastActiveDate = '',
  })  : verbsLearned = verbsLearned ?? {},
        lastUpdated = lastUpdated ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'totalSentences': totalSentences,
      'verbsLearned': verbsLearned.map((key, value) => MapEntry(key, value.toMap())),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'currentStreak': currentStreak,
      'lastActiveDate': lastActiveDate,
    };
  }

  factory UserData.fromMap(Map<String, dynamic> map) {
    final verbsMap = map['verbsLearned'] as Map<String, dynamic>? ?? {};
    final verbsLearned = verbsMap.map((key, value) {
      if (value is Map<String, dynamic>) {
        return MapEntry(key, VerbDetails.fromMap(value));
      }
      return MapEntry(key, VerbDetails(total: 0));
    });

    return UserData(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      totalSentences: map['totalSentences'] ?? 0,
      verbsLearned: verbsLearned,
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      currentStreak: map['currentStreak'] as int? ?? 0,
      lastActiveDate: map['lastActiveDate'] as String? ?? '',
    );
  }

  UserData copyWith({
    int? totalSentences,
    Map<String, VerbDetails>? verbsLearned,
    int? currentStreak,
    String? lastActiveDate,
  }) {
    return UserData(
      uid: uid,
      email: email,
      totalSentences: totalSentences ?? this.totalSentences,
      verbsLearned: verbsLearned ?? this.verbsLearned,
      lastUpdated: DateTime.now(),
      currentStreak: currentStreak ?? this.currentStreak,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
    );
  }
}

class UserDatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user data stream
  Stream<UserData?> getUserDataStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return UserData.fromMap(snapshot.data()!);
    });
  }

  // Get user data once
  Future<UserData?> getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserData.fromMap(doc.data()!);
  }

  // Create or update user
  Future<void> createOrUpdateUser(UserData userData) async {
    await _firestore.collection('users').doc(userData.uid).set(
          userData.toMap(),
          SetOptions(merge: true),
        );
  }

  // Increment sentence count
  Future<void> incrementSentenceCount(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'totalSentences': FieldValue.increment(1),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // Record a completed sentence with verb, tense, and optionally the phrase/translation.
  // Returns {totalSentences, streak} after the update.
  Future<Map<String, int>> recordSentenceComplete(
    String uid,
    String verb,
    String tense,
    String language, {
    String phrase = '',
    String phraseTranslation = '',
    String verbTranslation = '',
  }) async {
    // Validate inputs
    if (verb.isEmpty || tense.isEmpty) {
      print('Invalid data: verb=$verb, tense=$tense - skipping');
      return {'totalSentences': 0, 'streak': 0};
    }

    final userRef = _firestore.collection('users').doc(uid);

    // Compute today/yesterday strings for streak logic
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    // Get current data or create new
    final doc = await userRef.get();

    // Build phrase entry if we have content
    final newPhrase = phrase.isNotEmpty ? {'p': phrase, 't': phraseTranslation} : null;

    if (!doc.exists) {
      // If document doesn't exist, get email from auth and initialize
      final email = firebase_auth.FirebaseAuth.instance.currentUser?.email ?? '';
      await userRef.set({
        'uid': uid,
        'email': email,
        'totalSentences': 1,
        'verbsLearned': {
          verb: {
            'total': 1,
            'tenses': {tense: 1},
            'language': language,
            'verbTranslation': verbTranslation,
            if (newPhrase != null) 'phrases': {tense: [newPhrase]},
          }
        },
        'currentStreak': 1,
        'lastActiveDate': todayStr,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      return {'totalSentences': 1, 'streak': 1};
    } else {
      // Update existing - read current verb data
      final data = doc.data()!;
      final verbsLearnedRaw = data['verbsLearned'] as Map<String, dynamic>? ?? {};

      // Get or create verb details
      final verbData = verbsLearnedRaw[verb] as Map<String, dynamic>?;
      final currentTotal = verbData?['total'] as int? ?? 0;
      final currentTenses = verbData?['tenses'] as Map<String, dynamic>? ?? {};
      final tensesMap = Map<String, int>.from(currentTenses);

      // Preserve existing phrases and append new one (no duplicates)
      final currentPhrasesRaw = verbData?['phrases'] as Map<String, dynamic>? ?? {};
      final phrasesMap = currentPhrasesRaw.map(
        (k, v) => MapEntry(k, List<Map<String, dynamic>>.from(v as List)),
      );
      bool isNewPhrase = true;
      if (newPhrase != null) {
        final tensePhrases = phrasesMap.putIfAbsent(tense, () => []);
        final isDupe = tensePhrases.any((e) => e['p'] == newPhrase['p']);
        if (!isDupe) {
          tensePhrases.add(newPhrase);
          // Keep only the most recent 20 phrases per verb/tense
          if (tensePhrases.length > 20) {
            tensePhrases.removeRange(0, tensePhrases.length - 20);
          }
        } else {
          isNewPhrase = false;
          print('⚠️ Duplicate phrase detected, skipping count increment: ${newPhrase['p']}');
        }
      }

      // Only increment counts if this is a genuinely new phrase
      if (!isNewPhrase) return {'totalSentences': data['totalSentences'] as int? ?? 0, 'streak': data['currentStreak'] as int? ?? 0};

      tensesMap[tense] = (tensesMap[tense] ?? 0) + 1;

      // Keep existing verbTranslation if we don't have a newer one
      final storedVerbTranslation = verbTranslation.isNotEmpty
          ? verbTranslation
          : (verbData?['verbTranslation'] as String? ?? '');

      // Compute new streak
      final storedLastActiveDate = data['lastActiveDate'] as String? ?? '';
      final storedStreak = data['currentStreak'] as int? ?? 0;
      int newStreak;
      if (storedLastActiveDate == todayStr) {
        newStreak = storedStreak; // already active today, no change
      } else if (storedLastActiveDate == yesterdayStr) {
        newStreak = storedStreak + 1; // consecutive day
      } else {
        newStreak = 1; // streak broken or first save
      }

      final newTotal = (data['totalSentences'] as int? ?? 0) + 1;

      await userRef.update({
        'totalSentences': FieldValue.increment(1),
        'verbsLearned.$verb': {
          'total': currentTotal + 1,
          'tenses': tensesMap,
          'language': language,
          'verbTranslation': storedVerbTranslation,
          'phrases': phrasesMap,
        },
        'currentStreak': newStreak,
        'lastActiveDate': todayStr,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      return {'totalSentences': newTotal, 'streak': newStreak};
    }
    // Fallback (should not be reached)
    return {'totalSentences': 0, 'streak': 0};
  }

  // Initialize new user
  Future<void> initializeUser(String uid, String email) async {
    final userData = UserData(uid: uid, email: email);
    await createOrUpdateUser(userData);
  }

  // ---------------------------------------------------------------------------
  // Daily API rate limiting
  // ---------------------------------------------------------------------------

  static const int dailyApiLimit = 5;

  /// Returns true if the request is allowed, false if the daily limit is reached.
  /// Atomically increments the counter when allowed.
  Future<bool> checkAndIncrementDailyApiUsage(String uid) async {
    final userRef = _firestore.collection('users').doc(uid);

    return _firestore.runTransaction<bool>((transaction) async {
      final snapshot = await transaction.get(userRef);

      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      int currentCount = 0;

      if (snapshot.exists) {
        final data = snapshot.data()!;
        final storedDate = data['dailyApiDate'] as String?;
        if (storedDate == todayStr) {
          currentCount = (data['dailyApiCount'] as int?) ?? 0;
        }
        // If date is different, currentCount stays 0 (new day → reset)
      }

      if (currentCount >= dailyApiLimit) {
        return false; // limit reached, do not increment
      }

      transaction.set(
        userRef,
        {
          'dailyApiCount': currentCount + 1,
          'dailyApiDate': todayStr,
        },
        SetOptions(merge: true),
      );

      return true;
    });
  }
}
