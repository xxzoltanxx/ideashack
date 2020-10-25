import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:ideashack/Const.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hashtagable/hashtagable.dart';
import 'package:dotted_line/dotted_line.dart';

class DislikeIndicator extends StatelessWidget {
  DislikeIndicator(this.animationProgress, this.didSwipe, this.opacity);

  double opacity;
  double animationProgress;
  bool didSwipe;
  @override
  Widget build(BuildContext context) {
    if (!didSwipe) {
      animationProgress = opacity / 255.0;
    }
    if (didSwipe && opacity == 0) {
      animationProgress = 0;
    }
    return Center(
      child: Transform.scale(
          scale: (didSwipe && opacity != 0) ? 1 : animationProgress,
          child: Transform.rotate(
              angle: 3.14,
              child: Image.asset('assets/thumbs-up.png',
                  width: 200,
                  color: didSwipe
                      ? Color.lerp(Colors.white, Colors.red, animationProgress)
                      : Colors.white))),
    );
  }
}

class LikeIndicator extends StatelessWidget {
  LikeIndicator(this.animationProgress, this.didSwipe, this.opacity);

  double animationProgress;
  bool didSwipe;
  double opacity;
  @override
  Widget build(BuildContext context) {
    if (!didSwipe) {
      animationProgress = opacity / 255.0;
    }
    if (didSwipe && opacity == 0) {
      animationProgress = 0;
    }
    return Center(
      child: Transform.scale(
        scale: (didSwipe && opacity != 0) ? 1 : animationProgress,
        child: Image.asset('assets/thumbs-up.png',
            width: 200,
            color: didSwipe
                ? Color.lerp(Colors.white, Colors.green, animationProgress)
                : Colors.white),
      ),
    );
  }
}

class DeleteIdeaPopup extends StatefulWidget {
  DeleteIdeaPopup(this.future, this.callback);
  Future<void> future;
  Function callback;
  @override
  _DeleteIdeaPopupState createState() => _DeleteIdeaPopupState();
}

class _DeleteIdeaPopupState extends State<DeleteIdeaPopup> {
  bool triggeredCallback = false;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: Text('Deleting idea...'),
        content: FutureBuilder(
          future: widget.future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting ||
                snapshot.connectionState == ConnectionState.active) {
              return Container(
                width: 200,
                height: 200,
                child: Center(
                    child: SpinKitThreeBounce(color: Colors.white, size: 50)),
              );
            }
            if (snapshot.connectionState == ConnectionState.done) {
              if (!triggeredCallback) {
                WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                  widget.callback();
                });
                triggeredCallback = true;
              }
              return Container(
                  width: 200,
                  height: 200,
                  child: Center(child: Text('Deleted!')));
            }
            return Container(
              width: 200,
              height: 200,
              child: Center(
                  child: SpinKitThreeBounce(color: Colors.white, size: 50)),
            );
          },
        ));
  }
}

class ReportPopup extends StatefulWidget {
  ReportPopup(this.anonymous, this.reported, this.reportFunction);
  final bool reported;
  final bool anonymous;
  final Function reportFunction;
  @override
  _ReportPopupState createState() => _ReportPopupState();
}

enum ReportReason { Spam, IlicitContent, Advertisment, Other }

class _ReportPopupState extends State<ReportPopup> {
  ReportReason reason = ReportReason.Spam;
  String objectification;
  String textReason = 'Advertisement';

  Future<void> reportFuture;

  Future<void> report() async {
    try {
      await widget.reportFunction(reason.toString(),
          GlobalController.get().currentUserUid, objectification);
    } catch (e) {}
  }

  void onSubmit() {
    setState(() {
      reportFuture = report();
    });
  }

