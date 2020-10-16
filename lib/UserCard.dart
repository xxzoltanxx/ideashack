import 'package:flutter/material.dart';
import 'package:ideashack/Const.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'CardList.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'RegistrationScreen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:ideashack/MainScreenMisc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ideashack/FeedOverlay.dart';
import 'Analytics.dart';

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

  void cardCallback() {
    setState(() {
      fetched = false;
      ideas.clear();
      if (!GlobalController.get().currentUser.isAnonymous) {
        CardList.get().getUserCardsData(lambda: onCompleteFetch);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget widgetToEmbed;
    if (GlobalController.get().currentUser.isAnonymous) {
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
                SizedBox(height: 50),
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
            color: spinnerColor,
            size: 60,
          ),
        ],
      )));
    }

    return SafeArea(
        child: Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(
              colors: [Color(0xFFDBDBDB), Color(0xFFFFFFFF)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            )),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/userpanel.png', width: 100),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('User panel',
                          style: enabledUpperBarStyle.copyWith(
                              color: disabledUpperBarColor, fontSize: 30)),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Delete account',
                          style: disabledUpperBarStyle.copyWith(fontSize: 15)),
                    ],
                  ),
                  Divider(color: disabledUpperBarColor),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text('Your Ideas',
                          style: enabledUpperBarStyle.copyWith(
                              color: disabledUpperBarColor, fontSize: 20)),
                    ],
                  ),
                  SizedBox(height: 10),
                  Divider(color: disabledUpperBarColor),
                  Expanded(flex: 5, child: widgetToEmbed),
                ],
              ),
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

  Widget build(BuildContext context) {
    return Container(
        child: Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Posted on: ' + date,
              style: disabledUpperBarStyle.copyWith(
                  fontStyle: FontStyle.italic, fontSize: 10)),
          Row(
            children: [
              Image.asset('assets/score.png', height: 40, color: Colors.grey),
              SizedBox(width: 10),
              Text(cardData.score.toString(),
                  style: enabledUpperBarStyle.copyWith(
                      color: Colors.grey, fontSize: 25)),
              SizedBox(width: 30),
              Image.asset('assets/comments.png',
                  height: 40, color: Colors.grey),
              SizedBox(width: 10),
              Text(cardData.comments.toString(),
                  style: enabledUpperBarStyle.copyWith(
                      color: Colors.grey, fontSize: 25)),
              CommentsOverlay(cardData.id),
            ],
          ),
        ]),
        SizedBox(height: 20),
        Text(cardData.text, style: disabledUpperBarStyle),
        SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          InkWell(
              onTap: () {
                AnalyticsController.get().deleteIdeaTapped(cardData.id);
                deleteIdea(context);
              },
              child: Text('Delete Idea',
                  style: disabledUpperBarStyle.copyWith(
                      fontWeight: FontWeight.bold))),
          InkWell(
              onTap: () {
                AnalyticsController.get().viewCommentsTapped(cardData.id);
                Navigator.pushNamed(context, '/comments',
                    arguments: <dynamic>[cardData, modalFunction]);
              },
              child: Text('View Comments',
                  style: disabledUpperBarStyle.copyWith(
                      fontWeight: FontWeight.bold)))
        ]),
        SizedBox(height: 20),
        DottedLine(dashColor: disabledUpperBarColor),
        SizedBox(height: 20),
      ],
    ));
  }
}
