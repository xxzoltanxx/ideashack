import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'Const.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:async';
import 'CardList.dart';

class RegistrationScreen extends StatefulWidget {
  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  Future<FirebaseApp> firebaseFuture;

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
            return Scaffold(body: SomethingWentWrong());
          }
          // Once complete, show your application
          if (snapshot.connectionState == ConnectionState.done) {
            var _auth = FirebaseAuth.instance;
            CardList.get().setInstance(Firestore.instance);
            return Scaffold(body: LoginScreen(_auth));
          }
          return Scaffold(body: Loading());
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
  bool loggingInWithGoogle = false;
  bool failedLogin = false;
  bool checkingForSignIn = false;
  bool readyForSignIn = false;
  bool finishWithBuild = false;
  User user;

  Future<void> checkOrSetupNewUser(User user) async {
    QuerySnapshot possibleUser = await Firestore.instance
        .collection('users')
        .where('uid', isEqualTo: user.uid)
        .get();
    if (possibleUser.docs.length > 0) {
      return;
    }
    var timestamp = await getCurrentTimestampServer();
    await Firestore.instance.collection('users').add({
      'dailyPosts': BASE_DAILY_POSTS,
      'lastSeen': timestamp,
      'uid': user.uid
    });
  }

  Future<void> checkForSignIn() async {
    checkingForSignIn = true;
    var signedIn = await googleSignIn.isSignedIn();
    if (!signedIn) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        setState(() {
          checkingForSignIn = false;
        });
      });
    } else {
      try {
        WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {
              loggingInWithGoogle = true;
            }));

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
        await checkOrSetupNewUser(currentUser);
        WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {
              readyForSignIn = true;
            }));
        WidgetsBinding.instance.addPostFrameCallback((duration) =>
            Navigator.popAndPushNamed(context, '/main', arguments: user));
      } catch (e) {
        print(e);
        checkingForSignIn = false;
        failedLogin = true;
        loggingInWithGoogle = false;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    var future = checkForSignIn();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (readyForSignIn) {
      return Container(child: Center(child: Text('You\'re logged in!')));
    }
    if (checkingForSignIn) {
      return Container(
          child: Center(
        child: SpinKitFadingCircle(size: 100, color: Colors.white),
      ));
    }
    if (failedLogin) {
      return Container(
          child: Center(
              child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FontAwesomeIcons.solidLightbulb,
              size: 100, color: Colors.white60),
          SizedBox(height: 50),
          TypewriterAnimatedTextKit(
            text: ['Spark'],
            repeatForever: true,
            textStyle: SPLASH_TEXT_STYLE,
            speed: Duration(seconds: 1),
          ),
          SizedBox(height: 80),
          Container(
            width: 200,
            height: 70,
            child: RaisedButton(
                onPressed: loggingInWithGoogle
                    ? null
                    : () async {
                        try {
                          setState(() {
                            loggingInWithGoogle = true;
                          });
                          account = await googleSignIn.signInSilently(
                              suppressErrors: false);
                          GoogleSignInAuthentication
                              googleSignInAuthentication =
                              await account.authentication;

                          AuthCredential credential =
                              GoogleAuthProvider.credential(
                            accessToken: googleSignInAuthentication.accessToken,
                            idToken: googleSignInAuthentication.idToken,
                          );
                          UserCredential authResult = await widget.auth
                              .signInWithCredential(credential);
                          user = authResult.user;

                          if (user != null) assert(!user.isAnonymous);
                          assert(await user.getIdToken() != null);

                          User currentUser = widget.auth.currentUser;
                          assert(user.uid == currentUser.uid);
                          GlobalController.get().currentUserUid = user.uid;
                          await checkOrSetupNewUser(currentUser);
                          Navigator.popAndPushNamed(context, '/main',
                              arguments: user);
                        } catch (e) {
                          setState(() {
                            failedLogin = true;
                            loggingInWithGoogle = false;
                          });
                        }
                      },
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
          Text('Failed to login, try again!', style: AUTHOR_CARD_TEXT_STYLE)
        ],
      )));
    } else {
      return Container(
          child: Center(
              child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FontAwesomeIcons.solidLightbulb,
              size: 100, color: Colors.white60),
          SizedBox(height: 50),
          TypewriterAnimatedTextKit(
            text: ['Spark'],
            repeatForever: true,
            textStyle: SPLASH_TEXT_STYLE,
            speed: Duration(seconds: 1),
          ),
          SizedBox(height: 80),
          Container(
            width: 200,
            height: 70,
            child: RaisedButton(
                onPressed: loggingInWithGoogle
                    ? null
                    : () async {
                        try {
                          setState(() {
                            loggingInWithGoogle = true;
                          });
                          account = await googleSignIn.signIn();
                          GoogleSignInAuthentication
                              googleSignInAuthentication =
                              await account.authentication;

                          AuthCredential credential =
                              GoogleAuthProvider.credential(
                            accessToken: googleSignInAuthentication.accessToken,
                            idToken: googleSignInAuthentication.idToken,
                          );
                          UserCredential authResult = await widget.auth
                              .signInWithCredential(credential);
                          user = authResult.user;

                          if (user != null) assert(!user.isAnonymous);
                          assert(await user.getIdToken() != null);

                          User currentUser = widget.auth.currentUser;
                          assert(user.uid == currentUser.uid);
                          GlobalController.get().currentUserUid = user.uid;
                          await checkOrSetupNewUser(currentUser);
                          Navigator.popAndPushNamed(context, '/main',
                              arguments: user);
                        } catch (e) {
                          setState(() {
                            failedLogin = true;
                            loggingInWithGoogle = false;
                          });
                        }
                      },
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
