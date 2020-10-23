import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ideashack/Const.dart';

class CommentsOverlay extends StatefulWidget {
  CommentsOverlay(this.postId);
  String postId;
  @override
  _CommentsOverlayState createState() => _CommentsOverlayState();
}

class _CommentsOverlayState extends State<CommentsOverlay> {
  Stream<DocumentSnapshot> commentsStream;

  @override
  void initState() {
    commentsStream =
        Firestore.instance.collection('posts').doc(widget.postId).snapshots();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: commentsStream,
        builder: (context, snapshot) {
          if (snapshot.data == null || !snapshot.data.exists) {
            return Row(
              children: [
                Image.asset('assets/commentsPanel.png',
                    color: Colors.grey, height: 30),
                Text(0.toString(),
                    style: enabledUpperBarStyle.copyWith(
                        color: Colors.grey, fontSize: 20))
              ],
            );
          } else {
            if (snapshot.data.get('lastSeenComments') <
                snapshot.data.get('lastCommentTime')) {
              return Row(
                children: [
                  Image.asset('assets/commentsPanelActive.png',
                      color: Colors.grey, height: 30),
                  Text(snapshot.data.get('commentsNum').toString(),
                      style: enabledUpperBarStyle.copyWith(
                          color: Colors.grey, fontSize: 20))
                ],
              );
            }
            return Row(
              children: [
                Image.asset('assets/commentsPanel.png',
                    color: Colors.grey, height: 30),
                Text(snapshot.data.get('commentsNum').toString(),
                    style: enabledUpperBarStyle.copyWith(
                        color: Colors.grey, fontSize: 20))
              ],
            );
          }
        });
  }
}

class NotificationOverlay extends StatefulWidget {
  @override
  _NotificationOverlayState createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<NotificationOverlay> {
  Stream<QuerySnapshot> authorStream;

  @override
  void initState() {
    authorStream = Firestore.instance
        .collection('users')
        .doc(GlobalController.get().userDocId)
        .collection('notifications')
        .orderBy('time', descending: true)
        .where('time',
            isGreaterThan:
                GlobalController.get().timeOnStartup - TIME_TILL_DISCARD)
        .limit(10)
        .snapshots();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white60,
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.pushNamed(context, '/notifications');
        },
        child: StreamBuilder(
            stream: authorStream,
            builder: (context, snapshot) {
              if (snapshot.data == null) {
                return Image.asset(
                  'assets/bell-inactive.png',
                  width: 25,
                );
              } else {
                List<QueryDocumentSnapshot> commentHolderList =
                    snapshot.data.docs;

                for (var comment in commentHolderList) {
                  if (comment.get('clicked') == 0) {
                    return Image.asset('assets/bell-active.png', width: 25);
                  }
                }
                return Image.asset('assets/bell-inactive.png', width: 25);
              }
            }),
      ),
    );
  }
}

class FeedOverlay extends StatefulWidget {
  @override
  _FeedOverlayState createState() => _FeedOverlayState();
}

class _FeedOverlayState extends State<FeedOverlay> {
  Stream<QuerySnapshot> authorStream;
  @override
  void initState() {
    authorStream = Firestore.instance
        .collection('directMessages')
        .where('posters', arrayContains: GlobalController.get().currentUserUid)
        .where('lastMessage',
            isGreaterThan:
                GlobalController.get().timeOnStartup - TIME_TILL_DISCARD)
        .snapshots();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white60,
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.pushNamed(context, '/feed');
        },
        child: StreamBuilder(
            stream: authorStream,
            builder: (context, snapshot) {
              if (snapshot.data == null) {
                return Image.asset(
                  'assets/mail-inactive.png',
                  width: 25,
                );
              } else {
                List<QueryDocumentSnapshot> commentHolderList =
                    snapshot.data.docs;

                for (var snapshotDoc in commentHolderList) {
                  double relevantTimestamp = 0;
                  if (snapshotDoc.get('initializerId') ==
                      GlobalController.get().currentUserUid) {
                    relevantTimestamp = snapshotDoc.get('lastSeenInitializer');
                  } else {
                    relevantTimestamp = snapshotDoc.get('lastSeenAuthor');
                  }
                  if (snapshotDoc.get('lastMessage') > relevantTimestamp) {
                    return Image.asset('assets/mail-active.png', width: 25);
                  }
                }
                return Image.asset('assets/mail-inactive.png', width: 25);
              }
            }),
      ),
    );
  }
}