  ReportReason parseReason(String str) {
    if (str == 'Advertisement') return ReportReason.Advertisment;
    if (str == 'Spam') return ReportReason.Spam;
    if (str == 'Illicit content') return ReportReason.IlicitContent;
    if (str == 'Other') return ReportReason.Other;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reported) {
      return AlertDialog(
          title: Text("Reporting"),
          content: Container(
              width: 200,
              height: 200,
              child: Center(
                  child: Text(
                'You already reported this post!',
                textAlign: TextAlign.center,
              ))));
    }
    return AlertDialog(
        content: FutureBuilder(
      future: reportFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.none) {
          return Container(
              height: 300,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(child: Text('Reason for report:')),
                  SizedBox(height: 20),
                  Center(
                      child: Text(
                          'Bear in mind that unnecessary reports will get you banned',
                          style: TextStyle(fontSize: 10))),
                  DropdownButton<String>(
                    value: textReason,
                    items: <ReportReason>[
                      ReportReason.Spam,
                      ReportReason.Advertisment,
                      ReportReason.IlicitContent,
                      ReportReason.Other
                    ].map((ReportReason value) {
                      var text = "";
                      switch (value) {
                        case ReportReason.Advertisment:
                          text = 'Advertisement';
                          break;
                        case ReportReason.Spam:
                          text = 'Spam';
                          break;
                        case ReportReason.IlicitContent:
                          text = 'Illicit content';
                          break;
                        case ReportReason.Other:
                          text = 'Other';
                          break;
                      }
                      return new DropdownMenuItem<String>(
                        value: text,
                        child: new Text(text),
                      );
                    }).toList(),
                    onChanged: (String str) {
                      setState(() {
                        this.reason = parseReason(str);
                        textReason = str;
                      });
                    },
                  ),
                  TextField(
                      maxLength: 200,
                      decoration:
                          InputDecoration(hintText: 'Explain your reason...'),
                      onChanged: (String newStr) {
                        objectification = newStr;
                      }),
                  RaisedButton(
                      onPressed: onSubmit,
                      child: Center(child: Text('Submit'))),
                ],
              ));
        }
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.connectionState == ConnectionState.active) {
          return Container(
              width: 200,
              height: 200,
              child: Center(
                  child: SpinKitThreeBounce(size: 50, color: Colors.white)));
        }
        if (snapshot.hasError) {
          return Container(
              width: 200,
              height: 200,
              child: Center(
                  child: Text(
                'Something went wrong, try again!',
                textAlign: TextAlign.center,
              )));
        }
        if (snapshot.connectionState == ConnectionState.done) {
          String text;
          if (widget.anonymous == true) {
            text =
                "Report received, bear in mind that anonymous reports don't hold much value";
          } else {
            text = "Report received! We'll look into it!";
          }
          return Container(
              width: 200,
              height: 200,
              child: Center(
                  child: Text(
                text,
                textAlign: TextAlign.center,
              )));
        }
        return Container(
            child: Center(
                child: SpinKitThreeBounce(size: 50, color: Colors.white)));
      },
    ));
  }
}

class CommentPopup extends StatefulWidget {
  CommentPopup(
      {this.postId,
      this.commentId,
      this.commentIdSeen,
      this.idMapping,
      this.keyMapping});
  final String postId;
  final String commentId;
  final String commentIdSeen;
  final Map<String, int> idMapping;
  final Map<int, String> keyMapping;
  @override
  _CommentPopupState createState() => _CommentPopupState();
}

class _CommentPopupState extends State<CommentPopup> {
  @override
  void initState() {
    postId = widget.postId;
    commentId = widget.commentId;
    commentIdSeen = widget.commentIdSeen;
    super.initState();
  }

  String postId;
  String commentId;
  String commentIdSeen;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        contentPadding: EdgeInsets.all(0),
        insetPadding: EdgeInsets.all(0),
        content: Builder(
          builder: (context) {
            var width = MediaQuery.of(context).size.width;
            print(width);
            return FutureBuilder(
              future: Firestore.instance
                  .collection('posts')
                  .doc(postId)
                  .collection('comments')
                  .doc(commentId)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  DocumentSnapshot docSnap = snapshot.data;
                  if (!docSnap.exists) {
                    return Container(
                        decoration: BoxDecoration(color: Colors.white),
                        width: width,
                        height: 200,
                        child: Center(
                            child: Text('Comment does not exist!',
                                style: enabledUpperBarStyle)));
                  }
                  DateTime time = DateTime.fromMillisecondsSinceEpoch(
                      (docSnap.get('time') * 1000).toInt());
                  String date = '${time.day}.${time.month}.${time.year}';
                  String text = replaceHashtagsWithIds(
                      docSnap.get('comment'), widget.idMapping);
                  return Container(
                      width: width,
                      decoration: BoxDecoration(color: Colors.white),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Posted on: ' + date,
                                    style: disabledUpperBarStyle.copyWith(
                                        fontSize: 10,
                                        fontStyle: FontStyle.italic)),
                                SizedBox(width: 20),
                                Text('Comment id: ' + commentIdSeen,
                                    style: disabledUpperBarStyle.copyWith(
                                        fontSize: 10,
                                        fontStyle: FontStyle.italic))
                              ],
                            ),
                            SizedBox(height: 20),
                            HashTagText(
                              text: text,
                              basicStyle: enabledUpperBarStyle,
                              decoratedStyle: enabledUpperBarStyle.copyWith(
                                  color: Colors.red),
                              onTap: (id) {
                                String idConverted = replaceIdsWithHashtags(
                                    id, widget.keyMapping);
                                var idConvertedList =
                                    extractHashTags(idConverted);
                                setState(() {
                                  commentId = idConvertedList[0].substring(1);
                                  commentIdSeen = id;
                                });
                              },
                            ),
                            SizedBox(height: 20),
                            DottedLine(dashColor: disabledUpperBarColor),
                            SizedBox(height: 20),
                          ],
                        ),
                      ));
                }
                return Container(
                  width: width,
                  height: 200,
                  decoration: BoxDecoration(color: Colors.white),
                  child: Center(
                      child: SpinKitThreeBounce(
                          color: secondarySpinnerColor, size: 50)),
                );
              },
            );
          },
        ));
  }
}
