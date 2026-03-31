import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../main.dart';
import 'guest_onboarding_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;
  String? _error;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _clearMessages() {
    _error = null;
    _successMessage = null;
  }

  Future<void> _submitEmailForm() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;
    setState(() { _isLoading = true; _clearMessages(); });
    try {
      if (_isSignUp) {
        await context.read<AuthService>().signUpWithEmail(
          _emailController.text, _passwordController.text);
      } else {
        await context.read<AuthService>().signInWithEmail(
          _emailController.text, _passwordController.text);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email first, then tap Forgot Password.');
      return;
    }
    setState(() { _isLoading = true; _clearMessages(); });
    try {
      await context.read<AuthService>().sendPasswordResetEmail(email);
      if (mounted) setState(() => _successMessage = 'Password reset email sent to $email.');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeProvider.toggleTheme(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '👋 Welcome to DailyFrase!',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your daily dose of language learning.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Error / success messages
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
                          Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 14))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_successMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_successMessage!, style: const TextStyle(color: Colors.green, fontSize: 14))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Please enter your email.';
                      if (!v.contains('@')) return 'Please enter a valid email.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please enter your password.';
                      if (_isSignUp && v.length < 6) return 'Password must be at least 6 characters.';
                      return null;
                    },
                  ),

                  // Forgot password
                  if (!_isSignUp) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _forgotPassword,
                        child: const Text('Forgot password?'),
                      ),
                    ),
                  ] else
                    const SizedBox(height: 8),

                  // Sign in / Sign up button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitEmailForm,
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_isSignUp ? 'Create Account' : 'Sign In', style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Toggle sign in / sign up
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_isSignUp ? 'Already have an account?' : "Don't have an account?",
                          style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6))),
                      TextButton(
                        onPressed: () => setState(() { _isSignUp = !_isSignUp; _clearMessages(); }),
                        child: Text(_isSignUp ? 'Sign In' : 'Sign Up'),
                      ),
                    ],
                  ),

                    // Continue as Guest button
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.person_outline),
                        label: const Text('Continue as Guest', style: TextStyle(fontSize: 16)),
                        onPressed: _isLoading
                            ? null
                            : () async {
                                // Navigate to guest onboarding page
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const GuestOnboardingPage(),
                                  ),
                                );
                              },
                      ),
                    ),


                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
