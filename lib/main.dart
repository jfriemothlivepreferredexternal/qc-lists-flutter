import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

// ===== APP CONFIGURATION =====
// For administrators: Change settings below as needed for your organization
class AppConfig {
  // ENCRYPTION PASSWORD: Used to encrypt all QC checklist reports
  // - Change this to a secure password for your organization
  // - Share this password only with authorized personnel who need to decrypt reports
  // - After changing, rebuild the app with: flutter build apk --release
  static const String encryptionPassword = 'tiger-banana-river-almost-magnet-skydive';
}

void main() {
  runApp(const MyApp());
}          

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QC Lists',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}