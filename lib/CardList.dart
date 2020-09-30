import 'Const.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class CardList {
  static CardList _instance;
  static CardList get() {
    if (_instance == null) {
      _instance = CardList();
    }
    return _instance;
  }

  void setInstance(FirebaseFirestore inst) {
    _firestoreInstance = inst;
  }

  FirebaseFirestore _firestoreInstance;

  List<CardData> cardsData = [];
  List<CardData> userCardsData = [];

  void addCard(CardData data) {
    cardsData.add(data);
  }

  Future<void> getUserCardsData({Function lambda}) async {
    try {
      var userDataSnapshotList = await _firestoreInstance
          .collection('users')
          .where('uid', isEqualTo: GlobalController.get().currentUserUid)
          .get();
      var userDataSnapshot = userDataSnapshotList.docs[0];

      var timestamp = await getCurrentTimestampServer();
      var snapshot = await _firestoreInstance
          .collection('posts')
          .orderBy('postTime', descending: true)
          .where('postTime', isGreaterThan: timestamp - TIME_TILL_DISCARD)
          .where('userid', isEqualTo: GlobalController.get().currentUserUid)
          .get();

      userCardsData.clear();
      int i = 0;
      for (var doc in snapshot.docs) {
        bool commented =
            userDataSnapshot.get('commented').toSet().contains(doc.id);
        userCardsData.add(CardData(
            id: doc.id,
            author: doc.get('author'),
            score: doc.get('score'),
            text: doc.get('body'),
            comments: doc.get('commentsNum'),
            posterId: doc.get('userid'),
            commented: commented));
      }
    } catch (e) {
      print(e + "HELLO3");
    }
    if (lambda != null) lambda();
  }

  void clear() {
    cardsData.clear();
  }

  Future<void> getByTag({Function lambda, String tag}) async {
    try {
      var userDataSnapshotList = await _firestoreInstance
          .collection('users')
          .where('uid', isEqualTo: GlobalController.get().currentUserUid)
          .get();
      var userDataSnapshot = userDataSnapshotList.docs[0];
      var upvotedSet = userDataSnapshot.get('upvoted').toSet();
      var downvotedSet = userDataSnapshot.get('downvoted').toSet();
      var commentedSet = userDataSnapshot.get('commented').toSet();

      QuerySnapshot snapshot;
      UpvotedStatus upvoteStatus = UpvotedStatus.DidntVote;
      var timestamp = await getCurrentTimestampServer();
      snapshot = await _firestoreInstance
          .collection('posts')
          .where('hashtag', isEqualTo: tag)
          .where('postTime', isGreaterThan: timestamp - TIME_TILL_DISCARD)
          .get();
      var doxs = snapshot.docs;
      cardsData.clear();
      for (var doc in doxs) {
        upvoteStatus = UpvotedStatus.DidntVote;
        var upvoted = upvotedSet.contains(doc.id);
        var downvoted = downvotedSet.contains(doc.id);
        var commented = commentedSet.contains(doc.id);
        bool skipPost = false;
        if (upvoted) {
          upvoteStatus = UpvotedStatus.Upvoted;
        } else if (downvoted) {
          upvoteStatus = UpvotedStatus.Downvoted;
        }
        if (!skipPost) {
          cardsData.add(CardData(
              posterId: doc.get('userid'),
              id: doc.id,
              author: doc.get('author'),
              score: doc.get('score'),
              text: doc.get('body'),
              status: upvoteStatus,
              comments: doc.get('commentsNum'),
              commented: commented));
        }
      }
    } catch (e) {
      print(e);
    }
    if (lambda != null) lambda();
  }

  Future<void> getNextBatch({Function lambda, bool trending}) async {
    try {
      var userDataSnapshotList = await _firestoreInstance
          .collection('users')
          .where('uid', isEqualTo: GlobalController.get().currentUserUid)
          .get();
      var userDataSnapshot = userDataSnapshotList.docs[0];

      var upvotedSet = userDataSnapshot.get('upvoted').toSet();
      var downvotedSet = userDataSnapshot.get('downvoted').toSet();
      var commentedSet = userDataSnapshot.get('commented').toSet();
      QuerySnapshot snapshot;
      UpvotedStatus upvoteStatus = UpvotedStatus.DidntVote;
      var timestamp = await getCurrentTimestampServer();
      if (!trending) {
        snapshot = await _firestoreInstance
            .collection('posts')
            .orderBy('postTime', descending: true)
            .where('postTime', isGreaterThan: timestamp - TIME_TILL_DISCARD)
            .get();
      } else {
        snapshot = await _firestoreInstance
            .collection('posts')
            .where('postTime', isGreaterThan: timestamp - TIME_TILL_DISCARD)
            .get();
      }
      var doxs = snapshot.docs;
      if (trending) {
        doxs.sort((a, b) {
          return b.get('score').compareTo(a.get('score'));
        });
      }
      cardsData.clear();
      for (var doc in doxs) {
        upvoteStatus = UpvotedStatus.DidntVote;
        var upvoted = upvotedSet.contains(doc.id);
        var downvoted = downvotedSet.contains(doc.id);
        var commented = commentedSet.contains(doc.id);
        bool skipPost = false;
        if (!trending && (upvoted || downvoted)) {
          skipPost = true;
        } else if (trending) {
          if (upvoted) {
            upvoteStatus = UpvotedStatus.Upvoted;
          } else if (downvoted) {
            upvoteStatus = UpvotedStatus.Downvoted;
          }
        }
        if (!skipPost) {
          cardsData.add(CardData(
              posterId: doc.get('userid'),
              id: doc.id,
              author: doc.get('author'),
              score: doc.get('score'),
              text: doc.get('body'),
              status: upvoteStatus,
              comments: doc.get('commentsNum'),
              commented: commented));
        }
      }
    } catch (e) {
      print(e);
    }
    if (lambda != null) lambda();
  }

  CardData peekNextCard() {
    if (cardsData.isEmpty) {
      return null;
    } else {
      return cardsData[0];
    }
  }

  CardData getNextCard() {
    if (cardsData.isEmpty)
      return null;
    else {
      CardData data = cardsData[0];
      cardsData.removeAt(0);
      return data;
    }
  }
}
