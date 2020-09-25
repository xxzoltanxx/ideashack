import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'Const.dart';

class BackgroundCard extends StatelessWidget {
  BackgroundCard({this.cardData});
  final CardData cardData;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height -
          0.08 * MediaQuery.of(context).size.height,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Container(
          decoration: BoxDecoration(boxShadow: [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 20.0,
            )
          ]),
          child: Card(
              color: Color.lerp(Color(0xFF68482B), Color(0xFFFFD200),
                  (cardData.score.toDouble() / MAX_SCORE).clamp(0.0, 1.0)),
              child: Center(
                  child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Stack(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Align(
                          alignment: Alignment(0.7, -3),
                          child: Transform.rotate(
                            angle: 170,
                            child: Container(
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                        blurRadius: 9.0, color: Colors.black)
                                  ]),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                    formatedNumberString(cardData.score),
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 30,
                                        color: Color.fromARGB(
                                            200,
                                            cardData.score < 0 ? 170 : 0,
                                            cardData.score >= 0 ? 170 : 0,
                                            0))),
                              ),
                            ),
                          ),
                        ),
                        Text(cardData.text, style: MAIN_CARD_TEXT_STYLE),
                        SizedBox(height: 20),
                        Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text('- ${cardData.author}',
                                  style: AUTHOR_CARD_TEXT_STYLE),
                            ))
                      ],
                    ),
                    Align(
                      alignment: Alignment(-0.4, -0.4),
                      child: Icon(FontAwesomeIcons.solidThumbsUp,
                          size: 50,
                          color: cardData.status == UpvotedStatus.Upvoted
                              ? Color(0xFF00FF00)
                              : Color(0x00000000)),
                    ),
                    Align(
                      alignment: Alignment(0.4, -0.4),
                      child: Icon(FontAwesomeIcons.solidThumbsDown,
                          size: 50,
                          color: cardData.status == UpvotedStatus.Downvoted
                              ? Color(0xFFFF0000)
                              : Color(0x00000000)),
                    ),
                    Align(
                      alignment: Alignment(0.8, 0.8),
                      child: RaisedButton(
                        onPressed: () {},
                        highlightColor: Colors.white,
                        disabledColor: Colors.redAccent,
                        color: Colors.white60,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                          side: BorderSide(color: Colors.red, width: 3),
                        ),
                        child: Icon(FontAwesomeIcons.comments,
                            size: 50, color: Colors.black45),
                      ),
                    )
                  ],
                ),
              ))),
        ),
      ),
    );
  }
}
