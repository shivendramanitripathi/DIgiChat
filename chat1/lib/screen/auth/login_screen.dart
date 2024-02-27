import 'package:chat1/screen/auth/register_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import '../../commonwidget/common_textfield.dart';
import '../../commonwidget/loading_view.dart';
import '../../commonwidget/signIn.dart';
import '../../constants/app-images.dart';
import '../../controller/auth_provider.dart' as AuthProvider;
import '../../services/database_service.dart';
import '../../services/helper.dart';
import '../home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();
  String email = "";
  String password = "";

  @override
  Widget build(BuildContext context) {
    AuthProvider.AuthProvider authProvider =
        Provider.of<AuthProvider.AuthProvider>(context);
    bool _isLoading = authProvider.status == AuthProvider.Status.authenticating;

    return Scaffold(
      backgroundColor: Colors.black87,
      body: Stack(
        children: <Widget>[
          SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const SizedBox(height: 10,),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Image.asset(
                    AppImages.back,
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
                  child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          TextFormField(
                            decoration: textInputDecoration.copyWith(
                                labelText: "Email",
                                labelStyle:
                                    const TextStyle(color: Colors.white),
                                prefixIcon: Icon(
                                  Icons.email,
                                  color: Theme.of(context).primaryColor,
                                )),
                            onChanged: (val) {
                              setState(() {
                                email = val;
                              });
                            },
                            validator: (val) {
                              return RegExp(
                                          r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                                      .hasMatch(val!)
                                  ? null
                                  : "Please enter a valid email";
                            },
                          ),
                          const SizedBox(height: 15),
                          TextFormField(
                            obscureText: true,
                            decoration: textInputDecoration.copyWith(
                                labelText: "Password",
                                labelStyle:
                                    const TextStyle(color: Colors.white),
                                prefixIcon: Icon(
                                  Icons.lock,
                                  color: Theme.of(context).primaryColor,
                                )),
                            validator: (val) {
                              if (val!.length < 6) {
                                return "Password must be at least 6 characters";
                              } else {
                                return null;
                              }
                            },
                            onChanged: (val) {
                              setState(() {
                                password = val;
                              });
                            },
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30))),
                              child: const Text(
                                "Sign In",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 16),
                              ),
                              onPressed: () {
                                login();
                              },
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Text.rich(TextSpan(
                            text: "Don't have an account? ",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                            children: <TextSpan>[
                              TextSpan(
                                  text: "Register here",
                                  style: const TextStyle(
                                      color: Colors.white,
                                      decoration: TextDecoration.underline),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      nextScreen(context, const RegisterPage());
                                    }),
                            ],
                          )),
                          SizedBox(height: 30,),
                          GoogleLoginButton(
                            onPressed: () async {
                              bool isSuccess = await authProvider.handleSignIn();
                              if (isSuccess) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => const HomePage()),
                                );
                              }
                            },
                          ),
                          FacebookLoginButton(
                            onPressed: () async {
                              await authProvider.handleFacebookSignIn();
                            },
                          ),
                        ],
                      )),
                ),

              ],
            ),
          ),
          Positioned(
            child: _isLoading ? const LoadingView() : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  login() async {
    AuthProvider.AuthProvider authProvider =
        Provider.of<AuthProvider.AuthProvider>(context, listen: false);

    if (formKey.currentState!.validate()) {
      await authProvider.loginWithUserNameandPassword(email, password).then(
        (value) async {
          if (value == true) {
            QuerySnapshot snapshot = await DatabaseService(
              uid: FirebaseAuth.instance.currentUser!.uid,
            ).gettingUserData(email);
            await HelperFunctions.saveUserLoggedInStatus(true);
            await HelperFunctions.saveUserEmailSF(email);
            await HelperFunctions.saveUserNameSF(snapshot.docs[0]['fullName']);
            nextScreenReplace(context, const HomePage());
          } else {
            showSnackbar(context, Colors.red, value);
          }
        },
      );
    }
  }
}
