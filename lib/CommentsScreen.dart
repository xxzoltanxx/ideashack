import 'package:flutter/material.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Const.dart';
import 'MainScreenMisc.dart';
import 'Analytics.dart';

class CommentsScreen extends StatefulWidget {
  @override
  _CommentsScreenState createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  CardData cardData;
  String inputText = "";
  bool firstBuild = true;
  bool shownErrorMessage = false;
  Function commentsCallback;
  TextEditingController messageTextController;
  Future<void> postingFuture;

  @override
  void initState() {
    postingFuture = null;
    super.initState();
  }

  Future<void> postComment(String inputText) async {
    try {
      double time = await getCurrentTimestampServer();
      String input = inputText;
      try {
        DocumentSnapshot snapshot =
            await Firestore.instance.collection('posts').doc(cardData.id).get();
        if (!snapshot.exists) {
          return Future.error(1);
        }
      } catch (e) {
        return Future.error(1);
      }
      var ref = await Firestore.instance
          .collection('posts')
          .doc(cardData.id)
          .collection('comments')
          .add({'comment': input, 'time': time});
      await Firestore.instance.collection('posts').doc(cardData.id).update(
          {'commentsNum': FieldValue.increment(1), 'lastCommentTime': time});
      await Firestore.instance
          .collection('users')
          .doc(GlobalController.get().userDocId)
          .update({
        'commented': FieldValue.arrayUnion([cardData.id])
      });
      AnalyticsController.get().postedComment(cardData.id, ref.id);
      sendPushNotification();
    } catch (e) {
      print(e);
    }
  }

  void sendPushNotification() async {
    try {
      QuerySnapshot userDataa = await Firestore.instance
          .collection('users')
          .where('uid', isEqualTo: cardData.posterId)
          .get();
      DocumentSnapshot userData = userDataa.docs[0];
      print(userData.exists);
      print(userData.get('pushToken'));
      if (userData.exists && userData.get('pushToken') != null) {
        GlobalController.get().callOnFcmApiSendPushNotifications(
            [userData.get('pushToken')],
            'New comment on your idea!',
            'Someone posted a new comment on your idea!',
            'comment',
            NotificationData(cardData.id, null, null));
      }
    } catch (e) {
      print(e);
    }
  }

  void buttonCallback() {
    bool profane = false;
    if (spamFilter.isProfane(inputText) || inputText.trim().length < 15) {
      commentsCallback(cardData, InfoSheet.Profane);
    }
    if (!profane) {
      setState(() {
        postingFuture = postComment(inputText);
      });
    }
  }

  void syncTimeAction() async {
    if (cardData.posterId == GlobalController.get().currentUserUid) {
      var time = await getCurrentTimestampServer();
      try {
        Firestore.instance
            .collection('posts')
            .doc(cardData.id)
            .update({'lastSeenComments': time});
      } catch (e) {
        print(e);
      }
    }
  }

