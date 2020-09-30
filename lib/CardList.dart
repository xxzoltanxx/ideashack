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
        var commentedArr = await _firestoreInstance
            .collection('posts')
            .doc(doc.id)
            .collection('data')
            .where('commented',
                arrayContains: GlobalController.get().currentUserUid)
            .get();
        bool commented = commentedArr.docs.length > 0;
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
      print(tag);
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
        var upvoted = await _firestoreInstance
            .collection('posts')
            .doc(doc.id)
            .collection('data')
            .where('postUpvoted',
                arrayContains: GlobalController.get().currentUserUid)
            .get();
        var downvoted = await _firestoreInstance
            .collection('posts')
            .doc(doc.id)
            .collection('data')
            .where('postDownvoted',
                arrayContains: GlobalController.get().currentUserUid)
            .get();
        var commentedArr = await _firestoreInstance
            .collection('posts')
            .doc(doc.id)
            .collection('data')
            .where('commented',
                arrayContains: GlobalController.get().currentUserUid)
            .get();
        bool skipPost = false;
        if (upvoted.docs.length > 0) {
          upvoteStatus = UpvotedStatus.Upvoted;
        } else if (downvoted.docs.length > 0) {
          upvoteStatus = UpvotedStatus.Downvoted;
        }
        if (!skipPost) {
          bool commented = commentedArr.docs.length > 0;
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
        var upvoted = await _firestoreInstance
            .collection('posts')
            .doc(doc.id)
            .collection('data')
            .where('postUpvoted',
                arrayContains: GlobalController.get().currentUserUid)
            .get();
        var downvoted = await _firestoreInstance
            .collection('posts')
            .doc(doc.id)
            .collection('data')
            .where('postDownvoted',
                arrayContains: GlobalController.get().currentUserUid)
            .get();
        var commentedArr = await _firestoreInstance
            .collection('posts')
            .doc(doc.id)
            .collection('data')
            .where('commented',
                arrayContains: GlobalController.get().currentUserUid)
            .get();
        bool skipPost = false;
        if (!trending &&
            (upvoted.docs.length > 0 || downvoted.docs.length > 0)) {
          skipPost = true;
        } else if (trending) {
          if (upvoted.docs.length > 0) {
            upvoteStatus = UpvotedStatus.Upvoted;
          } else if (downvoted.docs.length > 0) {
            upvoteStatus = UpvotedStatus.Downvoted;
          }
        }
        if (!skipPost) {
          bool commented = commentedArr.docs.length > 0;
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
