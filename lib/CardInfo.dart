import 'package:flutter/material.dart';
import 'package:ideashack/Const.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CardInfo extends StatelessWidget {
  CardInfo(this.cardData, this.modalCallback);
  CardData cardData;
  Function modalCallback;

  void callback(CardData data) {
    cardData = data;
    modalCallback();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        child: Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: Text(cardData.text, style: AUTHOR_CARD_TEXT_STYLE)),
          Container(
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [BoxShadow(blurRadius: 9.0, color: Colors.black)]),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(formatedNumberString(cardData.score),
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 30,
                      color: Color.fromARGB(200, cardData.score < 0 ? 170 : 0,
                          cardData.score >= 0 ? 170 : 0, 0))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: RaisedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/comments',
                    arguments: <dynamic>[cardData, callback]);
              },
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
    ));
  }
}