  @override
  void dispose() {
    syncTimeAction();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (firstBuild) {
      messageTextController = TextEditingController(text: inputText);
      firstBuild = false;
      List<dynamic> list = ModalRoute.of(context).settings.arguments;
      cardData = list[0];
      commentsCallback = list[1];
      syncTimeAction();
    }
    return Scaffold(
      appBar: AppBar(
          iconTheme: IconThemeData(color: Colors.black),
          backgroundColor: Colors.white,
          elevation: 5.0,
          title:
              Text('Viewing comments', style: TextStyle(color: Colors.black))),
      body: FutureBuilder(
          future: postingFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              if (!shownErrorMessage) {
                WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                  commentsCallback(cardData, InfoSheet.Deleted);
                });
                shownErrorMessage = true;
              }
              return SafeArea(
                  child: Container(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                        colors: [Color(0xFFDBDBDB), Color(0xFFFFFFFF)],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      )),
                      child: GestureDetector(
                        onTap: () {
                          FocusScope.of(context).requestFocus(new FocusNode());
                        },
                        child: Column(
                          children: [
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: Column(
                                  children: [
                                    SizedBox(height: 30),
                                    Row(
                                      children: [
                                        Image.asset(
                                          'assets/score.png',
                                          width: 40,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(width: 10),
                                        Text(cardData.score.toString(),
                                            style:
                                                enabledUpperBarStyle.copyWith(
                                                    color: Colors.grey,
                                                    fontSize: 25))
                                      ],
                                    ),
                                    SizedBox(height: 20),
                                    Text(cardData.text,
                                        style: disabledUpperBarStyle),
                                    SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Comments',
                                            style: enabledUpperBarStyle),
                                        Icon(Icons.arrow_drop_down,
                                            color: disabledUpperBarColor),
                                      ],
                                    ),
                                    Divider(color: disabledUpperBarColor),
                                    SizedBox(height: 20),
                                    Expanded(
                                        flex: 5,
                                        child: Center(
                                            child: Text(
                                                'Post has been removed!',
                                                style: disabledUpperBarStyle)))
                                  ],
                                ),
                              ),
                            ),
                            Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
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
                                                decoration: InputDecoration(
                                                    hintStyle:
                                                        disabledUpperBarStyle,
                                                    hintText: cardData.commented
                                                        ? 'You already commented here..'
                                                        : 'Add a comment...'),
                                                maxLines: null,
                                                style: disabledUpperBarStyle,
                                                controller:
                                                    messageTextController,
                                                onChanged: (value) {
                                                  inputText = value;
                                                },
                                              ),
                                            ),
                                          ),
                                          FlatButton(
                                              disabledColor: Colors.transparent,
                                              color: Colors.transparent,
                                              child: Center(
                                                  child: Text('Post',
                                                      style: TextStyle(
                                                          color: Colors.grey))),
                                              onPressed: null)
                                        ],
                                      ),
                                      Divider(color: Colors.black),
                                      SizedBox(height: 10),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      )));
            } else if (snapshot.connectionState == ConnectionState.none) {
              return StreamBuilder(
                  stream: Firestore.instance
                      .collection('posts')
                      .doc(cardData.id)
                      .collection('comments')
                      .orderBy('time', descending: true)
                      .limit(100)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.data == null) {
                      return SafeArea(
                          child: Container(
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                colors: [Color(0xFFDBDBDB), Color(0xFFFFFFFF)],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              )),
                              child: GestureDetector(
                                onTap: () {
                                  FocusScope.of(context)
                                      .requestFocus(new FocusNode());
                                },
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20),
                                        child: Column(
                                          children: [
                                            SizedBox(height: 30),
                                            Row(
                                              children: [
                                                Image.asset(
                                                  'assets/score.png',
                                                  width: 40,
                                                  color: Colors.grey,
                                                ),
                                                SizedBox(width: 10),
                                                Text(cardData.score.toString(),
                                                    style: enabledUpperBarStyle
                                                        .copyWith(
                                                            color: Colors.grey,
                                                            fontSize: 25))
                                              ],
                                            ),
                                            SizedBox(height: 20),
                                            Text(cardData.text,
                                                style: disabledUpperBarStyle),
                                            SizedBox(height: 20),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text('Comments',
                                                    style:
                                                        enabledUpperBarStyle),
                                                Icon(Icons.arrow_drop_down,
                                                    color:
                                                        disabledUpperBarColor),
                                              ],
                                            ),
                                            Divider(
                                                color: disabledUpperBarColor),
                                            SizedBox(height: 20),
                                            Expanded(
                                                flex: 5,
                                                child: Container(
                                                    child: Center(
                                                        child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Image.asset(
                                                        'assets/logo.png',
                                                        width: 200),
                                                    SizedBox(height: 30),
                                                    SpinKitThreeBounce(
                                                      color: spinnerColor,
                                                      size: 60,
                                                    ),
                                                  ],
                                                ))))
                                          ],
                                        ),
                                      ),
                                    ),
                                    Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20),
                                          child: Column(
                                            children: [
                                              SizedBox(height: 10),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: ConstrainedBox(
                                                      constraints:
                                                          BoxConstraints(
                                                        maxHeight: 300,
                                                      ),
                                                      child: TextField(
                                                        decoration: InputDecoration(
                                                            hintStyle:
                                                                disabledUpperBarStyle,
                                                            hintText: cardData
                                                                    .commented
                                                                ? 'You already commented here..'
                                                                : 'Add a comment...'),
                                                        maxLines: null,
                                                        style:
                                                            disabledUpperBarStyle,
                                                        controller:
                                                            messageTextController,
                                                        onChanged: (value) {
                                                          setState(() {
                                                            inputText = value;
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                  FlatButton(
                                                    disabledColor:
                                                        Colors.transparent,
                                                    color: Colors.transparent,
                                                    child: Center(
                                                        child: Text('Post',
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .grey))),
                                                    onPressed: null,
                                                  )
                                                ],
                                              ),
                                              Divider(color: Colors.black),
                                              SizedBox(height: 10),
                                            ],
                                          ),
                                        )),
                                  ],
                                ),
                              )));
                    } else if (snapshot.hasData) {
                      List<Widget> comments = [];
                      Widget noCommentsWidget;
                      if (snapshot.data.docs.length == 0) {
                        noCommentsWidget = (Center(
                            child: Text('There are no comments yet.',
                                style: disabledUpperBarStyle)));
                      } else {
                        for (var doc in snapshot.data.docs) {
                          comments.add(Center(
                              child: Comment(
                                  comment: doc.get('comment'),
                                  timestamp: doc.get('time'),
                                  postId: cardData.id,
                                  commentId: doc.id)));
                        }
                      }
                      return SafeArea(
                          child: Container(
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                colors: [Color(0xFFDBDBDB), Color(0xFFFFFFFF)],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              )),
                              child: GestureDetector(
                                onTap: () {
                                  FocusScope.of(context)
                                      .requestFocus(new FocusNode());
                                },
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20),
                                        child: Column(
                                          children: [
                                            SizedBox(height: 30),
                                            Row(
                                              children: [
                                                Image.asset(
                                                  'assets/score.png',
                                                  width: 40,
                                                  color: Colors.grey,
                                                ),
                                                SizedBox(width: 10),
                                                Text(cardData.score.toString(),
                                                    style: enabledUpperBarStyle
                                                        .copyWith(
                                                            color: Colors.grey,
                                                            fontSize: 25))
                                              ],
                                            ),
                                            SizedBox(height: 20),
                                            Text(cardData.text,
                                                style: disabledUpperBarStyle),
                                            SizedBox(height: 20),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text('Comments',
                                                    style:
                                                        enabledUpperBarStyle),
                                                Icon(Icons.arrow_drop_down,
                                                    color:
                                                        disabledUpperBarColor),
                                              ],
                                            ),
                                            Divider(
                                                color: disabledUpperBarColor),
                                            SizedBox(height: 20),
                                            Expanded(
                                                flex: 5,
                                                child: noCommentsWidget != null
                                                    ? noCommentsWidget
                                                    : Center(
                                                        child: ListView(
                                                            shrinkWrap: false,
                                                            reverse: false,
                                                            children:
                                                                comments))),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20),
                                          child: Column(
                                            children: [
                                              SizedBox(height: 10),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: ConstrainedBox(
                                                      constraints:
                                                          BoxConstraints(
                                                        maxHeight: 300,
                                                      ),
                                                      child: TextField(
                                                        decoration: InputDecoration(
                                                            hintStyle:
                                                                disabledUpperBarStyle,
                                                            hintText: cardData
                                                                    .commented
                                                                ? 'You already commented here..'
                                                                : 'Add a comment...'),
                                                        maxLines: null,
                                                        style:
                                                            disabledUpperBarStyle,
                                                        controller:
                                                            messageTextController,
                                                        onChanged: (value) {
                                                          setState(() {
                                                            inputText = value;
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                  FlatButton(
                                                      disabledColor:
                                                          Colors.transparent,
                                                      color: Colors.transparent,
                                                      child: Center(
                                                          child: Text('Post',
                                                              style: TextStyle(
                                                                  color: (cardData
                                                                              .commented ||
                                                                          inputText.length <
                                                                              15)
                                                                      ? Colors
                                                                          .grey
                                                                      : Colors
                                                                          .blue))),
                                                      onPressed: (cardData
                                                                  .commented ||
                                                              inputText.length <
                                                                  15)
                                                          ? null
                                                          : buttonCallback)
                                                ],
                                              ),
                                              Divider(color: Colors.black),
                                              SizedBox(height: 10),
                                            ],
                                          ),
                                        )),
                                  ],
                                ),
                              )));
                    } else if (snapshot.hasError) {
                      return SafeArea(
                          child: Container(
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                colors: [Color(0xFFDBDBDB), Color(0xFFFFFFFF)],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              )),
                              child: GestureDetector(
                                onTap: () {
                                  FocusScope.of(context)
                                      .requestFocus(new FocusNode());
                                },
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20),
                                        child: Column(
                                          children: [
                                            SizedBox(height: 30),
                                            Row(
                                              children: [
                                                Image.asset(
                                                  'assets/score.png',
                                                  width: 40,
                                                  color: Colors.grey,
                                                ),
                                                SizedBox(width: 10),
                                                Text(cardData.score.toString(),
                                                    style: enabledUpperBarStyle
                                                        .copyWith(
                                                            color: Colors.grey,
                                                            fontSize: 25))
                                              ],
                                            ),
                                            SizedBox(height: 20),
                                            Text(cardData.text,
                                                style: disabledUpperBarStyle),
                                            SizedBox(height: 20),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text('Comments',
                                                    style:
                                                        enabledUpperBarStyle),
                                                Icon(Icons.arrow_drop_down,
                                                    color:
                                                        disabledUpperBarColor),
                                              ],
                                            ),
                                            Divider(
                                                color: disabledUpperBarColor),
                                            SizedBox(height: 20),
                                            Expanded(
                                                child: Center(
                                                    child: Text(
                                                        'Something went wrong with fetching the comments...',
                                                        style:
                                                            disabledUpperBarStyle)))
                                          ],
                                        ),
                                      ),
                                    ),
                                    Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20),
                                          child: Column(
                                            children: [
                                              SizedBox(height: 10),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: ConstrainedBox(
                                                      constraints:
                                                          BoxConstraints(
                                                        maxHeight: 300,
                                                      ),
                                                      child: TextField(
                                                        decoration: InputDecoration(
                                                            hintStyle:
                                                                disabledUpperBarStyle,
                                                            hintText: cardData
                                                                    .commented
                                                                ? 'You already commented here..'
                                                                : 'Add a comment...'),
                                                        maxLines: null,
                                                        style:
                                                            disabledUpperBarStyle,
                                                        controller:
                                                            messageTextController,
                                                        onChanged: (value) {
                                                          setState(() {
                                                            inputText = value;
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                  FlatButton(
                                                      disabledColor:
                                                          Colors.transparent,
                                                      color: Colors.transparent,
                                                      child: Center(
                                                          child: Text('Post',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .blue))),
                                                      onPressed: (cardData
                                                                  .commented ||
                                                              inputText.length <
                                                                  15)
                                                          ? null
                                                          : buttonCallback)
                                                ],
                                              ),
                                              Divider(color: Colors.black),
                                              SizedBox(height: 10),
                                            ],
                                          ),
                                        )),
                                  ],
                                ),
                              )));
                    }
                    return SafeArea(
                        child: Container(
                            decoration: BoxDecoration(
                                gradient: LinearGradient(
                              colors: [Color(0xFFDBDBDB), Color(0xFFFFFFFF)],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            )),
                            child: GestureDetector(
                              onTap: () {
                                FocusScope.of(context)
                                    .requestFocus(new FocusNode());
                              },
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20),
                                      child: Column(
                                        children: [
                                          SizedBox(height: 30),
                                          Row(
                                            children: [
                                              Image.asset(
                                                'assets/score.png',
                                                width: 40,
                                                color: Colors.grey,
                                              ),
                                              SizedBox(width: 10),
                                              Text(cardData.score.toString(),
                                                  style: enabledUpperBarStyle
                                                      .copyWith(
                                                          color: Colors.grey,
                                                          fontSize: 25))
                                            ],
                                          ),
                                          SizedBox(height: 20),
                                          Text(cardData.text,
                                              style: disabledUpperBarStyle),
                                          SizedBox(height: 20),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Comments',
                                                  style: enabledUpperBarStyle),
                                              Icon(Icons.arrow_drop_down,
                                                  color: disabledUpperBarColor),
                                            ],
                                          ),
                                          Divider(color: disabledUpperBarColor),
                                          SizedBox(height: 20),
                                          Expanded(
                                              child: Center(
                                                  child: Text(
                                                      'Something went wrong with fetching the comments...',
                                                      style:
                                                          disabledUpperBarStyle)))
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20),
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
                                                      decoration: InputDecoration(
                                                          hintStyle:
                                                              disabledUpperBarStyle,
                                                          hintText: cardData
                                                                  .commented
                                                              ? 'You already commented here..'
                                                              : 'Add a comment...'),
                                                      maxLines: null,
                                                      style:
                                                          disabledUpperBarStyle,
                                                      controller:
                                                          messageTextController,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          inputText = value;
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                FlatButton(
                                                    disabledColor:
                                                        Colors.transparent,
                                                    color: Colors.transparent,
                                                    child: Center(
                                                        child: Text('Post',
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .blue))),
                                                    onPressed: (cardData
                                                                .commented ||
                                                            inputText.length <
                                                                15)
                                                        ? null
                                                        : buttonCallback)
                                              ],
                                            ),
                                            Divider(color: Colors.black),
                                            SizedBox(height: 10),
                                          ],
                                        ),
                                      )),
                                ],
                              ),
                            )));
                  });
            }
            if (snapshot.connectionState == ConnectionState.waiting ||
                snapshot.connectionState == ConnectionState.active) {
              return SafeArea(
                  child: Container(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                        colors: [Color(0xFFDBDBDB), Color(0xFFFFFFFF)],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      )),
                      child: GestureDetector(
                        onTap: () {
                          FocusScope.of(context).requestFocus(new FocusNode());
                        },
                        child: Column(
                          children: [
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: Column(
                                  children: [
                                    SizedBox(height: 30),
                                    Row(
                                      children: [
                                        Image.asset(
                                          'assets/score.png',
                                          width: 40,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(width: 10),
                                        Text(cardData.score.toString(),
                                            style:
                                                enabledUpperBarStyle.copyWith(
                                                    color: Colors.grey,
                                                    fontSize: 25))
                                      ],
                                    ),
                                    SizedBox(height: 20),
                                    Text(cardData.text,
                                        style: disabledUpperBarStyle),
                                    SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Comments',
                                            style: enabledUpperBarStyle),
                                        Icon(Icons.arrow_drop_down,
                                            color: disabledUpperBarColor),
                                      ],
                                    ),
                                    Divider(color: disabledUpperBarColor),
                                    SizedBox(height: 20),
                                    Expanded(
                                        flex: 5,
                                        child: Center(
                                            child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Image.asset('assets/logo.png',
                                                width: 200),
                                            SizedBox(height: 30),
                                            SpinKitThreeBounce(
                                              color: spinnerColor,
                                              size: 60,
                                            ),
                                          ],
                                        )))
                                  ],
                                ),
                              ),
                            ),
                            Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
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
                                                decoration: InputDecoration(
                                                    hintStyle:
                                                        disabledUpperBarStyle,
                                                    hintText: cardData.commented
                                                        ? 'You already commented here..'
                                                        : 'Add a comment...'),
                                                maxLines: null,
                                                style: disabledUpperBarStyle,
                                                controller:
                                                    messageTextController,
                                                onChanged: (value) {
                                                  inputText = value;
                                                },
                                              ),
                                            ),
                                          ),
                                          FlatButton(
                                              disabledColor: Colors.transparent,
                                              color: Colors.transparent,
                                              child: Center(
                                                  child: Text('Post',
                                                      style: TextStyle(
                                                          color: Colors.grey))),
                                              onPressed: null)
                                        ],
                                      ),
                                      Divider(color: Colors.black),
                                      SizedBox(height: 10),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      )));
            } else {
              WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                setState(() {
                  messageTextController.text = '';
                  inputText = '';
                  cardData.commented = true;
                  postingFuture = null;
                });
                commentsCallback(cardData, InfoSheet.Commented);
              });
              return StreamBuilder(
                  stream: Firestore.instance
                      .collection('posts')
                      .doc(cardData.id)
                      .collection('comments')
                      .orderBy('time', descending: true)
                      .limit(100)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.data == null) {
                      return SafeArea(
                          child: Container(
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                colors: [Color(0xFFDBDBDB), Color(0xFFFFFFFF)],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              )),
                              child: GestureDetector(
                                onTap: () {
                                  FocusScope.of(context)
                                      .requestFocus(new FocusNode());
                                },
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20),
                                        child: Column(
                                          children: [
                                            SizedBox(height: 30),
                                            Row(
                                              children: [
                                                Image.asset(
                                                  'assets/score.png',
                                                  width: 40,
                                                  color: Colors.grey,
                                                ),
                                                SizedBox(width: 10),
                                                Text(cardData.score.toString(),
                                                    style: enabledUpperBarStyle
                                                        .copyWith(
                                                            color: Colors.grey,
                                                            fontSize: 25))
                                              ],
                                            ),
                                            SizedBox(height: 20),
                                            Text(cardData.text,
                                                style: disabledUpperBarStyle),
                                            SizedBox(height: 20),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text('Comments',
                                                    style:
                                                        enabledUpperBarStyle),
                                                Icon(Icons.arrow_drop_down,
                                                    color:
                                                        disabledUpperBarColor),
                                              ],
                                            ),
                                            Divider(
                                                color: disabledUpperBarColor),
                                            SizedBox(height: 20),
                                            Expanded(
                                                flex: 5,
                                                child: Container(
                                                    child: Center(
                                                        child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Image.asset(
                                                        'assets/logo.png',
                                                        width: 200),
                                                    SizedBox(height: 30),
                                                    SpinKitThreeBounce(
                                                      color: spinnerColor,
                                                      size: 60,
                                                    ),
                                                  ],
                                                ))))
                                          ],
                                        ),
                                      ),
                                    ),
                                    Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20),
                                          child: Column(
                                            children: [
                                              SizedBox(height: 10),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: ConstrainedBox(
                                                      constraints:
                                                          BoxConstraints(
                                                        maxHeight: 300,
                                                      ),
                                                      child: TextField(
                                                        decoration: InputDecoration(
                                                            hintStyle:
                                                                disabledUpperBarStyle,
                                                            hintText: cardData
                                                                    .commented
                                                                ? 'You already commented here..'
                                                                : 'Add a comment...'),
                                                        maxLines: null,
                                                        style:
                                                            disabledUpperBarStyle,
                                                        controller:
                                                            messageTextController,
                                                        onChanged: (value) {
                                                          setState(() {
                                                            inputText = value;
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                  FlatButton(
                                                    disabledColor:
                                                        Colors.transparent,
                                                    color: Colors.transparent,
                                                    child: Center(
                                                        child: Text('Post',
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .grey))),
                                                    onPressed: null,
                                                  )
                                                ],
                                              ),
                                              Divider(color: Colors.black),
                                              SizedBox(height: 10),
                                            ],
                                          ),
                                        )),
                                  ],
                                ),
                              )));
                    } else if (snapshot.hasData) {
                      List<Widget> comments = [];
                      Widget noCommentsWidget;
                      if (snapshot.data.docs.length == 0) {
                        noCommentsWidget = (Center(
                            child: Center(
                                child: Text('There are no comments yet!'))));
                      } else {
                        for (var doc in snapshot.data.docs) {
                          comments.add(Center(
                              child: Comment(
                                  comment: doc.get('comment'),
                                  timestamp: doc.get('time'),
                                  postId: cardData.id,
                                  commentId: doc.id)));
                        }
                      }
                      return SafeArea(
                          child: Container(
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                colors: [Color(0xFFDBDBDB), Color(0xFFFFFFFF)],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              )),
                              child: GestureDetector(
                                onTap: () {
                                  FocusScope.of(context)
                                      .requestFocus(new FocusNode());
                                },
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20),
                                        child: Column(
                                          children: [
                                            SizedBox(height: 30),
                                            Row(
                                              children: [
                                                Image.asset(
                                                  'assets/score.png',
                                                  width: 40,
                                                  color: Colors.grey,
                                                ),
                                                SizedBox(width: 10),
                                                Text(cardData.score.toString(),
                                                    style: enabledUpperBarStyle
                                                        .copyWith(
                                                            color: Colors.grey,
                                                            fontSize: 25))
                                              ],
                                            ),
                                            SizedBox(height: 20),
                                            Text(cardData.text,
                                                style: disabledUpperBarStyle),
                                            SizedBox(height: 20),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text('Comments',
                                                    style:
                                                        enabledUpperBarStyle),
                                                Icon(Icons.arrow_drop_down,
                                                    color:
                                                        disabledUpperBarColor),
                                              ],
                                            ),
                                            Divider(
                                                color: disabledUpperBarColor),
                                            SizedBox(height: 20),
                                            Expanded(
                                                flex: 5,
                                                child: noCommentsWidget != null
                                                    ? noCommentsWidget
                                                    : Center(
                                                        child: ListView(
                                                            shrinkWrap: false,
                                                            reverse: false,
                                                            children:
                                                                comments))),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20),
                                          child: Column(
                                            children: [
                                              SizedBox(height: 10),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: ConstrainedBox(
                                                      constraints:
                                                          BoxConstraints(
                                                        maxHeight: 300,
                                                      ),
                                                      child: TextField(
                                                        decoration: InputDecoration(
                                                            hintStyle:
                                                                disabledUpperBarStyle,
                                                            hintText: cardData
                                                                    .commented
                                                                ? 'You already commented here..'
                                                                : 'Add a comment...'),
                                                        maxLines: null,
                                                        style:
                                                            disabledUpperBarStyle,
                                                        controller:
                                                            messageTextController,
                                                        onChanged: (value) {
                                                          setState(() {
                                                            inputText = value;
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                  FlatButton(
                                                      disabledColor:
                                                          Colors.transparent,
                                                      color: Colors.transparent,
                                                      child: Center(
                                                          child: Text('Post',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .blue))),
                                                      onPressed: (cardData
                                                                  .commented ||
                                                              inputText.length <
                                                                  15)
                                                          ? null
                                                          : buttonCallback)
                                                ],
                                              ),
                                              Divider(color: Colors.black),
                                              SizedBox(height: 10),
                                            ],
                                          ),
                                        )),
                                  ],
                                ),
                              )));
                    } else if (snapshot.hasError) {
                      return SafeArea(
                          child: Container(
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                colors: [Color(0xFFDBDBDB), Color(0xFFFFFFFF)],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              )),
                              child: GestureDetector(
                                onTap: () {
                                  FocusScope.of(context)
                                      .requestFocus(new FocusNode());
                                },
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20),
                                        child: Column(
                                          children: [
                                            SizedBox(height: 30),
                                            Row(
                                              children: [
                                                Image.asset(
                                                  'assets/score.png',
                                                  width: 40,
                                                  color: Colors.grey,
                                                ),
                                                SizedBox(width: 10),
                                                Text(cardData.score.toString(),
                                                    style: enabledUpperBarStyle
                                                        .copyWith(
                                                            color: Colors.grey,
                                                            fontSize: 25))
                                              ],
                                            ),
                                            SizedBox(height: 20),
                                            Text(cardData.text,
                                                style: disabledUpperBarStyle),
                                            SizedBox(height: 20),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text('Comments',
                                                    style:
                                                        enabledUpperBarStyle),
                                                Icon(Icons.arrow_drop_down,
                                                    color:
                                                        disabledUpperBarColor),
                                              ],
                                            ),
                                            Divider(
                                                color: disabledUpperBarColor),
                                            SizedBox(height: 20),
                                            Expanded(
                                                child: Center(
                                                    child: Text(
                                                        'Something went wrong with fetching the comments...',
                                                        style:
                                                            disabledUpperBarStyle)))
                                          ],
                                        ),
                                      ),
                                    ),
                                    Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20),
                                          child: Column(
                                            children: [
                                              SizedBox(height: 10),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: ConstrainedBox(
                                                      constraints:
                                                          BoxConstraints(
                                                        maxHeight: 300,
                                                      ),
                                                      child: TextField(
                                                        decoration: InputDecoration(
                                                            hintStyle:
                                                                disabledUpperBarStyle,
                                                            hintText: cardData
                                                                    .commented
                                                                ? 'You already commented here..'
                                                                : 'Add a comment...'),
                                                        maxLines: null,
                                                        style:
                                                            disabledUpperBarStyle,
                                                        controller:
                                                            messageTextController,
                                                        onChanged: (value) {
                                                          setState(() {
                                                            inputText = value;
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                  FlatButton(
                                                      disabledColor:
                                                          Colors.transparent,
                                                      color: Colors.transparent,
                                                      child: Center(
                                                          child: Text('Post',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .blue))),
                                                      onPressed: (cardData
                                                                  .commented ||
                                                              inputText.length <
                                                                  15)
                                                          ? null
                                                          : buttonCallback)
                                                ],
                                              ),
                                              Divider(color: Colors.black),
                                              SizedBox(height: 10),
                                            ],
                                          ),
                                        )),
                                  ],
                                ),
                              )));
                    }
                    return SafeArea(
                        child: Container(
                            decoration: BoxDecoration(
                                gradient: LinearGradient(
                              colors: [Color(0xFFDBDBDB), Color(0xFFFFFFFF)],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            )),
                            child: GestureDetector(
                              onTap: () {
                                FocusScope.of(context)
                                    .requestFocus(new FocusNode());
                              },
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20),
                                      child: Column(
                                        children: [
                                          SizedBox(height: 30),
                                          Row(
                                            children: [
                                              Image.asset(
                                                'assets/score.png',
                                                width: 40,
                                                color: Colors.grey,
                                              ),
                                              SizedBox(width: 10),
                                              Text(cardData.score.toString(),
                                                  style: enabledUpperBarStyle
                                                      .copyWith(
                                                          color: Colors.grey,
                                                          fontSize: 25))
                                            ],
                                          ),
                                          SizedBox(height: 20),
                                          Text(cardData.text,
                                              style: disabledUpperBarStyle),
                                          SizedBox(height: 20),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Comments',
                                                  style: enabledUpperBarStyle),
                                              Icon(Icons.arrow_drop_down,
                                                  color: disabledUpperBarColor),
                                            ],
                                          ),
                                          Divider(color: disabledUpperBarColor),
                                          SizedBox(height: 20),
                                          Expanded(
                                              child: Center(
                                                  child: Text(
                                                      'Something went wrong with fetching the comments...',
                                                      style:
                                                          disabledUpperBarStyle)))
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20),
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
                                                      decoration: InputDecoration(
                                                          hintStyle:
                                                              disabledUpperBarStyle,
                                                          hintText: cardData
                                                                  .commented
                                                              ? 'You already commented here..'
                                                              : 'Add a comment...'),
                                                      maxLines: null,
                                                      style:
                                                          disabledUpperBarStyle,
                                                      controller:
                                                          messageTextController,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          inputText = value;
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                FlatButton(
                                                    disabledColor:
                                                        Colors.transparent,
                                                    color: Colors.transparent,
                                                    child: Center(
                                                        child: Text('Post',
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .blue))),
                                                    onPressed: (cardData
                                                                .commented ||
                                                            inputText.length <
                                                                15)
                                                        ? null
                                                        : buttonCallback)
                                              ],
                                            ),
                                            Divider(color: Colors.black),
                                            SizedBox(height: 10),
                                          ],
                                        ),
                                      )),
                                ],
                              ),
                            )));
                  });
            }
          }),
    );
  }
}

