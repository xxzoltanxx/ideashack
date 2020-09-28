import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'Const.dart';

class BackgroundCard extends StatelessWidget {
  BackgroundCard({this.cardData});

  final CardData cardData;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: FractionalOffset.bottomLeft,
              end: FractionalOffset.topRight,
              colors: [
                Color.lerp(bottomLeftStart, bottomLeftEnd,
                    (cardData.score.toDouble() / MAX_SCORE).clamp(0.0, 1.0)),
                Color.lerp(topRightStart, topRightEnd,
                    (cardData.score.toDouble() / MAX_SCORE).clamp(0.0, 1.0)),
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
                        padding: const EdgeInsets.only(left: cardthingspadding),
                        child: Row(
                          children: [
                            Icon(Icons.thumb_up,
                                color: cardThingsTextStyle.color, size: 30),
                            SizedBox(width: 10),
                            Text(cardData.score.toString(),
                                style: cardThingsTextStyle),
                          ],
                        ),
                      ),
                      Expanded(child: Container()),
                      Padding(
                        padding:
                            const EdgeInsets.only(right: cardthingspadding),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.comment,
                                    color: cardThingsTextStyle.color, size: 30),
                                SizedBox(width: 10),
                                Text(cardData.comments.length.toString(),
                                    style: cardThingsTextStyle),
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                      child: Center(
                    child: Text(cardData.text,
                        style: MAIN_CARD_TEXT_STYLE,
                        textAlign: TextAlign.center),
                  )),
                  SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.all(cardthingspadding),
                    child: Divider(
                      color: cardThingsTextStyle.color,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                        left: cardthingspadding, right: cardthingspadding),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                            child: Text('Message',
                                style: cardThingsBelowTextStyle),
                            onTap: null),
                        InkWell(
                            onTap: null,
                            child: Text('Comment',
                                style: cardThingsBelowTextStyle)),
                        InkWell(
                            child:
                                Text('Share', style: cardThingsBelowTextStyle))
                      ],
                    ),
                  )
                ],
              ),
              Align(
                alignment: Alignment(-0.4, -0.9),
                child: Icon(Icons.person,
                    size: 100,
                    color: cardData.status == UpvotedStatus.Upvoted
                        ? Color(0x80FFFFFF)
                        : Color(0x00000000)),
              ),
              Align(
                alignment: Alignment(0.4, -0.9),
                child: Icon(Icons.pool,
                    size: 100,
                    color: cardData.status == UpvotedStatus.Downvoted
                        ? Color(0x80FFFFFF)
                        : Color(0x00000000)),
              )
            ],
          ),
        )),
      ),
    );
  }
}
