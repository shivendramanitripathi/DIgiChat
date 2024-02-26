import 'package:chat1/controller/auth_provider.dart';
import 'package:chat1/screen/splash_screen.dart';
import 'package:chat1/services/firebaseServices.dart';
import 'package:chat1/utils/theme.dart';
import 'package:chat1/utils/theme_notifer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/app_constants.dart';
import 'controller/chat_provider.dart';
import 'controller/home_provider.dart';
import 'controller/setting_provider.dart';

bool isWhite =false;

void main() async {

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
  SharedPreferences prefs = await SharedPreferences.getInstance();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: MyApp(prefs: prefs),
    ),
  );
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;

  MyApp({required this.prefs});

  final _firebaseFirestore = FirebaseFirestore.instance;
  final _firebaseStorage = FirebaseStorage.instance;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(
            firebaseAuth: FirebaseAuth.instance,
            googleSignIn: GoogleSignIn(),
            prefs: prefs,
            firebaseFirestore: _firebaseFirestore,
          ),
        ),
        Provider<SettingProvider>(
          create: (_) => SettingProvider(
            prefs: prefs,
            firebaseFirestore: _firebaseFirestore,
            firebaseStorage: _firebaseStorage,
          ),
        ),
        Provider<HomeProvider>(
          create: (_) => HomeProvider(
            firebaseFirestore: _firebaseFirestore,
          ),
        ),
        Provider<ChatProvider>(
          create: (_) => ChatProvider(
            prefs: prefs,
            firebaseFirestore: _firebaseFirestore,
            firebaseStorage: _firebaseStorage,
          ),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appTitle,
        theme: Provider.of<ThemeProvider>(context).getTheme(),

        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

