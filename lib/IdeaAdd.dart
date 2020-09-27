import 'package:flutter/material.dart';
import 'Const.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_animation_progress_bar/flutter_animation_progress_bar.dart';

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
  bool anonimous = false;

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
    if (spamFilter.isProfane(inputText)) {
      return Future.error("SPAM");
    }
    try {
      var timestamp = await getCurrentTimestampServer();
      var result = await _firestore.collection('posts').add({
        'author': !anonimous ? widget.user.displayName : 'Anonymous',
        'body': inputText,
        'score': 0,
        'postTime': timestamp,
        'userid': widget.user.uid,
        'postUpvoted': [widget.user.uid],
        'postDownvoted': [],
        'comments': [],
        'commented': [],
      });
      await Firestore.instance
          .collection('users')
          .doc(GlobalController.get().userDocUid)
          .update({'dailyPosts': GlobalController.get().dailyPosts - 1});
    } catch (e) {
      return Future.error("ERROR");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fetchingDailyPosts) {
      return Container(
          child: Center(
              child: SpinKitRing(
        color: spinnerColor,
        size: 100,
      )));
    } else
      return FutureBuilder(
          future: postingFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.none) {
              print("NO CONNECTION");
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
                    Center(child: Text('Enter your idea, keep it short!')),
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
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Remain anonymous'),
                          SizedBox(width: 20),
                          Switch(
                            onChanged: (bool val) {
                              setState(() {
                                anonimous = val;
                              });
                            },
                            value: anonimous,
                            activeColor: Colors.green,
                          ),
                        ],
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
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Remain anonymous'),
                          SizedBox(width: 20),
                          Switch(
                            onChanged: (bool val) {
                              setState(() {
                                anonimous = val;
                              });
                            },
                            value: anonimous,
                            activeColor: Colors.green,
                          ),
                        ],
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
                        child: SpinKitRing(
                  color: spinnerColor,
                  size: 100,
                )));
              });
            }
            return Container(
                child: Center(
                    child: SpinKitRing(
              color: spinnerColor,
              size: 100,
            )));
            ;
          }

          // Otherwise, show something whilst waiting for initialization to complete
          );
  }
}
