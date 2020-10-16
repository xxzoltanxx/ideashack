import 'package:flutter/material.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Const.dart';
import 'MainScreenMisc.dart';
import 'Analytics.dart';
import 'package:hashtagable/hashtagable.dart';
import 'package:wc_flutter_share/wc_flutter_share.dart';
import 'dart:typed_data';

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
  GlobalKey key = GlobalKey();
  Map<int, String> keyMapping = {};
  Map<String, int> idMapping = {};
  GlobalKey listViewGlobalKey = GlobalKey();
  final _scrollController = ScrollController();
  Set repliedToAlready = {};

  @override
  void initState() {
    postingFuture = null;
    super.initState();
  }

  void sendNotificationReplied(String commentId, String input) async {
    try {
      var repliedTo = await Firestore.instance
          .collection('posts')
          .doc(cardData.id)
          .collection('comments')
          .doc(commentId)
          .get();
      print(repliedTo.data());
      String uid = repliedTo.get('uid');
      if (repliedToAlready.contains(uid)) {
        return;
      }
      repliedToAlready.add(uid);
      QuerySnapshot userDataa = await Firestore.instance
          .collection('users')
          .where('uid', isEqualTo: uid)
          .get();
      DocumentSnapshot userData = userDataa.docs[0];

      print(input);
      var time = await getCurrentTimestampServer();
      await Firestore.instance
          .collection('users')
          .doc(userData.id)
          .collection('notifications')
          .add({
        'type': 'reply',
        'text': input,
        'time': time,
        'clicked': 0,
        'postId': cardData.id
      });

      if (userData.exists && userData.get('pushToken') != null) {
        GlobalController.get().callOnFcmApiSendPushNotifications(
            [userData.get('pushToken')],
            'New reply to your comment',
            'Someone replied to your comment!',
            'comment',
            NotificationData(cardData.id, null, null));
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> postComment(String inputText) async {
    try {
      FocusScope.of(context).requestFocus(new FocusNode());
      var inputTextTransformed = replaceIdsWithHashtags(inputText, keyMapping);
      List<String> commentIds = extractHashTags(inputTextTransformed);
      repliedToAlready.clear();
      for (String commentId in commentIds) {
        sendNotificationReplied(commentId.substring(1), inputText);
      }
      double time = await getCurrentTimestampServer();
      String input = inputTextTransformed;
      DocumentSnapshot snapshot;
      try {
        snapshot =
            await Firestore.instance.collection('posts').doc(cardData.id).get();
        if (!snapshot.exists) {
          return Future.error(1);
        }
      } catch (e) {
        return Future.error(1);
      }

      if (snapshot.get('commentsNum') == 250) {
        return Future.error(2);
      }
      await Firestore.instance.collection('posts').doc(cardData.id).update(
          {'commentsNum': FieldValue.increment(1), 'lastCommentTime': time});
      var ref = await Firestore.instance
          .collection('posts')
          .doc(cardData.id)
          .collection('comments')
          .add({
        'comment': input,
        'time': time,
        'uid': GlobalController.get().currentUserUid,
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
      return;
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

  void onReply(String poster) {
    setState(() {
      inputText = inputText + '#' + poster + '\n';
      messageTextController.text = inputText;
    });
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
                if (snapshot.error == 2) {
                  WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                    commentsCallback(cardData, InfoSheet.PostLimitReached);
                  });
                } else {
                  WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                    commentsCallback(cardData, InfoSheet.Deleted);
                  });
                }
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
                                              child: HashTagTextField(
                                                key: key,
                                                decoration: InputDecoration(
                                                    counterText: "",
                                                    hintStyle:
                                                        disabledUpperBarStyle,
                                                    hintText:
                                                        'Add a comment...'),
                                                maxLines: null,
                                                basicStyle:
                                                    disabledUpperBarStyle,
                                                decoratedStyle:
                                                    disabledUpperBarStyle
                                                        .copyWith(
                                                            color: Colors.red),
                                                maxLength: 245,
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
                      .orderBy('time', descending: false)
                      .limit(250)
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
                                                      child: HashTagTextField(
                                                        key: key,
                                                        decoration: InputDecoration(
                                                            counterText: "",
                                                            hintStyle:
                                                                disabledUpperBarStyle,
                                                            hintText:
                                                                'Add a comment...'),
                                                        maxLines: null,
                                                        basicStyle:
                                                            disabledUpperBarStyle,
                                                        decoratedStyle:
                                                            disabledUpperBarStyle
                                                                .copyWith(
                                                                    color: Colors
                                                                        .red),
                                                        maxLength: 245,
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
                        keyMapping.clear();
                        idMapping.clear();
                        Set<String> youPosts = {};
                        int postCounter = 0;
                        for (var doc in snapshot.data.docs) {
                          if (doc.get('uid') ==
                              GlobalController.get().currentUserUid) {
                            youPosts.add(doc.id);
                          }
                        }
                        for (var doc in snapshot.data.docs) {
                          List<String> hashtags =
                              extractHashTags(doc.get('comment'));
                          bool isReply = false;
                          for (var commentId in hashtags) {
                            if (youPosts.contains(commentId.substring(1))) {
                              isReply = true;
                            }
                          }
                          keyMapping[postCounter] = doc.id;
                          idMapping[doc.id] = postCounter;
                          String comment = doc.get('comment');
                          comment = replaceHashtagsWithIds(comment, idMapping);
                          comments.add(Center(
                              child: Comment(
                                  idMapping: idMapping,
                                  keyMapping: keyMapping,
                                  isReply: isReply,
                                  onReply: onReply,
                                  uid: doc.get('uid'),
                                  currentCardData: cardData,
                                  comment: comment,
                                  timestamp: doc.get('time'),
                                  postId: cardData.id,
                                  commentId: postCounter.toString())));

                          postCounter = postCounter + 1;
                        }
                      }
                      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                        if (_scrollController.offset == 0)
                          _scrollController.animateTo(
                              _scrollController.position.maxScrollExtent,
                              duration: Duration(seconds: 1),
                              curve: Curves.fastOutSlowIn);
                      });
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
                                                            controller:
                                                                _scrollController,
                                                            key:
                                                                listViewGlobalKey,
                                                            shrinkWrap: false,
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
                                                      child: HashTagTextField(
                                                        key: key,
                                                        decoration: InputDecoration(
                                                            counterText: "",
                                                            hintStyle:
                                                                disabledUpperBarStyle,
                                                            hintText:
                                                                'Add a comment...'),
                                                        maxLines: null,
                                                        basicStyle:
                                                            disabledUpperBarStyle,
                                                        decoratedStyle:
                                                            disabledUpperBarStyle
                                                                .copyWith(
                                                                    color: Colors
                                                                        .red),
                                                        maxLength: 245,
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
                                                      child: HashTagTextField(
                                                        key: key,
                                                        decoration: InputDecoration(
                                                            counterText: "",
                                                            hintStyle:
                                                                disabledUpperBarStyle,
                                                            hintText:
                                                                'Add a comment...'),
                                                        maxLines: null,
                                                        basicStyle:
                                                            disabledUpperBarStyle,
                                                        decoratedStyle:
                                                            disabledUpperBarStyle
                                                                .copyWith(
                                                                    color: Colors
                                                                        .red),
                                                        maxLength: 245,
                                                        controller:
                                                            messageTextController,
                                                        onChanged: (value) {
                                                          inputText = value;
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
                                                    child: HashTagTextField(
                                                      key: key,
                                                      decoration: InputDecoration(
                                                          counterText: "",
                                                          hintStyle:
                                                              disabledUpperBarStyle,
                                                          hintText:
                                                              'Add a comment...'),
                                                      maxLines: null,
                                                      basicStyle:
                                                          disabledUpperBarStyle,
                                                      decoratedStyle:
                                                          disabledUpperBarStyle
                                                              .copyWith(
                                                                  color: Colors
                                                                      .red),
                                                      maxLength: 245,
                                                      controller:
                                                          messageTextController,
                                                      onChanged: (value) {
                                                        inputText = value;
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
                                              child: HashTagTextField(
                                                key: key,
                                                decoration: InputDecoration(
                                                    counterText: "",
                                                    hintStyle:
                                                        disabledUpperBarStyle,
                                                    hintText:
                                                        'Add a comment...'),
                                                maxLines: null,
                                                basicStyle:
                                                    disabledUpperBarStyle,
                                                decoratedStyle:
                                                    disabledUpperBarStyle
                                                        .copyWith(
                                                            color: Colors.red),
                                                maxLength: 245,
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
                  postingFuture = null;
                });
                commentsCallback(cardData, InfoSheet.Commented);
              });
              return StreamBuilder(
                  stream: Firestore.instance
                      .collection('posts')
                      .doc(cardData.id)
                      .collection('comments')
                      .orderBy('time', descending: false)
                      .limit(250)
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
                                                      child: HashTagTextField(
                                                        key: key,
                                                        decoration: InputDecoration(
                                                            counterText: "",
                                                            hintStyle:
                                                                disabledUpperBarStyle,
                                                            hintText:
                                                                'Add a comment...'),
                                                        maxLines: null,
                                                        basicStyle:
                                                            disabledUpperBarStyle,
                                                        decoratedStyle:
                                                            disabledUpperBarStyle
                                                                .copyWith(
                                                                    color: Colors
                                                                        .red),
                                                        maxLength: 245,
                                                        controller:
                                                            messageTextController,
                                                        onChanged: (value) {
                                                          inputText = value;
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
                        int postCounter = 0;
                        keyMapping.clear();
                        idMapping.clear();
                        Set<String> youPosts = {};
                        for (var doc in snapshot.data.docs) {
                          if (doc.get('uid') ==
                              GlobalController.get().currentUserUid) {
                            youPosts.add(doc.id);
                          }
                        }
                        for (var doc in snapshot.data.docs) {
                          List<String> hashtags =
                              extractHashTags(doc.get('comment'));
                          bool isReply = false;
                          for (var commentId in hashtags) {
                            if (youPosts.contains(commentId.substring(1))) {
                              isReply = true;
                            }
                          }
                          keyMapping[postCounter] = doc.id;
                          idMapping[doc.id] = postCounter;
                          String comment = doc.get('comment');
                          comment = replaceHashtagsWithIds(comment, idMapping);
                          comments.add(Center(
                              child: Comment(
                                  idMapping: idMapping,
                                  keyMapping: keyMapping,
                                  isReply: isReply,
                                  onReply: onReply,
                                  uid: doc.get('uid'),
                                  currentCardData: cardData,
                                  comment: comment,
                                  timestamp: doc.get('time'),
                                  postId: cardData.id,
                                  commentId: postCounter.toString())));

                          postCounter = postCounter + 1;
                        }
                      }
                      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                        if (_scrollController.offset == 0)
                          _scrollController.animateTo(
                              _scrollController.position.maxScrollExtent,
                              duration: Duration(seconds: 1),
                              curve: Curves.fastOutSlowIn);
                      });

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
                                                            controller:
                                                                _scrollController,
                                                            key:
                                                                listViewGlobalKey,
                                                            shrinkWrap: false,
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
                                                      child: HashTagTextField(
                                                        key: key,
                                                        decoration: InputDecoration(
                                                            counterText: "",
                                                            hintStyle:
                                                                disabledUpperBarStyle,
                                                            hintText:
                                                                'Add a comment...'),
                                                        maxLines: null,
                                                        basicStyle:
                                                            disabledUpperBarStyle,
                                                        decoratedStyle:
                                                            disabledUpperBarStyle
                                                                .copyWith(
                                                                    color: Colors
                                                                        .red),
                                                        maxLength: 245,
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
                                                      child: HashTagTextField(
                                                        key: key,
                                                        decoration: InputDecoration(
                                                            counterText: "",
                                                            hintStyle:
                                                                disabledUpperBarStyle,
                                                            hintText:
                                                                'Add a comment...'),
                                                        maxLines: null,
                                                        basicStyle:
                                                            disabledUpperBarStyle,
                                                        decoratedStyle:
                                                            disabledUpperBarStyle
                                                                .copyWith(
                                                                    color: Colors
                                                                        .red),
                                                        maxLength: 245,
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
                                                    child: HashTagTextField(
                                                      key: key,
                                                      decoration: InputDecoration(
                                                          counterText: "",
                                                          hintStyle:
                                                              disabledUpperBarStyle,
                                                          hintText:
                                                              'Add a comment...'),
                                                      maxLines: null,
                                                      basicStyle:
                                                          disabledUpperBarStyle,
                                                      decoratedStyle:
                                                          disabledUpperBarStyle
                                                              .copyWith(
                                                                  color: Colors
                                                                      .red),
                                                      maxLength: 245,
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
  Comment(
      {this.isReply,
      this.onReply,
      this.comment,
      this.timestamp,
      this.postId,
      this.commentId,
      this.currentCardData,
      this.uid,
      this.keyMapping,
      this.idMapping}) {
    DateTime time =
        DateTime.fromMillisecondsSinceEpoch((this.timestamp * 1000).toInt());
    date = '${time.day}.${time.month}.${time.year}';
  }
  final bool isReply;
  final Function onReply;
  final String uid;
  final CardData currentCardData;
  final String comment;
  final double timestamp;
  final String postId;
  final String commentId;
  final Map<int, String> keyMapping;
  final Map<String, int> idMapping;
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

  void reply() {
    widget.onReply(widget.commentId);
  }

  void shareCardData() async {
    if (GlobalController.get().commentShareDisabled) {
      return;
    }

    GlobalController.get().commentShareDisabled = true;
    Widget shareWidget = Material(
        child: Container(
      width: 800,
      height: 800,
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: FractionalOffset.bottomLeft,
            end: FractionalOffset.topRight,
            colors: splashScreenColors),
      ),
      child: Center(
          child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Center(
                          child: HashTagText(
                            onTap: null,
                            textAlign: TextAlign.center,
                            text: widget.currentCardData.text,
                            basicStyle:
                                MAIN_CARD_TEXT_STYLE.copyWith(fontSize: 50),
                            decoratedStyle: MAIN_CARD_TEXT_STYLE.copyWith(
                                fontSize: 50, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.all(cardthingspadding),
                    child: Divider(
                      color: cardThingsTextStyle.color,
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.topLeft,
                child: Transform.rotate(
                    angle: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/logo.png', width: 150),
                        Text('Share your idea!', style: cardThingsTextStyle)
                      ],
                    )),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(5.0)),
                        gradient: LinearGradient(
                          colors: [Color(0xFFDBDBDB), Color(0xFFFFFFFF)],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        )),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Posted on: ' + widget.date,
                              style: disabledUpperBarStyle.copyWith(
                                  fontSize: 10, fontStyle: FontStyle.italic)),
                          SizedBox(height: 20),
                          Text(widget.comment, style: enabledUpperBarStyle),
                          SizedBox(height: 20),
                          DottedLine(dashColor: disabledUpperBarColor),
                          SizedBox(height: 20),
                        ],
                      ),
                    )),
              )
            ],
          ),
        ),
      )),
    ));

    Uint8List imageData = await createImageFromWidget(shareWidget,
        logicalSize: Size(800, 800), imageSize: Size(800, 800));
    try {
      await WcFlutterShare.share(
          sharePopupTitle: 'Share',
          fileName: 'spark.png',
          mimeType: 'image/png',
          bytesOfFile: imageData);
    } catch (e) {
      print(e);
    }
    GlobalController.get().commentShareDisabled = false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Posted on: ' + widget.date,
                style: disabledUpperBarStyle.copyWith(
                    fontSize: 10, fontStyle: FontStyle.italic)),
            SizedBox(width: 20),
            Text('Comment id: ' + widget.commentId,
                style: disabledUpperBarStyle.copyWith(
                    fontSize: 10, fontStyle: FontStyle.italic))
          ],
        ),
        widget.isReply
            ? Text('Replying to you!',
                style: disabledUpperBarStyle.copyWith(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: Colors.red))
            : SizedBox(),
        SizedBox(height: 20),
        HashTagText(
            text: widget.comment,
            basicStyle: enabledUpperBarStyle,
            decoratedStyle: enabledUpperBarStyle.copyWith(color: Colors.red),
            onTap: (id) {
              String idConverted =
                  replaceIdsWithHashtags(id, widget.keyMapping);
              var idConvertedList = extractHashTags(idConverted);
              print(idConvertedList);

              showDialog(
                  context: context,
                  builder: (_) {
                    return CommentPopup(
                        keyMapping: widget.keyMapping,
                        commentId: idConvertedList[0].substring(1),
                        commentIdSeen: id,
                        postId: widget.postId,
                        idMapping: widget.idMapping);
                  });
            }),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FlatButton(
                onPressed: reply,
                child: Center(
                    child: Text('Reply',
                        style: disabledUpperBarStyle.copyWith(fontSize: 10)))),
            FlatButton(
                onPressed: shareCardData,
                child: Center(
                    child: Text('Share',
                        style: disabledUpperBarStyle.copyWith(fontSize: 10)))),
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
