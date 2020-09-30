import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'Const.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:async';
import 'CardList.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class RegistrationScreen extends StatefulWidget {
  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  Future<FirebaseApp> firebaseFuture;

  void initFirebaseMessaging() {
    FirebaseMessaging _firebaseMessaging =
        GlobalController.get().firebaseMessaging;
    _firebaseMessaging.configure(
      onMessage: (Map<String, dynamic> message) async {
        print("onMessage: $message");
      },
      onBackgroundMessage: myBackgroundMessageHandler,
      onLaunch: (Map<String, dynamic> message) async {
        print("onLaunch: $message");
      },
      onResume: (Map<String, dynamic> message) async {
        print("onResume: $message");
      },
    );
  }

  @override
  void initState() {
    firebaseFuture = Firebase.initializeApp();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        // Initialize FlutterFire
        future: firebaseFuture,
        builder: (context, snapshot) {
          // Check for errors
          if (snapshot.hasError) {
            return Scaffold(
                body: Container(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: splashScreenColors,
                            begin: Alignment.bottomLeft,
                            end: Alignment.topRight)),
                    child: SomethingWentWrong()));
          }
          // Once complete, show your application
          if (snapshot.connectionState == ConnectionState.done) {
            var _auth = FirebaseAuth.instance;
            CardList.get().setInstance(Firestore.instance);
            initFirebaseMessaging();
            return Scaffold(
                body: Container(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: splashScreenColors,
                            begin: Alignment.bottomLeft,
                            end: Alignment.topRight)),
                    child: LoginScreen(_auth)));
          }
          return Scaffold(
              body: SafeArea(
            child: Container(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: splashScreenColors,
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight)),
                child: Loading()),
          ));
        }

        // Otherwise, show something whilst waiting for initialization to complete
        );
  }
}

class LoginScreen extends StatefulWidget {
  LoginScreen(this.auth);
  final FirebaseAuth auth;

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  GoogleSignIn googleSignIn = GoogleSignIn();
  GoogleSignInAccount account;
  User user;
  Future<void> initialFuture;
  Future<void> secondaryFuture;

  Future<void> checkOrSetupNewUser(User user) async {
    QuerySnapshot parametersArray =
        await Firestore.instance.collection('parameters').get();
    GlobalController.get().parameters = parametersArray.docs[0];
    QuerySnapshot maxScore = await Firestore.instance
        .collection('posts')
        .orderBy('score', descending: true)
        .limit(1)
        .get();
    if (maxScore.docs.length > 0) {
      GlobalController.get().MAX_SCORE = maxScore.docs[0].get('score');
    }

    GlobalController.get().initParameters();
    QuerySnapshot possibleUser = await Firestore.instance
        .collection('users')
        .where('uid', isEqualTo: user.uid)
        .get();

    var timestamp = await getCurrentTimestampServer();
    GlobalController.get().timeOnStartup = timestamp;
    var pushToken = await GlobalController.get().fetchPushToken();
    if (possibleUser.docs.length > 0) {
      String docId = possibleUser.docs[0].id;
      await Firestore.instance.collection('users').doc(docId).update(
          {'lastSeen': timestamp, 'uid': user.uid, 'pushToken': pushToken});
      GlobalController.get().userDocId = docId;
      return;
    }
    var snapshot = await Firestore.instance.collection('users').add({
      'dailyPosts': BASE_DAILY_POSTS,
      'lastSeen': timestamp,
      'uid': user.uid,
      'pushToken': pushToken,
      'upvoted': [],
      'downvoted': [],
      'commented': [],
    });
    GlobalController.get().userDocId = snapshot.id;
  }

