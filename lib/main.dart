import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/services/admin_service.dart';
import 'models/services/main_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: Replace with your actual Firebase initialization
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );
  await Firebase.initializeApp(); // For a generic setup

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Centralized AdminService accessible throughout the app
        Provider<AdminService>(create: (_) => AdminService()),
      ],
      child: MaterialApp(
        title: 'SendIt Admin Dashboard',
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          scaffoldBackgroundColor: Colors.grey[100],
        ),
        home: const MainScreen(),
      ),
    );
  }
}