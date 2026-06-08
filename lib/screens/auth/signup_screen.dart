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
  final TextEditingController _nameController     = TextEditingController();
  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _phoneController    = TextEditingController();
  final TextEditingController _dobController      = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController  = TextEditingController();

  final AuthService _authService = AuthService();

  bool _obscurePassword     = true;
  bool _obscureConfirm      = true;
  bool _termsAccepted       = false;
  bool _isLoading           = false;
  String? _selectedState;
  String? _selectedQualification;

  // ── Error messages ─────────────────────────────────────
  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _dobError;
  String? _passwordError;
  String? _confirmError;

  final List<String> _states = [
    'Punjab', 'Haryana', 'Himachal Pradesh', 'Delhi',
    'Uttar Pradesh', 'Rajasthan', 'Bihar', 'Uttarakhand',
    'Madhya Pradesh', 'Maharashtra', 'Gujarat', 'Other'
  ];

  final List<String> _simpleQuals = [
    '8th Pass',
    '10th Pass (Matric)',
    '12th Pass (Inter)',
    'ITI',
    'Diploma (Engineering)',
    'Diploma (Non-Engineering)',
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
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
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

  // ── Email validation ───────────────────────────────────
  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(email);
  }

  // ── DOB validation ─────────────────────────────────────
  String? _validateDOB(String dob) {
    if (dob.isEmpty) return 'Please enter your date of birth';
    if (dob.length != 10) return 'Enter complete date DD/MM/YYYY';

    final parts = dob.split('/');
    if (parts.length != 3) return 'Invalid date format. Use DD/MM/YYYY';

    final day   = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year  = int.tryParse(parts[2]);

    if (day == null || month == null || year == null) {
      return 'Invalid date. Use numbers only!';
    }

    // ── Validate month FIRST ────────────────────────────
    if (month < 1 || month > 12) {
      return 'Month must be between 01 and 12!';
    }

    // ── Validate day ────────────────────────────────────
    if (day < 1 || day > 31) {
      return 'Day must be between 01 and 31!';
    }

    // ── Validate year ───────────────────────────────────
    final currentYear = DateTime.now().year;
    if (year < 1900 || year > currentYear) {
      return 'Enter a valid birth year (1900-$currentYear)!';
    }

    // ── Check days in month (with leap year) ────────────
    final daysInMonth = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    // Check leap year for February
    final isLeapYear = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
    final maxDays = (month == 2 && isLeapYear) ? 29 : daysInMonth[month];

    if (day > maxDays) {
      if (month == 2) {
        return isLeapYear
            ? 'February $year has only 29 days!'
            : 'February $year has only 28 days!';
      }
      return 'Month $month has only $maxDays days!';
    }

    // ── Validate using DateTime (catches all invalid dates) ──
    try {
      final date = DateTime(year, month, day);
      // If DateTime normalizes the date it was invalid
      if (date.day != day || date.month != month || date.year != year) {
        return 'Invalid date. Please check again!';
      }
    } catch (e) {
      return 'Invalid date. Please check again!';
    }

    // ── Age validation ──────────────────────────────────
    final dob2 = DateTime(year, month, day);
    final age = DateTime.now().difference(dob2).inDays ~/ 365;
    if (age < 14) {
      return 'You must be at least 14 years old!';
    }
    if (age > 100) {
      return 'Please enter a valid date of birth!';
    }

    return null; // ✅ Valid
  }

  // ── Validate all fields ────────────────────────────────
  bool _validateAll() {
    bool isValid = true;

    setState(() {
      // Name
      if (_nameController.text.trim().isEmpty) {
        _nameError = 'Please enter your full name';
        isValid = false;
      } else if (_nameController.text.trim().length < 3) {
        _nameError = 'Name must be at least 3 characters';
        isValid = false;
      } else {
        _nameError = null;
      }

      // Email
      if (_emailController.text.trim().isEmpty) {
        _emailError = 'Please enter your email address';
        isValid = false;
      } else if (!_isValidEmail(_emailController.text.trim())) {
        _emailError = 'Please enter a valid email (e.g. name@gmail.com)';
        isValid = false;
      } else {
        _emailError = null;
      }

      // Phone
      if (_phoneController.text.isNotEmpty &&
          _phoneController.text.length != 10) {
        _phoneError = 'Phone number must be exactly 10 digits';
        isValid = false;
      } else {
        _phoneError = null;
      }

      // DOB
      final dobError = _validateDOB(_dobController.text.trim());
      if (dobError != null) {
        _dobError = dobError;
        isValid = false;
      } else {
        _dobError = null;
      }

      // Password
      if (_passwordController.text.isEmpty) {
        _passwordError = 'Please enter a password';
        isValid = false;
      } else if (_passwordController.text.length < 6) {
        _passwordError = 'Password must be at least 6 characters';
        isValid = false;
      } else {
        _passwordError = null;
      }

      // Confirm password
      if (_confirmController.text.isEmpty) {
        _confirmError = 'Please confirm your password';
        isValid = false;
      } else if (_confirmController.text != _passwordController.text) {
        _confirmError = 'Passwords do not match';
        isValid = false;
      } else {
        _confirmError = null;
      }
    });

    return isValid;
  }

  String _getFriendlyError(String error) {
    if (error.contains('email-already-in-use')) {
      return 'This email is already registered. Please login!';
    } else if (error.contains('invalid-email')) {
      return 'Invalid email address. Please check and try again!';
    } else if (error.contains('weak-password')) {
      return 'Password is too weak. Use at least 6 characters!';
    } else if (error.contains('network-request-failed')) {
      return 'No internet connection. Please check your network!';
    } else {
      return 'Something went wrong. Please try again!';
    }
  }

  Future<void> _signup() async {
    if (!_validateAll()) return;

    if (!_termsAccepted) {
      _showSnack('Please accept Terms & Privacy Policy',
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

    final result = await _authService.signUpWithEmail(
      fullName:      _nameController.text.trim(),
      email:         _emailController.text.trim(),
      password:      _passwordController.text,
      phone:         _phoneController.text.trim(),
      dob:           _dobController.text.trim(),
      state:         _selectedState ?? 'Punjab',
      qualification: _selectedQualification ?? 'Graduate',
    );

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      // Show email verification dialog
      _showVerificationDialog();
    } else {
      _showSnack(
        _getFriendlyError(result['error'] ?? ''),
        const Color(0xFFEF4444),
      );
    }
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Column(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mark_email_unread_outlined,
                color: Color(0xFF10B981), size: 32),
          ),
          const SizedBox(height: 12),
          Text('Verify Your Email',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'A verification link has been sent to:',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 13, color: const Color(0xFF6B7280)),
          ),
          const SizedBox(height: 8),
          Text(
            _emailController.text.trim(),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1565C0)),
          ),
          const SizedBox(height: 12),
          Text(
            'Please verify your email before logging in. Check your inbox and spam folder.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 13, color: const Color(0xFF6B7280)),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: Text('Go to Login',
                style: GoogleFonts.poppins(
                    color: const Color(0xFF1565C0),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 20, right: 20, bottom: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text('Create Account',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 26,
                          fontWeight: FontWeight.w700)),
                  Text('Join ExamTrack and never miss a job!',
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),

            // ── Form ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Full Name
                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person_outline,
                    inputType: TextInputType.name,
                    errorText: _nameError,
                    onChanged: (_) => setState(() => _nameError = null),
                  ),
                  const SizedBox(height: 14),

                  // Email
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    icon: Icons.email_outlined,
                    inputType: TextInputType.emailAddress,
                    errorText: _emailError,
                    onChanged: (v) {
                      setState(() {
                        if (!_isValidEmail(v) && v.isNotEmpty) {
                          _emailError = 'Enter a valid email (e.g. name@gmail.com)';
                        } else {
                          _emailError = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 14),

                  // Phone
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number (10 digits)',
                    icon: Icons.phone_outlined,
                    inputType: TextInputType.number,
                    errorText: _phoneError,
                    formatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    onChanged: (v) {
                      setState(() {
                        if (v.isNotEmpty && v.length != 10) {
                          _phoneError = 'Phone number must be exactly 10 digits';
                        } else {
                          _phoneError = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 14),

                  // DOB
                  _buildTextField(
                    controller: _dobController,
                    label: 'Date of Birth (DD/MM/YYYY)',
                    icon: Icons.cake_outlined,
                    inputType: TextInputType.number,
                    errorText: _dobError,
                    formatters: [DOBInputFormatter()],
                    onChanged: (v) {
                      setState(() {
                        if (v.length == 10) {
                          // Full date entered — validate everything
                          _dobError = _validateDOB(v);
                        } else if (v.length >= 2) {
                          // Validate day as soon as 2 digits entered
                          final parts = v.split('/');
                          if (parts.isNotEmpty) {
                            final day = int.tryParse(parts[0]);
                            if (day != null && (day < 1 || day > 31)) {
                              _dobError = 'Day must be between 01 and 31!';
                              return;
                            }
                          }
                          // Validate month as soon as 5 chars entered (DD/MM)
                          if (v.length >= 5 && parts.length >= 2) {
                            final month = int.tryParse(parts[1]);
                            if (month != null && (month < 1 || month > 12)) {
                              _dobError = 'Month must be between 01 and 12!';
                              return;
                            }
                          }
                          _dobError = null;
                        } else {
                          _dobError = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 14),

                  // State
                  _buildDropdown(
                    value: _selectedState,
                    hint: 'Select Your State',
                    icon: Icons.location_on_outlined,
                    items: _states,
                    onChanged: (v) =>
                        setState(() => _selectedState = v),
                  ),
                  const SizedBox(height: 14),

                  // Qualification
                  _buildQualificationPicker(),
                  const SizedBox(height: 14),

                  // Password
                  _buildTextField(
                    controller: _passwordController,
                    label: 'Password',
                    icon: Icons.lock_outlined,
                    obscure: _obscurePassword,
                    errorText: _passwordError,
                    onChanged: (_) =>
                        setState(() => _passwordError = null),
                    onToggleObscure: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                  ),
                  const SizedBox(height: 14),

                  // Confirm Password
                  _buildTextField(
                    controller: _confirmController,
                    label: 'Confirm Password',
                    icon: Icons.lock_outlined,
                    obscure: _obscureConfirm,
                    errorText: _confirmError,
                    onChanged: (_) =>
                        setState(() => _confirmError = null),
                    onToggleObscure: () => setState(
                            () => _obscureConfirm = !_obscureConfirm),
                  ),
                  const SizedBox(height: 16),

                  // Terms checkbox
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _termsAccepted,
                        onChanged: (v) =>
                            setState(() => _termsAccepted = v!),
                        activeColor: const Color(0xFF1565C0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: RichText(
                            text: TextSpan(
                              text: 'I agree to the ',
                              style: GoogleFonts.poppins(
                                  color: const Color(0xFF6B7280),
                                  fontSize: 13),
                              children: [
                                TextSpan(
                                  text: 'Terms of Service',
                                  style: GoogleFonts.poppins(
                                      color: const Color(0xFF1565C0),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                                TextSpan(
                                  text: ' and ',
                                  style: GoogleFonts.poppins(
                                      color: const Color(0xFF6B7280),
                                      fontSize: 13),
                                ),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: GoogleFonts.poppins(
                                      color: const Color(0xFF1565C0),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Create Account button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: (_isLoading || !_termsAccepted)
                          ? null
                          : _signup,
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
                          : Text('Create Account',
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

                  // Login link
                  Center(
                    child: GestureDetector(
                      onTap: () =>
                          Navigator.pushReplacementNamed(
                              context, '/login'),
                      child: RichText(
                        text: TextSpan(
                          text: 'Already have an account? ',
                          style: GoogleFonts.poppins(
                              color: const Color(0xFF6B7280),
                              fontSize: 14),
                          children: [
                            TextSpan(
                              text: 'Login',
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
    List<TextInputFormatter>? formatters,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    String? errorText,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      obscureText: obscure,
      inputFormatters: formatters,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
            color: errorText != null
                ? const Color(0xFFEF4444)
                : const Color(0xFF6B7280)),
        prefixIcon: Icon(icon,
            color: errorText != null
                ? const Color(0xFFEF4444)
                : const Color(0xFF1565C0)),
        suffixIcon: onToggleObscure != null
            ? GestureDetector(
          onTap: onToggleObscure,
          child: Icon(
            obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: const Color(0xFF6B7280),
          ),
        )
            : null,
        filled: true,
        fillColor: Colors.white,
        errorText: errorText,
        errorStyle: GoogleFonts.poppins(
            fontSize: 11, color: const Color(0xFFEF4444)),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
            const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: errorText != null
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: errorText != null
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF1565C0),
                width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
                color: Color(0xFFEF4444))),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
                color: Color(0xFFEF4444), width: 2)),
      ),
      style: GoogleFonts.poppins(
          fontSize: 14, color: const Color(0xFF1A1A2E)),
    );
  }

  // ── Qualification Picker ───────────────────────────────
  Widget _buildQualificationPicker() {
    return GestureDetector(
      onTap: _showQualificationPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(children: [
          const Icon(Icons.school_outlined,
              color: Color(0xFF1565C0), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _selectedQualification ?? 'Select Qualification',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: _selectedQualification == null
                    ? const Color(0xFF6B7280)
                    : const Color(0xFF1A1A2E),
              ),
            ),
          ),
          const Icon(Icons.keyboard_arrow_down,
              color: Color(0xFF6B7280)),
        ]),
      ),
    );
  }

  void _showQualificationPicker() {
    String? expandedGroup;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(24)),
          ),
          child: Column(children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Select Qualification',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E))),
            ),
            const Divider(height: 1),
            Expanded(child: ListView(children: [
              // Simple options
              ..._simpleQuals.map((q) => _qualItem(q)),
              // Graduate group
              _qualGroupHeader(
                label: 'Graduate',
                icon: Icons.school_outlined,
                isExpanded: expandedGroup == 'grad',
                selected: _graduateOptions.contains(_selectedQualification),
                onTap: () => setSheet(() => expandedGroup =
                expandedGroup == 'grad' ? null : 'grad'),
              ),
              if (expandedGroup == 'grad')
                ..._graduateOptions.map((q) => _qualItem(q, sub: true)),
              // Post Graduate group
              _qualGroupHeader(
                label: 'Post Graduate',
                icon: Icons.workspace_premium_outlined,
                isExpanded: expandedGroup == 'pg',
                selected: _postGraduateOptions.contains(_selectedQualification),
                onTap: () => setSheet(() => expandedGroup =
                expandedGroup == 'pg' ? null : 'pg'),
              ),
              if (expandedGroup == 'pg')
                ..._postGraduateOptions.map((q) => _qualItem(q, sub: true)),
              // PhD
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
      onTap: () {
        setState(() => _selectedQualification = q);
        Navigator.pop(context);
      },
      child: Container(
        padding: EdgeInsets.only(
            left: sub ? 48 : 20, right: 20, top: 14, bottom: 14),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFE8F0FE) : Colors.transparent,
          border: const Border(
              bottom: BorderSide(color: Color(0xFFF5F5F5))),
        ),
        child: Row(children: [
          if (sub) const Icon(Icons.subdirectory_arrow_right,
              color: Color(0xFF9CA3AF), size: 16),
          if (sub) const SizedBox(width: 8),
          Expanded(child: Text(q,
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: sel
                      ? const Color(0xFF1565C0)
                      : const Color(0xFF1A1A2E),
                  fontWeight: sel
                      ? FontWeight.w600
                      : FontWeight.normal))),
          if (sel) const Icon(Icons.check,
              color: Color(0xFF1565C0), size: 18),
        ]),
      ),
    );
  }

  Widget _qualGroupHeader({
    required String label,
    required IconData icon,
    required bool isExpanded,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 14),
        color: const Color(0xFFF0F4FF),
        child: Row(children: [
          Icon(icon, color: const Color(0xFF1565C0), size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1565C0)))),
          if (selected) const Icon(Icons.check_circle,
              color: Color(0xFF1565C0), size: 18),
          const SizedBox(width: 8),
          Icon(
            isExpanded
                ? Icons.keyboard_arrow_up
                : Icons.keyboard_arrow_down,
            color: const Color(0xFF1565C0),
          ),
        ]),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Row(
            children: [
              Icon(icon,
                  color: const Color(0xFF1565C0), size: 20),
              const SizedBox(width: 12),
              Text(hint,
                  style: GoogleFonts.poppins(
                      color: const Color(0xFF6B7280),
                      fontSize: 14)),
            ],
          ),
          isExpanded: true,
          style: GoogleFonts.poppins(
              fontSize: 14, color: const Color(0xFF1A1A2E)),
          items: items
              .map((item) => DropdownMenuItem(
            value: item,
            child: Text(item),
          ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}