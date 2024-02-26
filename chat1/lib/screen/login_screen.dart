import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../commonwidget/loading_view.dart';
import '../commonwidget/signIn.dart';
import '../constants/app-images.dart';
import '../controller/auth_provider.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    AuthProvider authProvider = Provider.of<AuthProvider>(context);
    switch (authProvider.status) {
      case Status.authenticateError:
        Fluttertoast.showToast(msg: "Sign in fail");
        break;
      case Status.authenticateCanceled:
        Fluttertoast.showToast(msg: "Sign in canceled");
        break;
      case Status.authenticated:
        Fluttertoast.showToast(msg: "Sign in success");
        break;
      default:
        break;
    }

    return Scaffold(
      backgroundColor: Colors.black87,
      body: Stack( // Wrap your content in a Stack
        children: <Widget>[
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Image.asset(AppImages.back),
              ),
              const SizedBox(
                height: 20,
              ),
              GoogleLoginButton(
                onPressed: () async {
                  bool isSuccess = await authProvider.handleSignIn();
                  if (isSuccess) {
                    Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (context) => const HomePage()));
                  }
                },
              ),
              FacebookLoginButton(
                onPressed: () async {
                  await authProvider.handleFacebookSignIn();
                },
              ),
            ],
          ),
          Positioned(
            child: authProvider.status == Status.authenticating
                ? const LoadingView()
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
