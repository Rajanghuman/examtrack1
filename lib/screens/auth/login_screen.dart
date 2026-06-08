import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import 'dart:io';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _getFriendlyError(String error) {
    switch (error) {
      case 'user-not-found':
        return 'No account found with this email. Please sign up!';
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Wrong email or password. Please try again!';
      case 'invalid-email':
        return 'Invalid email address. Please check and try again!';
      case 'user-disabled':
        return 'This account has been disabled. Contact support!';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later!';
      case 'network-request-failed':
        return 'No internet connection. Please check your network!';
      case 'email-not-verified':
        return 'Please verify your email first. Check your inbox!';
      default:
        return 'Wrong email or password. Please try again!';
    }
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      _showSnack('Please enter email and password',
          const Color(0xFFEF4444));
      return;
    }

    setState(() => _isLoading = true);

    // Instant internet check before Firebase call
    try {
      final check = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      if (check.isEmpty || check[0].rawAddress.isEmpty) {
        setState(() => _isLoading = false);
        _showSnack('No internet connection. Please check your network!',
            const Color(0xFFEF4444));
        return;
      }
    } catch (_) {
      setState(() => _isLoading = false);
      _showSnack('No internet connection. Please check your network!',
          const Color(0xFFEF4444));
      return;
    }

    final result = await _authService.loginWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (result['error'] == 'email-not-verified') {
      // Show verification dialog with resend option
      _showEmailNotVerifiedDialog(result['email'] ?? '');
    } else {
      _showSnack(
        _getFriendlyError(result['error'] ?? ''),
        const Color(0xFFEF4444),
      );
    }
  }

  void _showEmailNotVerifiedDialog(String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Column(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mark_email_unread_outlined,
                color: Color(0xFFF59E0B), size: 32),
          ),
          const SizedBox(height: 12),
          Text('Email Not Verified',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'Please verify your email address before logging in.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 13, color: const Color(0xFF6B7280)),
          ),
          const SizedBox(height: 8),
          Text(email,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1565C0))),
          const SizedBox(height: 12),
          Text(
            'Check your inbox or spam folder for the verification link.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 13, color: const Color(0xFF6B7280)),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.poppins(
                    color: const Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final res = await _authService.resendVerificationEmail(
                email: _emailController.text.trim(),
                password: _passwordController.text,
              );
              if (res['success'] == true) {
                _showSnack(
                    'Verification email resent! Check your inbox.',
                    const Color(0xFF10B981));
              } else {
                _showSnack(
                    'Could not resend. Please try again.',
                    const Color(0xFFEF4444));
              }
            },
            child: Text('Resend Email',
                style: GoogleFonts.poppins(
                    color: const Color(0xFF1565C0),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _forgotPassword() async {
    if (_emailController.text.isEmpty) {
      _showSnack(
          'Please enter your email first', const Color(0xFFF59E0B));
      return;
    }
    final result = await _authService
        .forgotPassword(_emailController.text.trim());
    if (result['success'] == true) {
      _showSnack('Password reset email sent! Check your inbox or spam folder.',
          const Color(0xFF10B981));
    } else {
      _showSnack(
        _getFriendlyError(result['error'] ?? ''),
        const Color(0xFFEF4444),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    // Responsive header height based on screen size
    final headerHeight = screenHeight < 700 ? 200.0 : 260.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // ── Blue header ──────────────────────────────
            Container(
              height: headerHeight,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 70, height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.school,
                          color: Colors.white, size: 38),
                    ),
                    const SizedBox(height: 12),
                    Text('ExamTrack',
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontSize: 26,
                            fontWeight: FontWeight.w800)),
                    Text('Your Government Job Guide',
                        style: GoogleFonts.poppins(
                            color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Form ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome Back!',
                      style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1A2E))),
                  Text('Sign in to continue',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF6B7280))),

                  const SizedBox(height: 24),

                  // Email
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: GoogleFonts.poppins(
                          color: const Color(0xFF6B7280)),
                      prefixIcon: const Icon(Icons.email_outlined,
                          color: Color(0xFF1565C0)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: Color(0xFF1565C0), width: 2),
                      ),
                    ),
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),

                  const SizedBox(height: 16),

                  // Password
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: GoogleFonts.poppins(
                          color: const Color(0xFF6B7280)),
                      prefixIcon: const Icon(Icons.lock_outlined,
                          color: Color(0xFF1565C0)),
                      suffixIcon: GestureDetector(
                        onTap: () => setState(() =>
                        _obscurePassword = !_obscurePassword),
                        child: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: Color(0xFF1565C0), width: 2),
                      ),
                    ),
                    style: GoogleFonts.poppins(fontSize: 14),
                    onSubmitted: (_) => _login(),
                  ),

                  const SizedBox(height: 10),

                  // Forgot password
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: _forgotPassword,
                      child: Text('Forgot Password?',
                          style: GoogleFonts.poppins(
                              color: const Color(0xFF1565C0),
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Login button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        disabledBackgroundColor:
                        const Color(0xFF9CA3AF),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)
                          : Text('Login',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // OR divider
                  Row(
                    children: [
                      const Expanded(
                          child: Divider(color: Color(0xFFE5E7EB))),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16),
                        child: Text('OR',
                            style: GoogleFonts.poppins(
                                color: const Color(0xFF9CA3AF),
                                fontSize: 13)),
                      ),
                      const Expanded(
                          child: Divider(color: Color(0xFFE5E7EB))),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Google button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showSnack('Google sign-in coming soon!',
                            const Color(0xFF1565C0));
                      },
                      icon: const Icon(Icons.g_mobiledata,
                          size: 28, color: Color(0xFF1565C0)),
                      label: Text('Continue with Google',
                          style: GoogleFonts.poppins(
                              color: const Color(0xFF1A1A2E),
                              fontSize: 15,
                              fontWeight: FontWeight.w500)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Sign up link
                  Center(
                    child: GestureDetector(
                      onTap: () =>
                          Navigator.pushNamed(context, '/signup'),
                      child: RichText(
                        text: TextSpan(
                          text: "Don't have an account? ",
                          style: GoogleFonts.poppins(
                              color: const Color(0xFF6B7280),
                              fontSize: 14),
                          children: [
                            TextSpan(
                              text: 'Sign Up',
                              style: GoogleFonts.poppins(
                                  color: const Color(0xFF1565C0),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}