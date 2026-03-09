import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'user_database_service.dart';

/// A tiny User model used by the auth service.
class User {
  final String uid;
  final String email;
  User({required this.uid, required this.email});
}

/// AuthService using Firebase Authentication (Google Sign-In via web popup).
class AuthService extends ChangeNotifier {
  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;
  final UserDatabaseService _userDb = UserDatabaseService();
  User? _user;
  bool _isLoading = false;
  bool _isNewUser = false;

  AuthService() {
    _firebaseAuth.authStateChanges().listen((firebase_auth.User? firebaseUser) {
      if (firebaseUser != null) {
        _user = User(uid: firebaseUser.uid, email: firebaseUser.email ?? '');
      } else {
        _user = null;
      }
      notifyListeners();
    });
  }

  User? get currentUser => _user;
  bool get isLoading => _isLoading;
  bool get isNewUser => _isNewUser;

  void clearNewUserFlag() {
    _isNewUser = false;
    notifyListeners();
  }

  void setNewUserFlag() {
    _isNewUser = true;
    notifyListeners();
  }

  /// Sign in with email and password.
  Future<User?> signInWithEmail(String email, String password) async {
    _setLoading(true);
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user != null) {
        _user = User(uid: credential.user!.uid, email: credential.user!.email ?? '');
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      _setLoading(false);
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          throw Exception('Incorrect email or password.');
        case 'too-many-requests':
          throw Exception('Too many attempts. Please try again later.');
        default:
          throw Exception('Sign in failed. Please try again.');
      }
    } catch (e) {
      _setLoading(false);
      throw Exception('Sign in failed. Please try again.');
    }
    _setLoading(false);
    return _user;
  }

  /// Register with email and password.
  Future<User?> signUpWithEmail(String email, String password) async {
    _setLoading(true);
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user != null) {
        _user = User(uid: credential.user!.uid, email: credential.user!.email ?? '');
        _isNewUser = true;
        try {
          await _userDb.initializeUser(_user!.uid, _user!.email);
        } catch (dbError) {
          debugPrint('Warning: failed to initialize user in Firestore: $dbError');
        }
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      _setLoading(false);
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('An account with this email already exists.');
        case 'weak-password':
          throw Exception('Password must be at least 6 characters.');
        case 'invalid-email':
          throw Exception('Please enter a valid email address.');
        default:
          throw Exception('Sign up failed. Please try again.');
      }
    } catch (e) {
      _setLoading(false);
      throw Exception('Sign up failed. Please try again.');
    }
    _setLoading(false);
    return _user;
  }

  /// Send password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('No account found with this email.');
      }
      throw Exception('Failed to send reset email. Please try again.');
    }
  }

  /// Sign in with Google using a web popup.
  Future<User?> signInWithGoogle() async {
    _setLoading(true);
    try {
      final provider = firebase_auth.GoogleAuthProvider();
      final credential = await _firebaseAuth.signInWithPopup(provider);
      if (credential.user != null) {
        _user = User(
          uid: credential.user!.uid,
          email: credential.user!.email ?? '',
        );
        // Initialize user in Firestore if first time
        final userData = await _userDb.getUserData(_user!.uid);
        if (userData == null) {
          await _userDb.initializeUser(_user!.uid, _user!.email);
          _isNewUser = true;
        }
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      _setLoading(false);
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
        return null; // User dismissed — not an error
      }
      throw Exception('Sign in failed. Please try again.');
    } catch (e) {
      _setLoading(false);
      throw Exception('Sign in failed. Please try again.');
    }
    _setLoading(false);
    return _user;
  }

  /// Sign out.
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _firebaseAuth.signOut();
      _user = null;
      notifyListeners();
    } catch (e) {
      print('Error signing out: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool v) {
    if (_isLoading != v) {
      _isLoading = v;
      notifyListeners();
    }
  }
}