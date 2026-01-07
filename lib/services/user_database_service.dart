import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

class VerbDetails {
  final int total;
  final Map<String, int> tenses; // tense -> count
  final String language; // language the verb is from

  VerbDetails({
    this.total = 0,
    Map<String, int>? tenses,
    this.language = '',
  }) : tenses = tenses ?? {};

  Map<String, dynamic> toMap() {
    return {
      'total': total,
      'tenses': tenses,
      'language': language,
    };
  }

  factory VerbDetails.fromMap(Map<String, dynamic> map) {
    return VerbDetails(
      total: map['total'] ?? 0,
      tenses: Map<String, int>.from(map['tenses'] ?? {}),
      language: map['language'] ?? '',
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

  // Record a completed sentence with verb and tense
  Future<void> recordSentenceComplete(String uid, String verb, String tense, String language) async {
    // Validate inputs
    if (verb.isEmpty || tense.isEmpty) {
      print('Invalid data: verb=$verb, tense=$tense - skipping');
      return;
    }
    
    final userRef = _firestore.collection('users').doc(uid);
    
    // Get current data or create new
    final doc = await userRef.get();
    
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
      
      tensesMap[tense] = (tensesMap[tense] ?? 0) + 1;
      
      await userRef.update({
        'totalSentences': FieldValue.increment(1),
        'verbsLearned.$verb': {
          'total': currentTotal + 1,
          'tenses': tensesMap,
          'language': language,
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
