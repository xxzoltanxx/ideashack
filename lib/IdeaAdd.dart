import 'package:flutter/material.dart';
import 'Const.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_animation_progress_bar/flutter_animation_progress_bar.dart';
import 'package:hashtagable/hashtagable.dart';
import 'FeedOverlay.dart';

class IdeaAdd extends StatefulWidget {
  IdeaAdd(this.onEnd, this.user, this.fetchingDailyPosts);
  final Function onEnd;
  final User user;
  final bool fetchingDailyPosts;
  @override
  _IdeaAddState createState() => _IdeaAddState();
}

class _IdeaAddState extends State<IdeaAdd> with WidgetsBindingObserver {
  final _firestore = Firestore.instance;
  double maxLines = 8.0;
  String inputText = "";
  bool postEnabled = false;
  int indexOfPage = 0;

  TextEditingController controller;

  Future<void> postingFuture = null;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller = TextEditingController(
        text: inputText,
      );
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = TextEditingController(
      text: inputText,
    );
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void buttonCallack() {
    setState(() {
      postingFuture = Post();
    });
  }

  Future<void> Post() async {
    if (extractHashTags(inputText).length > 1) {
      return Future.error("SPAM");
    }
    if (spamFilter.isProfane(inputText)) {
      return Future.error("SPAM");
    }
    try {
      String tag = '';
      var hashtags = extractHashTags(inputText);
      if (hashtags.length > 0) {
        tag = hashtags[0];
      }

      var timestamp = await getCurrentTimestampServer();
      DocumentReference result;
      if (tag != '') {
        result = await _firestore.collection('posts').add({
          'author': widget.user.displayName,
          'body': inputText,
          'score': 0,
          'postTime': timestamp,
          'userid': widget.user.uid,
          'commentsNum': 0,
          'hidden': 0,
          'hashtag': tag,
          'lastSeenComments': 0,
          'lastCommentTime': 0
        });
        await _firestore
            .collection('users')
            .doc(GlobalController.get().userDocId)
            .update({
          'upvoted': FieldValue.arrayUnion([result.id])
        });
      } else {
        result = await _firestore.collection('posts').add({
          'author': widget.user.displayName,
          'body': inputText,
          'score': 0,
          'postTime': timestamp,
          'userid': widget.user.uid,
          'commentsNum': 0,
          'hidden': 0,
          'lastSeenComments': 0,
          'lastCommentTime': 0
        });
        await _firestore
            .collection('users')
            .doc(GlobalController.get().userDocId)
            .update({
          'upvoted': FieldValue.arrayUnion([result.id])
        });
      }

      if (tag != '') {
        var possibleEntry = await Firestore.instance
            .collection('hashtags')
            .where('tag', isEqualTo: tag)
            .get();
        if (possibleEntry.docs.length > 0) {
          await Firestore.instance
              .collection('hashtags')
              .doc(possibleEntry.docs[0].id)
              .update({'popularity': FieldValue.increment(1)});
        } else {
          await Firestore.instance.collection('hashtags').add({
            'tag': tag,
            'popularity': 0,
          });
        }
      }
      await Firestore.instance
          .collection('users')
          .doc(GlobalController.get().userDocId)
          .update({'dailyPosts': GlobalController.get().dailyPosts - 1});
    } catch (e) {
      return Future.error("ERROR");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fetchingDailyPosts) {
      return Container(
          decoration: BoxDecoration(
              gradient: LinearGradient(
            colors: [Color(0xFFDBDBDB), Color(0xFFFFFFFF)],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          )),
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
    } else
      return FutureBuilder(
          future: postingFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.none) {
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  FocusScope.of(context).requestFocus(new FocusNode());
                },
                child: SafeArea(
                    child: Container(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: splashScreenColors,
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight)),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            NotificationOverlay(),
                            FeedOverlay(),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: 400),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 15.0),
                              child: HashTagTextField(
                                minLines: 1,
                                decoratedStyle: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 20,
                                ),
                                controller: controller,
                                onChanged: (string) {
                                  inputText = string;
                                  if (inputText.length >=
                                          minimumCharactersForPost &&
                                      GlobalController.get().dailyPosts > 0) {
                                    setState(() {
                                      postEnabled = true;
                                    });
                                  } else {
                                    setState(() {
                                      postEnabled = false;
                                    });
                                  }
                                },
                                maxLines: null,
                                textAlign: TextAlign.center,
                                textAlignVertical: TextAlignVertical.center,
                                onEditingComplete: () {},
                                basicStyle: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                ),
                                cursorColor: Colors.white,
                                decoration: InputDecoration(
                                  hintText: 'Tap here to start writing',
                                  focusColor: Colors.white,
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  counterText: "",
                                  filled: false,
                                ),
                                maxLength: 245,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                              inputText.length < minimumCharactersForPost
                                  ? 'YOU NEED ${minimumCharactersForPost - inputText.length} CHARACTERS MORE'
                                  : 'YOU HAVE ${245 - inputText.length} CHARACTERS LEFT',
                              style: cardThingsBelowTextStyle.copyWith(
                                  fontSize: 10, fontStyle: FontStyle.normal)),
                          SizedBox(height: 10),
                          Container(
                            child: FAProgressBar(
                              backgroundColor: Colors.white,
                              size: 10,
                              borderRadius: 0,
                              maxValue: 245,
                              currentValue: inputText.length,
                              progressColor: Colors.yellow,
                              changeProgressColor: Colors.red,
                              direction: Axis.horizontal,
                              displayText: '',
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10.0),
                              child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                        'You have ${GlobalController.get().dailyPosts} ideas left for today',
                                        style: TextStyle(
                                            fontStyle: FontStyle.italic,
                                            color: disabledUpperBarColor)),
                                    FlatButton(
                                      onPressed:
                                          (GlobalController.get().dailyPosts >
                                                      0 &&
                                                  postEnabled)
                                              ? buttonCallack
                                              : null,
                                      child: Center(
                                          child: Text('Submit',
                                              style: disabledUpperBarStyle
                                                  .copyWith(
                                                      color: (GlobalController
                                                                          .get()
                                                                      .dailyPosts >
                                                                  0 &&
                                                              postEnabled)
                                                          ? enabledUpperBarColor
                                                          : Colors.grey,
                                                      fontSize: 20))),
                                    )
                                  ]),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )),
              );
            }
            if (snapshot.hasError) {
              print(snapshot.error);
              print("ERROR");
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  FocusScope.of(context).requestFocus(new FocusNode());
                },
                child: SafeArea(
                    child: Container(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: splashScreenColors,
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight)),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            NotificationOverlay(),
                            FeedOverlay(),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                ),
                                child: Center(
                                  child: Text(
                                      'Your post is either spam or too profane!'),
                                )),
                          )
                        ],
                      ),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: 400),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 15.0),
                              child: HashTagTextField(
                                minLines: 1,
                                decoratedStyle: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 20,
                                ),
                                controller: controller,
                                onChanged: (string) {
                                  inputText = string;
                                  if (inputText.length >=
                                          minimumCharactersForPost &&
                                      GlobalController.get().dailyPosts > 0) {
                                    setState(() {
                                      postEnabled = true;
                                    });
                                  } else {
                                    setState(() {
                                      postEnabled = false;
                                    });
                                  }
                                },
                                maxLines: null,
                                textAlign: TextAlign.center,
                                textAlignVertical: TextAlignVertical.center,
                                onEditingComplete: () {},
                                basicStyle: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                ),
                                cursorColor: Colors.white,
                                decoration: InputDecoration(
                                  focusColor: Colors.white,
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  counterText: "",
                                  filled: false,
                                ),
                                maxLength: 245,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                              inputText.length < minimumCharactersForPost
                                  ? 'YOU NEED ${minimumCharactersForPost - inputText.length} CHARACTERS MORE'
                                  : 'YOU HAVE ${245 - inputText.length} CHARACTERS LEFT',
                              style: cardThingsBelowTextStyle.copyWith(
                                  fontSize: 10, fontStyle: FontStyle.normal)),
                          SizedBox(height: 10),
                          Container(
                            child: FAProgressBar(
                              backgroundColor: Colors.white,
                              size: 10,
                              borderRadius: 0,
                              maxValue: MAX_POST_DAILY_LIMIT.toInt(),
                              currentValue: GlobalController.get().dailyPosts,
                              progressColor: Colors.yellow,
                              changeProgressColor: Colors.red,
                              direction: Axis.horizontal,
                              displayText: '',
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10.0),
                              child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                        'You have ${GlobalController.get().dailyPosts} ideas left for today',
                                        style: TextStyle(
                                            fontStyle: FontStyle.italic,
                                            color: disabledUpperBarColor)),
                                    FlatButton(
                                      onPressed:
                                          (GlobalController.get().dailyPosts >
                                                      0 &&
                                                  postEnabled)
                                              ? buttonCallack
                                              : null,
                                      child: Center(
                                          child: Text('Submit',
                                              style: disabledUpperBarStyle
                                                  .copyWith(
                                                      color: (GlobalController
                                                                          .get()
                                                                      .dailyPosts >
                                                                  0 &&
                                                              postEnabled)
                                                          ? enabledUpperBarColor
                                                          : Colors.grey,
                                                      fontSize: 20))),
                                    )
                                  ]),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )),
              );
            }
            // Once complete, show your application
            if (snapshot.connectionState == ConnectionState.done) {
              print("ENDED");
              WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                widget.onEnd();
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
              });
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
            ;
          }

          // Otherwise, show something whilst waiting for initialization to complete
          );
  }
}
