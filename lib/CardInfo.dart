import 'package:flutter/material.dart';
import 'package:ideashack/Const.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'DMList.dart';

class CardInfo extends StatefulWidget {
  CardInfo(this.cardData, this.modalCallback);
  final CardData cardData;
  final Function modalCallback;

  @override
  _CardInfoState createState() => _CardInfoState();
}

class _CardInfoState extends State<CardInfo> {
  CardData cardData;
  @override
  void initState() {
    cardData = widget.cardData;
    super.initState();
  }

  void callback(CardData data, profane) {
    cardData = data;
    widget.modalCallback(profane);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        child: Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
              child: Text(widget.cardData.text, style: AUTHOR_CARD_TEXT_STYLE)),
          Container(
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [BoxShadow(blurRadius: 9.0, color: Colors.black)]),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(formatedNumberString(widget.cardData.score),
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 30,
                      color: Color.fromARGB(
                          200,
                          widget.cardData.score < 0 ? 170 : 0,
                          widget.cardData.score >= 0 ? 170 : 0,
                          0))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: RaisedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/comments',
                    arguments: <dynamic>[widget.cardData, callback]);
              },
              highlightColor: Colors.white,
              disabledColor: Colors.redAccent,
              color: Colors.white60,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
                side: BorderSide(color: Colors.red, width: 3),
              ),
              child: Icon(FontAwesomeIcons.comments,
                  size: 20, color: Colors.black45),
            ),
          ),
        ],
      ),
    ));
  }
}
