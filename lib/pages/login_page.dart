import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _error;
  bool _noAccountFound = false;
  bool _isSignUp = false; // Toggle between sign in and sign up
  bool _isLoading = false; // Local loading state to prevent rebuilds
  bool _obscurePassword = true; // Password visibility toggle
  bool _resetEmailSent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email address above first.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
      _resetEmailSent = false;
    });
    try {
      await context.read<AuthService>().sendPasswordResetEmail(email);
      if (mounted) {
        setState(() {
          _resetEmailSent = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    print('🔄 Submit called, _isSignUp: $_isSignUp, _isLoading: $_isLoading');
    
    // Prevent double submission
    if (_isLoading) {
      print('⚠️ Already loading, ignoring submit');
      return;
    }
    
    setState(() {
      _error = null;
      _noAccountFound = false;
      _isLoading = true;
    });
    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation failed');
      setState(() => _isLoading = false);
      return;
    }

    final auth = context.read<AuthService>();
    try {
      print('📤 Calling auth service...');
      if (_isSignUp) {
        await auth.signUp(_emailCtrl.text.trim(), _passCtrl.text);
      } else {
        await auth.signIn(_emailCtrl.text.trim(), _passCtrl.text);
      }
      print('✅ Auth call completed successfully');
      // Success - wait a moment for auth state to propagate
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error in submit: $e');
      // Catch any error and display it
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        setState(() {
          if (msg == 'NO_ACCOUNT_FOUND') {
            _noAccountFound = true;
            _error = null;
          } else {
            _error = msg;
            _noAccountFound = false;
          }
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSignUp ? 'Sign Up' : 'Login'),
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () => themeProvider.toggleTheme(),
            tooltip: themeProvider.isDarkMode ? 'Switch to light mode' : 'Switch to dark mode',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Card(
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Enter email' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passCtrl,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter password';
                      if (_isSignUp && v.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_noAccountFound) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.person_search, color: Colors.orange),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No account found with this email.',
                                  style: TextStyle(color: Colors.orange, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _isSignUp = true;
                                  _noAccountFound = false;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange,
                                side: const BorderSide(color: Colors.orange),
                              ),
                              child: const Text('Create an Account'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_isSignUp ? 'Sign Up' : 'Sign In'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                        _error = null;
                        _noAccountFound = false;
                        _resetEmailSent = false;
                      });
                    },
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Sign in'
                          : 'Don\'t have an account? Sign up',
                    ),
                  ),
                  if (!_isSignUp) ...[  
                    TextButton(
                      onPressed: _isLoading ? null : _forgotPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ],
                  if (_resetEmailSent) ...[  
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.green),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Password reset email sent! Check your inbox.',
                              style: TextStyle(color: Colors.green, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}