class Comment extends StatefulWidget {
  Comment({this.comment, this.timestamp, this.postId, this.commentId}) {
    DateTime time =
        DateTime.fromMillisecondsSinceEpoch((this.timestamp * 1000).toInt());
    date = '${time.day}.${time.month}.${time.year}';
  }

  final String comment;
  final double timestamp;
  final String postId;
  final String commentId;
  String date;

  @override
  _CommentState createState() => _CommentState();
}

class _CommentState extends State<Comment> {
  Future<void> reportPost(
      String reason, String reporterId, String objection) async {
    try {
      User user = GlobalController.get().currentUser;
      var docs = await Firestore.instance
          .collection('reportedPosts')
          .where('postid', isEqualTo: widget.postId)
          .get();
      String postDocId = "";
      if (docs.docs.length == 0) {
        var ref = await Firestore.instance
            .collection('reportedPosts')
            .add({'postid': widget.postId, 'anonReports': 0, 'reports': 0});
        postDocId = ref.id;
      } else {
        postDocId = docs.docs[0].id;
      }
      var commentReported = await Firestore.instance
          .collection('reportedPosts')
          .doc(postDocId)
          .collection('comments')
          .where('commentId', isEqualTo: widget.commentId)
          .get();

      String commentDocId;
      if (commentReported.docs.length == 0) {
        DocumentReference doc;
        if (user.isAnonymous) {
          doc = await Firestore.instance
              .collection('reportedPosts')
              .doc(postDocId)
              .collection('comments')
              .add({
            'commentId': widget.commentId,
            'anonReports': 1,
            'reports': 0
          });
        } else {
          doc = await Firestore.instance
              .collection('reportedPosts')
              .doc(postDocId)
              .collection('comments')
              .add({
            'commentId': widget.commentId,
            'anonReports': 0,
            'reports': 1
          });
        }
        commentDocId = doc.id;
      } else {
        commentDocId = commentReported.docs[0].id;
      }
      if (!user.isAnonymous) {
        await Firestore.instance
            .collection('reportedPosts')
            .doc(postDocId)
            .collection('comments')
            .doc(commentDocId)
            .collection('reports')
            .add({
          'reporterId': GlobalController.get().currentUserUid,
          'reason': reason,
          'objection': objection
        });
      }
    } catch (e) {
      print(e);
      throw 1;
    }
  }

  void openReportScreen() {
    AnalyticsController.get()
        .reportTappedComment(widget.postId, widget.commentId);
    showDialog(
        context: context,
        builder: (_) => ReportPopup(
              GlobalController.get().currentUser.isAnonymous,
              false,
              reportPost,
            ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Posted on: ' + widget.date,
            style: disabledUpperBarStyle.copyWith(
                fontSize: 10, fontStyle: FontStyle.italic)),
        SizedBox(height: 20),
        Text(widget.comment, style: enabledUpperBarStyle),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FlatButton(
                onPressed: openReportScreen,
                child: Center(
                    child: Text('Report',
                        style: disabledUpperBarStyle.copyWith(fontSize: 10))))
          ],
        ),
        DottedLine(dashColor: disabledUpperBarColor),
        SizedBox(height: 20),
      ],
    ));
  }
}
