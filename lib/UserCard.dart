import 'package:flutter/material.dart';
import 'package:ideashack/Const.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'CardList.dart';
import 'CardInfo.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'RegistrationScreen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
        ideas.add(CardInfo(data, widget.modalFunction));
        ideas.add(Padding(
          padding: const EdgeInsets.only(left: 40.0, right: 40.0),
          child: Divider(
            color: Colors.red,
          ),
        ));
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
              style: AUTHOR_CARD_TEXT_STYLE));
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
            child: Column(
      children: [
        Expanded(
          flex: 1,
          child: Container(
              child: Center(
                  child: Text('Your Ideas', style: MAIN_CARD_TEXT_STYLE))),
        ),
        Expanded(flex: 5, child: widgetToEmbed),
      ],
    )));
  }
}
