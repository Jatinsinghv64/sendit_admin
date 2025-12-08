import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:senditadmin/screens/main_admin_wrapper.dart';

import 'models/services/OrderAlertListener.dart';
import 'models/services/admin_service.dart';
import 'firebase_options.dart'; // Ensure you have this

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AdminService>(create: (_) => AdminService()),
      ],
      child: MaterialApp(
        title: 'SendIt Admin Dashboard',
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          scaffoldBackgroundColor: Colors.grey[100],
        ),
        // Wrap the MainAdminWrapper with OrderAlertListener
        // This ensures the popup can appear on top of any screen inside the admin panel
        home: const OrderAlertListener(
          child: MainAdminWrapper(),
        ),
      ),
    );
  }
}