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
        bool commented = doc
            .get('commented')
            .toSet()
            .contains(GlobalController.get().currentUserUid);
        userCardsData.add(CardData(
            id: doc.id,
            author: doc.get('author'),
            score: doc.get('score'),
            text: doc.get('body'),
            comments: doc.get('comments'),
            commented: commented));
      }
    } catch (e) {
      print(e + "HELLO3");
    }
    if (lambda != null) lambda();
  }

  Future<void> getNextBatch({Function lambda, bool trending}) async {
    try {
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
        var upvoted = doc.get('postUpvoted');
        var downvoted = doc.get('postDownvoted');
        bool skipPost = false;
        if (!trending &&
            (upvoted.toSet().contains(GlobalController.get().currentUserUid) ||
                downvoted
                    .toSet()
                    .contains(GlobalController.get().currentUserUid))) {
          skipPost = true;
        } else if (trending) {
          if (upvoted.toSet().contains(GlobalController.get().currentUserUid)) {
            upvoteStatus = UpvotedStatus.Upvoted;
          } else if (downvoted
              .toSet()
              .contains(GlobalController.get().currentUserUid)) {
            upvoteStatus = UpvotedStatus.Downvoted;
          }
        }
        if (!skipPost) {
          bool commented = doc
              .get('commented')
              .toSet()
              .contains(GlobalController.get().currentUserUid);
          cardsData.add(CardData(
              id: doc.id,
              author: doc.get('author'),
              score: doc.get('score'),
              text: doc.get('body'),
              status: upvoteStatus,
              comments: doc.get('comments'),
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
