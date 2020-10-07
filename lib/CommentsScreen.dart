import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'Const.dart';

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
      await Firestore.instance
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

  void disposeAction() async {
    var time = await getCurrentTimestampServer();
    if (cardData.posterId == GlobalController.get().currentUserUid) {
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
    disposeAction();
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
    }
    return Scaffold(
      appBar: AppBar(title: Text('Viewing comments')),
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
                              colors: splashScreenColors,
                              begin: Alignment.bottomLeft,
                              end: Alignment.topRight)),
                      child: GestureDetector(
                        onTap: () {
                          FocusScope.of(context).requestFocus(new FocusNode());
                        },
                        child: Column(
                          children: [
                            Expanded(
                                flex: 5,
                                child: Center(
                                    child: Text('Post has been removed'))),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Container(
                                      height: 20.0 * 24,
                                      child: TextField(
                                        controller: messageTextController,
                                        onChanged: (string) {
                                          setState(() {
                                            inputText = string;
                                          });
                                        },
                                        onEditingComplete: () {},
                                        maxLines: 20.toInt(),
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 20,
                                        ),
                                        decoration: InputDecoration(
                                          filled: true,
                                          counterText: "",
                                          fillColor: Colors.white,
                                        ),
                                        maxLength: 245,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: RaisedButton(
                                        child: Center(child: Text('Post')),
                                        onPressed: null),
                                  )
                                ],
                              ),
                            )
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
                                      colors: splashScreenColors,
                                      begin: Alignment.bottomLeft,
                                      end: Alignment.topRight)),
                              child: GestureDetector(
                                onTap: () {
                                  FocusScope.of(context)
                                      .requestFocus(new FocusNode());
                                },
                                child: Column(
                                  children: [
                                    Expanded(
                                        flex: 5,
                                        child: Container(
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
                                        )))),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Container(
                                              height: 20.0 * 24,
                                              child: TextField(
                                                controller:
                                                    messageTextController,
                                                onChanged: (string) {
                                                  setState(() {
                                                    inputText = string;
                                                  });
                                                },
                                                onEditingComplete: () {},
                                                maxLines: 20.toInt(),
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 20,
                                                ),
                                                decoration: InputDecoration(
                                                  filled: true,
                                                  counterText: "",
                                                  fillColor: Colors.white,
                                                ),
                                                maxLength: 245,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                              child: RaisedButton(
                                            child: Center(child: Text('Post')),
                                            onPressed: null,
                                          ))
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              )));
                    } else if (snapshot.hasData) {
                      List<Widget> comments = [];
                      Widget noCommentsWidget;
                      if (snapshot.data.docs.length == 0) {
                        noCommentsWidget = (Center(
                            child:
                                Comment(comment: "There are no comments yet")));
                      } else {
                        for (var doc in snapshot.data.docs) {
                          comments.add(Center(
                              child: Comment(comment: doc.get('comment'))));
                          comments.add(Padding(
                            padding:
                                const EdgeInsets.only(left: 40.0, right: 40.0),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Divider(
                                color: Colors.red,
                              ),
                            ),
                          ));
                        }
                      }
                      return SafeArea(
                          child: Container(
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                      colors: splashScreenColors,
                                      begin: Alignment.bottomLeft,
                                      end: Alignment.topRight)),
                              child: GestureDetector(
                                onTap: () {
                                  FocusScope.of(context)
                                      .requestFocus(new FocusNode());
                                },
                                child: Column(
                                  children: [
                                    Expanded(
                                        flex: 5,
                                        child: noCommentsWidget != null
                                            ? noCommentsWidget
                                            : Center(
                                                child: Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 8.0,
                                                    bottom: 8.0,
                                                    left: 8.0,
                                                    right: 8.0),
                                                child: ListView(
                                                    shrinkWrap: true,
                                                    reverse: true,
                                                    children: comments),
                                              ))),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Container(
                                              height: 20.0 * 24,
                                              child: cardData.commented
                                                  ? Container(
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey,
                                                      ),
                                                      child: Center(
                                                          child: Text(
                                                              'You already commented on this post!')))
                                                  : TextField(
                                                      controller:
                                                          messageTextController,
                                                      onChanged: (string) {
                                                        setState(() {
                                                          inputText = string;
                                                        });
                                                      },
                                                      onEditingComplete: () {},
                                                      maxLines: 20.toInt(),
                                                      style: TextStyle(
                                                        color: Colors.black,
                                                        fontSize: 20,
                                                      ),
                                                      decoration:
                                                          InputDecoration(
                                                        filled: true,
                                                        counterText: "",
                                                        fillColor: Colors.white,
                                                      ),
                                                      maxLength: 245,
                                                    ),
                                            ),
                                          ),
                                          Expanded(
                                            child: RaisedButton(
                                                child:
                                                    Center(child: Text('Post')),
                                                onPressed: (cardData
                                                            .commented ||
                                                        inputText.length < 15)
                                                    ? null
                                                    : buttonCallback),
                                          )
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              )));
                    } else if (snapshot.hasError) {
                      return Container(
                          child: Center(
                              child: Text(
                                  'Something went wrong with fetching the comments!')));
                    }
                    return Container(
                        child: Center(
                            child: Text(
                                'Something went wrong with fetching the comments!')));
                  });
            }
            if (snapshot.connectionState == ConnectionState.waiting ||
                snapshot.connectionState == ConnectionState.active) {
              return SafeArea(
                child: Container(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: splashScreenColors,
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight)),
                  child: Column(children: [
                    Expanded(
                        flex: 5,
                        child: Container(
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
                        ))))
                  ]),
                ),
              );
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
                                      colors: splashScreenColors,
                                      begin: Alignment.bottomLeft,
                                      end: Alignment.topRight)),
                              child: GestureDetector(
                                onTap: () {
                                  FocusScope.of(context)
                                      .requestFocus(new FocusNode());
                                },
                                child: Column(
                                  children: [
                                    Expanded(
                                        flex: 5,
                                        child: Container(
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
                                        )))),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Container(
                                              height: 20.0 * 24,
                                              child: TextField(
                                                controller:
                                                    messageTextController,
                                                onChanged: (string) {
                                                  setState(() {
                                                    inputText = string;
                                                  });
                                                },
                                                onEditingComplete: () {},
                                                maxLines: 20.toInt(),
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 20,
                                                ),
                                                decoration: InputDecoration(
                                                  filled: true,
                                                  counterText: "",
                                                  fillColor: Colors.white,
                                                ),
                                                maxLength: 245,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                              child: RaisedButton(
                                            child: Center(child: Text('Post')),
                                            onPressed: null,
                                          ))
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              )));
                    } else if (snapshot.hasData) {
                      List<Widget> comments = [];
                      Widget noCommentsWidget;
                      if (snapshot.data.docs.length == 0) {
                        noCommentsWidget = (Center(
                            child:
                                Comment(comment: "There are no comments yet")));
                      } else {
                        for (var doc in snapshot.data.docs) {
                          comments.add(Center(
                              child: Comment(comment: doc.get('comment'))));
                          comments.add(Padding(
                            padding:
                                const EdgeInsets.only(left: 40.0, right: 40.0),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Divider(
                                color: Colors.red,
                              ),
                            ),
                          ));
                        }
                      }
                      return SafeArea(
                          child: Container(
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                      colors: splashScreenColors,
                                      begin: Alignment.bottomLeft,
                                      end: Alignment.topRight)),
                              child: GestureDetector(
                                onTap: () {
                                  FocusScope.of(context)
                                      .requestFocus(new FocusNode());
                                },
                                child: Column(
                                  children: [
                                    Expanded(
                                        flex: 5,
                                        child: noCommentsWidget != null
                                            ? noCommentsWidget
                                            : Center(
                                                child: Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 8.0,
                                                    bottom: 8.0,
                                                    left: 8.0,
                                                    right: 8.0),
                                                child: ListView(
                                                    shrinkWrap: true,
                                                    reverse: true,
                                                    children: comments),
                                              ))),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Container(
                                              height: 20.0 * 24,
                                              child: TextField(
                                                controller:
                                                    messageTextController,
                                                onChanged: (string) {
                                                  setState(() {
                                                    inputText = string;
                                                  });
                                                },
                                                onEditingComplete: () {},
                                                maxLines: 20.toInt(),
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 20,
                                                ),
                                                decoration: InputDecoration(
                                                  filled: true,
                                                  counterText: "",
                                                  fillColor: Colors.white,
                                                ),
                                                maxLength: 245,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: RaisedButton(
                                                child:
                                                    Center(child: Text('Post')),
                                                onPressed: (cardData
                                                            .commented ||
                                                        inputText.length < 15)
                                                    ? null
                                                    : buttonCallback),
                                          )
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              )));
                    } else if (snapshot.hasError) {
                      return Container(
                          child: Center(
                              child: Text(
                                  'Something went wrong with fetching the comments!')));
                    }
                    return Container(
                        child: Center(
                            child: Text(
                                'Something went wrong with fetching the comments!')));
                  });
            }
          }),
    );
  }
}

class Comment extends StatelessWidget {
  Comment({this.comment});
  final String comment;
  @override
  Widget build(BuildContext context) {
    return Text(comment,
        style: AUTHOR_CARD_TEXT_STYLE, textAlign: TextAlign.center);
  }
}
