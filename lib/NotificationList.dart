import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ideashack/Const.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:ideashack/CardList.dart';
import 'Analytics.dart';
import 'RegistrationScreen.dart';
import 'package:hashtagable/hashtagable.dart';
import 'CustomPainters.dart';

class NotificationList extends StatefulWidget {
  @override
  _NotificationListState createState() => _NotificationListState();
}

class _NotificationListState extends State<NotificationList> {
  Stream<QuerySnapshot> grabDMSnapshots;
  String lastText = "No messages.";
  @override
  void initState() {
    super.initState();
    grabDMSnapshots = Firestore.instance
        .collection('users')
        .doc(GlobalController.get().userDocId)
        .collection('notifications')
        .orderBy('time', descending: true)
        .where('time',
            isGreaterThan:
                GlobalController.get().timeOnStartup - TIME_TILL_DISCARD)
        .limit(10)
        .snapshots();
  }

  String parseSheet(InfoSheet sheet) {
    switch (sheet) {
      case InfoSheet.CantRate:
        return "cantrate";
        break;
      case InfoSheet.Commented:
        return "commented";
        break;
      case InfoSheet.Deleted:
        return "deleted";
        break;
      case InfoSheet.OneMessage:
        return "onemessage";
        break;
      case InfoSheet.Posted:
        return "posted";
        break;
      case InfoSheet.Profane:
        return "profane";
        break;
      case InfoSheet.Register:
        return "register";
        break;
    }
    return "undefined";
  }

  void notificationCommentsCallback(CardData data, InfoSheet sheet) {
    _settingModalBottomSheet(context, sheet);
  }

  void _settingModalBottomSheet(context, InfoSheet sheet) {
    ListTile info;
    if (sheet == InfoSheet.CantRate) {
      info = ListTile(
          leading: Icon(Icons.thumb_up),
          title: Padding(
            padding: const EdgeInsets.all(8.0),
            child: HashTagText(
                decoratedStyle: TextStyle(color: Colors.blue),
                basicStyle: TextStyle(),
                text:
                    '#register to rate ideas, you can only browse as an anonymous user!',
                onTap: (string) {
                  AnalyticsController.get().registerModalPopupTapped();
                  Navigator.pop(context);
                  print("POPPED");
                  Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (context) {
                    return RegistrationScreen(
                      doSignInWithGoogle: true,
                    );
                  }));
                }),
          ));
    }
    if (sheet == InfoSheet.Deleted) {
      info = ListTile(
          leading: Icon(Icons.comment), title: Text('Post was deleted!'));
    } else if (sheet == InfoSheet.Commented) {
      info = ListTile(
          leading: Icon(Icons.comment),
          title: Text('Succesfully posted a comment!'));
    } else if (sheet == InfoSheet.Posted) {
      info = ListTile(
          leading: Icon(Icons.lightbulb_outline),
          title: Text('You successfully posted an idea!'));
    } else if (sheet == InfoSheet.Profane) {
      info = ListTile(
          leading: Icon(Icons.not_interested),
          title: Text('Comment is too profane to post!'));
    } else if (sheet == InfoSheet.OneMessage) {
      info = ListTile(
          leading: Icon(Icons.not_interested),
          title: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
                'We limited direct message initializations to one a day to prevent unnecessary feedback!'),
          ));
    } else if (sheet == InfoSheet.Register) {
      info = ListTile(
          leading: Icon(Icons.remove_circle_outline),
          title: HashTagText(
              decoratedStyle: TextStyle(color: Colors.blue),
              basicStyle: TextStyle(),
              text: '#register to use this',
              onTap: (string) {
                Navigator.pop(context);
                print("POPPED");
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (context) {
                  return RegistrationScreen(
                    doSignInWithGoogle: true,
                  );
                }));
              }));
    }
    String sheetStr = parseSheet(sheet);
    AnalyticsController.get().modalPopupShown(sheetStr);
    showModalBottomSheet(
        isDismissible: true,
        context: context,
        builder: (BuildContext bc) {
          return Container(
            child: info,
          );
        });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void setLastText(String text) {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (lastText != text) {
        setState(() {
          lastText = text;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            iconTheme: IconThemeData(color: Colors.black),
            backgroundColor: Colors.orange,
            elevation: 5.0,
            title: Text('Your notifications',
                style: TextStyle(color: Colors.black))),
        body: SafeArea(
            child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
          ),
          child: StreamBuilder(
              stream: grabDMSnapshots,
              builder: (context, snapshot) {
                if (snapshot.data == null) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                        child: Center(
                            child: Text('Fetching notifications...',
                                style: enabledUpperBarStyle))),
                  );
                } else {
                  List<Widget> chatWidgets = [];
                  chatWidgets.add(Container(
                      height: 200,
                      child: CustomPaint(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('NEWEST',
                                    style: cardThingsBelowTextStyle.copyWith(
                                        fontSize: 12)),
                                Expanded(child: Center(child: Text(lastText)))
                              ],
                            ),
                          ),
                          painter: CustomBlockPainter(
                              gradientColors: splashScreenColors),
                          size: Size.infinite)));
                  bool first = true;
                  for (var post in snapshot.data.docs) {
                    var dmID = post.id;
                    Stream<DocumentSnapshot> lastMessageFirstListStream =
                        Firestore.instance
                            .collection('users')
                            .doc(GlobalController.get().userDocId)
                            .collection('notifications')
                            .doc(dmID)
                            .snapshots();
                    chatWidgets.add(NotificationBubbleFuture(
                        lastMessageFirstListStream: lastMessageFirstListStream,
                        notificationCommentsCallback:
                            notificationCommentsCallback,
                        callback: first ? setLastText : null));
                    first = false;
                  }
                  return ListView(
                      addAutomaticKeepAlives: true, children: chatWidgets);
                }
              }),
        )));
  }
}

class FetchingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    String typeShown = "Comment Reply";
    Widget icon =
        Image.asset('assets/comments.png', width: 20, color: Colors.grey);
    return Container(
        child: Column(
      children: [
        SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 20),
            icon,
            SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(typeShown, style: enabledUpperBarStyle),
                    ],
                  ),
                  SizedBox(height: 15),
                  Text("Fetching...", style: disabledUpperBarStyle),
                  SizedBox(height: 20),
                ],
              ),
            ),
            SizedBox(width: 20),
          ],
        ),
        Divider(color: Colors.grey)
      ],
    ));
  }
}

class NotificationBubble extends StatelessWidget {
  NotificationBubble(
      {this.type,
      this.postId,
      this.lastMessage,
      this.lastMessageTimestamp,
      this.shouldHighlight,
      this.notificationCommentsCallback,
      this.notificationDocId}) {
    DateTime time = DateTime.fromMillisecondsSinceEpoch(
        (lastMessageTimestamp * 1000).toInt());

    date = '${time.day}.${time.month}.${time.year}';
  }

  String type;
  String notificationDocId;
  String date;
  String postId;
  String lastMessage;
  double lastMessageTimestamp;
  bool shouldHighlight;
  Function notificationCommentsCallback;
  @override
  Widget build(BuildContext context) {
    Function notificationFunction = null;
    String typeShown = "";
    Widget icon;
    if (type == 'reply') {
      notificationFunction = () async {
        GlobalController.get().openingNotification = true;
        CardData data = await CardList.get().getCardDataForPost(postId);
        Navigator.pushNamed(context, '/comments',
            arguments: <dynamic>[data, notificationCommentsCallback]);
        GlobalController.get().openingNotification = false;
      };
      typeShown = "Comment Reply";
      icon = Image.asset('assets/comments.png', width: 20, color: Colors.grey);
    } else if (type == 'like') {
      notificationFunction = () async {
        GlobalController.get().openingNotification = true;
        CardData data = await CardList.get().getCardDataForPost(postId);
        Navigator.pushNamed(context, '/comments',
            arguments: <dynamic>[data, notificationCommentsCallback]);
        GlobalController.get().openingNotification = false;
      };
      typeShown = "Your idea is on fire!";
      icon = Image.asset('assets/score.png', width: 20, color: Colors.grey);
    }

    return InkWell(
        onTap: () async {
          if (GlobalController.get().openingNotification == true) {
            return;
          }
          Firestore.instance
              .collection('users')
              .doc(GlobalController.get().userDocId)
              .collection('notifications')
              .doc(notificationDocId)
              .update({'clicked': 1});
          if (notificationFunction != null) {
            notificationFunction();
          }
        },
        child: Container(
            child: Column(
          children: [
            SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 20),
                icon,
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(typeShown, style: enabledUpperBarStyle),
                          Text(date, style: disabledUpperBarStyle),
                        ],
                      ),
                      SizedBox(height: 15),
                      Text(lastMessage,
                          style: shouldHighlight
                              ? enabledUpperBarStyle
                              : disabledUpperBarStyle),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
                SizedBox(width: 20),
              ],
            ),
            Divider(color: Colors.grey)
          ],
        )));
  }
}

class NotificationBubbleFuture extends StatefulWidget {
  NotificationBubbleFuture(
      {this.lastMessageFirstListStream,
      this.callback,
      this.notificationCommentsCallback});
  final Stream<DocumentSnapshot> lastMessageFirstListStream;
  final Function callback;
  final Function notificationCommentsCallback;

  @override
  _NotificationBubbleFutureState createState() =>
      _NotificationBubbleFutureState();
}

class _NotificationBubbleFutureState extends State<NotificationBubbleFuture>
    with AutomaticKeepAliveClientMixin {
  get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: widget.lastMessageFirstListStream,
        builder: (context, snapshot) {
          if (snapshot.data == null) {
            return FetchingBubble();
          } else {
            int shouldHighlight = snapshot.data.get('clicked');
            var lastMessage = snapshot.data.get('text');
            if (widget.callback != null) {
              widget.callback(lastMessage);
            }
            return NotificationBubble(
                type: snapshot.data.get('type'),
                notificationDocId: snapshot.data.id,
                lastMessage: lastMessage,
                shouldHighlight: shouldHighlight.isEven,
                postId: snapshot.data.get('postId'),
                lastMessageTimestamp: snapshot.data.get('time'),
                notificationCommentsCallback:
                    widget.notificationCommentsCallback);
          }
        });
  }
}
