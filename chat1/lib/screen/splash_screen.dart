import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app-images.dart';
import '../controller/auth_provider.dart';
import 'home_screen.dart';
import 'auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    checkSignedIn();
  }

  void checkSignedIn() async {
    AuthProvider authProvider = context.read<AuthProvider>();
    bool isLoggedIn = await authProvider.isLoggedIn();

    await Future.delayed(const Duration(seconds: 2));

    if (isLoggedIn) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()));
    } else {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Chat App",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(
                height: 300, width: 300, child: Image.asset(AppImages.appIcon)),
            const Text("Private Chat Room",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(
              height: 10,
            ),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
