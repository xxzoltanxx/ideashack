import 'dart:async';
import 'dart:typed_data';
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
import 'ConnectivityManager.dart';
import 'package:async/async.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:admob_consent/admob_consent.dart';
import 'Analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:share/share.dart';
import 'NotificationList.dart';
import 'package:path_provider/path_provider.dart';

void initFirebaseMessaging() {
  FirebaseMessaging _firebaseMessaging =
      GlobalController.get().firebaseMessaging;
  _firebaseMessaging.configure(
    onMessage: (Map<String, dynamic> message) async {
      print("onMessage: $message");
    },
    onLaunch: (Map<String, dynamic> message) async {
      GlobalController.get().openFromNotification = true;
      print("onLaunch: $message");
      if (message['data'].containsKey('initializer')) {
        GlobalController.get().notificationData = NotificationData(
            'message',
            message['data']['postid'],
            message['data']['initializer'],
            message['data']['author']);
      } else if (message['data'].containsKey('type')) {
        if (message['data']['type'] == "comment") {
          GlobalController.get().notificationData = NotificationData(
              'comment', message['data']['postid'], null, null);
        } else if (message['data']['type'] == 'like') {
          GlobalController.get().notificationData =
              NotificationData('like', message['data']['postid'], null, null);
        }
      }
    },
    onResume: (Map<String, dynamic> message) async {
      GlobalController.get().openFromNotification = true;
      if (message['data'].containsKey('initializer')) {
        GlobalController.get().notificationData = NotificationData(
            'message',
            message['data']['postid'],
            message['data']['initializer'],
            message['data']['author']);
      } else if (message['data'].containsKey('type')) {
        if (message['data']['type'] == "comment") {
          GlobalController.get().notificationData = NotificationData(
              'comment', message['data']['postid'], null, null);
        } else if (message['data']['type'] == 'like') {
          GlobalController.get().notificationData =
              NotificationData('like', message['data']['postid'], null, null);
        }
      }
    },
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  AnalyticsController.get().init();
  Firestore.instance.settings = Settings(
    persistenceEnabled: false,
  );
  ConnectionStatusSingleton connectionStatus =
      ConnectionStatusSingleton.getInstance();
  connectionStatus.initialize();
  initFirebaseMessaging();
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
      navigatorObservers: [AnalyticsController.get().observer],
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
        '/feed': (context) => DMList(),
        '/notifications': (context) => NotificationList()
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
  AnimationController controller;
  bool isLockedSwipe = false;
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
  CancelableOperation batchFuture;
  bool searchSelected = false;
  String customSearch = "";
  GlobalKey mainWidgetKey;
  double adCounter = 0;
  Timer adTimer;
  Widget banner;
  bool isOffline = false;
  Future<CardData> commentToDisplay;
  bool isFetchindComment = false;
  NativeAdmobController controllerAdmob = NativeAdmobController();
  StreamSubscription _connectionChangeStream;
  GlobalKey adKey;
  bool sharing = false;

  void shareCardData() async {
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
                            text: currentCardData.text,
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
            ],
          ),
        ),
      )),
    ));

    Uint8List imageData = await createImageFromWidget(shareWidget,
        logicalSize: Size(800, 800), imageSize: Size(800, 800));
    String dir = (await getApplicationDocumentsDirectory()).path;
    File file = File("$dir/" + 'myimage' + ".png");
    await file.writeAsBytes(imageData);
    try {
      await Share.shareFiles([dir + "/myimage.png"],
          mimeTypes: ['image/png'],
          text: 'See more at https://sparkyourimagination.page.link/join',
          subject: 'A brilliant idea!');
    } catch (e) {
      print(e);
    }
    setState(() {
      sharing = false;
    });
  }

  void saveShowedEula() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('showedEula', true);
  }

  void getShouldShowEula() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      bool shouldShowEula = !(prefs.getBool('showedEula') ?? false);
      if (shouldShowEula) {
        final AdmobConsent admobConsent = AdmobConsent();
        admobConsent.show();
        admobConsent.onConsentFormObtained.listen((o) {
          AnalyticsController.get().consentGiven();
          saveShowedEula();
        });
      }
    });
  }

  final AlignmentSt defaultFrontCardAlign = AlignmentSt(0.0, 0.0);
  AlignmentSt frontCardAlign;
  double frontCardRot = 0.0;

  Future<void> reportPost(
      String reason, String reporterId, String objection) async {
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
          var ref = await Firestore.instance.collection('reportedPosts').add({
            'postid': currentCardData.id,
            'reports': 1,
            'anonReports': 0,
          });
          await Firestore.instance
              .collection('reportedPosts')
              .doc(ref.id)
              .collection('reports')
              .add({
            'reason': reason,
            'reporterId': reporterId,
            'objection': objection
          });
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
          await Firestore.instance
              .collection('reportedPosts')
              .doc(docs.docs[0].id)
              .collection('reports')
              .add({
            'reason': reason,
            'reporterId': reporterId,
            'objection': objection
          });
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
    AnalyticsController.get().reportTappedPost(currentCardData.id);
    showDialog(
        context: context,
        builder: (_) => ReportPopup(
              user.isAnonymous,
              currentCardData.reported,
              !currentCardData.reported ? reportPost : null,
            ));
  }

  void onFetchUserTimestampsCallback(int newPosts) {
    setState(() {
      print("FETCHED DAILY POSTS");
      GlobalController.get().fetchingDailyPosts = false;
      GlobalController.get().dailyPosts = newPosts;
    });
  }

  void fetchComment(String postid) async {
    CardData data = await CardList.get().getCardDataForPost(postid);
    setState(() {
      isFetchindComment = false;
    });
    Navigator.pushNamed(context, '/comments',
        arguments: <dynamic>[data, notificationCommentsCallback]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (GlobalController.get().openFromNotification) {
      GlobalController.get().openFromNotification = false;
      NotificationData data = GlobalController.get().notificationData;
      if (data.postInitializer != null) {
        Navigator.popUntil(context, (route) => route.settings.name == '/main');

        Navigator.pushNamed(context, '/message', arguments: <dynamic>[
          data.postId,
          data.postInitializer,
          data.postAuthor
        ]);
      } else if (data.type == 'comment') {
        Navigator.popUntil(context, (route) => route.settings.name == '/main');
        setState(() {
          isFetchindComment = true;
        });
        fetchComment(data.postId);
      }
    }
    if (state == AppLifecycleState.resumed) {
      GlobalController.get().initedTime = false;
      if (!fetchingData && currentCardData == null) {
        setState(() {
          fetchNum = 0;
        });
      }
      if (!GlobalController.get().fetchingDailyPosts) {
        setState(() {
          GlobalController.get().fetchingDailyPosts = true;
        });
        GlobalController.get().checkLastTimestampsAndUpdateCounters(
            onFetchUserTimestampsCallback);
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

  void notificationCommentsCallback(CardData data, InfoSheet sheet) {
    _settingModalBottomSheet(context, sheet);
  }

  void commentsCallbackUserPanel(CardData data, InfoSheet sheet) {
    _settingModalBottomSheet(context, sheet);
  }

  void connectionChanged(dynamic hasConnection) {
    setState(() {
      isOffline = !hasConnection;
      if (isOffline) {
        CardList.get().clear();
        isFetchindComment = false;
        GlobalController.get().fetchingDailyPosts = false;
        fetchingData = false;
        if (!batchFuture.isCompleted) {
          batchFuture.cancel();
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    precacheImage(AssetImage('assets/bell-active.png'), context);
    precacheImage(AssetImage('assets/bell-inactive.png'), context);
    precacheImage(AssetImage('assets/comments.png'), context);
    precacheImage(AssetImage('assets/downvoted.png'), context);
    precacheImage(AssetImage('assets/mail-active.png'), context);
    precacheImage(AssetImage('assets/mail-inactive.png'), context);
    precacheImage(AssetImage('assets/score.png'), context);
    precacheImage(AssetImage('assets/search.png'), context);
    precacheImage(AssetImage('assets/shareidea.png'), context);
    precacheImage(AssetImage('assets/thumbs-up.png'), context);
    precacheImage(AssetImage('assets/upvoted.png'), context);
    precacheImage(AssetImage('assets/userpanel.png'), context);
    super.didChangeDependencies();
  }

  @override
  void initState() {
    getShouldShowEula();
    adKey = GlobalKey();
    controllerAdmob = NativeAdmobController();
    controllerAdmob.setAdUnitID(
      'ca-app-pub-4102451006671600/2649770997',
    );
    controllerAdmob.reloadAd(forceRefresh: true);
    ConnectionStatusSingleton connectionStatus =
        ConnectionStatusSingleton.getInstance();
    _connectionChangeStream =
        connectionStatus.connectionChange.listen(connectionChanged);

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
        if (deletingCard) {
          popCard();
          AnalyticsController.get().swiped();
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
    if (GlobalController.get().finishedAd) {
      GlobalController.get().finishedAd = true;
      controllerAdmob.reloadAd(forceRefresh: true);
    }
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
    setState(() {});
  }

  void IdeaAddCallback() {
    setState(() {
      GlobalController.get().dailyPosts = GlobalController.get().dailyPosts - 1;
      GlobalController.get().selectedIndex = 1;
      fetchNum = 0;
      currentCardData = null;
      nextCardData = null;
      CardList.get().resetLastDocumentSnapshot();
      CardList.get().clear();
      searchSelected = false;
      tabSelect = SelectTab.New;
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
      if (currentCardData.isAd) {
        controllerAdmob.reloadAd(forceRefresh: true);
        GlobalController.get().finishedAd = true;
      }
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
    if (currentCardData == null) {
      AnalyticsController.get().browseEndReached();
    }
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
                  upvote(currentCardData.score);
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

  void upvote(int score) async {
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
      sendNotificationForLikesIfEligible(score, id);
      AnalyticsController.get().upvoted(currentCardData.id);
    } catch (e) {
      print(e);
    }
  }

  void sendNotificationForLikesIfEligible(int score, String id) async {
    try {
      int realScore = score + 1;
      var time = await getCurrentTimestampServer();
      if (likeMilestones.contains(realScore)) {
        var postDoc =
            await Firestore.instance.collection('posts').doc(id).get();
        String userId = postDoc.get('userid');
        var userDocList = await Firestore.instance
            .collection('users')
            .where('uid', isEqualTo: userId)
            .get();
        var userDoc = userDocList.docs[0];
        GlobalController.get().callOnFcmApiSendPushNotifications(
            [userDoc.get('pushToken')],
            "Your idea got " + realScore.toString() + " likes!",
            "Nice job, people like your idea!",
            postDoc.id + "Like",
            NotificationData('like', postDoc.id, null, null));
        await Firestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('notifications')
            .add({
          'clicked': 0,
          'postId': postDoc.id,
          'text': 'Your idea got ${realScore} likes!',
          'time': time,
          'type': 'like'
        });
      }
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
      AnalyticsController.get().downvoted(currentCardData.id);
    } catch (e) {
      print(e);
    }
  }

  void _settingModalBottomSheet(context, InfoSheet sheet) {
    ListTile info;
    if (sheet == InfoSheet.PostLimitReached) {
      info = ListTile(
          leading: Icon(Icons.not_interested),
          title: Text('Post reached comment limit!'));
    }
    if (sheet == InfoSheet.CantRate) {
      info = ListTile(
          leading: Icon(Icons.thumb_up),
          title: Padding(
            padding: const EdgeInsets.all(8.0),
            child: HashTagText(
                decoratedStyle: TextStyle(color: Colors.blue),
                basicStyle: TextStyle(),
                text:
                    '#register to rate ideas, you can only browse as an anonymous user!',
                onTap: (string) {
                  AnalyticsController.get().registerModalPopupTapped();
                  Navigator.pop(context);
                  print("POPPED");
                  Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (context) {
                    return RegistrationScreen(
                      doSignInWithGoogle: true,
                    );
                  }));
                }),
          ));
    }
    if (sheet == InfoSheet.Deleted) {
      info = ListTile(
          leading: Icon(Icons.comment), title: Text('Post was deleted!'));
    } else if (sheet == InfoSheet.Commented) {
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
    } else if (sheet == InfoSheet.OneMessage) {
      info = ListTile(
          leading: Icon(Icons.not_interested),
          title: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
                'We limited direct message initializations to one a day to prevent unnecessary feedback!'),
          ));
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
    String sheetStr = parseSheet(sheet);
    AnalyticsController.get().modalPopupShown(sheetStr);
    showModalBottomSheet(
        isDismissible: true,
        context: context,
        builder: (BuildContext bc) {
          return Container(
            child: info,
          );
        });
  }

  String parseSheet(InfoSheet sheet) {
    switch (sheet) {
      case InfoSheet.PostLimitReached:
        return "postlimitreached";
        break;
      case InfoSheet.CantRate:
        return "cantrate";
        break;
      case InfoSheet.Commented:
        return "commented";
        break;
      case InfoSheet.Deleted:
        return "deleted";
        break;
      case InfoSheet.OneMessage:
        return "onemessage";
        break;
      case InfoSheet.Posted:
        return "posted";
        break;
      case InfoSheet.Profane:
        return "profane";
        break;
      case InfoSheet.Register:
        return "register";
        break;
    }
    return "undefined";
  }

  void FetchedData() {
    setState(() {
      print("TRIGGERED2");
      fetchingData = false;
      searchSelected = false;
      if (CardList.get().peekNextCard() == null) {
        fetchNum = fetchNum + 1;
      } else {
        fetchNum = 2;
      }
      checkForNextCard();
    });
  }

  void dontDeleteAccount() async {
    try {
      await Firestore.instance
          .collection('users')
          .doc(GlobalController.get().userDocId)
          .update({'scheduledForDeletion': 0});
      setState(() {
        GlobalController.get().scheduledForDeletion = 0;
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (GlobalController.get().scheduledForDeletion == 1) {
      bodyWidget = Container(
          child: Center(
              child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
              child: Text(
                'Account is scheduled for deletion which should occur in the timeframe of 48 hours!',
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 20),
            RaisedButton(
              child: Text('Reconsider?'),
              onPressed: dontDeleteAccount,
            )
          ],
        ),
      )));
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
                if (number == 1) {
                  setState(() {
                    fetchNum = 0;
                  });
                }
                if (number == 0) {
                  setState(() {
                    GlobalController.get().fetchingDailyPosts = true;
                  });
                  GlobalController.get().checkLastTimestampsAndUpdateCounters(
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
                child: bodyWidget),
          ));
    } else if (isOffline) {
      bodyWidget = Container(child: Center(child: Text('You\'re offline!')));
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
                if (number == 1) {
                  setState(() {
                    fetchNum = 0;
                  });
                }
                if (number == 0) {
                  setState(() {
                    GlobalController.get().fetchingDailyPosts = true;
                  });
                  GlobalController.get().checkLastTimestampsAndUpdateCounters(
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
                child: bodyWidget),
          ));
    }
    if (firstBuild) {
      if (GlobalController.get().currentUser.isAnonymous) {
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          _settingModalBottomSheet(context, InfoSheet.CantRate);
        });
      }
      print(currentCardData);
      user = ModalRoute.of(context).settings.arguments;
      firstBuild = false;
      if (GlobalController.get().openFromNotification) {
        GlobalController.get().openFromNotification = false;
        NotificationData data = GlobalController.get().notificationData;
        if (data.postInitializer != null) {
          Navigator.pushNamed(context, '/message', arguments: <dynamic>[
            data.postId,
            data.postInitializer,
            data.postAuthor
          ]);
        } else if (data.type == 'comment') {
          isFetchindComment = true;
          fetchComment(data.postId);
        }
      }
    }
    if (currentCardData == null) {
      currentCardData = CardList.get().getNextCard();
    }
    if (nextCardData == null) {
      nextCardData = CardList.get().getNextCard();
    }
    if (currentCardData != null) {
      if (currentCardData.status == UpvotedStatus.Upvoted) {
        thumbsDownOpacity = 0;
        thumbsUpOpacity = 255;
      } else if (currentCardData.status == UpvotedStatus.Downvoted) {
        thumbsUpOpacity = 0;
        thumbsDownOpacity = 255;
      }
    }

    bodyWidget = null;
    if ((currentCardData == null &&
        CardList.get().lastDocumentSnapshot != null &&
        !fetchingData &&
        user != null &&
        !isFetchindComment)) {
      fetchingData = true;
      print("TRIGGERED");
      if (tabSelect == SelectTab.Trending) {
        if (adTimer != null) {
          adTimer.cancel();
          adTimer = null;
        }
        AnalyticsController.get().loadingBatch();
        batchFuture = CancelableOperation.fromFuture(
            CardList.get().getNextBatch(lambda: FetchedData, trending: true));
      } else if (tabSelect == SelectTab.New) {
        if (adTimer != null) {
          adTimer.cancel();
          adTimer = null;
        }
        AnalyticsController.get().loadingBatch();
        batchFuture = CancelableOperation.fromFuture(
            CardList.get().getNextBatch(lambda: FetchedData, trending: false));
      } else {
        if (adTimer != null) {
          adTimer.cancel();
          adTimer = null;
        }
        AnalyticsController.get().loadingBatch();
        batchFuture = CancelableOperation.fromFuture(
            CardList.get().getByTag(lambda: FetchedData, tag: customSearch));
      }
    } else if ((currentCardData == null &&
            fetchNum < 2 &&
            !fetchingData &&
            user != null &&
            !isFetchindComment) ||
        tabSelect != currentSelect) {
      currentSelect = tabSelect;
      currentCardData = null;
      nextCardData = null;
      fetchingData = true;
      print("IT WAS HERE");
      if (tabSelect == SelectTab.Trending) {
        if (adTimer != null) {
          adTimer.cancel();
          adTimer = null;
        }
        AnalyticsController.get().loadingBatch();
        CardList.get().resetLastDocumentSnapshot();
        batchFuture = CancelableOperation.fromFuture(
            CardList.get().getNextBatch(lambda: FetchedData, trending: true));
      } else if (tabSelect == SelectTab.New) {
        if (adTimer != null) {
          adTimer.cancel();
          adTimer = null;
        }
        AnalyticsController.get().loadingBatch();
        CardList.get().resetLastDocumentSnapshot();
        batchFuture = CancelableOperation.fromFuture(
            CardList.get().getNextBatch(lambda: FetchedData, trending: false));
      } else {
        if (adTimer != null) {
          adTimer.cancel();
          adTimer = null;
        }
        AnalyticsController.get().loadingBatch();
        CardList.get().resetLastDocumentSnapshot();
        batchFuture = CancelableOperation.fromFuture(
            CardList.get().getByTag(lambda: FetchedData, tag: customSearch));
      }
    } else if (currentCardData != null &&
        stackCards.length > 1 &&
        !GlobalController.get().fetchingDailyPosts &&
        !isFetchindComment) {
      if (currentCardData.isAd) {
        if (!GlobalController.get().isAdLocked &&
            !GlobalController.get().finishedAd) {
          GlobalController.get().isAdLocked = true;
          AnalyticsController.get().adShown();
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
              child: Container(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xFFDBDBDB), Color(0xFFFFFFFF)]),
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
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Container(
                            decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border(
                                    top: BorderSide(color: Colors.black),
                                    bottom: BorderSide(color: Colors.black),
                                    left: BorderSide(color: Colors.black),
                                    right: BorderSide(color: Colors.black))),
                            child: Center(
                                child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: NativeAdmob(
                                  key: adKey,
                                  error: Center(
                                      child: Text('No ads to display!',
                                          style: disabledUpperBarStyle)),
                                  adUnitID:
                                      'ca-app-pub-4102451006671600/2649770997',
                                  controller: controllerAdmob,
                                  loading: Center(
                                      child: SpinKitThreeBounce(
                                          size: 20, color: Colors.white)),
                                  type: NativeAdmobType.full,
                                  options: NativeAdmobOptions(
                                      callToActionStyle:
                                          NativeTextStyle(color: Colors.black),
                                      adLabelTextStyle:
                                          NativeTextStyle(color: Colors.black),
                                      bodyTextStyle:
                                          NativeTextStyle(color: Colors.black),
                                      headlineTextStyle:
                                          NativeTextStyle(color: Colors.black),
                                      advertiserTextStyle:
                                          NativeTextStyle(color: Colors.black),
                                      storeTextStyle:
                                          NativeTextStyle(color: Colors.black),
                                      showMediaContent: true)),
                            ))),
                      ),
                    ),
                    Text('We are grateful for your support.',
                        style: disabledUpperBarStyle),
                    Text('Spark will continue in...',
                        style: enabledUpperBarStyle),
                    SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Divider(color: Colors.grey),
                    ),
                    SizedBox(height: 20),
                    GlobalController.get().isAdLocked
                        ? Text('${adCounter.toInt()}s',
                            style: enabledUpperBarStyle)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_left,
                                  color: enabledUpperBarColor),
                              SizedBox(width: 10),
                              Text('Swipe', style: enabledUpperBarStyle),
                              SizedBox(width: 10),
                              Icon(Icons.arrow_right,
                                  color: enabledUpperBarColor)
                            ],
                          ),
                    SizedBox(height: 20),
                  ],
                )),
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
              currentCardData.hidden = snapshot.data.get('hidden');
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
                                                        AnalyticsController
                                                                .get()
                                                            .commentTapped();
                                                        _settingModalBottomSheet(
                                                            context,
                                                            InfoSheet.Register);
                                                      }
                                                    : () {
                                                        AnalyticsController
                                                                .get()
                                                            .commentTapped();
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
                                          AnalyticsController.get()
                                              .hashTagCardClicked(string);
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
                                      Container(
                                        width: 90,
                                        child: Center(
                                          child: InkWell(
                                            child: Text('Message',
                                                style: ((GlobalController.get()
                                                                .canMessage ==
                                                            1) &&
                                                        (currentCardData
                                                                .posterId !=
                                                            GlobalController
                                                                    .get()
                                                                .currentUserUid))
                                                    ? cardThingsBelowTextStyle
                                                    : cardThingsBelowTextStyle
                                                        .copyWith(
                                                            color: Color(
                                                                0x55894100))),
                                            onTap: GlobalController.get()
                                                    .currentUser
                                                    .isAnonymous
                                                ? () {
                                                    AnalyticsController.get()
                                                        .messageTapped();
                                                    _settingModalBottomSheet(
                                                        context,
                                                        InfoSheet.Register);
                                                  }
                                                : ((GlobalController.get()
                                                                .canMessage ==
                                                            1) &&
                                                        (currentCardData
                                                                .posterId !=
                                                            GlobalController
                                                                    .get()
                                                                .currentUserUid))
                                                    ? () {
                                                        AnalyticsController
                                                                .get()
                                                            .messageTapped();
                                                        Navigator.pushNamed(
                                                            context, '/message',
                                                            arguments: <
                                                                dynamic>[
                                                              currentCardData
                                                                  .id,
                                                              GlobalController
                                                                      .get()
                                                                  .currentUserUid,
                                                              currentCardData
                                                                  .posterId,
                                                            ]);
                                                      }
                                                    : () {
                                                        _settingModalBottomSheet(
                                                            context,
                                                            InfoSheet
                                                                .OneMessage);
                                                      },
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 90,
                                        child: InkWell(
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
                                            child: Text(
                                              'Comment',
                                              style: cardThingsBelowTextStyle,
                                              textAlign: TextAlign.center,
                                            )),
                                      ),
                                      Container(
                                        width: 90,
                                        child: InkWell(
                                            onTap: sharing
                                                ? null
                                                : () {
                                                    setState(() {
                                                      sharing = true;
                                                    });
                                                    AnalyticsController.get()
                                                        .shareClicked();
                                                    shareCardData();
                                                  },
                                            child: Text(
                                              'Share',
                                              style: ((!sharing)
                                                  ? cardThingsBelowTextStyle
                                                  : cardThingsBelowTextStyle
                                                      .copyWith(
                                                          color: Color(
                                                              0x55894100))),
                                              textAlign: TextAlign.center,
                                            )),
                                      )
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
        stackCards.length > 1 &&
        !GlobalController.get().fetchingDailyPosts &&
        !isFetchindComment) {
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
                          AnalyticsController.get().tabSelected('Newest');
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
                          AnalyticsController.get().tabSelected('Trending');
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
                      NotificationOverlay(),
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
    } else if (GlobalController.get().selectedIndex == 2 &&
        !isFetchindComment) {
      bodyWidget = UserCard(commentsCallbackUserPanel);
    } else if (((fetchingData || GlobalController.get().fetchingDailyPosts) &&
            GlobalController.get().selectedIndex == 1) ||
        isFetchindComment) {
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
                      NotificationOverlay(),
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
                            AnalyticsController.get().tabSelected('Newest');
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
                            AnalyticsController.get().tabSelected('Trending');
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
                        NotificationOverlay(),
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
              if (number == 1) {
                AnalyticsController.get().browseIdeaEntered();
                setState(() {
                  fetchNum = 0;
                });
              }
              if (number == 2) {
                AnalyticsController.get().userPanelEntered();
              }

              if (number == 0) {
                AnalyticsController.get().shareIdeaEntered();
                setState(() {
                  GlobalController.get().fetchingDailyPosts = true;
                });
                GlobalController.get().checkLastTimestampsAndUpdateCounters(
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
              child: bodyWidget),
        ));
  }
}
