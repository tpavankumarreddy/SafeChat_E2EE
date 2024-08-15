import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:SafeChat/firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:SafeChat/services/auth/auth_gate.dart';
import 'package:SafeChat/themes/theme_provider.dart';
import 'package:flutter/scheduler.dart';

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final themeProvider = Provider.of<ThemeProvider>(context);

        // Schedule the state update after the current frame is finished
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (lightDynamic != null && darkDynamic != null) {
            themeProvider.setDynamicColorScheme(
              themeProvider.isDarkmode ? darkDynamic : lightDynamic,
            );
          }
        });

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: const AuthGate(),
          theme: themeProvider.themedata,
        );
      },
    );
  }
}
