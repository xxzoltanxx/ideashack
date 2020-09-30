import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'Const.dart';
import 'BackgroundCard.dart';
import 'package:ideashack/CardList.dart';
import 'IdeaAdd.dart';
import 'RegistrationScreen.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'UserCard.dart';
import 'CommentsScreen.dart';
import 'DirectMessageScreen.dart';
import 'DMList.dart';
import 'package:hashtagable/hashtagable.dart';
import 'package:autocomplete_textfield/autocomplete_textfield.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light
      .copyWith(systemNavigationBarColor: Colors.white));
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
          textTheme: TextTheme(
            headline6: TextStyle(fontFamily: 'Roboto'),
            headline5: TextStyle(fontFamily: 'Roboto'),
            bodyText1: TextStyle(fontFamily: 'Roboto'),
            bodyText2: TextStyle(fontFamily: 'Roboto'),
          ),
          primaryColor: Color(0xFF212121),
          cardColor: Color(0xFF444444),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: Colors.white,
            selectedItemColor: Color(0xFFEABD00),
            unselectedItemColor: Color(0xFF666666),
          )),
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
  SelectTab tabSelect = SelectTab.New;
  SelectTab currentSelect = SelectTab.New;
  int fetchNum = 0;
  Widget bodyWidget;
  User user;
  bool firstBuild = true;
  Future<void> batchFuture;
  bool searchSelected = false;
  String customSearch = "";

  final AlignmentSt defaultFrontCardAlign = AlignmentSt(0.0, 0.0);
  AlignmentSt frontCardAlign;
  double frontCardRot = 0.0;

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

  void customSearchFunc(String tag) {
    this.tabSelect = SelectTab.Custom;
    this.currentSelect = SelectTab.Custom;
    customSearch = tag;
    setState(() {
      fetchNum = 0;
      currentCardData = null;
      nextCardData = null;
      CardList.get().clear();
    });
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
      if (trending)
        this.tabSelect = SelectTab.Trending;
      else
        this.tabSelect = SelectTab.New;
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
    }
    stackCards.add(Container());
    stackCards.add(Container());
    if (currentCardData != null) {
      stackCards.add(Container());
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
      await Firestore.instance
          .collection('users')
          .doc(GlobalController.get().userDocId)
          .update({
        'upvoted': FieldValue.arrayUnion([id])
      });
      await Firestore.instance.collection('posts').doc(id).update({
        'score': FieldValue.increment(1),
      });
    } catch (e) {
      print(e);
    }
  }

  void downvote() async {
    try {
      String id = currentCardData.id;
      await Firestore.instance
          .collection('users')
          .doc(GlobalController.get().userDocId)
          .update({
        'downvoted': FieldValue.arrayUnion([id])
      });
      await Firestore.instance.collection('posts').doc(id).update({
        'score': FieldValue.increment(-1),
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
      print("TRIGGERED2");
      fetchingData = false;
      searchSelected = false;
      currentSelect = tabSelect;
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
        tabSelect != currentSelect) {
      currentCardData = null;
      nextCardData = null;
      setState(() {
        fetchingData = true;
        print("TRIGGERED");
        if (tabSelect == SelectTab.Trending) {
          batchFuture =
              CardList.get().getNextBatch(lambda: FetchedData, trending: true);
        } else if (tabSelect == SelectTab.New) {
          batchFuture =
              CardList.get().getNextBatch(lambda: FetchedData, trending: false);
        } else {
          batchFuture =
              CardList.get().getByTag(lambda: FetchedData, tag: customSearch);
        }
      });
    } else if (currentCardData != null && stackCards.length > 1) {
      stackCards[1] = (Container(
        child: Transform.rotate(
          angle: frontCardRot * 3.14 / 180,
          child: Transform.translate(
            offset:
                Offset(frontCardAlign.x * 20, (frontCardAlign.x.abs()) * 10),
            child: Container(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: FractionalOffset.bottomLeft,
                      end: FractionalOffset.topRight,
                      colors: [
                        Color.lerp(
                            bottomLeftStart,
                            bottomLeftEnd,
                            (currentCardData.score.toDouble() /
                                    GlobalController.get().MAX_SCORE)
                                .clamp(0.0, 1.0)),
                        Color.lerp(
                            topRightStart,
                            topRightEnd,
                            (currentCardData.score.toDouble() /
                                    GlobalController.get().MAX_SCORE)
                                .clamp(0.0, 1.0)),
                      ]),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 20.0,
                      color: Color.fromARGB(boxColor.toInt(), 0, 0, 0),
                    )
                  ]),
              child: Center(
                  child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: cardthingspadding),
                              child: Row(
                                children: [
                                  Image.asset('assets/score.png', width: 40),
                                  SizedBox(width: 10),
                                  Text(currentCardData.score.toString(),
                                      style: cardThingsTextStyle),
                                ],
                              ),
                            ),
                            Expanded(child: Container()),
                            Padding(
                              padding: const EdgeInsets.only(
                                  right: cardthingspadding),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Row(
                                    children: [
                                      Image.asset('assets/comments.png',
                                          width: 40),
                                      SizedBox(width: 10),
                                      Text(currentCardData.comments.toString(),
                                          style: cardThingsTextStyle),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                        Expanded(
                            child: Center(
                          child: HashTagText(
                            onTap: (string) {
                              customSearchFunc(string.trim());
                            },
                            textAlign: TextAlign.center,
                            text: currentCardData.text,
                            basicStyle: MAIN_CARD_TEXT_STYLE,
                            decoratedStyle: MAIN_CARD_TEXT_STYLE.copyWith(
                                color: Colors.blue),
                          ),
                        )),
                        SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.all(cardthingspadding),
                          child: Divider(
                            color: cardThingsTextStyle.color,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                              left: cardthingspadding,
                              right: cardthingspadding),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                  child: Text('Message',
                                      style: cardThingsBelowTextStyle),
                                  onTap: () {
                                    Navigator.pushNamed(context, '/message',
                                        arguments: <dynamic>[
                                          currentCardData.id,
                                          GlobalController.get().currentUserUid,
                                          currentCardData.posterId,
                                        ]);
                                  }),
                              InkWell(
                                  onTap: () {
                                    Navigator.pushNamed(context, '/comments',
                                        arguments: <dynamic>[
                                          currentCardData,
                                          commentsCallback
                                        ]);
                                  },
                                  child: Text('Comment',
                                      style: cardThingsBelowTextStyle)),
                              InkWell(
                                  child: Text('Share',
                                      style: cardThingsBelowTextStyle))
                            ],
                          ),
                        )
                      ],
                    ),
                    IgnorePointer(
                      child: Align(
                        alignment: Alignment(-0.4, -0.9),
                        child: Image.asset('assets/upvoted.png',
                            width: 200,
                            color:
                                currentCardData.status == UpvotedStatus.Upvoted
                                    ? Color(0x80FFFFFF)
                                    : Color(0x00000000)),
                      ),
                    ),
                    IgnorePointer(
                      child: Align(
                        alignment: Alignment(0.4, -0.9),
                        child: Image.asset('assets/downvoted.png',
                            width: 200,
                            color: currentCardData.status ==
                                    UpvotedStatus.Downvoted
                                ? Color(0x80FFFFFF)
                                : Color(0x00000000)),
                      ),
                    )
                  ],
                ),
              )),
            ),
          ),
        ),
      ));
      if (currentCardData.status == UpvotedStatus.DidntVote) {
        stackCards[2] =
            LikeIndicator(controller.value, deletingCard, thumbsUpOpacity);
        stackCards[3] =
            DislikeIndicator(controller.value, deletingCard, thumbsDownOpacity);
      }
    }

    if (GlobalController.get().selectedIndex == 1 &&
        !fetchingData &&
        stackCards.length > 1) {
      bodyWidget = SafeArea(
        child: Column(
          children: [
            Container(
                color: Colors.white,
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () {
                          setTrendingFunc(false);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Text('New',
                              style: (tabSelect == SelectTab.New)
                                  ? enabledUpperBarStyle
                                  : disabledUpperBarStyle),
                        ),
                      ),
                      VerticalDivider(
                        color: Colors.grey,
                        thickness: 1,
                        indent: 2,
                        endIndent: 2,
                      ),
                      InkWell(
                        onTap: () {
                          setTrendingFunc(true);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Text('Trending',
                              style: (tabSelect == SelectTab.Trending)
                                  ? enabledUpperBarStyle
                                  : disabledUpperBarStyle),
                        ),
                      ),
                      VerticalDivider(
                        color: Colors.grey,
                        thickness: 1,
                        indent: 2,
                        endIndent: 2,
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            searchSelected = !searchSelected;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Text(
                            'Search',
                            style: searchSelected
                                ? enabledUpperBarStyle
                                : disabledUpperBarStyle,
                          ),
                        ),
                      ),
                      Expanded(child: Container()),
                      FeedOverlay(),
                    ],
                  ),
                )),
            Container(
                child: !searchSelected ? null : SearchBar(customSearchFunc)),
            Expanded(child: Stack(children: stackCards)),
          ],
        ),
      );
    } else if (GlobalController.get().selectedIndex == 0) {
      bodyWidget = IdeaAdd(
          IdeaAddCallback, user, GlobalController.get().fetchingDailyPosts);
    } else if (GlobalController.get().selectedIndex == 2) {
      bodyWidget = UserCard(commentsCallbackUserPanel);
    } else if ((fetchingData || stackCards.length < 1) &&
        GlobalController.get().selectedIndex == 1) {
      bodyWidget = SafeArea(
        child: Column(
          children: [
            Container(
                color: Colors.white,
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      InkWell(
                        onTap: null,
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Text('New',
                              style: (tabSelect == SelectTab.New)
                                  ? enabledOnReloadStyle
                                  : disabledOnReloadStyle),
                        ),
                      ),
                      VerticalDivider(
                        color: Colors.grey,
                        thickness: 1,
                        indent: 2,
                        endIndent: 2,
                      ),
                      InkWell(
                        onTap: null,
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Text('Trending',
                              style: (tabSelect == SelectTab.New)
                                  ? enabledOnReloadStyle
                                  : disabledOnReloadStyle),
                        ),
                      ),
                      VerticalDivider(
                        color: Colors.grey,
                        thickness: 1,
                        indent: 2,
                        endIndent: 2,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Text('Search', style: disabledOnReloadStyle),
                      ),
                      Expanded(child: Container()),
                      FeedOverlay(),
                    ],
                  ),
                )),
            Expanded(
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
          ],
        ),
      );
    } else {
      bodyWidget = SafeArea(
        child: SizedBox.expand(
          child: Column(
            children: [
              Container(
                  color: Colors.white,
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () {
                            setTrendingFunc(false);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Text('New',
                                style: (tabSelect == SelectTab.New)
                                    ? enabledUpperBarStyle
                                    : disabledUpperBarStyle),
                          ),
                        ),
                        VerticalDivider(
                          color: Colors.grey,
                          thickness: 1,
                          indent: 2,
                          endIndent: 2,
                        ),
                        InkWell(
                          onTap: () {
                            setTrendingFunc(true);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Text('Trending',
                                style: (tabSelect == SelectTab.Trending)
                                    ? enabledUpperBarStyle
                                    : disabledUpperBarStyle),
                          ),
                        ),
                        VerticalDivider(
                          color: Colors.grey,
                          thickness: 1,
                          indent: 2,
                          endIndent: 2,
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {});
                          },
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                searchSelected = !searchSelected;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Text(
                                'Search',
                                style: searchSelected
                                    ? enabledUpperBarStyle
                                    : disabledUpperBarStyle,
                              ),
                            ),
                          ),
                        ),
                        Expanded(child: Container()),
                        FeedOverlay(),
                      ],
                    ),
                  )),
              Expanded(child: Stack(children: stackCards)),
            ],
          ),
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
        body: SafeArea(
          child: Container(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: splashScreenColors,
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight)),
              child: Opacity(
                  opacity: fadingIn ? animation.value : 1, child: bodyWidget)),
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
    return Container(
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
                return Image.asset(
                  'assets/bell-inactive.png',
                  width: 25,
                );
              } else {
                List<QueryDocumentSnapshot> commentHolderList =
                    snapshot.data.docs;

                for (var snapshotDoc in commentHolderList) {
                  double relevantTimestamp = 0;
                  if (snapshotDoc.get('initializerId') ==
                      GlobalController.get().currentUserUid) {
                    relevantTimestamp = snapshotDoc.get('lastSeenInitializer');
                  } else {
                    relevantTimestamp = snapshotDoc.get('lastSeenAuthor');
                  }
                  if (snapshotDoc.get('lastMessage') > relevantTimestamp) {
                    return Image.asset('assets/bell-active.png', width: 25);
                  }
                }
                return Image.asset('assets/bell-inactive.png', width: 25);
              }
            }),
      ),
    );
  }
}

