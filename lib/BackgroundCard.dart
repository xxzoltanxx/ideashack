import 'package:flutter/material.dart';
import 'package:hashtagable/hashtagable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Const.dart';

class BackgroundCard extends StatelessWidget {
  BackgroundCard({this.cardData});

  final CardData cardData;

  @override
  Widget build(BuildContext context) {
    if (cardData.isAd) {
      return Container(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: FractionalOffset.bottomLeft,
                end: FractionalOffset.topRight,
                colors: [
                  Color.lerp(
                      bottomLeftStart,
                      bottomLeftEnd,
                      (0.toDouble() / GlobalController.get().MAX_SCORE)
                          .clamp(0.0, 1.0)),
                  Color.lerp(
                      topRightStart,
                      topRightEnd,
                      (0.toDouble() / GlobalController.get().MAX_SCORE)
                          .clamp(0.0, 1.0)),
                ]),
          ),
          child: Center(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 20),
              Text('Thanks for supporting us!'),
              SizedBox(height: 30),
              Text(
                  'Take a break for ${GlobalController.get().adLockTime.toInt()} seconds!'),
              SizedBox(height: 30),
              Flexible(
                  child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: BoxDecoration(color: Colors.black45, boxShadow: [
                    BoxShadow(color: Colors.black45, blurRadius: 20)
                  ]),
                ),
              ))
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
            child: Container(
              decoration: BoxDecoration(
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
                                  Image.asset('assets/score.png', width: 40),
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
                                  decoratedStyle: MAIN_CARD_TEXT_STYLE.copyWith(
                                      color: Colors.blue),
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  FlatButton(
                                    child: Text('Report',
                                        style:
                                            cardThingsBelowTextStyle.copyWith(
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
                                      style: GlobalController.get()
                                                  .canMessage ==
                                              1
                                          ? cardThingsBelowTextStyle
                                          : cardThingsBelowTextStyle.copyWith(
                                              color: Color(0x55894100))),
                                  onTap: null),
                              InkWell(
                                  onTap: null,
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
          );
        });
  }
}