  Future<void> checkForSignIn() async {
    var signedIn = await googleSignIn.isSignedIn();
    if (!signedIn) {
      return Future.error("NOT SIGNED IN");
    } else {
      try {
        account = await googleSignIn.signIn();
        GoogleSignInAuthentication googleSignInAuthentication =
            await account.authentication;

        AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleSignInAuthentication.accessToken,
          idToken: googleSignInAuthentication.idToken,
        );
        UserCredential authResult =
            await widget.auth.signInWithCredential(credential);
        user = authResult.user;

        if (user != null) assert(!user.isAnonymous);
        assert(await user.getIdToken() != null);

        User currentUser = widget.auth.currentUser;
        assert(user.uid == currentUser.uid);
        GlobalController.get().currentUserUid = user.uid;
        GlobalController.get().currentUser = user;
        await checkOrSetupNewUser(currentUser);
      } catch (e) {
        print(e);
        return Future.error("COULDN'T LOG IN");
      }
    }
  }

  void signInButtonCallback() {
    setState(() {
      secondaryFuture = signIn();
    });
  }

  Future<void> signIn() async {
    try {
      account = await googleSignIn.signIn();
      GoogleSignInAuthentication googleSignInAuthentication =
          await account.authentication;

      AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleSignInAuthentication.accessToken,
        idToken: googleSignInAuthentication.idToken,
      );
      UserCredential authResult =
          await widget.auth.signInWithCredential(credential);
      user = authResult.user;

      if (user != null) assert(!user.isAnonymous);
      assert(await user.getIdToken() != null);

      User currentUser = widget.auth.currentUser;
      assert(user.uid == currentUser.uid);
      GlobalController.get().currentUserUid = user.uid;
      GlobalController.get().currentUser = user;
      await checkOrSetupNewUser(currentUser);
    } catch (e) {
      return Future.error("FAILED TO SIGN IN CONVENTIONALLY!");
    }
  }

  @override
  void initState() {
    super.initState();
    initialFuture = checkForSignIn();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        // Initialize FlutterFire
        future: initialFuture,
        builder: (context, snapshot) {
          // Check for errors
          if (snapshot.hasError) {
            return FutureBuilder(
                future: secondaryFuture,
                builder: (context, snapshot) {
                  print("INNER BUILDER");
                  if (snapshot.connectionState == ConnectionState.none) {
                    return Container(
                        child: Center(
                            child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(child: Image.asset('assets/logo.png')),
                        SizedBox(height: 80),
                        Container(
                          width: 200,
                          height: 70,
                          child: RaisedButton(
                              onPressed: signInButtonCallback,
                              color: Colors.white,
                              child: Row(
                                children: [
                                  Icon(
                                    FontAwesomeIcons.googlePlusSquare,
                                    color: Colors.black,
                                  ),
                                  SizedBox(width: 20),
                                  Text('Google login', style: LOGINTEXTSTYLE)
                                ],
                              )),
                        ),
                      ],
                    )));
                  }
                  if (snapshot.connectionState == ConnectionState.active ||
                      snapshot.connectionState == ConnectionState.waiting) {
                    print("ONGOING");
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
                  }
                  if (snapshot.hasError) {
                    print("SNAPSHOT ERROR");
                    return Container(
                        child: Center(
                            child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(child: Image.asset('assets/logo.png')),
                        SizedBox(height: 80),
                        Container(
                          width: 200,
                          height: 70,
                          child: RaisedButton(
                              onPressed: signInButtonCallback,
                              color: Colors.white,
                              child: Row(
                                children: [
                                  Icon(
                                    FontAwesomeIcons.googlePlusSquare,
                                    color: Colors.black,
                                  ),
                                  SizedBox(width: 20),
                                  Text('Google login', style: LOGINTEXTSTYLE)
                                ],
                              )),
                        ),
                        SizedBox(height: 20),
                        Text("Failed to sign in, try again!"),
                      ],
                    )));
                  }
                  if (snapshot.connectionState == ConnectionState.done) {
                    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                      WidgetsBinding.instance.addPostFrameCallback((duration) =>
                          Navigator.popAndPushNamed(context, '/main',
                              arguments: user));
                    });
                    return Container(
                        child: Center(child: Text('You\'re logged in!')));
                  }
                  print("REACHED HERE");
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
                });
          }
          // Once complete, show your application
          if (snapshot.connectionState == ConnectionState.done) {
            WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
              WidgetsBinding.instance.addPostFrameCallback((duration) =>
                  Navigator.popAndPushNamed(context, '/main', arguments: user));
            });
            return Container(child: Center(child: Text('You\'re logged in!')));
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
        });
  }
}

class SomethingWentWrong extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        child: Center(child: Text('Could not connect to server...')));
  }
}

class Loading extends StatefulWidget {
  @override
  _LoadingState createState() => _LoadingState();
}

class _LoadingState extends State<Loading> with SingleTickerProviderStateMixin {
  AnimationController _controller;
  Animation _animation;
  double _size = 50;
  double _angleSum = 0;

  @override
  void initState() {
    _controller = new AnimationController(
        vsync: this, duration: Duration(milliseconds: 500));
    _controller.repeat(min: 0.0, max: 1.0);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.bounceIn);
    _controller.addListener(() {
      setState(() {
        _angleSum += _controller.value * 50;
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        child: Center(
            child: Transform.rotate(
      angle: _angleSum,
      child: Icon(FontAwesomeIcons.lightbulb, size: _size * _animation.value),
    )));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
