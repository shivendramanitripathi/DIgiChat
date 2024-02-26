import 'dart:async';
import 'dart:io';

import 'package:chat1/screen/setting_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../commonwidget/loading_view.dart';
import '../constants/firestore_constants.dart';
import '../controller/auth_provider.dart';
import '../controller/home_provider.dart';
import '../model/popup_choices.dart';
import '../model/user_chat.dart';
import '../utils/debounce.dart';
import '../utils/theme_notifer.dart';
import '../utils/utilies.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key});

  @override
  State createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final _firebaseMessaging = FirebaseMessaging.instance;
  final _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final _listScrollController = ScrollController();

  int _limit = 20;
  final _limitIncrement = 20;
  String _textSearch = "";
  bool _isLoading = false;

  late final AuthProvider _authProvider;
  late final HomeProvider _homeProvider;
  late final String _currentUserId;
  bool isWhite = false;

  final _searchDebouncer = Debouncer(milliseconds: 300);
  final _btnClearController = StreamController<bool>();
  final _searchBarController = TextEditingController();

  final _menus = <MenuSetting>[
    const MenuSetting(title: 'Settings', icon: Icons.settings),
    const MenuSetting(title: 'Log out', icon: Icons.exit_to_app),
  ];

  @override
  void initState() {
    super.initState();
    _authProvider = context.read<AuthProvider>();
    _homeProvider = context.read<HomeProvider>();
    if (_authProvider.userFirebaseId?.isNotEmpty == true) {
      _currentUserId = _authProvider.userFirebaseId!;
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
      );
    }
    _registerNotification();
    _configLocalNotification();
    _listScrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _btnClearController.close();
    _searchBarController.dispose();
    _listScrollController
      ..removeListener(_scrollListener)
      ..dispose();
    super.dispose();
  }

  void _registerNotification() {
    _firebaseMessaging.requestPermission();
    FirebaseMessaging.onMessage.listen((message) {
      print('onMessage: $message');

      if (message.notification != null) {
        _showNotification(message.notification!);
      }
      return;
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print('onMessageOpenedApp: $message');
      final String peerId = message.data['peerId'];
      final String peerAvatar = message.data['peerAvatar'];
      final String peerNickname = message.data['peerNickname'];

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            arguments: ChatPageArguments(
              peerId: peerId,
              peerAvatar: peerAvatar,
              peerNickname: peerNickname,
            ),
          ),
        ),
      );

    });
    _firebaseMessaging.getToken().then((token) {
      if (token != null) {
        _homeProvider.updateDataFirestore(FirestoreConstants.pathUserCollection,
            _currentUserId, {'pushToken': token});
      }
    }).catchError((err) {
      Fluttertoast.showToast(msg: err.message.toString());
    });
  }

  void _configLocalNotification() {
    const initializationSettingsAndroid =
    AndroidInitializationSettings('app_icon');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void _scrollListener() {
    if (_listScrollController.offset >=
        _listScrollController.position.maxScrollExtent &&
        !_listScrollController.position.outOfRange) {
      setState(() {
        _limit += _limitIncrement;
      });
    }
  }

  void _onItemMenuPress(MenuSetting choice) {
    if (choice.title == 'Log out') {
      _handleSignOut();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
    }
  }

  void _showNotification(RemoteNotification remoteNotification) async {
    print('Received Notification: $remoteNotification');
    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'com.example.chat1',
      'chat1',
      playSound: true,
      enableVibration: true,
      importance: Importance.max,
      priority: Priority.high,
    );
    const iOSPlatformChannelSpecifics = DarwinNotificationDetails();
    const platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      0,
      remoteNotification.title,
      remoteNotification.body,
      platformChannelSpecifics,
      payload: null,
    );
  }

  Future<void> _handleSignOut() async {
    await _authProvider.handleSignOut();
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode ? Colors.black45 : Colors.white,
      appBar: AppBar(
        backgroundColor:
        themeProvider.isDarkMode ? Colors.black45 : Colors.white,
        title: const Text(
          "Chat Room",
          style: TextStyle(color: ColorConstants.primaryColor),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 28.0),
          child: Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return Switch(
                value: themeProvider.isDarkMode,
                onChanged: (value) {
                  themeProvider.toggleTheme();
                },
              );
            },
          ),
        ),
        centerTitle: true,
        actions: [buildPopupMenu()],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _homeProvider.getStreamFireStore(
                      FirestoreConstants.pathUserCollection,
                      _limit,
                      _textSearch,
                    ),
                    builder: (_, snapshot) {
                      if (snapshot.hasData) {
                        if ((snapshot.data?.docs.length ?? 0) > 0) {
                          return ListView.builder(
                            padding: const EdgeInsets.all(10),
                            itemBuilder: (_, index) =>
                                _buildItem(snapshot.data?.docs[index]),
                            itemCount: snapshot.data?.docs.length,
                            controller: _listScrollController,
                          );
                        } else {
                          return const Center(
                            child: Text("No users"),
                          );
                        }
                      } else {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: ColorConstants.themeColor,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              child: _isLoading ? const LoadingView() : const SizedBox.shrink(),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: ColorConstants.greyColor2,
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.search,
              color: ColorConstants.primaryColor, size: 20),
          const SizedBox(width: 5),
          Expanded(
            child: TextFormField(
              textInputAction: TextInputAction.search,
              controller: _searchBarController,
              onChanged: (value) {
                _searchDebouncer.run(
                      () {
                    if (value.isNotEmpty) {
                      _btnClearController.add(true);
                      setState(() {
                        _textSearch = value;
                      });
                    } else {
                      _btnClearController.add(false);
                      setState(() {
                        _textSearch = "";
                      });
                    }
                  },
                );
              },
              decoration: const InputDecoration.collapsed(
                hintText: 'Search by nickname (type exactly case sensitive)',
                hintStyle:
                TextStyle(fontSize: 13, color: ColorConstants.greyColor),
              ),
              style:
              const TextStyle(fontSize: 13, color: ColorConstants.primaryColor),
            ),
          ),
          StreamBuilder<bool>(
            stream: _btnClearController.stream,
            builder: (_, snapshot) {
              return snapshot.data == true
                  ? GestureDetector(
                onTap: () {
                  _searchBarController.clear();
                  _btnClearController.add(false);
                  setState(() {
                    _textSearch = "";
                  });
                },
                child: const Icon(Icons.clear_rounded,
                    color: ColorConstants.greyColor, size: 20),
              )
                  : const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget buildPopupMenu() {
    return PopupMenuButton<MenuSetting>(
      icon: const Icon(Icons.more_vert, color: Colors.grey),
      onSelected: _onItemMenuPress,
      itemBuilder: (BuildContext context) {
        return _menus.map((MenuSetting choice) {
          return PopupMenuItem<MenuSetting>(
            value: choice,
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  choice.icon,
                  color: ColorConstants.primaryColor,
                ),
                const SizedBox(width: 30),
                Text(
                  choice.title,
                  style: const TextStyle(color: ColorConstants.primaryColor),
                ),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  Widget _buildItem(DocumentSnapshot? document) {
    if (document != null) {
      final userChat = UserChat.fromDocument(document);
      if (userChat.id == _currentUserId) {
        return const SizedBox.shrink();
      } else {
        return Container(
          height: 70,
          margin: const EdgeInsets.only(bottom: 10, left: 5, right: 5),
          child: TextButton(
            onPressed: () {
              if (Utilities.isKeyboardShowing(context)) {
                Utilities.closeKeyboard();
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    arguments: ChatPageArguments(
                      peerId: userChat.id,
                      peerAvatar: userChat.photoUrl,
                      peerNickname: userChat.nickname,
                    ),
                  ),
                ),
              );
            },
            style: ButtonStyle(
              backgroundColor:
              MaterialStateProperty.all<Color>(ColorConstants.greyColor2),
              shape: MaterialStateProperty.all<OutlinedBorder>(
                const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
            ),
            child: Row(
              children: [
                ClipOval(
                  child: userChat.photoUrl.isNotEmpty
                      ? Image.network(
                    userChat.photoUrl,
                    fit: BoxFit.cover,
                    width: 50,
                    height: 50,
                    loadingBuilder: (_, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return SizedBox(
                        width: 50,
                        height: 50,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: ColorConstants.themeColor,
                            value: loadingProgress.expectedTotalBytes !=
                                null
                                ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, object, stackTrace) {
                      return const Icon(
                        Icons.account_circle,
                        size: 50,
                        color: ColorConstants.greyColor,
                      );
                    },
                  )
                      : const Icon(
                    Icons.account_circle,
                    size: 50,
                    color: ColorConstants.greyColor,
                  ),
                ),
                Flexible(
                  child: Container(
                    margin: const EdgeInsets.only(left: 20),
                    child: Column(
                      children: [
                        Container(
                          alignment: Alignment.centerLeft,
                          margin: const EdgeInsets.fromLTRB(10, 0, 0, 5),
                          child: Text(
                            'Nickname: ${userChat.nickname}',
                            maxLines: 1,
                            style: const TextStyle(
                                color: ColorConstants.primaryColor),
                          ),
                        ),
                        Container(
                          alignment: Alignment.centerLeft,
                          margin: const EdgeInsets.fromLTRB(10, 0, 0, 0),
                          child: Text(
                            'About me: ${userChat.aboutMe}',
                            maxLines: 1,
                            style: const TextStyle(
                                color: ColorConstants.primaryColor),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } else {
      return const SizedBox.shrink();
    }
  }
}