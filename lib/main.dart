import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'Const.dart';
import 'BackgroundCard.dart';
import 'OverlayWidget.dart';
import 'package:ideashack/CardList.dart';
import 'IdeaAdd.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'RegistrationScreen.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'UserCard.dart';
import 'CommentsScreen.dart';
import 'DirectMessageScreen.dart';
import 'DMList.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIOverlays(
      [SystemUiOverlay.top, SystemUiOverlay.bottom]).then((_) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
        .then((_) {
      runApp(MyApp());
    });
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
          primaryColor: Color(0xFF212121), cardColor: Color(0xFF444444)),
      routes: {
        '/main': (context) => MainPage(),
        '/auth': (context) => RegistrationScreen(),
        '/comments': (context) => CommentsScreen(),
        '/message': (context) => DmScreen(),
        '/feed': (context) => DMList()
      },
      initialRoute: '/auth',
    );
  }
}

class AlignmentSt {
  AlignmentSt(this.x, this.y);
  double x;
  double y;
}

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool fadingIn = true;
  AnimationController controller;
  bool isLockedSwipe = true;
  bool deletingCard = false;
  List<Widget> stackCards = [];
  CardData currentCardData;
  CardData nextCardData;
  double thumbsUpOpacity = 0;
  double thumbsDownOpacity = 0;
  double boxColor = 0;
  Animation animation;
  bool fetchingData = false;
  bool trendingSelect = false;
  bool currentlyTrending = false;
  int fetchNum = 0;
  Widget bodyWidget;
  User user;
  bool firstBuild = true;
  List<int> selectedIndexes = [];
  Future<void> batchFuture;

  final AlignmentSt defaultFrontCardAlign = AlignmentSt(0.0, 0.0);
  AlignmentSt frontCardAlign;
  double frontCardRot = 0.0;

  Future<bool> _backButtonPressed() async {
    setState(() {});
    if (selectedIndexes.length == 0) {
      SystemNavigator.pop(animated: true);
      return false;
    } else {
      var indexToGo = selectedIndexes[selectedIndexes.length - 1];
      selectedIndexes.removeLast();

      setState(() {
        fadingIn = true;
        controller.forward(from: 0.0);
        if (indexToGo == 1) {
          fetchNum = 0;
        }
        if (indexToGo == 0) {
          GlobalController.get()
              .checkLastTimestampsAndUpdatePosts(onFetchUserTimestampsCallback);
        }
        GlobalController.get().selectedIndex = indexToGo;
      });
    }
    return false;
  }

  void onFetchUserTimestampsCallback(int newPosts) {
    setState(() {
      GlobalController.get().fetchingDailyPosts = false;
      GlobalController.get().dailyPosts = newPosts;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!fetchingData) {
        setState(() {
          fetchNum = 0;
        });
      }
      if (!GlobalController.get().fetchingDailyPosts) {
        GlobalController.get()
            .checkLastTimestampsAndUpdatePosts(onFetchUserTimestampsCallback);
      }
    }
  }

  void commentsCallback(CardData data, bool profane) {
    setState(() {
      currentCardData = data;
    });
    if (profane) {
      _settingModalBottomSheet(context, InfoSheet.Profane);
    } else {
      _settingModalBottomSheet(context, InfoSheet.Commented);
    }
  }

  void commentsCallbackUserPanel(bool profane) {
    if (profane)
      _settingModalBottomSheet(context, InfoSheet.Profane);
    else
      _settingModalBottomSheet(context, InfoSheet.Commented);
  }

  @override
  void initState() {
    KeyboardVisibilityNotification().addNewListener(onHide: () {
      SystemChrome.restoreSystemUIOverlays();
    });
    WidgetsBinding.instance.addObserver(this);
    currentCardData = CardList.get().getNextCard();
    nextCardData = CardList.get().getNextCard();
    frontCardAlign = defaultFrontCardAlign;
    controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );

    controller.addListener(() {
      setState(() {
        if (!isLockedSwipe) return;
        if (deletingCard) {
          frontCardAlign = AlignmentSt(
              frontCardAlign.x +
                  frontCardAlign.x.clamp(-1, 1) * controller.value * 50,
              frontCardAlign.y + controller.value * 100);
        } else {
          frontCardAlign = AlignmentSt(
              frontCardAlign.x - frontCardAlign.x * controller.value,
              frontCardAlign.y - frontCardAlign.y * controller.value);
        }
        frontCardRot = frontCardRot - frontCardRot * controller.value;
        if (currentCardData != null &&
            currentCardData.status == UpvotedStatus.DidntVote) {
          thumbsUpOpacity = (frontCardRot * 20.0).clamp(0.0, 255.0);
          thumbsDownOpacity = (-frontCardRot * 20.0).clamp(0.0, 255.0);
        }
        boxColor = (frontCardRot.abs() * 50.0).clamp(0.0, 255.0);
      });
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (fadingIn) {
          fadingIn = false;
          isLockedSwipe = false;
        }
        if (deletingCard) {
          popCard();
          deletingCard = false;
        }
        isLockedSwipe = false;
      }
    });
    buildCards();
    animation = CurvedAnimation(parent: controller, curve: Curves.linear);
    controller.forward(from: 0);
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  void checkForNextCard() {
    setState(() {});
    if (currentCardData == null) {
      currentCardData = CardList.get().getNextCard();
    }
    if (nextCardData == null) {
      nextCardData = CardList.get().getNextCard();
    }
    setState(() {
      thumbsDownOpacity = 0;
      thumbsUpOpacity = 0;
    });
    buildCards();
  }

  void IdeaAddCallback() {
    setState(() {
      GlobalController.get().dailyPosts = GlobalController.get().dailyPosts - 1;
      GlobalController.get().selectedIndex = 1;
      fetchNum = 0;
    });
    _settingModalBottomSheet(context, InfoSheet.Posted);
  }

  void setTrendingFunc(bool trending) {
    setState(() {
      this.trendingSelect = trending;
    });
  }

  void popCard() {
    setState(() {
      frontCardAlign = defaultFrontCardAlign;
      frontCardRot = 0;
      currentCardData = nextCardData;
      nextCardData = CardList.get().getNextCard();
      setState(() {
        thumbsDownOpacity = 0;
        thumbsUpOpacity = 0;
      });
      buildCards();
    });
  }

  void buildCards() {
    stackCards.clear();
    if (nextCardData != null) {
      stackCards.add(BackgroundCard(cardData: nextCardData));
    } else {
      stackCards.add(
          Container(child: Center(child: Text('No more ideas currently'))));
      stackCards.add(OverlayWidget(
          noCards: true,
          setTrendingFunc: setTrendingFunc,
          trending: trendingSelect));
    }
    if (currentCardData != null) {
      stackCards.add(Container());
      stackCards.add(OverlayWidget(
          setTrendingFunc: setTrendingFunc,
          noCards: currentCardData == null,
          trending: trendingSelect));
      stackCards.add(SizedBox(
          child: GestureDetector(onPanUpdate: (thang) {
        if (isLockedSwipe) return;
        setState(() {
          frontCardAlign = AlignmentSt(
              frontCardAlign.x +
                  20 * thang.delta.dx / MediaQuery.of(context).size.width,
              frontCardAlign.y +
                  40 * thang.delta.dy / MediaQuery.of(context).size.height);
          frontCardRot = frontCardAlign.x;
          if (currentCardData != null &&
              currentCardData.status == UpvotedStatus.DidntVote) {
            thumbsUpOpacity = (frontCardRot * 20.0).clamp(0.0, 255.0);
            thumbsDownOpacity = (-frontCardRot * 20.0).clamp(0.0, 255.0);
          }
          boxColor = (frontCardRot.abs() * 50.0).clamp(0.0, 255.0);
        });
      }, onPanEnd: (thang) {
        if (isLockedSwipe) {
          return;
        }
        setState(() {
          isLockedSwipe = true;
          if ((frontCardRot.abs()) > 10) {
            if (currentCardData.status == UpvotedStatus.DidntVote) {
              if (frontCardRot > 10) {
                upvote();
              } else {
                downvote();
              }
            }
            deletingCard = true;
            controller.forward(from: 0);
          } else {
            deletingCard = false;
            controller.forward(from: 0);
          }
        });
      })));
    }
  }

  void upvote() async {
    try {
      String id = currentCardData.id;
      var snapshot = await Firestore.instance.collection('posts').doc(id).get();
      int score = snapshot.get('score');
      score = score + 1;
      await Firestore.instance.collection('posts').doc(id).update({
        'score': score,
        'postUpvoted': FieldValue.arrayUnion([user.uid])
      });
    } catch (e) {
      print(e);
    }
  }

  void downvote() async {
    try {
      String id = currentCardData.id;
      var snapshot = await Firestore.instance.collection('posts').doc(id).get();
      int score = snapshot.get('score');
      score = score - 1;
      await Firestore.instance.collection('posts').doc(id).update({
        'score': score,
        'postDownvoted': FieldValue.arrayUnion([user.uid])
      });
    } catch (e) {
      print(e);
    }
  }

  void _settingModalBottomSheet(context, InfoSheet sheet) {
    ListTile info;
    if (sheet == InfoSheet.Commented) {
      info = ListTile(
          leading: Icon(Icons.comment),
          title: Text('Succesfully posted a comment!'));
    } else if (sheet == InfoSheet.Posted) {
      info = ListTile(
          leading: Icon(Icons.lightbulb_outline),
          title: Text('You successfully posted an idea!'));
    } else if (sheet == InfoSheet.Profane) {
      info = ListTile(
          leading: Icon(Icons.not_interested),
          title: Text('Comment is too profane to post!'));
    }
    showModalBottomSheet(
        isDismissible: true,
        context: context,
        builder: (BuildContext bc) {
          return Container(
            child: info,
          );
        });
  }

  void FetchedData() {
    setState(() {
      currentlyTrending = trendingSelect;
      fetchingData = false;
      if (CardList.get().peekNextCard() == null) {
        fetchNum = fetchNum + 1;
      }
      checkForNextCard();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (firstBuild) {
      user = ModalRoute.of(context).settings.arguments;
      firstBuild = false;
    }
    if (currentCardData == null) {
      currentCardData = CardList.get().getNextCard();
    }
    if (nextCardData == null) {
      nextCardData = CardList.get().getNextCard();
    }
    if (currentCardData != null) {
      if (currentCardData.status == UpvotedStatus.Upvoted) {
        setState(() {
          thumbsDownOpacity = 0;
          thumbsUpOpacity = 255;
        });
      } else if (currentCardData.status == UpvotedStatus.Downvoted) {
        setState(() {
          thumbsUpOpacity = 0;
          thumbsDownOpacity = 255;
        });
      }
    }

    bodyWidget = null;
    if ((currentCardData == null &&
            fetchNum < 2 &&
            !fetchingData &&
            user != null) ||
        trendingSelect != currentlyTrending) {
      currentCardData = null;
      nextCardData = null;
      fetchingData = true;
      setState(() {
        batchFuture = CardList.get()
            .getNextBatch(lambda: FetchedData, trending: trendingSelect);
      });
    } else if (currentCardData != null && stackCards.length > 1) {
      stackCards[1] = (Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height -
            0.08 * MediaQuery.of(context).size.height,
        child: Transform.rotate(
          angle: frontCardRot * 3.14 / 180,
          child: Transform.translate(
            offset:
                Offset(frontCardAlign.x * 20, (frontCardAlign.x.abs()) * 10),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                decoration: BoxDecoration(boxShadow: [
                  BoxShadow(
                    blurRadius: 20.0,
                    color: Color.fromARGB(boxColor.toInt(), 0, 0, 0),
                  )
                ]),
                child: Card(
                    color: Color.lerp(
                        Color(0xFF68482B),
                        Color(0xFFFFD200),
                        (currentCardData.score.toDouble() / MAX_SCORE)
                            .clamp(0.0, 1.0)),
                    child: Center(
                        child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Stack(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Align(
                                alignment: Alignment(0.7, -3),
                                child: Transform.rotate(
                                  angle: 170,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      boxShadow: [
                                        BoxShadow(
                                            blurRadius: 9.0,
                                            color: Colors.black)
                                      ],
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                          formatedNumberString(
                                              currentCardData.score),
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 30,
                                              color: Color.fromARGB(
                                                  200,
                                                  currentCardData.score < 0
                                                      ? 170
                                                      : 0,
                                                  currentCardData.score >= 0
                                                      ? 170
                                                      : 0,
                                                  0))),
                                    ),
                                  ),
                                ),
                              ),
                              Text(currentCardData.text,
                                  style: MAIN_CARD_TEXT_STYLE),
                              SizedBox(height: 20),
                              Align(
                                  alignment: Alignment.bottomRight,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('- ${currentCardData.author}',
                                        style: AUTHOR_CARD_TEXT_STYLE),
                                  ))
                            ],
                          ),
                          Align(
                            alignment: Alignment(-0.4, -0.4),
                            child: Icon(FontAwesomeIcons.solidThumbsUp,
                                size: 50,
                                color: Color.fromARGB(
                                    thumbsUpOpacity.toInt(), 0, 255, 0)),
                          ),
                          Align(
                            alignment: Alignment(0.4, -0.4),
                            child: Icon(FontAwesomeIcons.solidThumbsDown,
                                size: 50,
                                color: Color.fromARGB(
                                    thumbsDownOpacity.toInt(), 255, 0, 0)),
                          ),
                          Align(
                            alignment: Alignment(0.8, 0.8),
                            child: RaisedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/comments',
                                    arguments: <dynamic>[
                                      currentCardData,
                                      commentsCallback
                                    ]);
                              },
                              highlightColor: Colors.white,
                              disabledColor: Colors.redAccent,
                              color: Colors.white60,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20.0),
                                side: BorderSide(color: Colors.red, width: 3),
                              ),
                              child: Icon(FontAwesomeIcons.comments,
                                  size: 50, color: Colors.black45),
                            ),
                          ),
                          Align(
                            alignment: Alignment(-0.8, 0.8),
                            child: RaisedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/message',
                                    arguments: <dynamic>[
                                      currentCardData.id,
                                      GlobalController.get().currentUserUid,
                                      currentCardData.posterId,
                                    ]);
                              },
                              highlightColor: Colors.white,
                              disabledColor: Colors.redAccent,
                              color: Colors.white60,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20.0),
                                side: BorderSide(color: Colors.red, width: 3),
                              ),
                              child: Icon(Icons.message,
                                  size: 50, color: Colors.black45),
                            ),
                          )
                        ],
                      ),
                    ))),
              ),
            ),
          ),
        ),
      ));
    }

    if (GlobalController.get().selectedIndex == 1 &&
        !fetchingData &&
        stackCards.length > 1) {
      bodyWidget = SafeArea(
        child: Stack(
          children: stackCards,
        ),
      );
    } else if (GlobalController.get().selectedIndex == 0) {
      bodyWidget = IdeaAdd(
          IdeaAddCallback, user, GlobalController.get().fetchingDailyPosts);
    } else if (GlobalController.get().selectedIndex == 2) {
      bodyWidget = UserCard(commentsCallbackUserPanel);
    } else if ((fetchingData || stackCards.length < 1) &&
        GlobalController.get().selectedIndex == 1) {
      bodyWidget = Container(
          child: Center(child: SpinKitRing(size: 100, color: spinnerColor)));
    } else {
      bodyWidget = SafeArea(
        child: Stack(
          children: stackCards,
        ),
      );
    }

    return Scaffold(
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: GlobalController.get().selectedIndex,
          onTap: (number) {
            if (number == GlobalController.get().selectedIndex) {
              return;
            } else {
              fadingIn = true;
              controller.forward(from: 0.0);
              if (number == 1) {
                setState(() {
                  fetchNum = 0;
                });
              }
              if (number == 0) {
                GlobalController.get().checkLastTimestampsAndUpdatePosts(
                    onFetchUserTimestampsCallback);
              }
              setState(() {
                selectedIndexes.add(GlobalController.get().selectedIndex);
                GlobalController.get().selectedIndex = number;
              });
            }
          },
          items: [
            BottomNavigationBarItem(
                icon: Icon(Icons.add), title: Text('Share Idea')),
            BottomNavigationBarItem(
                icon: Icon(Icons.lightbulb_outline),
                title: Text('Browse Ideas')),
            BottomNavigationBarItem(
                icon: Icon(Icons.person), title: Text('User Panel'))
          ],
        ),
        body: WillPopScope(
          onWillPop: _backButtonPressed,
          child: Stack(children: [
            Opacity(child: bodyWidget, opacity: fadingIn ? animation.value : 1),
            FeedOverlay()
          ]),
        ));
  }
}

