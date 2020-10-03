import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ideashack/Const.dart';

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
                  'assets/bell-inactive.png',
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
