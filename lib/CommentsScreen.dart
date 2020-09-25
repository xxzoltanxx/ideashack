import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Const.dart';

class CommentsScreen extends StatefulWidget {
  @override
  _CommentsScreenState createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  CardData cardData;
  List<Widget> comments = [];
  String inputText = "";
  bool firstBuild = true;
  Function commentsCallback;

  @override
  void initState() {
    super.initState();
  }

  void postComment() async {
    try {
      cardData.commented = true;
      await Firestore.instance.collection('posts').doc(cardData.id).update({
        'comments': FieldValue.arrayUnion([inputText]),
        'commented':
            FieldValue.arrayUnion([GlobalController.get().currentUserUid])
      });
    } catch (e) {
      print(e);
    }
  }

  void buttonCallback() {
    bool profane = false;
    if (spamFilter.isProfane(inputText)) {
      profane = true;
    }
    if (!profane) {
      postComment();
    }
    Navigator.pop(context);
    commentsCallback(cardData, profane: profane);
  }

  @override
  Widget build(BuildContext context) {
    if (firstBuild) {
      firstBuild = false;
      comments.clear();
      List<dynamic> list = ModalRoute.of(context).settings.arguments;
      cardData = list[0];
      commentsCallback = list[1];
      List<dynamic> commentsStr = cardData.comments;

      if (commentsStr.length == 0) {
        comments
            .add(Center(child: Comment(comment: "There are no comments yet")));
      } else {
        for (int i = commentsStr.length - 1; i >= 0; i = i - 1) {
          String str = commentsStr[i];
          comments.add(Center(child: Comment(comment: str)));
          comments.add(Padding(
            padding: const EdgeInsets.only(left: 40.0, right: 40.0),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Divider(
                color: Colors.red,
              ),
            ),
          ));
        }
      }
    }
    return Scaffold(
        appBar: AppBar(title: Text('Viewing comments')),
        body: GestureDetector(
          onTap: () {
            FocusScope.of(context).requestFocus(new FocusNode());
          },
          child: Column(
            children: [
              Expanded(
                  flex: 5,
                  child: Center(
                      child: ListView(shrinkWrap: true, children: comments))),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 20.0 * 24,
                        child: TextField(
                          onChanged: (string) {
                            inputText = string;
                          },
                          onEditingComplete: () {},
                          maxLines: 20.toInt(),
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            counterText: "",
                            fillColor: Colors.white,
                          ),
                          maxLength: 245,
                        ),
                      ),
                    ),
                    Expanded(
                      child: RaisedButton(
                          child: Center(child: Text('Post')),
                          onPressed:
                              (cardData.commented && inputText.length > 15)
                                  ? null
                                  : buttonCallback),
                    )
                  ],
                ),
              )
            ],
          ),
        ));
  }
}

class Comment extends StatelessWidget {
  Comment({this.comment});
  final String comment;
  @override
  Widget build(BuildContext context) {
    return Text(comment,
        style: AUTHOR_CARD_TEXT_STYLE, textAlign: TextAlign.center);
  }
}
