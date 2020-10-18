import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'Const.dart';
import 'package:faker/faker.dart';
import 'Analytics.dart';
import 'CustomPainters.dart';

class DmScreen extends StatefulWidget {
  @override
  _DmScreenState createState() => _DmScreenState();
}

class _DmScreenState extends State<DmScreen> with WidgetsBindingObserver {
  String postInitializer;
  String postId;
  String postAuthor;
  String messageText;
  String thisDocumentReference;

  TextEditingController messageTextController;
  bool firstBuild = true;
  bool firstTimeBuildingStream = true;
  bool isBlocked = false;
  Function buttonCallback;
  String blockText = "";
  DocumentSnapshot thisDocument = null;
  StreamSubscription snapshotStream = null;
  String username = "";

  Stream<QuerySnapshot> commentsStream;
  Future<void> fetchDmFuture;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (postAuthor == GlobalController.get().currentUserUid)
        setupTimestamps(true);
      if (postInitializer == GlobalController.get().currentUserUid)
        setupTimestamps(false);
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    messageTextController = TextEditingController(text: messageText);
    super.initState();
  }

  void initialSendButtonCallback() {
    messageText = messageText.replaceAll("/n", " ");
    if (messageText.trim().length == 0) {
      return;
    }
    messageTextController.clear();
    setState(() {
      fetchDmFuture = initialize();
    });
  }

  void sendNormal() async {
    messageText = messageText.replaceAll("/n", " ");
    if (messageText.trim().length == 0) {
      return;
    }
    messageTextController.clear();
    normalPostAsyncAction(messageText.trim());
  }

  void normalPostAsyncAction(String messageText) async {
    var time = await getCurrentTimestampServer();
    try {
      if (isBlocked) {
        showModalBottomSheet(
            isDismissible: true,
            context: context,
            builder: (BuildContext bc) {
              return Container(
                child: ListTile(
                    leading: Icon(Icons.not_interested),
                    title: Text(
                        'This channel has been blocked, it will fade away!')),
              );
            });
        return;
      }
      Firestore.instance
          .collection('directMessages')
          .doc(thisDocumentReference)
          .update({
        'lastMessage': time,
      });
      Firestore.instance
          .collection('directMessages')
          .doc(thisDocumentReference)
          .collection('messages')
          .add({
        'time': time,
        'text': messageText,
        'sender': GlobalController.get().currentUser.displayName,
        'senderUid': GlobalController.get().currentUserUid,
      });
      AnalyticsController.get().dmSent();
      sendPush();
    } catch (e) {
      print(e);
    }
    messageText = "";
  }

  Future<void> setupTimestamps(bool isPostAuthor) async {
    var timestamp = await getCurrentTimestampServer();
    if (isPostAuthor) {
      await Firestore.instance
          .collection('directMessages')
          .doc(thisDocumentReference)
          .update({
        'lastSeenAuthor': timestamp,
      });
    } else {
      await Firestore.instance
          .collection('directMessages')
          .doc(thisDocumentReference)
          .update({'lastSeenInitializer': timestamp});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (postAuthor == GlobalController.get().currentUserUid)
      setupTimestamps(true);
    if (postInitializer == GlobalController.get().currentUserUid)
      setupTimestamps(false);
    super.dispose();
  }

  Future<DocumentSnapshot> initialize() async {
    try {
      username = faker.internet.userName();
      var time = await getCurrentTimestampServer();
      var ref = await Firestore.instance.collection('directMessages').add({
        'initializerId': postInitializer,
        'postId': postId,
        'postAuthorId': postAuthor,
        'lastSeenInitializer': time,
        'lastSeenAuthor': 0.toDouble(),
        'posters': [postAuthor, postInitializer],
        'lastMessage': time,
        'conversationPartner': username,
        'isBlocked': []
      });
      thisDocument = await ref.get();
      thisDocumentReference = ref.id;
      await ref.collection('messages').add({
        'text': messageText.trim(),
        'sender': GlobalController.get().currentUser.displayName,
        'senderUid': GlobalController.get().currentUserUid,
        'time': time
      });
      await Firestore.instance
          .collection('users')
          .doc(GlobalController.get().userDocId)
          .update({'canInitializeMessage': 0});
      GlobalController.get().canMessage = 0;
      AnalyticsController.get().dmInitialized();
      sendPush();
    } catch (e) {
      print(e);
      return Future.error(CommentsErrorCode.FailedToInitialize);
    }
    messageText = "";
  }

  Future<void> sendPush() async {
    try {
      String otherUserPushId;
      if (postAuthor == GlobalController.get().currentUserUid) {
        var otherUser = await Firestore.instance
            .collection('users')
            .where('uid', isEqualTo: postInitializer)
            .get();
        otherUserPushId = otherUser.docs[0].get('pushToken');
      } else {
        var otherUser = await Firestore.instance
            .collection('users')
            .where('uid', isEqualTo: postAuthor)
            .get();
        otherUserPushId = otherUser.docs[0].get('pushToken');
      }
      var theseMessages = await Firestore.instance
          .collection('directMessages')
          .doc(thisDocumentReference)
          .get();
      var callsign = theseMessages.get('conversationPartner');

      GlobalController.get().callOnFcmApiSendPushNotifications(
          [otherUserPushId],
          'New direct message!',
          'New chat message from $callsign',
          GlobalController.get().currentUserUid,
          NotificationData(postId, postInitializer, postAuthor));
    } catch (e) {
      print('could not send push');
    }
  }

  Future<void> fetchDm() async {
    var directMessageField = await Firestore.instance
        .collection('directMessages')
        .where('postId', isEqualTo: postId)
        .where('initializerId', isEqualTo: postInitializer)
        .get();

    print(directMessageField.docs.length);
    if (directMessageField.docs.length == 0) {
      return Future.error(CommentsErrorCode.DidntInitializeData);
    }
    thisDocument = directMessageField.docs[0];
    thisDocumentReference = directMessageField.docs[0].id;

    commentsStream = Firestore.instance
        .collection('directMessages')
        .doc(thisDocumentReference)
        .collection('messages')
        .orderBy('time', descending: true)
        .limit(QUERY_SIZE)
        .snapshots();
  }

  void blockCallback() {
    setState(() {
      blockText = "Unblock";
      buttonCallback = unblockCallback;
    });
    blockCommunication();
  }

  void unblockCallback() {
    setState(() {
      blockText = "Block";
      buttonCallback = blockCallback;
    });
    unblockCommunication();
  }

  void deleteConversation() async {
    await Firestore.instance
        .collection('directMessages')
        .doc(thisDocumentReference)
        .collection('messages')
        .get()
        .then((snapshot) {
      for (var document in snapshot.docs) {
        document.reference.delete();
      }
    });
    await Firestore.instance
        .collection('directMessages')
        .doc(thisDocumentReference)
        .delete();
    Navigator.pop(context);
  }

  void blockCommunication() async {
    await Firestore.instance
        .collection('directMessages')
        .doc(thisDocumentReference)
        .update({
      'isBlocked':
          FieldValue.arrayUnion([GlobalController.get().currentUserUid])
    });
  }

  void unblockCommunication() async {
    await Firestore.instance
        .collection('directMessages')
        .doc(thisDocumentReference)
        .update({
      'isBlocked':
          FieldValue.arrayRemove([GlobalController.get().currentUserUid])
    });
  }

  @override
  Widget build(BuildContext context) {
    if (firstBuild) {
      List<dynamic> arguments = ModalRoute.of(context).settings.arguments;
      postId = arguments[0];
      postInitializer = arguments[1];
      postAuthor = arguments[2];
      fetchDmFuture = fetchDm();
      firstBuild = false;
    }
    return Scaffold(
        appBar: AppBar(
            actions: [
              Center(
                  child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: RaisedButton(
                    onPressed: commentsStream == null ? null : buttonCallback,
                    child: Text(blockText)),
              ))
            ],
            actionsIconTheme: IconThemeData(color: Colors.black),
            iconTheme: IconThemeData(color: Colors.black),
            backgroundColor: Colors.white,
            elevation: 5.0,
            title:
                Text('Direct message ', style: TextStyle(color: Colors.black))),
        body: SafeArea(
            child: Container(
                decoration: BoxDecoration(color: Colors.white),
                child: FutureBuilder(
                  future: fetchDmFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.active ||
                        snapshot.connectionState == ConnectionState.waiting) {
                      return Container(
                          child: Center(
                              child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/logo.png', width: 200),
                          SizedBox(height: 30),
                          SpinKitThreeBounce(
                            color: spinnerColor,
                            size: 60,
                          ),
                        ],
                      )));
                    } else if (snapshot.hasError &&
                        snapshot.error ==
                            CommentsErrorCode.DidntInitializeData) {
                      print("IT IS HERE");
                      return Column(children: [
                        Expanded(
                            flex: 8,
                            child: Container(
                                child: Center(
                                    child: Text('Start messaging!',
                                        style: disabledUpperBarStyle)))),
                        Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(color: Colors.black45, blurRadius: 5)
                              ],
                              color: Colors.white,
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                children: [
                                  SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxHeight: 300,
                                          ),
                                          child: TextField(
                                            maxLength: 245,
                                            decoration: InputDecoration(
                                                counterText: "",
                                                hintStyle:
                                                    disabledUpperBarStyle),
                                            maxLines: null,
                                            style: disabledUpperBarStyle,
                                            controller: messageTextController,
                                            onChanged: (value) {
                                              messageText = value;
                                            },
                                          ),
                                        ),
                                      ),
                                      FlatButton(
                                          disabledColor: Colors.transparent,
                                          color: Colors.transparent,
                                          child: Center(
                                              child: Text('Send',
                                                  style: TextStyle(
                                                      color: Colors.blue))),
                                          onPressed: initialSendButtonCallback)
                                    ],
                                  ),
                                  Divider(color: Colors.black),
                                  SizedBox(height: 10),
                                ],
                              ),
                            ))
                      ]);
                    } else if (snapshot.hasError &&
                        snapshot.error ==
                            CommentsErrorCode.FailedToInitialize) {
                      return Column(children: [
                        Expanded(
                            flex: 8,
                            child: Container(
                                child: Center(
                                    child: Text(
                                        'Failed to initialize, try again!',
                                        style: disabledUpperBarStyle)))),
                        Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                children: [
                                  SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxHeight: 300,
                                          ),
                                          child: TextField(
                                            maxLength: 245,
                                            decoration: InputDecoration(
                                                counterText: "",
                                                hintStyle:
                                                    disabledUpperBarStyle),
                                            maxLines: null,
                                            style: disabledUpperBarStyle,
                                            controller: messageTextController,
                                            onChanged: (value) {
                                              messageText = value;
                                            },
                                          ),
                                        ),
                                      ),
                                      FlatButton(
                                          disabledColor: Colors.transparent,
                                          color: Colors.transparent,
                                          child: Center(
                                              child: Text('Send',
                                                  style: TextStyle(
                                                      color: Colors.blue))),
                                          onPressed: initialSendButtonCallback)
                                    ],
                                  ),
                                  Divider(color: Colors.black),
                                  SizedBox(height: 10),
                                ],
                              ),
                            ))
                      ]);
                    } else if (snapshot.connectionState ==
                        ConnectionState.done) {
                      if (firstTimeBuildingStream) {
                        WidgetsBinding.instance
                            .addPostFrameCallback((timeStamp) {
                          setState(() {
                            username = thisDocument.get('conversationPartner');
                            firstTimeBuildingStream = false;
                            commentsStream = Firestore.instance
                                .collection('directMessages')
                                .doc(thisDocumentReference)
                                .collection('messages')
                                .orderBy('time', descending: true)
                                .limit(QUERY_SIZE)
                                .snapshots();
                            if (thisDocument != null) {
                              isBlocked = thisDocument
                                  .get('isBlocked')
                                  .toSet()
                                  .contains(
                                      GlobalController.get().currentUserUid);
                              if (isBlocked) {
                                blockText = "Unblock";
                                buttonCallback = unblockCallback;
                              } else {
                                blockText = "Block";
                                buttonCallback = blockCallback;
                              }
                              snapshotStream = Firestore.instance
                                  .collection('directMessages')
                                  .doc(thisDocumentReference)
                                  .snapshots()
                                  .listen((event) {
                                if (event.get('isBlocked').length > 0) {
                                  isBlocked = true;
                                } else {
                                  isBlocked = false;
                                }
                              });
                            }
                          });
                        });
                        return Container(
                            child: Center(
                                child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset('assets/logo.png', width: 200),
                            SizedBox(height: 30),
                            SpinKitThreeBounce(
                              color: spinnerColor,
                              size: 60,
                            ),
                          ],
                        )));
                      }
                      return Column(children: [
                        StreamBuilder(
                            stream: commentsStream,
                            builder: (context, snapshot) {
                              var messages = [].reversed;
                              var listMessages = [];
                              if (snapshot.data != null) {
                                List<QueryDocumentSnapshot> messagesReversed =
                                    snapshot.data.docs;
                                messages = messagesReversed;
                                listMessages = messages.toList();
                              }
                              bool nextIsMe = false;
                              List<Widget> messageBubbles = [];
                              int i = 0;
                              for (var doc in messages) {
                                i = i + 1;
                                if (i > messages.length - 1) {
                                  nextIsMe =
                                      GlobalController.get().currentUserUid !=
                                          doc.get('senderUid');
                                } else {
                                  nextIsMe = listMessages[i].get('senderUid') ==
                                      GlobalController.get().currentUserUid;
                                }
                                messageBubbles.add(MessageBubble(
                                    nextIsMe: nextIsMe,
                                    callsign: username,
                                    sender: (doc.get('senderUid') ==
                                            GlobalController.get()
                                                .currentUserUid)
                                        ? 'YOU'
                                        : 'SOMEONE',
                                    text: doc.get('text'),
                                    isMe: doc.get('senderUid') ==
                                        GlobalController.get().currentUserUid));
                              }
                              return Expanded(
                                  flex: 8,
                                  child: ListView(
                                    reverse: true,
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 0.0, vertical: 20.0),
                                    children: messageBubbles,
                                  ));
                            }),
                        Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(color: Colors.black45, blurRadius: 5)
                              ],
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                children: [
                                  SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxHeight: 300,
                                          ),
                                          child: TextField(
                                            maxLength: 245,
                                            decoration: InputDecoration(
                                                counterText: "",
                                                hintStyle:
                                                    disabledUpperBarStyle),
                                            maxLines: null,
                                            style: disabledUpperBarStyle,
                                            controller: messageTextController,
                                            onChanged: (value) {
                                              messageText = value;
                                            },
                                          ),
                                        ),
                                      ),
                                      FlatButton(
                                          disabledColor: Colors.transparent,
                                          color: Colors.transparent,
                                          child: Center(
                                              child: Text('Send',
                                                  style: TextStyle(
                                                      color: Colors.blue))),
                                          onPressed: sendNormal)
                                    ],
                                  ),
                                  Divider(color: Colors.black),
                                  SizedBox(height: 10),
                                ],
                              ),
                            )),
                      ]);
                    }
                    return Container(
                        child: Center(
                            child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/logo.png', width: 200),
                        SizedBox(height: 30),
                        SpinKitThreeBounce(
                          color: spinnerColor,
                          size: 60,
                        ),
                      ],
                    )));
                  },
                ))));
  }
}

class MessageBubble extends StatelessWidget {
  MessageBubble(
      {this.callsign,
      this.sender,
      this.text,
      this.isMe,
      this.nextIsMe = false});

  final bool nextIsMe;
  final String callsign;
  final String sender;
  final String text;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    Color backgroundColor = Color.fromARGB(255, callsign.codeUnitAt(0),
        callsign.codeUnitAt(1), callsign.codeUnitAt(2));
    String theChar = callsign[0];

    Widget partnerImage = ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          color: backgroundColor,
          width: 20,
          height: 20,
          child: Center(
            child: Text(theChar,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
        ));

    return Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 100,
          child: ((isMe && !nextIsMe) || (!isMe && nextIsMe))
              ? (isMe
                  ? Text(
                      sender,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    )
                  : Row(
                      children: [
                        SizedBox(width: 5),
                        partnerImage,
                        SizedBox(width: 5),
                        Text('SOMEONE',
                            style: TextStyle(
                              fontSize: 12.0,
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                            ))
                      ],
                    ))
              : SizedBox(),
        ),
        CustomPaint(
          size: Size.infinite,
          painter: ((isMe && !nextIsMe) || (!isMe && nextIsMe))
              ? CustomBubble(!isMe)
              : null,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 15.0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
