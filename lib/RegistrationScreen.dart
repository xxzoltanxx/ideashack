import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'Const.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:async';
import 'CardList.dart';
import 'package:social_share/social_share.dart';
import 'Analytics.dart';

class RegistrationScreen extends StatefulWidget {
  RegistrationScreen({this.doSignInWithGoogle = false});
  bool doSignInWithGoogle;
  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var _auth = FirebaseAuth.instance;
    CardList.get().setInstance(Firestore.instance);
    return Scaffold(
        body: Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: splashScreenColors,
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight)),
            child: LoginScreen(_auth, widget.doSignInWithGoogle)));
  }
}

class LoginScreen extends StatefulWidget {
  LoginScreen(this.auth, this.doSignInWithGoogle);
  bool doSignInWithGoogle;
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

  void signInButtonSecondary() {
    setState(() {
      initialFuture = checkForSignIn();
    });
  }

  Future<void> checkOrSetupNewUser(User user) async {
    try {
      SocialShare.checkInstalledAppsForShare();
      QuerySnapshot parametersArray =
          await Firestore.instance.collection('parameters').get();
      GlobalController.get().parameters = parametersArray.docs[0];
      QuerySnapshot maxScore = await Firestore.instance
          .collection('posts')
          .orderBy('score', descending: true)
          .limit(1)
          .get();
      if (maxScore.docs != null && maxScore.docs.length > 0) {
        GlobalController.get().MAX_SCORE = maxScore.docs[0].get('score');
      }

      GlobalController.get().initParameters();
      QuerySnapshot possibleUser;

      var pushToken;
      if (!user.isAnonymous) {
        possibleUser = await Firestore.instance
            .collection('users')
            .where('uid', isEqualTo: user.uid)
            .get(GetOptions(source: Source.server));
        pushToken = await GlobalController.get().fetchPushToken();
      }
      var timestamp = await getCurrentTimestampServer();
      GlobalController.get().timeOnStartup = timestamp;
      if (!user.isAnonymous &&
          possibleUser.docs != null &&
          possibleUser.docs.length > 0) {
        print(possibleUser.docs);
        String docId = possibleUser.docs[0].id;
        await Firestore.instance
            .collection('users')
            .doc(docId)
            .update({'uid': user.uid, 'pushToken': pushToken});
        GlobalController.get().userDocId = docId;
        return;
      }
      print("REACHED HERE");
      if (!user.isAnonymous) {
        var snapshot = await Firestore.instance.collection('users').add({
          'dailyPosts': BASE_DAILY_POSTS,
          'lastSeen': timestamp,
          'uid': user.uid,
          'pushToken': pushToken,
          'upvoted': [],
          'downvoted': [],
          'commented': [],
          'reportedPosts': [],
          'canInitializeMessage': 1
        });
        GlobalController.get().userDocId = snapshot.id;
      }
      AnalyticsController.get().logInCompletedEvent();
    } catch (e) {
      throw e;
    }
  }

  Future<void> checkForSignIn() async {
    var signedIn = widget.auth.currentUser != null;
    if (!signedIn) {
      {
        try {
          UserCredential creds = await widget.auth.signInAnonymously();
          user = creds.user;

          assert(await user.getIdToken() != null);

          User currentUser = widget.auth.currentUser;
          assert(user.uid == currentUser.uid);
          GlobalController.get().currentUserUid = user.uid;
          GlobalController.get().currentUser = user;
          AnalyticsController.get().setUserId();
          await checkOrSetupNewUser(currentUser);
        } catch (e) {
          print(e);
          return Future.error("COULDN'T LOG IN");
        }
      }
    } else {
      try {
        user = widget.auth.currentUser;

        assert(await user.getIdToken() != null);

        User currentUser = widget.auth.currentUser;
        assert(user.uid == currentUser.uid);
        GlobalController.get().currentUserUid = user.uid;
        GlobalController.get().currentUser = user;
        AnalyticsController.get().setUserId();
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
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.currentUser.delete();
        await FirebaseAuth.instance.signOut();
      }
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
      AnalyticsController.get().userRegistered();
      AnalyticsController.get().setUserId();
      await checkOrSetupNewUser(currentUser);
    } catch (e) {
      return Future.error("FAILED TO SIGN IN CONVENTIONALLY!");
    }
  }

  @override
  void initState() {
    if (!widget.doSignInWithGoogle) {
      AnalyticsController.get().logAppLaunched();
      initialFuture = checkForSignIn();
    }
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.doSignInWithGoogle) {
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
                  SizedBox(height: 40),
                  FadeAnimatedTextKit(
                      text: splashScreenText,
                      repeatForever: true,
                      textStyle: (TextStyle(fontWeight: FontWeight.bold))),
                  SizedBox(height: 40),
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
                  SizedBox(height: 40),
                  FadeAnimatedTextKit(
                      text: splashScreenText,
                      repeatForever: true,
                      textStyle: (TextStyle(fontWeight: FontWeight.bold))),
                  SizedBox(height: 40),
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

    return FutureBuilder(
        // Initialize FlutterFire
        future: initialFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active ||
              snapshot.connectionState == ConnectionState.waiting) {
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
          // Check for errors
          if (snapshot.hasError) {
            return Container(
                child: Center(
                    child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: Image.asset('assets/logo.png')),
                SizedBox(height: 40),
                FadeAnimatedTextKit(
                    text: splashScreenText,
                    repeatForever: true,
                    textStyle: (TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(height: 40),
                Text('Something went wrong',
                    style: TextStyle(
                        color: Colors.red, fontStyle: FontStyle.italic)),
                SizedBox(height: 40),
                Container(
                  width: 200,
                  height: 70,
                  child: RaisedButton(
                      onPressed: signInButtonSecondary,
                      color: Colors.white,
                      child: Center(
                          child: Text('Try again', style: LOGINTEXTSTYLE))),
                ),
              ],
            )));
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
  SomethingWentWrong(this.callback);
  final Function callback;
  @override
  Widget build(BuildContext context) {
    return Container(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(child: Text('Could not connect to server...')),
        SizedBox(height: 20),
        RaisedButton(child: Text('TRY AGAIN'), onPressed: callback),
      ],
    ));
  }
}

class Loading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
}