class FeedOverlay extends StatefulWidget {
  @override
  _FeedOverlayState createState() => _FeedOverlayState();
}

class _FeedOverlayState extends State<FeedOverlay> {
  Stream<QuerySnapshot> authorStream;
  @override
  void initState() {
    authorStream = Firestore.instance
        .collection('directMessages')
        .where('posters', arrayContains: GlobalController.get().currentUserUid)
        .snapshots();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
        child: Container(
            child: Align(
                alignment: Alignment(1, -0.5),
                child: GestureDetector(
                    child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white60,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/feed');
                    },
                    child: StreamBuilder(
                        stream: authorStream,
                        builder: (context, snapshot) {
                          if (snapshot.data == null) {
                            return Icon(Icons.notifications, size: 40);
                          } else {
                            List<QueryDocumentSnapshot> commentHolderList =
                                snapshot.data.docs;

                            for (var snapshotDoc in commentHolderList) {
                              double relevantTimestamp = 0;
                              if (snapshotDoc.get('initializerId') ==
                                  GlobalController.get().currentUserUid) {
                                relevantTimestamp =
                                    snapshotDoc.get('lastSeenInitializer');
                              } else {
                                relevantTimestamp =
                                    snapshotDoc.get('lastSeenAuthor');
                              }
                              if (snapshotDoc.get('lastMessage') >
                                  relevantTimestamp) {
                                return Icon(Icons.notifications_active,
                                    size: 40, color: Colors.red);
                              }
                            }
                            return Icon(Icons.notifications,
                                size: 40, color: Colors.white);
                          }
                        }),
                  ),
                )))));
  }
}
