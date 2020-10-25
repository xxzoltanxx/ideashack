import 'package:flutter/material.dart';
import 'package:ideashack/Const.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'CardList.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'RegistrationScreen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:ideashack/MainScreenMisc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ideashack/FeedOverlay.dart';
import 'Analytics.dart';
import 'package:share/share.dart';
import 'package:hashtagable/hashtagable.dart';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class UserCard extends StatefulWidget {
  UserCard(this.modalFunction);
  final Function modalFunction;
  @override
  _UserCardState createState() => _UserCardState();
}

class _UserCardState extends State<UserCard> {
  GoogleSignIn googleSignIn = GoogleSignIn();
  List<Widget> ideas = [];
  bool fetched = true;
  GoogleSignInAccount account;
  User user;
  bool signingOut = false;

  @override
  void initState() {
    fetched = false;
    if (!GlobalController.get().currentUser.isAnonymous) {
      CardList.get().getUserCardsData(lambda: onCompleteFetch);
    }
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void onCompleteFetch() {
    ideas.clear();
    setState(() {
      fetched = true;
      for (CardData data in CardList.get().userCardsData) {
        ideas.add(IdeaUserCard(
            cardData: data,
            modalFunction: widget.modalFunction,
            deleteCallback: cardCallback));
      }
    });
  }

  void deleteAccount() async {
    await Firestore.instance
        .collection('users')
        .doc(GlobalController.get().userDocId)
        .update({'isScheduledForDeletion': 1});
    Navigator.pop(context);
    Navigator.pushNamed(context, '/auth');
  }

  void deleteAccountCallback() {
    setState(() {
      signingOut = true;
    });
    deleteAccount();
  }

  void cardCallback() {
    setState(() {
      fetched = false;
      ideas.clear();
      if (!GlobalController.get().currentUser.isAnonymous) {
        CardList.get().getUserCardsData(lambda: onCompleteFetch);
      }
    });
  }

  void signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pop(context);
    Navigator.pushNamed(context, '/auth');
  }

  void signOutButtonCallback() {
    setState(() {
      signingOut = true;
    });
    signOut();
  }

  @override
  Widget build(BuildContext context) {
    Widget widgetToEmbed;

    if (signingOut) {
      widgetToEmbed =
          Center(child: Text('Signing out...', style: disabledUpperBarStyle));
    } else if (GlobalController.get().currentUser.isAnonymous) {
      widgetToEmbed = Center(
          child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: FutureBuilder(
          builder: (context, snapshot) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: Text(
                    'Sign in to like/dislike ideas, post comments, post ideas, and more!',
                    style: disabledUpperBarStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 200,
                    height: 50,
                    child: RaisedButton(
                        onPressed: () {
                          AnalyticsController.get().userPanelRegisterTapped();
                          Navigator.pushReplacement(context,
                              MaterialPageRoute(builder: (context) {
                            return RegistrationScreen(
                              doSignInWithGoogle: true,
                            );
                          }));
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
                )
              ],
            );
          },
        ),
      ));
    } else if (ideas.length != 0) {
      widgetToEmbed = ListView(children: ideas);
    } else if (fetched) {
      widgetToEmbed = Center(
          child: Text('You have no ideas on display!',
              style: disabledUpperBarStyle));
    } else {
      widgetToEmbed = Container(
          child: Center(
              child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/logo.png', width: 200),
          SizedBox(height: 30),
          SpinKitThreeBounce(
            color: secondarySpinnerColor,
            size: 60,
          ),
        ],
      )));
    }

    return SafeArea(
        child: Container(
            decoration: BoxDecoration(color: Colors.white),
            child: Column(
              children: [
                Container(
                    height: 180,
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: splashScreenColors,
                            begin: Alignment.bottomLeft,
                            end: Alignment.topRight)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset('assets/userpanel.png', width: 70),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('User panel',
                                  style: enabledUpperBarStyle.copyWith(
                                      color: Colors.white, fontSize: 30)),
                            ],
                          ),
                          SizedBox(height: 20),
                          GlobalController.get().currentUser.isAnonymous
                              ? SizedBox()
                              : Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        signOutButtonCallback();
                                      },
                                      child: Text('Log out',
                                          style: disabledUpperBarStyle.copyWith(
                                              color: Colors.white,
                                              fontSize: 15)),
                                    ),
                                    InkWell(
                                      onTap: deleteAccountCallback,
                                      child: Text('Delete account',
                                          style: disabledUpperBarStyle.copyWith(
                                              color: Colors.white,
                                              fontSize: 15)),
                                    ),
                                  ],
                                ),
                          Divider(color: Colors.white)
                        ],
                      ),
                    )),
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text('Your Ideas',
                                style: enabledUpperBarStyle.copyWith(
                                    color: disabledUpperBarColor,
                                    fontSize: 20)),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      Expanded(flex: 5, child: widgetToEmbed),
                    ],
                  ),
                ),
              ],
            )));
  }
}

class IdeaUserCard extends StatelessWidget {
  IdeaUserCard({this.cardData, this.modalFunction, this.deleteCallback}) {
    DateTime time =
        DateTime.fromMillisecondsSinceEpoch((cardData.time * 1000).toInt());
    date = '${time.day}.${time.month}.${time.year}';
  }
  Function deleteCallback;
  Function modalFunction;
  CardData cardData;
  String date;

  Future<void> deleteAsync() async {
    await Firestore.instance
        .collection('posts')
        .doc(cardData.id)
        .update({'hidden': 1});
  }

  @override
  void deleteIdea(BuildContext context) {
    showDialog(
        context: context,
        builder: (_) => DeleteIdeaPopup(deleteAsync(), deleteCallback));
  }

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
                            text: cardData.text,
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
  }

  Widget build(BuildContext context) {
    return Container(
        child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Posted on: ' + date,
                    style: disabledUpperBarStyle.copyWith(
                        fontStyle: FontStyle.italic, fontSize: 10)),
                Row(
                  children: [
                    Image.asset('assets/score.png',
                        height: 20, color: Colors.grey),
                    Text(formatedNumberString(cardData.score),
                        style: enabledUpperBarStyle.copyWith(
                            color: Colors.grey, fontSize: 15)),
                    SizedBox(width: 5),
                    InkWell(
                        onTap: () {
                          AnalyticsController.get()
                              .viewCommentsTapped(cardData.id);
                          Navigator.pushNamed(context, '/comments',
                              arguments: <dynamic>[cardData, modalFunction]);
                        },
                        child: CommentsOverlay(cardData.id)),
                  ],
                ),
              ]),
              SizedBox(height: 20),
              Text(cardData.text, style: disabledUpperBarStyle),
              SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                InkWell(
                    onTap: () {
                      AnalyticsController.get().deleteIdeaTapped(cardData.id);
                      deleteIdea(context);
                    },
                    child: Text('Delete Idea', style: disabledUpperBarStyle)),
                SizedBox(width: 20),
                InkWell(
                    onTap: () {
                      shareCardData();
                    },
                    child: Text('Share', style: disabledUpperBarStyle))
              ]),
              SizedBox(height: 20),
            ],
          ),
        ),
        Divider(color: Colors.grey),
        SizedBox(height: 20),
      ],
    ));
  }
}
