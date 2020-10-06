import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_admob/native_admob_controller.dart';
import 'package:flutter_native_admob/native_admob_options.dart';
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
import 'package:flutter/rendering.dart';
import 'dart:io';
import 'package:ideashack/SearchScreen.dart';
import 'FeedOverlay.dart';
import 'package:flutter_native_admob/flutter_native_admob.dart';
import 'package:ideashack/MainScreenMisc.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light
      .copyWith(systemNavigationBarColor: Colors.white));
  SystemChrome.setEnabledSystemUIOverlays(
      [SystemUiOverlay.top, SystemUiOverlay.bottom]);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(MyApp());
}

String getBannerAdUnitId() {
  if (Platform.isIOS) {
    return 'ca-app-pub-3940256099942544/2934735716';
  } else if (Platform.isAndroid) {
    return 'ca-app-pub-9903730459271982/9623099806';
  }
  return null;
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
  RenderRepaintBoundary repaint;
  GlobalKey mainWidgetKey;
  double adCounter = 0;
  Timer adTimer;
  Widget banner;
  NativeAdmobController controllerAdmob = NativeAdmobController();

  final AlignmentSt defaultFrontCardAlign = AlignmentSt(0.0, 0.0);
  AlignmentSt frontCardAlign;
  double frontCardRot = 0.0;

  Future<void> reportPost() async {
    try {
      var docs = await Firestore.instance
          .collection('reportedPosts')
          .where('postid', isEqualTo: currentCardData.id)
          .get();
      if (docs.docs.length == 0) {
        if (user.isAnonymous) {
          await Firestore.instance.collection('reportedPosts').add(
              {'postid': currentCardData.id, 'anonReports': 1, 'reports': 0});
        } else {
          await Firestore.instance.collection('reportedPosts').add(
              {'postid': currentCardData.id, 'reports': 1, 'anonReports': 0});
        }
      } else {
        if (user.isAnonymous) {
          await Firestore.instance
              .collection('reportedPosts')
              .doc(docs.docs[0].id)
              .update({'anonReports': FieldValue.increment(1)});
        } else {
          await Firestore.instance
              .collection('reportedPosts')
              .doc(docs.docs[0].id)
              .update({'reports': FieldValue.increment(1)});
        }
      }
      if (!user.isAnonymous) {
        await Firestore.instance
            .collection('users')
            .doc(GlobalController.get().userDocId)
            .update({
          'reportedPosts': FieldValue.arrayUnion([currentCardData.id])
        });
      }
      currentCardData.reported = true;
    } catch (e) {
      return Future.error(e);
    }
  }

  void reportPostButtonClicked() {
    showDialog(
        context: context,
        builder: (_) => ReportPopup(
            !currentCardData.reported ? reportPost() : null,
            user.isAnonymous,
            currentCardData.reported));
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
      if (!GlobalController.get().fetchingDailyPosts &&
          GlobalController.get().selectedIndex == 0) {
        setState(() {
          GlobalController.get().fetchingDailyPosts = true;
        });
        print("HERE");
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

  void commentsCallback(CardData data, InfoSheet sheet) {
    setState(() {
      currentCardData = data;
    });
    _settingModalBottomSheet(context, sheet);
  }

  void commentsCallbackUserPanel(bool profane) {
    if (profane)
      _settingModalBottomSheet(context, InfoSheet.Profane);
    else
      _settingModalBottomSheet(context, InfoSheet.Commented);
  }

  @override
  void initState() {
    controllerAdmob.setTestDeviceIds(['738451C1DB43B39858E14A914334CF2A']);
    controllerAdmob.setAdUnitID('ca-app-pub-4102451006671600/2649770997');
    controllerAdmob.reloadAd();
    CardList.get().clear();
    KeyboardVisibilityNotification().addNewListener(onHide: () {
      SystemChrome.restoreSystemUIOverlays();
    });
    mainWidgetKey = GlobalKey();
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
    if (adTimer != null) {
      adTimer.cancel();
    }
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  void checkForNextCard() {
    setState(() {});
    if (GlobalController.get().isNextAd) {
      GlobalController.get().isAdLocked = false;
      if (adTimer != null) {
        adTimer.cancel();
        adTimer = null;
      }
      currentCardData = CardData(
          author: "Trash",
          score: 0,
          id: "trash",
          comments: 0,
          text: "",
          commented: true,
          posterId: "",
          status: UpvotedStatus.Upvoted,
          isAd: true);
    }
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
      GlobalController.get().cardsSwiped =
          GlobalController.get().cardsSwiped + 1;
      frontCardAlign = defaultFrontCardAlign;
      frontCardRot = 0;
      currentCardData = nextCardData;
      print("PUSHED");
      if (GlobalController.get().shouldShowAd()) {
        GlobalController.get().isNextAd = true;
        nextCardData = CardData(
            author: "Trash",
            score: 0,
            id: "trash",
            comments: 0,
            text: "",
            commented: true,
            posterId: "",
            status: UpvotedStatus.Upvoted,
            isAd: true);
        GlobalController.get().finishedAd = false;
      } else {
        nextCardData = CardList.get().getNextCard();
      }
      setState(() {
        thumbsDownOpacity = 0;
        thumbsUpOpacity = 0;
      });
      buildCards();
    });
  }

  void buildCards() {
    stackCards.clear();
    if (currentCardData != null && nextCardData != null) {
      stackCards.add(BackgroundCard(cardData: nextCardData));
    } else {
      stackCards.add(Container(
          child: Center(
              child: Container(
                  child: Center(
                      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/logo.png', width: 200),
          SizedBox(height: 20),
          Text('No more ideas currently'),
          SizedBox(height: 54)
        ],
      ))))));
    }
    stackCards.add(Container());
    stackCards.add(Container());
    if (currentCardData != null) {
      stackCards.add(Container());
      stackCards.add(SizedBox(
          child: GestureDetector(onPanUpdate: (thang) {
        if (GlobalController.get().isAdLocked) return;
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
                if (!GlobalController.get().currentUser.isAnonymous) {
                  upvote();
                }
              } else {
                if (!GlobalController.get().currentUser.isAnonymous) {
                  downvote();
                }
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
    if (sheet == InfoSheet.Deleted) {
      info = ListTile(
          leading: Icon(Icons.comment), title: Text('Post was deleted!'));
    }
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
    } else if (sheet == InfoSheet.Register) {
      info = ListTile(
          leading: Icon(Icons.remove_circle_outline),
          title: HashTagText(
              decoratedStyle: TextStyle(color: Colors.blue),
              basicStyle: TextStyle(),
              text: '#register to use this',
              onTap: (string) {
                Navigator.pop(context);
                print("POPPED");
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (context) {
                  return RegistrationScreen(
                    doSignInWithGoogle: true,
                  );
                }));
              }));
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
      } else {
        fetchNum = 2;
      }
      checkForNextCard();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (firstBuild) {
      print(currentCardData);
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
        CardList.get().lastDocumentSnapshot != null &&
        !fetchingData &&
        user != null)) {
      setState(() {
        fetchingData = true;
        print("TRIGGERED");
        if (tabSelect == SelectTab.Trending) {
          if (adTimer != null) {
            adTimer.cancel();
            adTimer = null;
          }
          batchFuture =
              CardList.get().getNextBatch(lambda: FetchedData, trending: true);
        } else if (tabSelect == SelectTab.New) {
          if (adTimer != null) {
            adTimer.cancel();
            adTimer = null;
          }
          batchFuture =
              CardList.get().getNextBatch(lambda: FetchedData, trending: false);
        } else {
          if (adTimer != null) {
            adTimer.cancel();
            adTimer = null;
          }
          batchFuture =
              CardList.get().getByTag(lambda: FetchedData, tag: customSearch);
        }
      });
    } else if ((currentCardData == null &&
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
          if (adTimer != null) {
            adTimer.cancel();
            adTimer = null;
          }
          CardList.get().resetLastDocumentSnapshot();
          batchFuture =
              CardList.get().getNextBatch(lambda: FetchedData, trending: true);
        } else if (tabSelect == SelectTab.New) {
          if (adTimer != null) {
            adTimer.cancel();
            adTimer = null;
          }
          CardList.get().resetLastDocumentSnapshot();
          batchFuture =
              CardList.get().getNextBatch(lambda: FetchedData, trending: false);
        } else {
          if (adTimer != null) {
            adTimer.cancel();
            adTimer = null;
          }
          CardList.get().resetLastDocumentSnapshot();
          batchFuture =
              CardList.get().getByTag(lambda: FetchedData, tag: customSearch);
        }
      });
    } else if (currentCardData != null && stackCards.length > 1) {
      if (currentCardData.isAd) {
        if (!GlobalController.get().isAdLocked &&
            !GlobalController.get().finishedAd) {
          GlobalController.get().isAdLocked = true;
          adCounter = GlobalController.get().adLockTime;
          adTimer = Timer.periodic(Duration(seconds: 1), (t) {
            setState(() {
              adCounter = adCounter - 1;
              if (adCounter == 0) {
                GlobalController.get().isAdLocked = false;
                adTimer.cancel();
                adTimer = null;
                GlobalController.get().finishedAd = true;
                GlobalController.get().isNextAd = false;
              }
            });
          });
        }
        stackCards[1] = Container(
          child: Transform.rotate(
            angle: frontCardRot * 3.14 / 180,
            child: Transform.translate(
              offset:
                  Offset(frontCardAlign.x * 20, (frontCardAlign.x.abs()) * 10),
              child: RepaintBoundary(
                key: mainWidgetKey,
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
                      child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 30),
                      Text('Thanks for supporting us!'),
                      SizedBox(height: 30),
                      Text(GlobalController.get().isAdLocked
                          ? 'Take a break for ${adCounter.toInt()} seconds!'
                          : 'Keep swiping!'),
                      SizedBox(height: 30),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Container(
                              decoration:
                                  BoxDecoration(color: Colors.black45, boxShadow: [
                                BoxShadow(color: Colors.black45, blurRadius: 20)
                              ]),
                              child: Center(
                                  child: NativeAdmob(
                                      error: Center(
                                          child: Text('No ads to display',
                                              style: TextStyle(
                                                  color: Colors.white))),
                                      adUnitID:
                                          'ca-app-pub-4102451006671600/2649770997',
                                      controller: controllerAdmob,
                                      loading: Center(
                                          child: SpinKitThreeBounce(
                                              size: 20, color: Colors.white)),
                                      type: NativeAdmobType.full,
                                      options: NativeAdmobOptions(
                                          callToActionStyle: NativeTextStyle(
                                              color: Colors.white),
                                          adLabelTextStyle: NativeTextStyle(
                                              color: Colors.white),
                                          bodyTextStyle: NativeTextStyle(
                                              color: Colors.white),
                                          headlineTextStyle: NativeTextStyle(color: Colors.white),
                                          advertiserTextStyle: NativeTextStyle(color: Colors.white),
                                          storeTextStyle: NativeTextStyle(color: Colors.white),
                                          showMediaContent: true)))),
                        ),
                      ),
                    ],
                  )),
                ),
              ),
            ),
          ),
        );
      } else {
        stackCards[1] = StreamBuilder(
          stream: Firestore.instance
              .collection('posts')
              .doc(currentCardData.id)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.waiting &&
                snapshot.data != null &&
                snapshot.data.data() != null) {
              currentCardData.comments = snapshot.data.get('commentsNum');
              currentCardData.score = snapshot.data.get('score');
            }
            return (Container(
              child: Transform.rotate(
                angle: frontCardRot * 3.14 / 180,
                child: Transform.translate(
                  offset: Offset(
                      frontCardAlign.x * 20, (frontCardAlign.x.abs()) * 10),
                  child: RepaintBoundary(
                    key: mainWidgetKey,
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
                                          Image.asset('assets/score.png',
                                              width: 40),
                                          SizedBox(width: 10),
                                          Text(
                                              formatedNumberString(
                                                  currentCardData.score),
                                              style: cardThingsTextStyle),
                                        ],
                                      ),
                                    ),
                                    Expanded(child: Container()),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          right: cardthingspadding),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Row(
                                            children: [
                                              GestureDetector(
                                                onTap: GlobalController.get()
                                                        .currentUser
                                                        .isAnonymous
                                                    ? () {
                                                        _settingModalBottomSheet(
                                                            context,
                                                            InfoSheet.Register);
                                                      }
                                                    : () {
                                                        Navigator.pushNamed(
                                                            context,
                                                            '/comments',
                                                            arguments: <
                                                                dynamic>[
                                                              currentCardData,
                                                              commentsCallback
                                                            ]);
                                                      },
                                                child: Image.asset(
                                                    'assets/comments.png',
                                                    width: 40),
                                              ),
                                              SizedBox(width: 10),
                                              Text(
                                                  formatedNumberString(
                                                      currentCardData.comments),
                                                  style: cardThingsTextStyle),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Expanded(
                                    child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Center(
                                      child: HashTagText(
                                        onTap: (string) {
                                          customSearchFunc(string.trim());
                                        },
                                        textAlign: TextAlign.center,
                                        text: currentCardData.text,
                                        basicStyle: MAIN_CARD_TEXT_STYLE,
                                        decoratedStyle: MAIN_CARD_TEXT_STYLE
                                            .copyWith(color: Colors.blue),
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        FlatButton(
                                          child: Text('Report',
                                              style: cardThingsBelowTextStyle
                                                  .copyWith(
                                                      fontStyle:
                                                          FontStyle.italic,
                                                      fontSize: 15)),
                                          onPressed: reportPostButtonClicked,
                                        )
                                      ],
                                    )
                                  ],
                                )),
                                SizedBox(height: 20),
                                Padding(
                                  padding:
                                      const EdgeInsets.all(cardthingspadding),
                                  child: Divider(
                                    color: cardThingsTextStyle.color,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: cardthingspadding,
                                      right: cardthingspadding),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      InkWell(
                                          child: Text('Message',
                                              style: cardThingsBelowTextStyle),
                                          onTap: GlobalController.get()
                                                  .currentUser
                                                  .isAnonymous
                                              ? () {
                                                  _settingModalBottomSheet(
                                                      context,
                                                      InfoSheet.Register);
                                                }
                                              : () {
                                                  Navigator.pushNamed(
                                                      context, '/message',
                                                      arguments: <dynamic>[
                                                        currentCardData.id,
                                                        GlobalController.get()
                                                            .currentUserUid,
                                                        currentCardData
                                                            .posterId,
                                                      ]);
                                                }),
                                      InkWell(
                                          onTap: GlobalController.get()
                                                  .currentUser
                                                  .isAnonymous
                                              ? () {
                                                  _settingModalBottomSheet(
                                                      context,
                                                      InfoSheet.Register);
                                                }
                                              : () {
                                                  Navigator.pushNamed(
                                                      context, '/comments',
                                                      arguments: <dynamic>[
                                                        currentCardData,
                                                        commentsCallback
                                                      ]);
                                                },
                                          child: Text('Comment',
                                              style: cardThingsBelowTextStyle)),
                                      InkWell(
                                          onTap: () {
                                            repaint = mainWidgetKey
                                                .currentContext
                                                .findRenderObject();
                                            showDialog(
                                                context: context,
                                                builder: (_) => SharePopup(
                                                    repaint,
                                                    currentCardData.text));
                                          },
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
                                    color: currentCardData.status ==
                                            UpvotedStatus.Upvoted
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
              ),
            ));
          },
        );
      }
      if (currentCardData.status == UpvotedStatus.DidntVote &&
          !GlobalController.get().currentUser.isAnonymous) {
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
                          searchSelected = false;
                          setTrendingFunc(false);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Text('Newest',
                              style: (tabSelect == SelectTab.New &&
                                      !searchSelected)
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
                          searchSelected = false;
                          setTrendingFunc(true);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Text('Trending',
                              style: (tabSelect == SelectTab.Trending &&
                                      !searchSelected)
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
                            searchSelected = true;
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
            Expanded(
                child: searchSelected
                    ? SearchScreen(customSearchFunc)
                    : Stack(children: stackCards)),
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
                          child: Text('Newest',
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
                              style: (tabSelect == SelectTab.Trending)
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
                            searchSelected = false;
                            setTrendingFunc(false);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Text('Newest',
                                style: (tabSelect == SelectTab.New &&
                                        !searchSelected)
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
                            searchSelected = false;
                            setTrendingFunc(true);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Text('Trending',
                                style: (tabSelect == SelectTab.Trending &&
                                        !searchSelected)
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
                                searchSelected = true;
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
              if ((number == 0 &&
                  GlobalController.get().currentUser.isAnonymous)) {
                _settingModalBottomSheet(context, InfoSheet.Register);
                return;
              }
              fadingIn = true;
              controller.forward(from: 0.0);
              if (number == 1) {
                setState(() {
                  fetchNum = 0;
                });
              }
              if (number == 0) {
                setState(() {
                  GlobalController.get().fetchingDailyPosts = true;
                });
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
