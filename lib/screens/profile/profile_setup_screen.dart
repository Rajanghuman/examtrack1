import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import '../../constants/app_colors.dart';
import '../../utils/dob_formatter.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = true;
  bool _isSaving = false;

  final _nameController = TextEditingController();
  final _dobController  = TextEditingController();
  String? _selectedGender;
  String? _selectedState;
  String? _selectedQualification;
  String? _selectedStream;

  final List<String> _selectedCategories = [];
  final List<String> _selectedStates     = [];

  final List<String> _genders = ['Male', 'Female', 'Other'];

  final List<String> _qualifications = [
    '8th Pass', '10th Pass', '12th Pass', 'ITI',
    'Diploma', 'Graduate', 'Post Graduate',
  ];

  final List<String> _states = [
    'Punjab', 'Haryana', 'Himachal Pradesh', 'Uttarakhand',
    'Uttar Pradesh', 'Delhi', 'Rajasthan',
    'Jammu & Kashmir', 'All India',
  ];

  final List<String> _jobCategories = [
    'Railway', 'Police', 'Banking', 'SSC',
    'UPSC', 'Army/Defence', 'Teaching', 'Health', 'State PSC',
  ];

  final List<Map<String, dynamic>> _steps = [
    {'title': 'Personal Details', 'icon': Icons.person_rounded},
    {'title': 'Education',        'icon': Icons.school_rounded},
    {'title': 'Preferences',      'icon': Icons.tune_rounded},
  ];

  // Profile photo state — same pattern as ProfileScreen. Null/empty
  // means show the placeholder person icon instead of a real photo.
  String? _photoUrl;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            if (data['fullName'] != null)
              _nameController.text = data['fullName'];
            if (data['dob'] != null)
              _dobController.text = data['dob'];
            if (data['state'] != null &&
                _states.contains(data['state']))
              _selectedState = data['state'];
            if (data['qualification'] != null &&
                _qualifications.contains(data['qualification']))
              _selectedQualification = data['qualification'];
            if (data['gender'] != null)
              _selectedGender = data['gender'];
            if (data['photoUrl'] != null)
              _photoUrl = data['photoUrl'] as String?;
          });
        }
      }
    } catch (e) {
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _saveAndFinish();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _saveAndFinish() async {
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'fullName':        _nameController.text.trim(),
          'dob':             _dobController.text.trim(),
          'gender':          _selectedGender ?? '',
          'state':           _selectedState ?? 'Punjab',
          'qualification':   _selectedQualification ?? 'Graduate',
          'stream':          _selectedStream ?? '',
          'categories':      _selectedCategories,
          'preferredStates': _selectedStates,
          'profileComplete': true,
          'updatedAt':       FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
    }
    setState(() => _isSaving = false);
    Navigator.pushReplacementNamed(context, '/home');
  }

  // ============================================================
  // ── Profile Photo Upload ─────────────────────────────────
  // Same flow as ProfileScreen's version — fixes Apple Guideline
  // 2.1(a): this camera badge previously had no onTap at all.
  // ============================================================
  Future<void> _pickProfilePhoto() async {
    if (_isUploadingPhoto) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text('Update Profile Photo',
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A2E))),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_outlined,
                    color: AppColors.primary),
                title: Text('Take Photo',
                    style: GoogleFonts.poppins(fontSize: 14)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined,
                    color: AppColors.primary),
                title: Text('Choose from Gallery',
                    style: GoogleFonts.poppins(fontSize: 14)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;
    if (!mounted) return;

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (pickedFile == null) return;
      if (!mounted) return;

      // Workaround for a known image_cropper issue (GitHub #605) where
      // the crop screen fails to appear after camera capture on iOS —
      // gallery works fine, only camera is affected. Giving the camera
      // picker's dismissal animation time to finish before presenting
      // the cropper resolves it in most reported cases.
      if (source == ImageSource.camera) {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final cropped = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Photo',
            aspectRatioLockEnabled: true,
          ),
        ],
      );
      if (cropped == null) return;
      if (!mounted) return;

      setState(() => _isUploadingPhoto = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isUploadingPhoto = false);
        return;
      }

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${user.uid}.jpg');

      await storageRef.putFile(File(cropped.path));
      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'photoUrl': downloadUrl}, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _photoUrl = downloadUrl;
        _isUploadingPhoto = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update photo. Please try again.')),
      );
    }
  }

  // ── Build page with buttons inside ────────────────────
  Widget _buildPageWithButtons(Widget pageContent) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          pageContent,
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: GestureDetector(
                      onTap: _previousStep,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: AppColors.primary),
                          borderRadius:
                          BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text('← Back',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 16,
                                  fontWeight:
                                  FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                if (_currentStep > 0)
                  const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _isSaving ? null : _nextStep,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primaryLight,
                          ],
                        ),
                        borderRadius:
                        BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primary
                                  .withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Center(
                        child: _isSaving
                            ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2)
                            : Text(
                            _currentStep < (_steps.length - 1)
                                ? 'Next →'
                                : '🚀 Start Exploring!',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(
              color: Color(0xFF1565C0)))
          : Column(
        children: [
          _buildHeader(),
          _buildStepIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics:
              const NeverScrollableScrollPhysics(),
              children: [
                _buildPageWithButtons(
                    _buildPersonalDetails()),
                _buildPageWithButtons(
                    _buildEducation()),
                _buildPageWithButtons(
                    _buildPreferences()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20, right: 20, bottom: 24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Complete Your Profile',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Help us find the perfect jobs for you!',
              style: GoogleFonts.poppins(
                  color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('✅ Your info has been pre-filled!',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
          vertical: 20, horizontal: 20),
      child: Row(
        children: _steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step  = entry.value;
          final isCompleted = index < _currentStep;
          final isCurrent   = index == _currentStep;

          return Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppColors.success
                            : isCurrent
                            ? AppColors.primary
                            : Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCompleted
                            ? Icons.check_rounded
                            : step['icon'] as IconData,
                        color: isCompleted || isCurrent
                            ? Colors.white
                            : Colors.grey,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(step['title'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isCurrent
                            ? AppColors.primary
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
                if (index < _steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin:
                      const EdgeInsets.only(bottom: 20),
                      color: isCompleted
                          ? AppColors.success
                          : Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Personal Details ───────────────────────────────────
  Widget _buildPersonalDetails() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personal Details',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A2E))),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color:
                  const Color(0xFF10B981).withOpacity(0.3)),
            ),
            child: Text(
              '✅ Fields are pre-filled from your signup. Just verify and continue!',
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF10B981)),
            ),
          ),
          const SizedBox(height: 20),

          // Profile picture — now wired to a real upload flow.
          // Previously this camera badge had no onTap handler at
          // all (Apple Guideline 2.1(a) bug report).
          Center(
            child: Stack(
              children: [
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                      AppColors.primary.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: (_photoUrl != null && _photoUrl!.isNotEmpty)
                      ? ClipOval(
                    child: Image.network(
                      _photoUrl!,
                      width: 100, height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                          Icons.person_rounded,
                          size: 50, color: AppColors.primary),
                    ),
                  )
                      : Icon(Icons.person_rounded,
                      size: 50, color: AppColors.primary),
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: GestureDetector(
                    onTap: _pickProfilePhoto,
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white, width: 2),
                      ),
                      child: _isUploadingPhoto
                          ? const Padding(
                        padding: EdgeInsets.all(7),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                          : const Icon(Icons.camera_alt_rounded,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildLabel('Full Name'),
          _buildTextField(
            controller: _nameController,
            hint: 'Enter your full name',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 16),

          _buildLabel('Date of Birth (Optional)'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: TextField(
              controller: _dobController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                DOBInputFormatter(),
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                hintText: 'DD/MM/YYYY',
                hintStyle: TextStyle(
                    color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: Icon(Icons.cake_rounded,
                    color: AppColors.primary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),

          _buildLabel('Gender (Optional)'),
          Row(
            children: _genders.map((gender) {
              final isSelected = _selectedGender == gender;
              return Expanded(
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _selectedGender = gender),
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 4),
                    padding:
                    const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey.shade200,
                      ),
                      boxShadow: [
                        BoxShadow(
                            color:
                            Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Text(gender,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          _buildLabel('Your State'),
          _buildDropdown(
            value: _selectedState,
            hint: 'Select your state',
            icon: Icons.location_on_rounded,
            items: _states,
            onChanged: (val) =>
                setState(() => _selectedState = val),
          ),
        ],
      ),
    );
  }

  // ── Education ──────────────────────────────────────────
  Widget _buildEducation() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Education',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A2E))),
          Text('We will show jobs matching your qualification',
              style: TextStyle(
                  fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 20),

          Center(
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.school_rounded,
                  size: 60, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 24),

          _buildLabel('Highest Qualification'),
          _buildDropdown(
            value: _selectedQualification,
            hint: 'Select your qualification',
            icon: Icons.school_rounded,
            items: _qualifications,
            onChanged: (val) =>
                setState(() => _selectedQualification = val),
          ),
          const SizedBox(height: 16),

          _buildLabel('Stream / Subject (Optional)'),
          _buildDropdown(
            value: _selectedStream,
            hint: 'Select your stream',
            icon: Icons.menu_book_rounded,
            items: [
              'Science (PCM)', 'Science (PCB)', 'Commerce',
              'Arts / Humanities', 'Engineering', 'Medical',
              'Law', 'Management', 'Agriculture', 'Other',
            ],
            onChanged: (val) =>
                setState(() => _selectedStream = val),
          ),
        ],
      ),
    );
  }

  // ── Preferences ────────────────────────────────────────
  Widget _buildPreferences() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Job Preferences',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A2E))),
          Text('Select categories you are interested in',
              style: TextStyle(
                  fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 20),

          _buildLabel(
              'Job Categories (Select all that apply)'),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _jobCategories.map((cat) {
              final isSelected =
              _selectedCategories.contains(cat);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedCategories.remove(cat);
                    } else {
                      _selectedCategories.add(cat);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey.shade200,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color:
                          Colors.black.withOpacity(0.05),
                          blurRadius: 4),
                    ],
                  ),
                  child: Text(cat,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          _buildLabel('Preferred States (Optional)'),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _states.map((state) {
              final isSelected =
              _selectedStates.contains(state);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedStates.remove(state);
                    } else {
                      _selectedStates.add(state);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.police
                        : Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.police
                          : Colors.grey.shade200,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color:
                          Colors.black.withOpacity(0.05),
                          blurRadius: 4),
                    ],
                  ),
                  child: Text(state,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          _buildLabel('Notification Preferences'),
          _buildNotificationTile(
              'New Job Alerts',
              'Get notified when new jobs match your profile',
              Icons.work_rounded, true),
          _buildNotificationTile(
              'Deadline Reminders',
              'Never miss an application deadline',
              Icons.alarm_rounded, true),
          _buildNotificationTile(
              'Exam Date Alerts',
              'Know when your exam dates are announced',
              Icons.event_rounded, true),
          _buildNotificationTile(
              'Admit Card Alerts',
              'Get notified when admit cards release',
              Icons.card_membership_rounded, false),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(String title, String subtitle,
      IconData icon, bool initialValue) {
    bool value = initialValue;
    return StatefulBuilder(
      builder: (context, setStateLocal) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A2E))),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: (val) =>
                    setStateLocal(() => value = val),
                activeColor: AppColors.primary,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E))),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(icon, color: AppColors.primary),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
        ),
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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Text(hint,
                  style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14)),
            ],
          ),
          isExpanded: true,
          items: items
              .map((item) => DropdownMenuItem(
              value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}