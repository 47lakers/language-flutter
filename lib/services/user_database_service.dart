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

  UserData({
    required this.uid,
    required this.email,
    this.totalSentences = 0,
    Map<String, VerbDetails>? verbsLearned,
    DateTime? lastUpdated,
  })  : verbsLearned = verbsLearned ?? {},
        lastUpdated = lastUpdated ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'totalSentences': totalSentences,
      'verbsLearned': verbsLearned.map((key, value) => MapEntry(key, value.toMap())),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
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
    );
  }

  UserData copyWith({
    int? totalSentences,
    Map<String, VerbDetails>? verbsLearned,
  }) {
    return UserData(
      uid: uid,
      email: email,
      totalSentences: totalSentences ?? this.totalSentences,
      verbsLearned: verbsLearned ?? this.verbsLearned,
      lastUpdated: DateTime.now(),
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

  // Record a completed sentence with verb, tense, and optionally the phrase/translation
  Future<void> recordSentenceComplete(
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
      return;
    }

    final userRef = _firestore.collection('users').doc(uid);

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
        'lastUpdated': FieldValue.serverTimestamp(),
      });
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
        } else {
          isNewPhrase = false;
          print('⚠️ Duplicate phrase detected, skipping count increment: ${newPhrase['p']}');
        }
      }

      // Only increment counts if this is a genuinely new phrase
      if (!isNewPhrase) return;

      tensesMap[tense] = (tensesMap[tense] ?? 0) + 1;

      // Keep existing verbTranslation if we don't have a newer one
      final storedVerbTranslation = verbTranslation.isNotEmpty
          ? verbTranslation
          : (verbData?['verbTranslation'] as String? ?? '');

      await userRef.update({
        'totalSentences': FieldValue.increment(1),
        'verbsLearned.$verb': {
          'total': currentTotal + 1,
          'tenses': tensesMap,
          'language': language,
          'verbTranslation': storedVerbTranslation,
          'phrases': phrasesMap,
        },
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }
  }

  // Initialize new user
  Future<void> initializeUser(String uid, String email) async {
    final userData = UserData(uid: uid, email: email);
    await createOrUpdateUser(userData);
  }
}
