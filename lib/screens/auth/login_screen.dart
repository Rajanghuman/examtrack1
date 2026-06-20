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
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _obscurePassword = true;
  bool _isLoading       = false;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(color: Colors.white)),
      backgroundColor: color, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _getFriendlyError(String error) {
    switch (error) {
      case 'user-not-found':       return 'No account found with this email. Please sign up!';
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS': return 'Wrong email or password. Please try again!';
      case 'invalid-email':        return 'Invalid email address!';
      case 'user-disabled':        return 'Account disabled. Contact support!';
      case 'too-many-requests':    return 'Too many attempts. Try again later!';
      case 'network-request-failed': return 'No internet connection!';
      default: return 'Wrong email or password. Please try again!';
    }
  }

  Future<void> _login() async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text;
    bool valid = true;

    setState(() {
      if (email.isEmpty) {
        _emailError = 'Please enter your email';
        valid = false;
      } else { _emailError = null; }

      if (password.isEmpty) {
        _passwordError = 'Please enter your password';
        valid = false;
      } else { _passwordError = null; }
    });

    if (!valid) return;
    setState(() => _isLoading = true);

    try {
      final check = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      if (check.isEmpty || check[0].rawAddress.isEmpty) {
        setState(() => _isLoading = false);
        _showSnack('No internet connection!', const Color(0xFFEF4444));
        return;
      }
    } catch (_) {
      setState(() => _isLoading = false);
      _showSnack('No internet connection!', const Color(0xFFEF4444));
      return;
    }

    final result = await _authService.loginWithEmail(
        email: email, password: password);
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      _showSnack(_getFriendlyError(result['error'] ?? ''), const Color(0xFFEF4444));
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _emailError = 'Enter your email first then tap Forgot Password');
      return;
    }
    setState(() => _isLoading = true);
    final result = await _authService.forgotPassword(email);
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      _showSnack('Password reset link sent! Check your inbox.', const Color(0xFF10B981));
    } else {
      _showSnack('Email not found. Please check and try again.', const Color(0xFFEF4444));
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final check = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      if (check.isEmpty || check[0].rawAddress.isEmpty) {
        setState(() => _isLoading = false);
        _showSnack('No internet connection!', const Color(0xFFEF4444));
        return;
      }
    } catch (_) {
      setState(() => _isLoading = false);
      _showSnack('No internet connection!', const Color(0xFFEF4444));
      return;
    }

    final result = await _authService.signInWithGoogle();
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      if (result['profileComplete'] == false) {
        Navigator.pushReplacementNamed(context, '/profile-setup');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else if (result['error'] != 'cancelled') {
      _showSnack('Google sign-in failed. Please try again.', const Color(0xFFEF4444));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final headerHeight = screenHeight < 700 ? 200.0 : 260.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(children: [

          // ── Header ──────────────────────────────────
          Container(
            height: headerHeight, width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
            ),
            child: SafeArea(child: Column(
                mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 70, height: 70,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.school, color: Colors.white, size: 38)),
              const SizedBox(height: 12),
              Text('ExamTrack', style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
              Text('Your Government Job Guide', style: GoogleFonts.poppins(
                  color: Colors.white70, fontSize: 13)),
            ])),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              Text('Welcome Back!', style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A2E))),
              Text('Sign in to continue', style: GoogleFonts.poppins(
                  fontSize: 13, color: const Color(0xFF6B7280))),
              const SizedBox(height: 24),

              // ── Email ────────────────────────────────
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() => _emailError = null),
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  labelStyle: GoogleFonts.poppins(color: _emailError != null
                      ? const Color(0xFFEF4444) : const Color(0xFF6B7280)),
                  prefixIcon: Icon(Icons.email_outlined, color: _emailError != null
                      ? const Color(0xFFEF4444) : const Color(0xFF1565C0)),
                  filled: true, fillColor: Colors.white,
                  errorText: _emailError,
                  errorStyle: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFEF4444)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _emailError != null
                          ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2)),
                ),
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              const SizedBox(height: 14),

              // ── Password ─────────────────────────────
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                onChanged: (_) => setState(() => _passwordError = null),
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: GoogleFonts.poppins(color: _passwordError != null
                      ? const Color(0xFFEF4444) : const Color(0xFF6B7280)),
                  prefixIcon: Icon(Icons.lock_outlined, color: _passwordError != null
                      ? const Color(0xFFEF4444) : const Color(0xFF1565C0)),
                  suffixIcon: GestureDetector(
                      onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                      child: Icon(_obscurePassword
                          ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: const Color(0xFF6B7280))),
                  filled: true, fillColor: Colors.white,
                  errorText: _passwordError,
                  errorStyle: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFEF4444)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2)),
                ),
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              const SizedBox(height: 10),

              // ── Forgot Password ───────────────────────
              Align(alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _forgotPassword,
                  child: Text('Forgot Password?', style: GoogleFonts.poppins(
                      color: const Color(0xFF1565C0), fontSize: 13,
                      fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(height: 24),

              // ── Login button ──────────────────────────
              SizedBox(width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      disabledBackgroundColor: const Color(0xFF9CA3AF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : Text('Login', style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 20),

              // ── OR divider ────────────────────────────
              Row(children: [
                const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('OR', style: GoogleFonts.poppins(
                        color: const Color(0xFF9CA3AF), fontSize: 13))),
                const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
              ]),
              const SizedBox(height: 20),

              // ── Google button ─────────────────────────
              SizedBox(width: double.infinity, height: 54,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  icon: const Icon(Icons.g_mobiledata, size: 28, color: Color(0xFF1565C0)),
                  label: Text('Continue with Google', style: GoogleFonts.poppins(
                      color: const Color(0xFF1A1A2E), fontSize: 15,
                      fontWeight: FontWeight.w500)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      backgroundColor: Colors.white),
                ),
              ),
              const SizedBox(height: 20),

              // ── New user button ───────────────────────
              SizedBox(width: double.infinity, height: 54,
                child: OutlinedButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/signup'),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1565C0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      backgroundColor: Colors.transparent),
                  child: Text('New User? Create Account', style: GoogleFonts.poppins(
                      color: const Color(0xFF1565C0), fontSize: 15,
                      fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
