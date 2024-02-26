import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../commonwidget/loading_view.dart';
import '../constants/app_constants.dart';
import '../constants/color_constants.dart';
import '../constants/firestore_constants.dart';
import '../controller/setting_provider.dart';
import '../model/user_chat.dart';
import '../utils/theme_notifer.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _controllerNickname;
  late final TextEditingController _controllerAboutMe;

  String _userId = '';
  String _nickname = '';
  String _aboutMe = '';
  String _avatarUrl = '';
  String phoneNumber = '';

  bool _isLoading = false;
  File? _avatarFile;
  late final _settingProvider = context.read<SettingProvider>();

  final _focusNodeNickname = FocusNode();
  final _focusNodeAboutMe = FocusNode();

  @override
  void initState() {
    super.initState();
    _readLocal();
  }

  void _readLocal() {
    setState(() {
      _userId = _settingProvider.getPref(FirestoreConstants.id) ?? "";
      _nickname = _settingProvider.getPref(FirestoreConstants.nickname) ?? "";
      _aboutMe = _settingProvider.getPref(FirestoreConstants.aboutMe) ?? "";
      _avatarUrl = _settingProvider.getPref(FirestoreConstants.photoUrl) ?? "";
    });

    _controllerNickname = TextEditingController(text: _nickname);
    _controllerAboutMe = TextEditingController(text: _aboutMe);
  }

  Future<bool> _pickAvatar() async {
    final imagePicker = ImagePicker();
    final pickedXFile = await imagePicker
        .pickImage(source: ImageSource.gallery)
        .catchError((err) {
      Fluttertoast.showToast(msg: err.toString());
      return null;
    });
    if (pickedXFile != null) {
      final imageFile = File(pickedXFile.path);
      setState(() {
        _avatarFile = imageFile;
        _isLoading = true;
      });
      return true;
    } else {
      return false;
    }
  }

  Future<void> _uploadFile() async {
    final fileName = _userId;
    final uploadTask = _settingProvider.uploadFile(_avatarFile!, fileName);
    try {
      final snapshot = await uploadTask;
      _avatarUrl = await snapshot.ref.getDownloadURL();
      final updateInfo = UserChat(
        id: _userId,
        photoUrl: _avatarUrl,
        nickname: _nickname,
        aboutMe: _aboutMe,
      );
      _settingProvider
          .updateDataFirestore(FirestoreConstants.pathUserCollection, _userId,
              updateInfo.toJson())
          .then((_) async {
        await _settingProvider.setPref(FirestoreConstants.photoUrl, _avatarUrl);
        setState(() {
          _isLoading = false;
        });
        Fluttertoast.showToast(msg: "Upload success");
      }).catchError((err) {
        setState(() {
          _isLoading = false;
        });
        Fluttertoast.showToast(msg: err.toString());
      });
    } on FirebaseException catch (e) {
      setState(() {
        _isLoading = false;
      });
      Fluttertoast.showToast(msg: e.message ?? e.toString());
    }
  }

  void _handleUpdateData() {
    _focusNodeNickname.unfocus();
    _focusNodeAboutMe.unfocus();

    setState(() {
      _isLoading = true;
    });
    UserChat updateInfo = UserChat(
      id: _userId,
      photoUrl: _avatarUrl,
      nickname: _nickname,
      aboutMe: _aboutMe,
    );
    _settingProvider
        .updateDataFirestore(
            FirestoreConstants.pathUserCollection, _userId, updateInfo.toJson())
        .then((_) async {
      await _settingProvider.setPref(FirestoreConstants.nickname, _nickname);
      await _settingProvider.setPref(FirestoreConstants.aboutMe, _aboutMe);
      await _settingProvider.setPref(FirestoreConstants.photoUrl, _avatarUrl);

      setState(() {
        _isLoading = false;
      });

      Fluttertoast.showToast(msg: "Update success");
    }).catchError((err) {
      setState(() {
        _isLoading = false;
      });

      Fluttertoast.showToast(msg: err.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          AppConstants.settingsTitle,
          style: TextStyle(color: ColorConstants.primaryColor),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(left: 15, right: 15),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CupertinoButton(
                  onPressed: () {
                    _pickAvatar().then((isSuccess) {
                      if (isSuccess) _uploadFile();
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(45),
                    ),
                    child: _avatarFile == null
                        ? _avatarUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(43),
                                child: Image.network(
                                  _avatarUrl,
                                  fit: BoxFit.cover,
                                  width: 90,
                                  height: 90,
                                  errorBuilder: (_, __, ___) {
                                    return const Icon(
                                      Icons.account_circle,
                                      size: 90,
                                      color: ColorConstants.greyColor,
                                    );
                                  },
                                  loadingBuilder: (_, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return SizedBox(
                                      width: 90,
                                      height: 90,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              )
                            : Container(
                                width: 120,
                                height: 120,
                                color: ColorConstants.greyColor,
                                child: const Icon(
                                  Icons.account_circle,
                                  size: 90,
                                ),
                              )
                        : ClipOval(
                            child: Image.file(
                              _avatarFile!,
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Username
                    Container(
                      margin:
                          const EdgeInsets.only(left: 10, bottom: 5, top: 10),
                      child: const Text(
                        'Nickname',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.bold,
                          color: ColorConstants.primaryColor,
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(left: 30, right: 30),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                            primaryColor: ColorConstants.primaryColor),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Sweetie',
                            contentPadding: EdgeInsets.all(5),
                            hintStyle:
                                TextStyle(color: ColorConstants.greyColor),
                          ),
                          controller: _controllerNickname,
                          onChanged: (value) {
                            _nickname = value;
                          },
                          focusNode: _focusNodeNickname,
                        ),
                      ),
                    ),

                    // About me
                    Container(
                      margin:
                          const EdgeInsets.only(left: 10, top: 30, bottom: 5),
                      child: const Text(
                        'About me',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.bold,
                          color: ColorConstants.primaryColor,
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(left: 30, right: 30),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                            primaryColor: ColorConstants.primaryColor),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Fun, like travel and play PES...',
                            contentPadding: EdgeInsets.all(5),
                            hintStyle:
                                TextStyle(color: ColorConstants.greyColor),
                          ),
                          controller: _controllerAboutMe,
                          onChanged: (value) {
                            _aboutMe = value;
                          },
                          focusNode: _focusNodeAboutMe,
                        ),
                      ),
                    ),
                  ],
                ),

                // Button
                Container(
                  margin: const EdgeInsets.only(top: 50, bottom: 50),
                  child: TextButton(
                    onPressed: _handleUpdateData,
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(
                          ColorConstants.primaryColor),
                      padding: MaterialStateProperty.all<EdgeInsets>(
                        const EdgeInsets.fromLTRB(30, 10, 30, 10),
                      ),
                    ),
                    child: const Text(
                      'Update',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Loading
          Positioned(
              child:
                  _isLoading ? const LoadingView() : const SizedBox.shrink()),
        ],
      ),
    );
  }
}
