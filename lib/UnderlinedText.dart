import 'package:flutter/material.dart';

class UnderlinedText extends StatelessWidget {
  UnderlinedText({@required this.text, @required this.overline});
  final String text;
  final bool overline;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: 3, // space between underline and text
      ),
      decoration: BoxDecoration(
          border: overline
              ? Border(
                  bottom: BorderSide(
                  color: Colors.white, // Text colour here
                  width: 1.0, // Underline width
                ))
              : null),
      child: Text(text,
          style: TextStyle(
              fontSize: 15,
              color: Colors.white,
              fontWeight: FontWeight.w100) // Text colour here,),
          ),
    );
  }
}
