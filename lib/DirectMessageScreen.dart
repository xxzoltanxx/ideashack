import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'Const.dart';

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
    if (messageText.length == 0) {
      return;
    }
    messageTextController.clear();
    setState(() {
      fetchDmFuture = initialize();
    });
  }

  void sendNormal() async {
    if (messageText.length == 0) {
      return;
    }
    messageTextController.clear();
    normalPostAsyncAction();
  }

  void normalPostAsyncAction() async {
    var time = await getCurrentTimestampServer();
    try {
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

  Future<void> initialize() async {
    try {
      var time = await getCurrentTimestampServer();
      var ref = await Firestore.instance.collection('directMessages').add({
        'initializerId': postInitializer,
        'postId': postId,
        'postAuthorId': postAuthor,
        'lastSeenInitializer': time,
        'lastSeenAuthor': 0.toDouble(),
        'posters': [postAuthor, postInitializer],
        'lastMessage': time
      });
      thisDocumentReference = ref.id;
      await ref.collection('messages').add({
        'text': messageText,
        'sender': GlobalController.get().currentUser.displayName,
        'senderUid': GlobalController.get().currentUserUid,
        'time': time
      });
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
      GlobalController.get().callOnFcmApiSendPushNotifications(
          [otherUserPushId],
          'New direct message!',
          'New chat message from ${GlobalController.get().getUserName()}',
          GlobalController.get().currentUserUid);
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

    thisDocumentReference = directMessageField.docs[0].id;

    var res = await Firestore.instance
        .collection('directMessages')
        .doc(thisDocumentReference)
        .collection('messages')
        .get();
    print(res.docs[0].data());

    commentsStream = Firestore.instance
        .collection('directMessages')
        .doc(thisDocumentReference)
        .collection('messages')
        .orderBy('time')
        .snapshots();
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
        appBar: AppBar(title: Text('Direct message')),
        body: FutureBuilder(
          future: fetchDmFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.active ||
                snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                  child: Center(
                      child: SpinKitRing(size: 100, color: spinnerColor)));
            } else if (snapshot.hasError &&
                snapshot.error == CommentsErrorCode.DidntInitializeData) {
              print("IT IS HERE");
              return Column(children: [
                Expanded(
                    flex: 8,
                    child: Container(
                        child: Center(child: Text('Start messaging!')))),
                Expanded(
                  flex: 2,
                  child: Container(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: 300,
                            ),
                            child: TextField(
                              maxLines: null,
                              controller: messageTextController,
                              onChanged: (value) {
                                messageText = value;
                              },
                            ),
                          ),
                        ),
                        FlatButton(
                          onPressed: initialSendButtonCallback,
                          child: Text(
                            'Send',
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ]);
            } else if (snapshot.hasError &&
                snapshot.error == CommentsErrorCode.FailedToInitialize) {
              return Column(children: [
                Expanded(
                    flex: 8,
                    child: Container(
                        child: Center(
                            child: Text('Failed to initialize, try again!')))),
                Container(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: 300,
                          ),
                          child: TextField(
                            maxLines: null,
                            controller: messageTextController,
                            onChanged: (value) {
                              messageText = value;
                            },
                          ),
                        ),
                      ),
                      FlatButton(
                        onPressed: initialSendButtonCallback,
                        child: Text(
                          'Send',
                        ),
                      ),
                    ],
                  ),
                )
              ]);
            } else if (snapshot.connectionState == ConnectionState.done) {
              if (firstTimeBuildingStream) {
                WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                  setState(() {
                    firstTimeBuildingStream = false;
                    commentsStream = Firestore.instance
                        .collection('directMessages')
                        .doc(thisDocumentReference)
                        .collection('messages')
                        .orderBy('time')
                        .snapshots();
                  });
                });
                return Container(
                    child: Center(
                        child: SpinKitRing(size: 100, color: spinnerColor)));
              }
              return Column(children: [
                StreamBuilder(
                    stream: commentsStream,
                    builder: (context, snapshot) {
                      print(commentsStream);
                      var messages = [].reversed;
                      if (snapshot.data != null) {
                        List<QueryDocumentSnapshot> messagesReversed =
                            snapshot.data.docs;
                        messages = messagesReversed.reversed;
                      }

                      List<Widget> messageBubbles = [];
                      for (var doc in messages) {
                        messageBubbles.add(MessageBubble(
                            sender: doc.get('sender'),
                            text: doc.get('text'),
                            isMe: doc.get('senderUid') ==
                                GlobalController.get().currentUserUid));
                      }
                      return Expanded(
                          flex: 8,
                          child: ListView(
                            reverse: true,
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.0, vertical: 20.0),
                            children: messageBubbles,
                          ));
                    }),
                Expanded(
                  flex: 2,
                  child: Container(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: 300,
                            ),
                            child: TextField(
                              maxLines: null,
                              controller: messageTextController,
                              onChanged: (value) {
                                messageText = value;
                              },
                            ),
                          ),
                        ),
                        FlatButton(
                          onPressed: sendNormal,
                          child: Text(
                            'Send',
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ]);
            }
            return Container(
                child:
                    Center(child: SpinKitRing(size: 100, color: spinnerColor)));
          },
        ));
  }
}

class MessageBubble extends StatelessWidget {
  MessageBubble({this.sender, this.text, this.isMe});

  final String sender;
  final String text;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            sender,
            style: TextStyle(
              fontSize: 12.0,
              color: Colors.white,
            ),
          ),
          Material(
            borderRadius: isMe
                ? BorderRadius.only(
                    topLeft: Radius.circular(30.0),
                    bottomLeft: Radius.circular(30.0),
                    bottomRight: Radius.circular(30.0))
                : BorderRadius.only(
                    bottomLeft: Radius.circular(30.0),
                    bottomRight: Radius.circular(30.0),
                    topRight: Radius.circular(30.0),
                  ),
            elevation: 5.0,
            color: isMe ? Colors.lightBlueAccent : Colors.white,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
              child: Text(
                text,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black54,
                  fontSize: 15.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
