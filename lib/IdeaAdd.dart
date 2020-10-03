import 'package:flutter/material.dart';
import 'Const.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
          'hashtag': tag
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
          'hidden': 0
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
                    colors: [Color(0xFFDBDBDB), Color(0xFFFFFFFF)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  )),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FeedOverlay(),
                        ],
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 20,
                              ),
                              Center(
                                  child: Image.asset('assets/shareidea.png',
                                      width: 100)),
                              SizedBox(height: 20),
                              Center(
                                child: Text('Add idea',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: disabledUpperBarColor)),
                              ),
                              SizedBox(height: 20),
                              Container(
                                height: 170,
                                child: HashTagTextField(
                                  decoratedStyle: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 20,
                                  ),
                                  controller: controller,
                                  onChanged: (string) {
                                    inputText = string;
                                    if (inputText.length >
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
                                  onEditingComplete: () {},
                                  maxLines: maxLines.toInt(),
                                  basicStyle: TextStyle(
                                    color: Colors.black,
                                    fontSize: 20,
                                  ),
                                  decoration: InputDecoration(
                                    counterStyle:
                                        TextStyle(color: Colors.black45),
                                    filled: true,
                                    fillColor:
                                        GlobalController.get().dailyPosts > 0
                                            ? Colors.white
                                            : Colors.grey,
                                  ),
                                  maxLength: 245,
                                ),
                              ),
                              SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  FlatButton(
                                    onPressed:
                                        (GlobalController.get().dailyPosts >
                                                    0 &&
                                                postEnabled)
                                            ? buttonCallack
                                            : null,
                                    child: Center(
                                        child: Text('Submit',
                                            style:
                                                disabledUpperBarStyle.copyWith(
                                                    color: (GlobalController
                                                                        .get()
                                                                    .dailyPosts >
                                                                0 &&
                                                            postEnabled)
                                                        ? enabledUpperBarColor
                                                        : Colors.grey,
                                                    fontSize: 20))),
                                  )
                                ],
                              ),
                              Expanded(
                                flex: 1,
                                child: Container(),
                              ),
                              Divider(color: disabledUpperBarColor),
                              SizedBox(height: 10),
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                        '${GlobalController.get().dailyPosts}/${BASE_DAILY_POSTS.toInt()} Ideas',
                                        style: TextStyle(
                                            fontStyle: FontStyle.italic,
                                            color: disabledUpperBarColor)),
                                    Text(
                                        '${GlobalController.get().dailyPosts} ideas left for today',
                                        style: TextStyle(
                                            fontStyle: FontStyle.italic,
                                            color: disabledUpperBarColor))
                                  ]),
                              Container(
                                child: FAProgressBar(
                                  backgroundColor: Colors.white,
                                  size: 20,
                                  borderRadius: 0,
                                  maxValue: MAX_POST_DAILY_LIMIT.toInt(),
                                  currentValue:
                                      GlobalController.get().dailyPosts,
                                  progressColor: Colors.blue,
                                  changeProgressColor: Colors.red,
                                  direction: Axis.horizontal,
                                  displayText:
                                      '/${MAX_POST_DAILY_LIMIT.toInt()} ',
                                ),
                              ),
                              SizedBox(height: 50),
                              Divider(color: disabledUpperBarColor),
                              Expanded(child: Container()),
                            ],
                          ),
                        ),
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
                    child: Column(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Container(),
                    ),
                    Center(
                        child: Text(
                            'Your post is either spam, profane, or an error occured!',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ))),
                    Container(
                      height: maxLines * 24,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Container(
                          child: TextField(
                            controller: controller,
                            onChanged: (string) {
                              inputText = string;
                              if (inputText.length > minimumCharactersForPost &&
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
                            onEditingComplete: () {},
                            maxLines: maxLines.toInt(),
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 20,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            maxLength: 245,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Container(),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          GlobalController.get().dailyPosts > 0
                              ? 'You may still post ideas today! 💡'
                              : 'That\'s it for today, check in tomorrow!',
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Container(
                        child: FAProgressBar(
                          backgroundColor: Colors.white,
                          size: 20,
                          borderRadius: 10.0,
                          maxValue: MAX_POST_DAILY_LIMIT.toInt(),
                          currentValue: GlobalController.get().dailyPosts,
                          progressColor: Colors.blue,
                          changeProgressColor: Colors.red,
                          direction: Axis.horizontal,
                          displayText: '/${MAX_POST_DAILY_LIMIT.toInt()} ',
                        ),
                      ),
                    ),
                    Container(
                      child: FlatButton(
                        onPressed: postEnabled ? buttonCallack : null,
                        disabledColor: Colors.red,
                        color: Colors.green,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Icon(FontAwesomeIcons.comment),
                            SizedBox(width: 20),
                            Text('SUBMIT'),
                          ],
                        ),
                      ),
                    )
                  ],
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
