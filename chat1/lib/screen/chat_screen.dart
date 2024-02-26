import 'dart:async';
import 'dart:io';
import 'package:chat1/controller/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../commonwidget/loading_view.dart';
import '../constants/app-images.dart';
import '../constants/color_constants.dart';
import '../constants/firestore_constants.dart';
import '../constants/type_constant.dart';
import '../controller/chat_provider.dart';
import '../controller/setting_provider.dart';
import '../model/message_chat.dart';
import '../utils/theme_notifer.dart';
import 'full_photo.dart';
import 'login_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.arguments});

  final ChatPageArguments arguments;

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  late final String _currentUserId;

  List<QueryDocumentSnapshot> _listMessage = [];
  int _limit = 20;
  final _limitIncrement = 20;
  String _groupChatId = "";

  File? _imageFile;
  bool _isLoading = false;
  bool _isShowSticker = false;
  String _imageUrl = "";

  final _chatInputController = TextEditingController();
  final _listScrollController = ScrollController();
  final _focusNode = FocusNode();

  late final _chatProvider = context.read<ChatProvider>();
  late final _authProvider = context.read<AuthProvider>();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _listScrollController.addListener(_scrollListener);
    _readLocal();
  }

  @override
  void dispose() {
    _chatInputController.dispose();
    _listScrollController
      ..removeListener(_scrollListener)
      ..dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (!_listScrollController.hasClients) return;
    if (_listScrollController.offset >=
            _listScrollController.position.maxScrollExtent &&
        !_listScrollController.position.outOfRange &&
        _limit <= _listMessage.length) {
      setState(() {
        _limit += _limitIncrement;
      });
    }
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      setState(() {
        _isShowSticker = false;
      });
    }
  }

  void _callPhoneNumber(String callPhoneNumber) async{
    var url = 'tel://$callPhoneNumber';
    if(await canLaunch(url)){
      await launch(url);
    }else{
      throw 'Error occurred';
    }
  }
  void _readLocal() {
    if (_authProvider.userFirebaseId?.isNotEmpty == true) {
      _currentUserId = _authProvider.userFirebaseId!;
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
    String peerId = widget.arguments.peerId;
    if (_currentUserId.compareTo(peerId) > 0) {
      _groupChatId = '$_currentUserId-$peerId';
    } else {
      _groupChatId = '$peerId-$_currentUserId';
    }

    _chatProvider.updateDataFirestore(
      FirestoreConstants.pathUserCollection,
      _currentUserId,
      {FirestoreConstants.chattingWith: peerId},
    );
  }

  Future<bool> _pickImage() async {
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
        _imageFile = imageFile;
        _isLoading = true;
      });
      return true;
    } else {
      return false;
    }
  }

  void _getSticker() {
    _focusNode.unfocus();
    setState(() {
      _isShowSticker = !_isShowSticker;
    });
  }

  Future<void> _uploadFile() async {
    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final uploadTask = _chatProvider.uploadFile(_imageFile!, fileName);
    try {
      final snapshot = await uploadTask;
      _imageUrl = await snapshot.ref.getDownloadURL();
      setState(() {
        _isLoading = false;
        _onSendMessage(_imageUrl, TypeMessage.image);
      });
    } on FirebaseException catch (e) {
      setState(() {
        _isLoading = false;
      });
      Fluttertoast.showToast(msg: e.message ?? e.toString());
    }
  }

  void _onSendMessage(String content, int type) {
    if (content.trim().isNotEmpty) {
      _chatInputController.clear();
      _chatProvider.sendMessage(
          content, type, _groupChatId, _currentUserId, widget.arguments.peerId);
      if (_listScrollController.hasClients) {
        _listScrollController.animateTo(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } else {
      Fluttertoast.showToast(
          msg: 'Nothing to send', backgroundColor: ColorConstants.greyColor);
    }
  }

  Widget _buildItemMessage(int index, DocumentSnapshot? document) {
    if (document == null) return const SizedBox.shrink();
    final messageChat = MessageChat.fromDocument(document);
    if (messageChat.idFrom == _currentUserId) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          messageChat.type == TypeMessage.text
              ? Container(
                  padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
                  width: 200,
                  decoration: BoxDecoration(
                      color: ColorConstants.greyColor2,
                      borderRadius: BorderRadius.circular(8)),
                  margin: EdgeInsets.only(
                      bottom: _isLastMessageRight(index) ? 20 : 10, right: 10),
                  child: Text(
                    messageChat.content,
                    style: const TextStyle(color: ColorConstants.primaryColor),
                  ),
                )
              : messageChat.type == TypeMessage.image
                  // Image
                  ? Container(
                      clipBehavior: Clip.hardEdge,
                      decoration:
                          BoxDecoration(borderRadius: BorderRadius.circular(8)),
                      margin: EdgeInsets.only(
                          bottom: _isLastMessageRight(index) ? 20 : 10,
                          right: 10),
                      child: GestureDetector(
                        child: Image.network(
                          messageChat.content,
                          loadingBuilder: (_, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              decoration: const BoxDecoration(
                                color: ColorConstants.greyColor2,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(8),
                                ),
                              ),
                              width: 200,
                              height: 200,
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
                          errorBuilder: (_, __, ___) {
                            return Image.asset(
                              AppImages.imageNot,
                              width: 200,
                              height: 200,
                              fit: BoxFit.cover,
                            );
                          },
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FullPhotoPage(
                                url: messageChat.content,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  // Sticker
                  : Container(
                      margin: EdgeInsets.only(
                          bottom: _isLastMessageRight(index) ? 20 : 10,
                          right: 10),
                      child: Image.asset(
                        'assets/image/${messageChat.content}.gif',
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
        ],
      );
    } else {
      // Left (peer message)
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipOval(
                  child: _isLastMessageLeft(index)
                      ? Image.network(
                          widget.arguments.peerAvatar,
                          loadingBuilder: (_, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                color: ColorConstants.themeColor,
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) {
                            return const Icon(
                              Icons.account_circle,
                              size: 35,
                              color: ColorConstants.greyColor,
                            );
                          },
                          width: 35,
                          height: 35,
                          fit: BoxFit.cover,
                        )
                      : Container(width: 35),
                ),
                messageChat.type == TypeMessage.text
                    ? Container(
                        padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
                        width: 200,
                        decoration: BoxDecoration(
                            color: ColorConstants.primaryColor,
                            borderRadius: BorderRadius.circular(8)),
                        margin: const EdgeInsets.only(left: 10),
                        child: Text(
                          messageChat.content,
                          style: const TextStyle(color: Colors.white),
                        ),
                      )
                    : messageChat.type == TypeMessage.image
                        ? Container(
                            clipBehavior: Clip.hardEdge,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8)),
                            margin: const EdgeInsets.only(left: 10),
                            child: GestureDetector(
                              child: Image.network(
                                messageChat.content,
                                loadingBuilder: (_, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    decoration: const BoxDecoration(
                                      color: ColorConstants.greyColor2,
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(8),
                                      ),
                                    ),
                                    width: 200,
                                    height: 200,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: ColorConstants.themeColor,
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
                                errorBuilder: (_, __, ___) => Image.asset(
                                  AppImages.imageNot,
                                  width: 200,
                                  height: 200,
                                  fit: BoxFit.cover,
                                ),
                                width: 200,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        FullPhotoPage(url: messageChat.content),
                                  ),
                                );
                              },
                            ),
                          )
                        : Container(
                            margin: EdgeInsets.only(
                                bottom: _isLastMessageRight(index) ? 20 : 10,
                                right: 10),
                            child: Image.asset(
                              'assets/image/${messageChat.content}.gif',
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
              ],
            ),

            // Time
            _isLastMessageLeft(index)
                ? Container(
                    margin: const EdgeInsets.only(left: 50, top: 5, bottom: 5),
                    child: Text(
                      DateFormat('dd MMM kk:mm').format(
                          DateTime.fromMillisecondsSinceEpoch(
                              int.parse(messageChat.timestamp))),
                      style: const TextStyle(
                          color: ColorConstants.greyColor,
                          fontSize: 12,
                          fontStyle: FontStyle.italic),
                    ),
                  )
                : const SizedBox.shrink()
          ],
        ),
      );
    }
  }

  bool _isLastMessageLeft(int index) {
    if ((index > 0 &&
            _listMessage[index - 1].get(FirestoreConstants.idFrom) ==
                _currentUserId) ||
        index == 0) {
      return true;
    } else {
      return false;
    }
  }

  bool _isLastMessageRight(int index) {
    if ((index > 0 &&
            _listMessage[index - 1].get(FirestoreConstants.idFrom) !=
                _currentUserId) ||
        index == 0) {
      return true;
    } else {
      return false;
    }
  }

  void _onBackPress() {
    _chatProvider.updateDataFirestore(
      FirestoreConstants.pathUserCollection,
      _currentUserId,
      {FirestoreConstants.chattingWith: null},
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.arguments.peerNickname,
          style: const TextStyle(color: ColorConstants.primaryColor),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            icon: const Icon(
              Icons.phone_iphone,
              size: 30,
              color: ColorConstants.primaryColor,
            ),
            onPressed: (){
              SettingProvider settingProvider;
              settingProvider = context.read<SettingProvider>();
              String callPhoneNumber = settingProvider.getPref(FirestoreConstants.phoneNumber) ?? "";
              _callPhoneNumber(callPhoneNumber);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: PopScope(
          canPop: false,
          onPopInvoked: (didPop) {
            if (didPop) return;
            _onBackPress();
          },
          child: Stack(
            children: [
              Column(
                children: [
                  _buildListMessage(),
                  _isShowSticker ? _buildStickers() : const SizedBox.shrink(),
                  _buildInput(),
                ],
              ),
              Positioned(
                child:
                    _isLoading ? const LoadingView() : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStickers() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
            top: BorderSide(color: ColorConstants.greyColor2, width: 0.5)),
        color: Colors.white,
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildItemSticker(AppImages.imageMimi),
              _buildItemSticker(AppImages.imageMimi1),
              _buildItemSticker(AppImages.imageMimi2),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildItemSticker(AppImages.imageMimi3),
              _buildItemSticker(AppImages.imageMimi1),
              _buildItemSticker(AppImages.imageMimi2),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildItemSticker(AppImages.imageMimi3),
              _buildItemSticker(AppImages.imageMimi1),
              _buildItemSticker(AppImages.imageMimi2),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildItemSticker(String stickerName) {
    return TextButton(
      onPressed: () => _onSendMessage(stickerName, TypeMessage.sticker),
      child: Image.asset(
        '$stickerName',
        width: 50,
        height: 50,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: const BoxDecoration(
          border: Border(
              top: BorderSide(color: ColorConstants.greyColor2, width: 0.5)),
          color: Colors.white),
      child: Row(
        children: [
          // button send image
          Material(
            color: Colors.white,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              child: IconButton(
                icon: const Icon(Icons.image),
                onPressed: () {
                  _pickImage().then((isSuccess) {
                    if (isSuccess) _uploadFile();
                  });
                },
                color: ColorConstants.primaryColor,
              ),
            ),
          ),
          Material(
            color: Colors.white,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              child: IconButton(
                icon: const Icon(Icons.face),
                onPressed: _getSticker,
                color: ColorConstants.primaryColor,
              ),
            ),
          ),

          // chat input
          Flexible(
            child: TextField(
              onSubmitted: (_) {
                _onSendMessage(_chatInputController.text, TypeMessage.text);
              },
              style: const TextStyle(
                  color: ColorConstants.primaryColor, fontSize: 15),
              controller: _chatInputController,
              decoration: const InputDecoration.collapsed(
                hintText: 'Type your message...',
                hintStyle: TextStyle(color: ColorConstants.greyColor),
              ),
              focusNode: _focusNode,
            ),
          ),

          // Button send message
          Material(
            color: Colors.white,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () =>
                    _onSendMessage(_chatInputController.text, TypeMessage.text),
                color: ColorConstants.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListMessage() {
    return Flexible(
      child: _groupChatId.isNotEmpty
          ? StreamBuilder<QuerySnapshot>(
              stream: _chatProvider.getChatStream(_groupChatId, _limit),
              builder: (_, snapshot) {
                if (snapshot.hasData) {
                  _listMessage = snapshot.data!.docs;
                  if (_listMessage.length > 0) {
                    return ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemBuilder: (_, index) =>
                          _buildItemMessage(index, snapshot.data?.docs[index]),
                      itemCount: snapshot.data?.docs.length,
                      reverse: true,
                      controller: _listScrollController,
                    );
                  } else {
                    return const Center(child: Text("No message here yet..."));
                  }
                } else {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: ColorConstants.themeColor,
                    ),
                  );
                }
              },
            )
          : const Center(
              child: CircularProgressIndicator(
                color: ColorConstants.themeColor,
              ),
            ),
    );
  }
}

class ChatPageArguments {
  final String peerId;
  final String peerAvatar;
  final String peerNickname;

  ChatPageArguments(
      {required this.peerId,
      required this.peerAvatar,
      required this.peerNickname});
}
