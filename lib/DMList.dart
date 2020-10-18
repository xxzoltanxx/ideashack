import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ideashack/Const.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_line/dotted_line.dart';
import 'CustomPainters.dart';

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
  String lastText = "No new messages...";
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

  void setHeaderText(String text) {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      setState(() {
        lastText = text;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            iconTheme: IconThemeData(color: Colors.black),
            backgroundColor: Colors.orange,
            elevation: 5.0,
            title: Text('Your direct messages',
                style: TextStyle(color: Colors.black))),
        body: SafeArea(
            child: Container(
          decoration: BoxDecoration(color: Colors.white),
          child: StreamBuilder(
              stream: grabDMSnapshots,
              builder: (context, snapshot) {
                if (snapshot.data == null) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                        child: Center(
                            child: Text('Fetching messages...',
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
                  bool firstMessage = true;
                  for (var post in snapshot.data.docs) {
                    var dmID = post.id;
                    Stream<QuerySnapshot> lastMessageFirstListStream = Firestore
                        .instance
                        .collection('directMessages')
                        .doc(dmID)
                        .collection('messages')
                        .orderBy('time', descending: true)
                        .snapshots();

                    chatWidgets.add(ChatBubbleStream(lastMessageFirstListStream,
                        post, setHeaderText, firstMessage));
                    firstMessage = false;
                  }
                  return ListView(
                      addAutomaticKeepAlives: true, children: chatWidgets);
                }
              }),
        )));
  }
}

class ChatBubbleStream extends StatefulWidget {
  ChatBubbleStream(this.lastMessageFirstListStream, this.post, this.callback,
      this.firstMessage);
  final DocumentSnapshot post;
  final Stream<QuerySnapshot> lastMessageFirstListStream;

  final bool firstMessage;
  final Function callback;

  @override
  _ChatBubbleStreamState createState() => _ChatBubbleStreamState();
}

class _ChatBubbleStreamState extends State<ChatBubbleStream>
    with AutomaticKeepAliveClientMixin {
  get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: widget.lastMessageFirstListStream,
        builder: (context, snapshot) {
          if (snapshot.data == null || snapshot.data.docs.length == 0) {
            return FetchingBubble();
          } else {
            var lastMessageFirstList = snapshot.data;
            snapshot.data.docs[0].get('text');
            bool shouldHighlight = false;

            bool isInitializer = false;
            if (widget.post.get('initializerId') ==
                GlobalController.get().currentUserUid) {
              isInitializer = true;
            }
            double timestampToCompare;
            if (isInitializer) {
              timestampToCompare = widget.post.get('lastSeenInitializer');
            } else {
              timestampToCompare = widget.post.get('lastSeenAuthor');
            }
            if (lastMessageFirstList.docs[0].get('time') > timestampToCompare) {
              shouldHighlight = true;
            }
            var lastMessage = lastMessageFirstList.docs[0].get('text');
            DMData data = DMData(
                widget.post.get('postId'),
                widget.post.get('initializerId'),
                widget.post.get('postAuthorId'),
                lastMessage,
                shouldHighlight,
                widget.post.get('conversationPartner'));
            if (widget.firstMessage) {
              widget.callback(data.lastMessage);
            }
            double lastTimestamp = lastMessageFirstList.docs[0].get('time');
            bool lastMessageIsAnon =
                (lastMessageFirstList.docs[0].get('senderUid') !=
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
        });
  }
}

class FetchingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Color backgroundColor = Color.fromARGB(255, 125, 125, 125);
    String theChar = 'F';

    Widget partnerImage = ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: Container(
          color: backgroundColor,
          width: 50,
          height: 50,
          child: Center(
            child: Text(theChar,
                style: TextStyle(fontSize: 60, fontWeight: FontWeight.bold)),
          ),
        ));
    return Container(
        child: Column(
      children: [
        SizedBox(height: 10),
        Row(
          children: [
            SizedBox(width: 5),
            partnerImage,
            SizedBox(width: 5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Text("SOMEONE",
                          style: enabledUpperBarStyle.copyWith(
                              fontWeight: FontWeight.w700, color: Colors.grey)),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text("Fetching...",
                      style: disabledUpperBarStyle,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            SizedBox(width: 20),
          ],
        ),
        Divider(color: Colors.grey),
      ],
    ));
  }
}

class DMBubble extends StatelessWidget {
  DMBubble(
      {this.firstMessage,
      this.initializerID,
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

  bool firstMessage;
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
    Color backgroundColor = Color.fromARGB(255, callsign.codeUnitAt(0),
        callsign.codeUnitAt(1), callsign.codeUnitAt(2));
    String theChar = callsign[0];

    Widget partnerImage = ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: Container(
          color: backgroundColor,
          width: 50,
          height: 50,
          child: Center(
            child: Text(theChar,
                style: TextStyle(fontSize: 60, fontWeight: FontWeight.bold)),
          ),
        ));

    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, '/message',
            arguments: <dynamic>[postId, initializerID, authorId]);
      },
      child: Container(
          child: Column(
        children: [
          SizedBox(height: 10),
          Row(
            children: [
              SizedBox(width: 5),
              partnerImage,
              SizedBox(width: 5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Text(callsign.toUpperCase(),
                            style: enabledUpperBarStyle.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.grey)),
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
                  ],
                ),
              ),
              Text(date,
                  style: disabledUpperBarStyle.copyWith(
                      fontSize: 10, fontStyle: FontStyle.italic)),
              SizedBox(width: 20),
            ],
          ),
          Divider(color: Colors.grey),
        ],
      )),
    );
  }
}
