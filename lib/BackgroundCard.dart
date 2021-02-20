import 'package:flutter/material.dart';
import 'package:hashtagable/hashtagable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Const.dart';

class BackgroundCard extends StatelessWidget {
  BackgroundCard({this.cardData, this.backgroundScale});

  final double backgroundScale;
  final CardData cardData;

  @override
  Widget build(BuildContext context) {
    if (cardData.isAd) {
      return Transform.scale(
        scale: backgroundScale,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xFFDBDBDB), Color(0xFFFFFFFF)]),
          ),
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
                          child: Center(
                              child: Text('Oh no! An ad!',
                                  style: disabledUpperBarStyle)))),
                ),
              ),
              Text('We are grateful for your support.',
                  style: disabledUpperBarStyle),
              Text('Spark will continue in...', style: enabledUpperBarStyle),
              SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Divider(color: Colors.grey),
              ),
              SizedBox(height: 20),
              Text('${GlobalController.get().adLockTime.toInt()}s',
                  style: enabledUpperBarStyle),
              SizedBox(height: 20),
            ],
          )),
        ),
      );
    }

    return StreamBuilder(
        stream:
            Firestore.instance.collection('posts').doc(cardData.id).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.waiting &&
              snapshot.data != null &&
              snapshot.data.data() != null) {
            cardData.comments = snapshot.data.get('commentsNum');
            cardData.score = snapshot.data.get('score');
          }
          return Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: FractionalOffset.bottomLeft,
                    end: FractionalOffset.topRight,
                    colors: [
                  Color.lerp(
                      Color(0xFF000000),
                      Color.lerp(
                          bottomLeftStart,
                          bottomLeftEnd,
                          (cardData.score.toDouble() /
                                  GlobalController.get().MAX_SCORE)
                              .clamp(0.0, 1.0)),
                      0.9),
                  Color.lerp(
                      Color(0xFF000000),
                      Color.lerp(
                          topRightStart,
                          topRightEnd,
                          (cardData.score.toDouble() /
                                  GlobalController.get().MAX_SCORE)
                              .clamp(0.0, 1.0)),
                      0.8),
                ])),
            child: Transform.scale(
              scale: backgroundScale,
              child: Container(
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 10.0,
                        color: Color.fromARGB(125, 0, 0, 0),
                        offset: Offset(0, 10),
                      )
                    ],
                    gradient: LinearGradient(
                        begin: FractionalOffset.bottomLeft,
                        end: FractionalOffset.topRight,
                        colors: [
                          Color.lerp(
                              bottomLeftStart,
                              bottomLeftEnd,
                              (cardData.score.toDouble() /
                                      GlobalController.get().MAX_SCORE)
                                  .clamp(0.0, 1.0)),
                          Color.lerp(
                              topRightStart,
                              topRightEnd,
                              (cardData.score.toDouble() /
                                      GlobalController.get().MAX_SCORE)
                                  .clamp(0.0, 1.0)),
                        ]),
                  ),
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
                                      Text(cardData.score.toString(),
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
                                          Text(cardData.comments.toString(),
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
                                      onTap: null,
                                      textAlign: TextAlign.center,
                                      text: cardData.text,
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
                                                    fontStyle: FontStyle.italic,
                                                    fontSize: 15)),
                                      )
                                    ],
                                  )
                                ],
                              ),
                            ),
                            SizedBox(height: 20),
                            Padding(
                              padding: const EdgeInsets.all(0),
                              child: Divider(
                                color: cardThingsTextStyle.color,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                RaisedButton(
                                  color: Colors.transparent,
                                  disabledColor: Colors.transparent,
                                  disabledElevation: 0,
                                  onPressed: null,
                                  child: Text('Message',
                                      style: ((GlobalController.get()
                                                      .canMessage ==
                                                  1) &&
                                              (cardData.posterId !=
                                                  GlobalController.get()
                                                      .currentUserUid))
                                          ? cardThingsBelowTextStyle
                                          : cardThingsBelowTextStyle.copyWith(
                                              color: Color(0x55894100))),
                                ),
                                RaisedButton(
                                    color: Colors.transparent,
                                    disabledColor: Colors.transparent,
                                    disabledElevation: 0,
                                    onPressed: null,
                                    child: Text('Comment',
                                        style: cardThingsBelowTextStyle,
                                        textAlign: TextAlign.center)),
                                RaisedButton(
                                    color: Colors.transparent,
                                    disabledColor: Colors.transparent,
                                    disabledElevation: 0,
                                    onPressed: null,
                                    child: Text('Share',
                                        style: cardThingsBelowTextStyle))
                              ],
                            )
                          ],
                        ),
                        Align(
                          alignment: Alignment(-0.4, -0.9),
                          child: Image.asset('assets/upvoted.png',
                              width: 200,
                              color: cardData.status == UpvotedStatus.Upvoted
                                  ? Color(0x80FFFFFF)
                                  : Color(0x00000000)),
                        ),
                        Align(
                          alignment: Alignment(0.4, -0.9),
                          child: Image.asset('assets/downvoted.png',
                              width: 200,
                              color: cardData.status == UpvotedStatus.Downvoted
                                  ? Color(0x80FFFFFF)
                                  : Color(0x00000000)),
                        )
                      ],
                    ),
                  )),
                ),
              ),
            ),
          );
        });
  }
}
