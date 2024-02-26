import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/firestore_constants.dart';
import '../model/user_chat.dart';

enum Status {
  uninitialized,
  authenticated,
  authenticating,
  authenticateError,
  authenticateException,
  authenticateCanceled,
}

class AuthProvider extends ChangeNotifier {
  final GoogleSignIn googleSignIn;
  final FirebaseAuth firebaseAuth;
  final FirebaseFirestore firebaseFirestore;
  final SharedPreferences prefs;

  AuthProvider({
    required this.firebaseAuth,
    required this.googleSignIn,
    required this.prefs,
    required this.firebaseFirestore,
  });

  Status _status = Status.uninitialized;

  Status get status => _status;

  String? get userFirebaseId => prefs.getString(FirestoreConstants.id);

  Future<bool> isLoggedIn() async {
    bool isLoggedIn = await googleSignIn.isSignedIn();
    if (isLoggedIn &&
        prefs.getString(FirestoreConstants.id)?.isNotEmpty == true) {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> handleSignIn() async {
    _status = Status.authenticating;
    notifyListeners();

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      _status = Status.authenticateCanceled;
      notifyListeners();
      return false;
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final firebaseUser =
        (await firebaseAuth.signInWithCredential(credential)).user;
    if (firebaseUser == null) {
      _status = Status.authenticateError;
      notifyListeners();
      return false;
    }

    final result = await firebaseFirestore
        .collection(FirestoreConstants.pathUserCollection)
        .where(FirestoreConstants.id, isEqualTo: firebaseUser.uid)
        .get();
    final documents = result.docs;
    if (documents.length == 0) {
      firebaseFirestore
          .collection(FirestoreConstants.pathUserCollection)
          .doc(firebaseUser.uid)
          .set({
        FirestoreConstants.nickname: firebaseUser.displayName,
        FirestoreConstants.photoUrl: firebaseUser.photoURL,
        FirestoreConstants.id: firebaseUser.uid,
        FirestoreConstants.createdAt:
            DateTime.now().millisecondsSinceEpoch.toString(),
        FirestoreConstants.chattingWith: null
      });

      // Write data to local storage
      User? currentUser = firebaseUser;
      await prefs.setString(FirestoreConstants.id, currentUser.uid);
      await prefs.setString(
          FirestoreConstants.nickname, currentUser.displayName ?? "");
      await prefs.setString(
          FirestoreConstants.photoUrl, currentUser.photoURL ?? "");
    } else {
      final documentSnapshot = documents.first;
      final userChat = UserChat.fromDocument(documentSnapshot);
      await prefs.setString(FirestoreConstants.id, userChat.id);
      await prefs.setString(FirestoreConstants.nickname, userChat.nickname);
      await prefs.setString(FirestoreConstants.photoUrl, userChat.photoUrl);
      await prefs.setString(FirestoreConstants.aboutMe, userChat.aboutMe);
    }
    _status = Status.authenticated;
    notifyListeners();
    return true;
  }

  Future<bool> handleFacebookSignIn() async {
    _status = Status.authenticating;
    notifyListeners();

    try {
      final result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.success) {
        final AuthCredential credential =
            FacebookAuthProvider.credential(result.accessToken!.token);
        final UserCredential authResult =
            await firebaseAuth.signInWithCredential(credential);
        final User? firebaseUser = authResult.user;
        _status = Status.authenticated;
        notifyListeners();
        return true;
      } else {
        _status = Status.authenticateError;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print("Facebook sign-in error: $e");
      _status = Status.authenticateException;
      notifyListeners();
      return false;
    }
  }

  Future<User?> signUpWithEmailAndPassword(String email, String password) async {

    try {
      UserCredential credential =await firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
      return credential.user;
    } on FirebaseAuthException catch (e) {

      if (e.code == 'email-already-in-use') {
        Fluttertoast.showToast(msg: 'The email address is already in use.');
      } else {
        Fluttertoast.showToast(msg: 'An error occurred: ${e.code}');
      }
    }
    return null;

  }

  Future<User?> signInWithEmailAndPassword(String email, String password) async {

    try {
      UserCredential credential =await firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
      return credential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        Fluttertoast.showToast(msg: 'Invalid email or password.');

      } else {
        Fluttertoast.showToast(msg: 'An error occurred: ${e.code}');
      }

    }
    return null;

  }


  void handleException() {
    _status = Status.authenticateException;
    notifyListeners();
  }

  Future<void> handleSignOut() async {
    _status = Status.uninitialized;
    await firebaseAuth.signOut();
    await googleSignIn.disconnect();
    await googleSignIn.signOut();
  }
}
