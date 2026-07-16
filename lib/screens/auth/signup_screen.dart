import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../utils/dob_formatter.dart';
import 'dart:io';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController     = TextEditingController();
  final _emailController    = TextEditingController();
  final _phoneController    = TextEditingController();
  final _dobController      = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();

  final AuthService _authService = AuthService();

  bool _obscurePassword  = true;
  bool _obscureConfirm   = true;
  bool _termsAccepted    = false;
  bool _isLoading        = false;

  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _dobError;
  String? _passwordError;
  String? _confirmError;

  String? _selectedState;
  String? _selectedQualification;
  // Gender is now nullable with NO default — Apple Guideline
  // 5.1.1(v): this must be optional, not silently pre-filled with
  // 'Male' for every account that doesn't explicitly change it.
  String? _selectedGender;

  final List<String> _states = [
    'Punjab', 'Haryana', 'Himachal Pradesh', 'Delhi',
    'Uttar Pradesh', 'Rajasthan', 'Bihar', 'Uttarakhand',
    'Madhya Pradesh', 'Maharashtra', 'Gujarat', 'Other'
  ];
  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _simpleQuals = [
    '8th Pass', '10th Pass (Matric)', '12th Pass (Inter)',
    'ITI', 'Diploma (Engineering)', 'Diploma (Non-Engineering)',
  ];
  final List<String> _graduateOptions = [
    'B.A (Arts)', 'B.Sc (Science)', 'B.Com (Commerce)',
    'B.Tech / B.E (Engineering)', 'B.C.A (Computer)',
    'B.B.A (Business)', 'B.Ed (Teaching)', 'B.Sc Nursing',
    'B.Pharma', 'B.Sc Agriculture', 'BDS (Dental)',
    'MBBS (Medical)', 'LLB (Law)', 'B.Arch (Architecture)',
    'B.Sc (IT)', 'Other Graduate',
  ];
  final List<String> _postGraduateOptions = [
    'M.A (Arts)', 'M.Sc (Science)', 'M.Com (Commerce)',
    'M.Tech / M.E (Engineering)', 'M.C.A (Computer)',
    'M.B.A (Business)', 'M.Ed (Teaching)', 'M.Sc Nursing',
    'M.Pharma', 'LLM (Law)', 'PGDM', 'Other Post Graduate',
  ];

  @override
  void dispose() {
    _nameController.dispose(); _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose(); _passwordController.dispose();
    _confirmController.dispose();
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

  bool _isValidEmail(String email) =>
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);

  // DOB is now OPTIONAL — Apple Guideline 5.1.1(v): date of birth is
  // not core to ExamTrack's function (exam tracking), so it must not
  // block account creation. An empty DOB is valid; if the user DOES
  // enter something, we still validate the format/plausibility so we
  // don't save garbage data.
  String? _validateDOB(String dob) {
    if (dob.isEmpty) return null; // optional — empty is fine
    if (dob.length != 10) return 'Enter complete date DD/MM/YYYY';
    final parts = dob.split('/');
    if (parts.length != 3) return 'Use format DD/MM/YYYY';
    final day   = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year  = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return 'Invalid date';
    if (month < 1 || month > 12) return 'Month must be 01-12';
    if (day < 1 || day > 31) return 'Day must be 01-31';
    final currentYear = DateTime.now().year;
    if (year < 1900 || year > currentYear) return 'Enter a valid birth year';
    final daysInMonth = [0,31,28,31,30,31,30,31,31,30,31,30,31];
    final isLeap = (year%4==0 && year%100!=0) || (year%400==0);
    final maxDays = (month==2 && isLeap) ? 29 : daysInMonth[month];
    if (day > maxDays) return 'Invalid date for this month';
    try {
      final date = DateTime(year, month, day);
      if (date.day != day || date.month != month || date.year != year) return 'Invalid date';
      final age = DateTime.now().difference(date).inDays ~/ 365;
      if (age < 14) return 'You must be at least 14 years old';
      if (age > 100) return 'Enter a valid date of birth';
    } catch (_) { return 'Invalid date'; }
    return null;
  }

  bool _validateAll() {
    bool valid = true;
    setState(() {
      // Name
      if (_nameController.text.trim().length < 3) {
        _nameError = 'Enter your full name (min 3 characters)';
        valid = false;
      } else { _nameError = null; }

      // Email
      final email = _emailController.text.trim();
      if (email.isEmpty) {
        _emailError = 'Please enter your email address';
        valid = false;
      } else if (!_isValidEmail(email)) {
        _emailError = 'Enter a valid email (e.g. name@gmail.com)';
        valid = false;
      } else { _emailError = null; }

      // Phone (optional)
      if (_phoneController.text.isNotEmpty && _phoneController.text.length != 10) {
        _phoneError = 'Phone number must be 10 digits';
        valid = false;
      } else { _phoneError = null; }

      // DOB (optional — only validated if something was entered)
      _dobError = _validateDOB(_dobController.text.trim());
      if (_dobError != null) valid = false;

      // Password
      if (_passwordController.text.isEmpty) {
        _passwordError = 'Please enter a password';
        valid = false;
      } else if (_passwordController.text.length < 6) {
        _passwordError = 'Password must be at least 6 characters';
        valid = false;
      } else { _passwordError = null; }

      // Confirm Password
      if (_confirmController.text.isEmpty) {
        _confirmError = 'Please confirm your password';
        valid = false;
      } else if (_confirmController.text != _passwordController.text) {
        _confirmError = 'Passwords do not match';
        valid = false;
      } else { _confirmError = null; }
    });
    return valid;
  }

  String _getFriendlyError(String error) {
    if (error.contains('email-already-in-use')) {
      return 'This email is already registered. Please login!';
    } else if (error.contains('weak-password')) {
      return 'Password is too weak. Use at least 6 characters!';
    } else if (error.contains('network-request-failed')) {
      return 'No internet connection. Please check your network!';
    }
    return 'Something went wrong. Please try again!';
  }

  Future<void> _signup() async {
    if (!_validateAll()) return;
    if (!_termsAccepted) {
      _showSnack('Please accept Terms & Privacy Policy', const Color(0xFFEF4444));
      return;
    }
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

    final result = await _authService.signUpWithEmail(
      fullName:      _nameController.text.trim(),
      email:         _emailController.text.trim(),
      password:      _passwordController.text,
      phone:         _phoneController.text.trim(),
      // Pass null instead of an empty string when left blank —
      // matches AuthService's optional dob/gender parameters.
      dob:           _dobController.text.trim().isEmpty
          ? null : _dobController.text.trim(),
      state:         _selectedState ?? 'Punjab',
      qualification: _selectedQualification ?? 'Graduate',
      gender:        _selectedGender,
    );

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      _showSnack(_getFriendlyError(result['error'] ?? ''), const Color(0xFFEF4444));
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
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

  // ── Sign in with Apple ──────────────────────────────────
  // Mirrors _signInWithGoogle() exactly above, same pattern used on
  // login_screen.dart's _signInWithApple() too.
  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    final result = await _authService.signInWithApple();
    setState(() => _isLoading = false);
    if (result['success'] == true) {
      if (result['profileComplete'] == false) {
        Navigator.pushReplacementNamed(context, '/profile-setup');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else if (result['error'] != 'cancelled') {
      _showSnack('Apple sign-in failed. Please try again.', const Color(0xFFEF4444));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(child: Column(children: [
        _buildHeader(),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 60),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Full Name ──────────────────────────────
            _buildField(controller: _nameController,
                label: 'Full Name', icon: Icons.person_outline,
                inputType: TextInputType.name, errorText: _nameError,
                onChanged: (_) => setState(() => _nameError = null)),
            const SizedBox(height: 14),

            // ── Email ──────────────────────────────────
            _buildField(controller: _emailController,
                label: 'Email Address', icon: Icons.email_outlined,
                inputType: TextInputType.emailAddress, errorText: _emailError,
                onChanged: (v) => setState(() {
                  _emailError = v.isNotEmpty && !_isValidEmail(v)
                      ? 'Enter a valid email (e.g. name@gmail.com)' : null;
                })),
            const SizedBox(height: 14),

            // ── Phone (optional) ───────────────────────
            _buildField(controller: _phoneController,
                label: 'Phone Number (Optional)',
                icon: Icons.phone_outlined,
                inputType: TextInputType.number, errorText: _phoneError,
                formatters: [FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10)],
                onChanged: (v) => setState(() {
                  _phoneError = v.isNotEmpty && v.length != 10
                      ? 'Must be 10 digits' : null;
                })),
            const SizedBox(height: 4),
            Text('Optional — used for account recovery',
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade400)),
            const SizedBox(height: 14),

            // ── DOB (Optional) ─────────────────────────
            _buildField(controller: _dobController,
                label: 'Date of Birth (DD/MM/YYYY) — Optional',
                icon: Icons.cake_outlined,
                inputType: TextInputType.number, errorText: _dobError,
                formatters: [DOBInputFormatter(), LengthLimitingTextInputFormatter(10)],
                onChanged: (v) => setState(() {
                  _dobError = v.length == 10 ? _validateDOB(v) : null;
                })),
            const SizedBox(height: 14),

            // ── Gender (Optional) ──────────────────────
            Text('Gender (Optional)', style: GoogleFonts.poppins(fontSize: 13,
                fontWeight: FontWeight.w500, color: const Color(0xFF374151))),
            const SizedBox(height: 8),
            Row(children: _genders.map((g) {
              final sel = _selectedGender == g;
              return Expanded(child: GestureDetector(
                // Tapping an already-selected option deselects it —
                // this is the genuine "skip/prefer not to say" path,
                // since there's no separate skip button in this
                // compact 3-button row layout.
                onTap: () => setState(
                        () => _selectedGender = sel ? null : g),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: sel ? const Color(0xFF1565C0) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sel
                        ? const Color(0xFF1565C0) : const Color(0xFFE5E7EB)),
                  ),
                  child: Text(g, textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 13,
                          color: sel ? Colors.white : const Color(0xFF374151),
                          fontWeight: FontWeight.w500)),
                ),
              ));
            }).toList()),
            const SizedBox(height: 14),

            // ── State ──────────────────────────────────
            _buildDropdown(value: _selectedState,
                hint: 'Select Your State',
                icon: Icons.location_on_outlined,
                items: _states,
                onChanged: (v) => setState(() => _selectedState = v)),
            const SizedBox(height: 14),

            // ── Qualification ──────────────────────────
            _buildQualPicker(),
            const SizedBox(height: 14),

            // ── Password ───────────────────────────────
            _buildField(controller: _passwordController,
                label: 'Password', icon: Icons.lock_outlined,
                obscure: _obscurePassword, errorText: _passwordError,
                onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                onChanged: (_) => setState(() => _passwordError = null)),
            const SizedBox(height: 14),

            // ── Confirm Password ───────────────────────
            _buildField(controller: _confirmController,
                label: 'Confirm Password', icon: Icons.lock_outlined,
                obscure: _obscureConfirm, errorText: _confirmError,
                onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
                onChanged: (v) => setState(() {
                  _confirmError = v != _passwordController.text
                      ? 'Passwords do not match' : null;
                })),
            const SizedBox(height: 16),

            // ── Terms ──────────────────────────────────
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Checkbox(value: _termsAccepted,
                  onChanged: (v) => setState(() => _termsAccepted = v!),
                  activeColor: const Color(0xFF1565C0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
              Expanded(child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: RichText(text: TextSpan(
                  text: 'I agree to the ',
                  style: GoogleFonts.poppins(color: const Color(0xFF6B7280), fontSize: 13),
                  children: [
                    TextSpan(text: 'Terms of Service',
                        style: GoogleFonts.poppins(color: const Color(0xFF1565C0),
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    TextSpan(text: ' and ',
                        style: GoogleFonts.poppins(color: const Color(0xFF6B7280), fontSize: 13)),
                    TextSpan(text: 'Privacy Policy',
                        style: GoogleFonts.poppins(color: const Color(0xFF1565C0),
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                )),
              )),
            ]),
            const SizedBox(height: 24),

            // ── Create Account button ──────────────────
            SizedBox(width: double.infinity, height: 54,
              child: ElevatedButton(
                onPressed: (_isLoading || !_termsAccepted) ? null : _signup,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    disabledBackgroundColor: const Color(0xFF9CA3AF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : Text('Create Account', style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 20),

            // ── OR divider ─────────────────────────────
            Row(children: [
              const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('OR', style: GoogleFonts.poppins(
                      color: const Color(0xFF9CA3AF), fontSize: 13))),
              const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
            ]),
            const SizedBox(height: 20),

            // ── Google button ──────────────────────────
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
            const SizedBox(height: 14),

            // ── Apple button ────────────────────────────
            // Required by App Store Guideline 4.8: since Google Sign-In
            // is offered, Sign in with Apple must be offered as an
            // equivalent option.
            SizedBox(width: double.infinity, height: 54,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _signInWithApple,
                icon: const Icon(Icons.apple, size: 26, color: Colors.black),
                label: Text('Continue with Apple', style: GoogleFonts.poppins(
                    color: const Color(0xFF1A1A2E), fontSize: 15,
                    fontWeight: FontWeight.w500)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    backgroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ])),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          left: 20, right: 20, bottom: 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Logo row
        Row(children: [
          Container(width: 44, height: 44,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.school, color: Colors.white, size: 24)),
          const SizedBox(width: 12),
          Text('ExamTrack', style: GoogleFonts.poppins(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 20),
        Text('Create Account', style: GoogleFonts.poppins(
            color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
        Text('Join ExamTrack — Never miss a govt job!',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 16),
        // Already a user — visible at top
        GestureDetector(
          onTap: () => Navigator.pushReplacementNamed(context, '/login'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.login, color: Colors.white, size: 15),
              const SizedBox(width: 6),
              Text('Already a User? Login', style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildQualPicker() {
    return GestureDetector(
      onTap: _showQualPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Row(children: [
          const Icon(Icons.school_outlined, color: Color(0xFF1565C0), size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(
            _selectedQualification ?? 'Select Qualification',
            style: GoogleFonts.poppins(fontSize: 14,
                color: _selectedQualification == null
                    ? const Color(0xFF6B7280) : const Color(0xFF1A1A2E)),
          )),
          const Icon(Icons.keyboard_arrow_down, color: Color(0xFF6B7280)),
        ]),
      ),
    );
  }

  void _showQualPicker() {
    String? expandedGroup;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.all(20),
                child: Text('Select Qualification', style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700))),
            const Divider(height: 1),
            Expanded(child: ListView(children: [
              ..._simpleQuals.map((q) => _qualItem(q)),
              _qualHeader('Graduate', Icons.school_outlined, expandedGroup == 'grad',
                  _graduateOptions.contains(_selectedQualification),
                      () => setSheet(() => expandedGroup = expandedGroup == 'grad' ? null : 'grad')),
              if (expandedGroup == 'grad')
                ..._graduateOptions.map((q) => _qualItem(q, sub: true)),
              _qualHeader('Post Graduate', Icons.workspace_premium_outlined, expandedGroup == 'pg',
                  _postGraduateOptions.contains(_selectedQualification),
                      () => setSheet(() => expandedGroup = expandedGroup == 'pg' ? null : 'pg')),
              if (expandedGroup == 'pg')
                ..._postGraduateOptions.map((q) => _qualItem(q, sub: true)),
              _qualItem('Ph.D'),
              const SizedBox(height: 20),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _qualItem(String q, {bool sub = false}) {
    final sel = _selectedQualification == q;
    return InkWell(
      onTap: () { setState(() => _selectedQualification = q); Navigator.pop(context); },
      child: Container(
        padding: EdgeInsets.only(left: sub ? 48 : 20, right: 20, top: 14, bottom: 14),
        decoration: BoxDecoration(
            color: sel ? const Color(0xFFE8F0FE) : Colors.transparent,
            border: const Border(bottom: BorderSide(color: Color(0xFFF5F5F5)))),
        child: Row(children: [
          if (sub) const Icon(Icons.subdirectory_arrow_right,
              color: Color(0xFF9CA3AF), size: 16),
          if (sub) const SizedBox(width: 8),
          Expanded(child: Text(q, style: GoogleFonts.poppins(fontSize: 14,
              color: sel ? const Color(0xFF1565C0) : const Color(0xFF1A1A2E),
              fontWeight: sel ? FontWeight.w600 : FontWeight.normal))),
          if (sel) const Icon(Icons.check, color: Color(0xFF1565C0), size: 18),
        ]),
      ),
    );
  }

  Widget _qualHeader(String label, IconData icon, bool expanded,
      bool selected, VoidCallback onTap) {
    return InkWell(onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: const Color(0xFFF0F4FF),
        child: Row(children: [
          Icon(icon, color: const Color(0xFF1565C0), size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1565C0)))),
          if (selected) const Icon(Icons.check_circle, color: Color(0xFF1565C0), size: 18),
          const SizedBox(width: 8),
          Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: const Color(0xFF1565C0)),
        ]),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller, required String label,
    required IconData icon, TextInputType inputType = TextInputType.text,
    List<TextInputFormatter>? formatters, bool obscure = false,
    VoidCallback? onToggleObscure, String? errorText, Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller, keyboardType: inputType,
      obscureText: obscure, inputFormatters: formatters, onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: errorText != null
            ? const Color(0xFFEF4444) : const Color(0xFF6B7280)),
        prefixIcon: Icon(icon, color: errorText != null
            ? const Color(0xFFEF4444) : const Color(0xFF1565C0)),
        suffixIcon: onToggleObscure != null
            ? GestureDetector(onTap: onToggleObscure,
            child: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: const Color(0xFF6B7280))) : null,
        filled: true, fillColor: Colors.white,
        errorText: errorText,
        errorStyle: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFEF4444)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: errorText != null
                ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: errorText != null
                ? const Color(0xFFEF4444) : const Color(0xFF1565C0), width: 2)),
      ),
      style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF1A1A2E)),
    );
  }

  Widget _buildDropdown({required String? value, required String hint,
    required IconData icon, required List<String> items,
    required Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB))),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: value, isExpanded: true,
        hint: Row(children: [
          Icon(icon, color: const Color(0xFF1565C0), size: 20),
          const SizedBox(width: 12),
          Text(hint, style: GoogleFonts.poppins(
              color: const Color(0xFF6B7280), fontSize: 14)),
        ]),
        style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF1A1A2E)),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
      )),
    );
  }
}