import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'user_database_service.dart';

/// A tiny User model used by the auth service.
class User {
  final String uid;
  final String email;
  User({required this.uid, required this.email});
}

/// AuthService using Firebase Authentication.
class AuthService extends ChangeNotifier {
  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;
  final UserDatabaseService _userDb = UserDatabaseService();
  User? _user;
  bool _isLoading = false;

  AuthService() {
    // Listen to auth state changes
    _firebaseAuth.authStateChanges().listen((firebase_auth.User? firebaseUser) {
      print('🔔 Auth state changed: ${firebaseUser?.uid ?? 'null'}');
      if (firebaseUser != null) {
        _user = User(uid: firebaseUser.uid, email: firebaseUser.email ?? '');
        print('✅ User set: ${_user?.uid}');
      } else {
        _user = null;
        print('❌ User cleared');
      }
      notifyListeners();
    });
  }

  User? get currentUser => _user;
  bool get isLoading => _isLoading;

  /// Sign in with email and password.
  Future<User?> signIn(String email, String password) async {
    _setLoading(true);
    try {
      print('🔐 Attempting sign in...');
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        print('✅ Sign in successful: ${credential.user!.uid}');
        _user = User(
          uid: credential.user!.uid,
          email: credential.user!.email ?? '',
        );
        
        // Initialize user in Firestore if not exists
        print('📝 Checking user data in Firestore...');
        final userData = await _userDb.getUserData(_user!.uid);
        if (userData == null) {
          print('🆕 Initializing new user in Firestore...');
          await _userDb.initializeUser(_user!.uid, _user!.email);
        }
        print('✅ User data ready');
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      print('❌ Firebase auth error: ${e.code}');
      _setLoading(false);
      throw Exception(_getErrorMessage(e.code));
    } catch (e) {
      print('❌ Sign in error: $e');
      _setLoading(false);
      throw Exception('An error occurred during sign in');
    }
    _setLoading(false);
    print('🎉 Sign in complete');
    return _user;
  }

  /// Sign up with email and password.
  Future<User?> signUp(String email, String password) async {
    _setLoading(true);
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        _user = User(
          uid: credential.user!.uid,
          email: credential.user!.email ?? '',
        );
        
        // Initialize user in Firestore
        await _userDb.initializeUser(_user!.uid, _user!.email);
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      _setLoading(false);
      throw Exception(_getErrorMessage(e.code));
    } catch (e) {
      _setLoading(false);
      throw Exception('An error occurred during sign up');
    }
    _setLoading(false);
    return _user;
  }

  /// Sign out.
  Future<void> signOut() async {
    print('🚪 signOut() called');
    print('Stack trace: ${StackTrace.current}');
    _setLoading(true);
    try {
      await _firebaseAuth.signOut();
      _user = null;
      notifyListeners();
      print('✅ Sign out complete');
    } catch (e) {
      print('Error signing out: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool v) {
    if (_isLoading != v) {
      _isLoading = v;
      print('⏳ Loading state changed: $v');
      notifyListeners();
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}