class DislikeIndicator extends StatelessWidget {
  DislikeIndicator(this.animationProgress, this.didSwipe, this.opacity);

  double opacity;
  double animationProgress;
  bool didSwipe;
  @override
  Widget build(BuildContext context) {
    if (!didSwipe) {
      animationProgress = opacity / 255.0;
    }
    if (didSwipe && opacity == 0) {
      animationProgress = 0;
    }
    return Center(
      child: Transform.scale(
          scale: (didSwipe && opacity != 0) ? 1 : animationProgress,
          child: Transform.rotate(
              angle: 3.14,
              child: Image.asset('assets/thumbs-up.png',
                  width: 200,
                  color: didSwipe
                      ? Color.lerp(Colors.white, Colors.red, animationProgress)
                      : Colors.white))),
    );
  }
}

class LikeIndicator extends StatelessWidget {
  LikeIndicator(this.animationProgress, this.didSwipe, this.opacity);

  double animationProgress;
  bool didSwipe;
  double opacity;
  @override
  Widget build(BuildContext context) {
    if (!didSwipe) {
      animationProgress = opacity / 255.0;
    }
    if (didSwipe && opacity == 0) {
      animationProgress = 0;
    }
    return Center(
      child: Transform.scale(
        scale: (didSwipe && opacity != 0) ? 1 : animationProgress,
        child: Image.asset('assets/thumbs-up.png',
            width: 200,
            color: didSwipe
                ? Color.lerp(Colors.white, Colors.green, animationProgress)
                : Colors.white),
      ),
    );
  }
}

