import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'constants/app_colors.dart';
import 'services/notification_service.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/jobs/job_detail_screen.dart';
import 'screens/jobs/job_listing_screen.dart';
import 'screens/profile/profile_setup_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/calendar/exam_calendar_screen.dart';
import 'screens/saved/saved_jobs_screen.dart';
import 'screens/tracker/job_tracker_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/tools/age_calculator_screen.dart';
import 'screens/current_affairs/current_affairs_screen.dart';
import 'screens/tools/eligibility_checker_screen.dart';
import 'screens/admit_card/admit_card_screen.dart';
import 'screens/results/results_screen.dart';
import 'screens/study/study_material_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    await NotificationService.initialize();
    await NotificationService.subscribeToDefaultTopics();
  } catch (e) {
  }
  runApp(const ExamTrackApp());
}

class ExamTrackApp extends StatelessWidget {
  const ExamTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExamTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/':                (context) => const SplashScreen(),
        '/onboarding':      (context) => const OnboardingScreen(),
        '/login':           (context) => const LoginScreen(),
        '/signup':          (context) => const SignupScreen(),
        '/profile-setup':   (context) => const ProfileSetupScreen(),
        '/profile':         (context) => const ProfileScreen(),
        '/home':            (context) => const HomeScreen(),
        '/jobs':            (context) => const JobListingScreen(),
        '/job-detail':      (context) => const JobDetailScreen(),
        '/calendar':        (context) => const ExamCalendarScreen(),
        '/saved':           (context) => const SavedJobsScreen(),
        '/tracker':         (context) => const JobTrackerScreen(),
        '/notifications':   (context) => const NotificationsScreen(),
        '/eligibility':     (context) => const EligibilityCheckerScreen(),
        '/tools':           (context) => const AgeCalculatorScreen(),
        '/admit-card':      (context) => const AdmitCardScreen(),
        '/results':         (context) => const ResultsScreen(),
        '/current-affairs': (context) => const CurrentAffairsScreen(),
        '/study-material':  (context) => const StudyMaterialScreen(),
      },
    );
  }
}
