import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/patient_login_screen.dart';
import 'screens/doctor_login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/patient_dashboard_screen.dart';
import 'screens/doctor_dashboard_screen.dart';
import 'theme/app_theme.dart';
import 'services/firebase_service.dart';
import 'services/api_service.dart';
import 'models/ecg_record.dart';
import 'models/vitals_record.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApiSmokeTest();

  final firebaseInitialized = await FirebaseService.initialize();

  runApp(MyApp(firebaseInitialized: firebaseInitialized));
}

class MyApp extends StatelessWidget {
  final bool firebaseInitialized;

  const MyApp({super.key, required this.firebaseInitialized});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HealthTrack',
      theme: AppTheme.lightTheme,
      home: firebaseInitialized
          ? const SplashScreen()
          : Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      FirebaseService.errorMessage ??
                          'Failed to initialize app',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final success = await FirebaseService.initialize();
                        if (success && context.mounted) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const SplashScreen(),
                            ),
                          );
                        }
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
      routes: {
        '/patient-login': (context) => const PatientLoginScreen(),
        '/doctor-login': (context) => const DoctorLoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/patient-dashboard': (context) => const PatientDashboardScreen(),
        '/doctor-dashboard': (context) => const DoctorDashboardScreen(),
      },
    );
  }
}

void runApiSmokeTest() async {
  const api = ApiService('http://127.0.0.1:8000');

  try {
    debugPrint('Starting API smoke test...');
    final List<ECGRecord> ecg = await api.fetchEcg(3);
    debugPrint('ECG data received successfully');
    final List<VitalsRecord> vitals = await api.fetchVitals(3);
    debugPrint('Vitals data received successfully');

    debugPrint('✅ ECG 0 label: ${ecg.first.prediction.label}');
    debugPrint(
      '✅ Vitals 0 SpO₂: ${vitals.first.vitals.spo2.toStringAsFixed(1)}',
    );
  } catch (e, stackTrace) {
    debugPrint('❌ API test failed: $e');
    debugPrint('Stack trace:\n$stackTrace');
  }
}
