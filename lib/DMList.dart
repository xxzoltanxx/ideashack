import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ideashack/Const.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_line/dotted_line.dart';

class DMData {
  DMData(this.postId, this.postInitializer, this.postAuthor, this.lastMessage,
      this.shouldHiglight, this.conversationPartner);
  String postId;
  String postInitializer;
  String postAuthor;
  String lastMessage;
  bool shouldHiglight;
  String conversationPartner;
}

class DMList extends StatefulWidget {
  @override
  _DMListState createState() => _DMListState();
}

class _DMListState extends State<DMList> {
  List<DMData> dmData = [];
  List<DMData> dmDataHighlighted = [];
  Stream<QuerySnapshot> grabDMSnapshots;
  @override
  void initState() {
    super.initState();
    grabDMSnapshots = Firestore.instance
        .collection('directMessages')
        .where('posters', arrayContains: GlobalController.get().currentUserUid)
        .orderBy('lastMessage', descending: true)
        .where('lastMessage',
            isGreaterThan:
                GlobalController.get().timeOnStartup - TIME_TILL_DISCARD)
        .snapshots();
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
            title: Text('Your direct messages',
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
                        child: Center(child: Text('Fetching messages...'))),
                  );
                } else {
                  List<Widget> chatWidgets = [];
                  for (var post in snapshot.data.docs) {
                    var dmID = post.id;
                    Stream<QuerySnapshot> lastMessageFirstListStream = Firestore
                        .instance
                        .collection('directMessages')
                        .doc(dmID)
                        .collection('messages')
                        .orderBy('time', descending: true)
                        .snapshots();

                    chatWidgets.add(Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: StreamBuilder(
                          stream: lastMessageFirstListStream,
                          builder: (context, snapshot) {
                            if (snapshot.data == null ||
                                snapshot.data.docs.length == 0) {
                              return FetchingBubble();
                            } else {
                              var lastMessageFirstList = snapshot.data;
                              snapshot.data.docs[0].get('text');
                              bool shouldHighlight = false;

                              bool isInitializer = false;
                              if (post.get('initializerId') ==
                                  GlobalController.get().currentUserUid) {
                                isInitializer = true;
                              }
                              double timestampToCompare;
                              if (isInitializer) {
                                timestampToCompare =
                                    post.get('lastSeenInitializer');
                              } else {
                                timestampToCompare = post.get('lastSeenAuthor');
                              }
                              if (lastMessageFirstList.docs[0].get('time') >
                                  timestampToCompare) {
                                shouldHighlight = true;
                              }
                              var lastMessage =
                                  lastMessageFirstList.docs[0].get('text');
                              DMData data = DMData(
                                  post.get('postId'),
                                  post.get('initializerId'),
                                  post.get('postAuthorId'),
                                  lastMessage,
                                  shouldHighlight,
                                  post.get('conversationPartner'));

                              double lastTimestamp =
                                  lastMessageFirstList.docs[0].get('time');
                              bool lastMessageIsAnon = (lastMessageFirstList
                                      .docs[0]
                                      .get('senderUid') !=
                                  GlobalController.get().currentUserUid);
                              return DMBubble(
                                  initializerID: data.postInitializer,
                                  authorId: data.postAuthor,
                                  callsign: data.conversationPartner,
                                  lastMessage: data.lastMessage,
                                  lastMessageAnon: lastMessageIsAnon,
                                  lastMessageTimestamp: lastTimestamp,
                                  postId: data.postId,
                                  shouldHighlight: data.shouldHiglight);
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

class DMBubble extends StatelessWidget {
  DMBubble(
      {this.initializerID,
      this.authorId,
      this.postId,
      this.callsign,
      this.lastMessage,
      this.lastMessageTimestamp,
      this.lastMessageAnon,
      this.shouldHighlight}) {
    DateTime time = DateTime.fromMillisecondsSinceEpoch(
        (lastMessageTimestamp * 1000).toInt());
    date = '${time.day}.${time.month}.${time.year}';
  }

  String date;
  String initializerID;
  String authorId;
  String postId;
  String callsign;
  String lastMessage;
  double lastMessageTimestamp;
  bool lastMessageAnon;
  bool shouldHighlight;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, '/message',
            arguments: <dynamic>[postId, initializerID, authorId]);
      },
      child: Container(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 10),
          Row(
            children: [
              SizedBox(width: 30),
              Text(callsign, style: enabledUpperBarStyle),
            ],
          ),
          SizedBox(height: 10),
          Text(
              lastMessageAnon
                  ? 'Somebody: ' + lastMessage
                  : 'You: ' + lastMessage,
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
