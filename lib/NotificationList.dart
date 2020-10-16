import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ideashack/Const.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:ideashack/CardList.dart';
import 'Analytics.dart';
import 'RegistrationScreen.dart';
import 'package:hashtagable/hashtagable.dart';

class NotificationList extends StatefulWidget {
  @override
  _NotificationListState createState() => _NotificationListState();
}

class _NotificationListState extends State<NotificationList> {
  Stream<QuerySnapshot> grabDMSnapshots;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            iconTheme: IconThemeData(color: Colors.black),
            backgroundColor: Colors.white,
            elevation: 5.0,
            title: Text('Your notifications',
                style: TextStyle(color: Colors.black))),
        body: SafeArea(
            child: Container(
          decoration: BoxDecoration(
              gradient: LinearGradient(
            colors: [Color(0xFFDBDBDB), Color(0xFFFFFFFF)],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          )),
          child: StreamBuilder(
              stream: grabDMSnapshots,
              builder: (context, snapshot) {
                if (snapshot.data == null) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                        child:
                            Center(child: Text('Fetching notifications...'))),
                  );
                } else {
                  List<Widget> chatWidgets = [];
                  for (var post in snapshot.data.docs) {
                    var dmID = post.id;
                    Stream<DocumentSnapshot> lastMessageFirstListStream =
                        Firestore.instance
                            .collection('users')
                            .doc(GlobalController.get().userDocId)
                            .collection('notifications')
                            .doc(dmID)
                            .snapshots();

                    chatWidgets.add(Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: StreamBuilder(
                          stream: lastMessageFirstListStream,
                          builder: (context, snapshot) {
                            if (snapshot.data == null) {
                              return FetchingBubble();
                            } else {
                              int shouldHighlight =
                                  snapshot.data.get('clicked');

                              var lastMessage = snapshot.data.get('text');
                              return NotificationBubble(
                                  notificationDocId: snapshot.data.id,
                                  lastMessage: lastMessage,
                                  shouldHighlight: shouldHighlight.isEven,
                                  postId: snapshot.data.get('postId'),
                                  lastMessageTimestamp:
                                      snapshot.data.get('time'),
                                  notificationCommentsCallback:
                                      notificationCommentsCallback);
                            }
                          }),
                    ));
                  }
                  return ListView(children: chatWidgets);
                }
              }),
        )));
  }
}

class FetchingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 10),
        Row(
          children: [
            SizedBox(width: 30),
            Text('unknown', style: enabledUpperBarStyle),
          ],
        ),
        SizedBox(height: 10),
        Text('Fetching message...',
            style: disabledUpperBarStyle, overflow: TextOverflow.ellipsis),
        Text('unknown',
            style: disabledUpperBarStyle.copyWith(
                fontSize: 10, fontStyle: FontStyle.italic)),
        SizedBox(height: 10),
        DottedLine(dashColor: disabledUpperBarColor),
      ],
    ));
  }
}

class NotificationBubble extends StatelessWidget {
  NotificationBubble(
      {this.postId,
      this.lastMessage,
      this.lastMessageTimestamp,
      this.shouldHighlight,
      this.notificationCommentsCallback,
      this.notificationDocId}) {
    DateTime time = DateTime.fromMillisecondsSinceEpoch(
        (lastMessageTimestamp * 1000).toInt());
    date = '${time.day}.${time.month}.${time.year}';
  }

  String notificationDocId;
  String date;
  String postId;
  String lastMessage;
  double lastMessageTimestamp;
  bool shouldHighlight;
  Function notificationCommentsCallback;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        Firestore.instance
            .collection('users')
            .doc(GlobalController.get().userDocId)
            .collection('notifications')
            .doc(notificationDocId)
            .update({'clicked': 1});
        CardData data = await CardList.get().getCardDataForPost(postId);
        Navigator.pushNamed(context, '/comments',
            arguments: <dynamic>[data, notificationCommentsCallback]);
      },
      child: Container(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 10),
          Text('Someone replied to you!',
              style: shouldHighlight
                  ? enabledUpperBarStyle
                  : disabledUpperBarStyle,
              overflow: TextOverflow.ellipsis),
          SizedBox(height: 10),
          Text(lastMessage,
              style: shouldHighlight
                  ? enabledUpperBarStyle
                  : disabledUpperBarStyle,
              overflow: TextOverflow.ellipsis),
          Text(date,
              style: disabledUpperBarStyle.copyWith(
                  fontSize: 10, fontStyle: FontStyle.italic)),
          SizedBox(height: 10),
          DottedLine(dashColor: disabledUpperBarColor),
        ],
      )),
    );
  }
}
