import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:SafeChat/firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:SafeChat/services/auth/auth_gate.dart';
import 'package:SafeChat/themes/theme_provider.dart';
import 'package:flutter/scheduler.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _isBiometricEnabled = false; // To track if biometric is enabled
  bool _isAuthenticated = false; // To track if user is authenticated
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Listen for app lifecycle events
    _loadBiometricPreference();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Clean up observer
    super.dispose();
  }

  // Load the biometric setting from shared preferences
  Future<void> _loadBiometricPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isBiometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    });
  }

  // Authenticate using biometrics
  Future<void> _authenticateWithBiometrics() async {
    if (!_isBiometricEnabled) return; // Skip if biometric is not enabled

    try {
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      if (canCheckBiometrics) {
        final isAuthenticated = await _auth.authenticate(
          localizedReason: 'Please authenticate to access SafeChat',
          options: const AuthenticationOptions(biometricOnly: true),
        );

        if (isAuthenticated) {
          setState(() {
            _isAuthenticated = true; // Set authenticated to true if successful
          });
        } else {
          print("Biometric authentication failed");
        }
      }
    } catch (e) {
      print(e);
    }
  }

  // Save the time when the app is closed/paused
  Future<void> _saveAppClosedTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_closed_time', DateTime.now().millisecondsSinceEpoch);
  }

  // Check if the app should ask for biometric authentication on resume
  Future<void> _checkAppLockStatus() async {
    if (_isBiometricEnabled && !_isAuthenticated) {
      await _authenticateWithBiometrics();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // When app goes to background, save current time and reset auth
      _saveAppClosedTime();
      setState(() {
        _isAuthenticated = false; // Reset authentication when app goes to background
      });
    } else if (state == AppLifecycleState.resumed) {
      // When app comes back to foreground, check if it should be locked
      _checkAppLockStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final themeProvider = Provider.of<ThemeProvider>(context);

        // Apply dynamic color scheme after the frame is finished
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (lightDynamic != null && darkDynamic != null) {
            themeProvider.setDynamicColorScheme(
              themeProvider.isDarkmode ? darkDynamic : lightDynamic,
            );
          }
        });

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: _isAuthenticated || !_isBiometricEnabled
              ? AuthGate()
              : _buildBiometricLockScreen(), // Show biometric lock screen if necessary
          theme: themeProvider.themedata,
        );
      },
    );
  }

  // Screen to show when biometric authentication is required
  Widget _buildBiometricLockScreen() {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: _authenticateWithBiometrics,
          child: const Text('Authenticate to Continue'),
        ),
      ),
    );
  }
}