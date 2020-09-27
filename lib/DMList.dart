import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ideashack/Const.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class DMList extends StatefulWidget {
  @override
  _DMListState createState() => _DMListState();
}

class DMData {
  DMData(this.postId, this.postInitializer, this.postAuthor, this.lastMessage,
      this.shouldHiglight);
  String postId;
  String postInitializer;
  String postAuthor;
  String lastMessage;
  bool shouldHiglight;
}

class _DMListState extends State<DMList> {
  List<DMData> dmData = [];
  List<DMData> dmDataHighlighted = [];
  Future<void> grabDMFuture;
  Future<void> grabDMS() async {
    try {
      var dms = await Firestore.instance
          .collection('directMessages')
          .where('posters',
              arrayContains: GlobalController.get().currentUserUid)
          .get();
      for (var post in dms.docs) {
        var dmID = post.id;
        var lastMessageFirstList = await Firestore.instance
            .collection('directMessages')
            .doc(dmID)
            .collection('messages')
            .orderBy('time', descending: true)
            .get();
        var lastMessage = lastMessageFirstList.docs[0].get('text');
        bool shouldHighlight = false;

        bool isInitializer = false;
        if (post.get('initializerId') ==
            GlobalController.get().currentUserUid) {
          isInitializer = true;
        }
        double timestampToCompare;
        if (isInitializer) {
          timestampToCompare = post.get('lastSeenInitializer');
        } else {
          timestampToCompare = post.get('lastSeenAuthor');
        }
        if (lastMessageFirstList.docs[0].get('time') > timestampToCompare) {
          shouldHighlight = true;
        }
        if (shouldHighlight) {
          dmDataHighlighted.add(DMData(
              post.get('postId'),
              post.get('initializerId'),
              post.get('postAuthorId'),
              lastMessage,
              shouldHighlight));
        } else {
          dmData.add(DMData(post.get('postId'), post.get('initializerId'),
              post.get('postAuthorId'), lastMessage, shouldHighlight));
        }
      }
      return;
    } catch (e) {
      return Future.error("SOMETHING WENT WRONG");
    }
  }

  @override
  void initState() {
    super.initState();
    grabDMFuture = grabDMS();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Direct messages")),
      body: FutureBuilder(
        future: grabDMFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              snapshot.connectionState == ConnectionState.waiting) {
            return Container(
                child:
                    Center(child: SpinKitRing(size: 100, color: spinnerColor)));
          } else if (snapshot.connectionState == ConnectionState.done) {
            List<Widget> widgetsToEmbed = [];
            for (var data in dmDataHighlighted) {
              bool isPostAuthor =
                  data.postAuthor == GlobalController.get().currentUserUid;
              widgetsToEmbed.add(Container(
                  child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                        child: Text(data.lastMessage,
                            style: data.shouldHiglight
                                ? AUTHOR_CARD_TEXT_STYLE.copyWith(
                                    fontWeight: FontWeight.bold)
                                : AUTHOR_CARD_TEXT_STYLE)),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: RaisedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/message',
                              arguments: <dynamic>[
                                data.postId,
                                data.postInitializer,
                                data.postAuthor
                              ]);
                        },
                        highlightColor: Colors.white,
                        disabledColor: Colors.redAccent,
                        color: Colors.white60,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                          side: BorderSide(color: Colors.red, width: 3),
                        ),
                        child: Icon(Icons.comment,
                            size: 50, color: Colors.black45),
                      ),
                    ),
                  ],
                ),
              )));
            }
            for (var data in dmData) {
              widgetsToEmbed.add(Container(
                  child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                        child: Text(data.lastMessage,
                            style: data.shouldHiglight
                                ? AUTHOR_CARD_TEXT_STYLE.copyWith(
                                    fontWeight: FontWeight.bold)
                                : AUTHOR_CARD_TEXT_STYLE)),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: RaisedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/message',
                              arguments: <dynamic>[
                                data.postId,
                                data.postInitializer,
                                data.postAuthor
                              ]);
                        },
                        highlightColor: Colors.white,
                        disabledColor: Colors.redAccent,
                        color: Colors.white60,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                          side: BorderSide(color: Colors.red, width: 3),
                        ),
                        child: Icon(Icons.comment,
                            size: 50, color: Colors.black45),
                      ),
                    ),
                  ],
                ),
              )));
            }
            return ListView(
              children: widgetsToEmbed,
            );
          } else if (snapshot.hasError) {
            return Container(child: Center(child: Text('Could not fetch DMs')));
          }
          return Container(
              child:
                  Center(child: SpinKitRing(size: 100, color: spinnerColor)));
        },
      ),
    );
  }
}