class SearchBar extends StatefulWidget {
  @override
  _SearchBarState createState() => _SearchBarState();
  SearchBar(this.callback);
  final Function callback;
}

class _SearchBarState extends State<SearchBar> {
  Future<QuerySnapshot> snapshot;
  String searchString = "#";
  TextEditingController controller;
  GlobalKey key;
  @override
  void initState() {
    key = GlobalKey<AutoCompleteTextFieldState<String>>();
    snapshot = Firestore.instance
        .collection('hashtags')
        .orderBy('popularity', descending: true)
        .limit(HASH_TAG_LIMIT)
        .get();
    controller = TextEditingController(text: searchString);
    super.initState();
  }

  void callback() {
    print("TRIGGERED");
    widget.callback(searchString);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: snapshot,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active ||
              snapshot.connectionState == ConnectionState.waiting) {
            return Container(child: Center(child: Text('Fetching tags...')));
          }
          if (snapshot.hasError) {
            return Container(
                child: Center(child: Text('Could not fetch tags...')));
          } else {
            if (snapshot.data == null || snapshot.data.docs == null) {
              return Container(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 50,
                        child: SimpleAutoCompleteTextField(
                          suggestionsAmount: 5,
                          textSubmitted: (string) {
                            searchString = string;
                            callback();
                          },
                          onFocusChanged: (hasFocus) {},
                          key: key,
                          suggestions: [],
                          textChanged: (str) {
                            searchString = str;
                          },
                        ),
                      ),
                    ),
                    SizedBox(width: 50),
                    FlatButton(
                        onPressed: callback,
                        color: Colors.transparent,
                        child: Center(child: Text('Search')))
                  ],
                ),
              );
            } else {
              List<String> suggestions = [];
              for (var doc in snapshot.data.docs) {
                suggestions.add(doc.get('tag'));
              }
              print(suggestions);
              return Container(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 50,
                        child: SimpleAutoCompleteTextField(
                          suggestionsAmount: 5,
                          textSubmitted: (string) {
                            print('submited');
                            searchString = string;
                            callback();
                          },
                          controller: controller,
                          key: key,
                          suggestions: suggestions,
                          textChanged: (str) {
                            searchString = str;
                          },
                        ),
                      ),
                    ),
                    SizedBox(width: 50),
                    FlatButton(
                        onPressed: callback,
                        color: Colors.transparent,
                        child: Center(child: Text('Search')))
                  ],
                ),
              );
            }
          }
        });
  }
}
