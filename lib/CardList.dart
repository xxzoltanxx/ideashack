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

  DocumentSnapshot lastDocumentSnapshot;

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
          .where('hidden', isEqualTo: 0)
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
    resetLastDocumentSnapshot();
  }

  void resetLastDocumentSnapshot() {
    lastDocumentSnapshot = null;
  }

  Future<void> getByTag({Function lambda, String tag}) async {
    try {
      if (GlobalController.get().currentUser.isAnonymous) {
        QuerySnapshot snapshot;
        UpvotedStatus upvoteStatus = UpvotedStatus.DidntVote;
        var timestamp = await getCurrentTimestampServer();
        if (lastDocumentSnapshot != null) {
          snapshot = await _firestoreInstance
              .collection('posts')
              .where('hashtag', isEqualTo: tag)
              .orderBy('score', descending: true)
              .where('hidden', isEqualTo: 0)
              .startAfterDocument(lastDocumentSnapshot)
              .limit(QUERY_SIZE)
              .get();
        } else {
          snapshot = await _firestoreInstance
              .collection('posts')
              .where('hashtag', isEqualTo: tag)
              .orderBy('score', descending: true)
              .where('hidden', isEqualTo: 0)
              .limit(QUERY_SIZE)
              .get();
        }
        if (snapshot.docs.length == 0) {
          print("IT IS NULL");
        }
        var doxs = snapshot.docs;
        cardsData.clear();
        for (var doc in doxs) {
          upvoteStatus = UpvotedStatus.DidntVote;
          var upvoted = false;
          var downvoted = false;
          var commented = false;
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
        if (snapshot.docs.length < QUERY_SIZE) {
          lastDocumentSnapshot = null;
        } else {
          lastDocumentSnapshot = snapshot.docs.last;
        }
      } else {
        var userDataSnapshotList = await _firestoreInstance
            .collection('users')
            .where('uid', isEqualTo: GlobalController.get().currentUserUid)
            .get();
        var userDataSnapshot = userDataSnapshotList.docs[0];
        var upvotedSet = userDataSnapshot.get('upvoted').toSet();
        var downvotedSet = userDataSnapshot.get('downvoted').toSet();
        var commentedSet = userDataSnapshot.get('commented').toSet();
        var reportedSet = userDataSnapshot.get('reportedPosts').toSet();

        QuerySnapshot snapshot;
        UpvotedStatus upvoteStatus = UpvotedStatus.DidntVote;
        var timestamp = await getCurrentTimestampServer();
        if (lastDocumentSnapshot != null) {
          snapshot = await _firestoreInstance
              .collection('posts')
              .where('hashtag', isEqualTo: tag)
              .orderBy('score', descending: true)
              .where('hidden', isEqualTo: 0)
              .startAfterDocument(lastDocumentSnapshot)
              .limit(QUERY_SIZE)
              .get();
        } else {
          snapshot = await _firestoreInstance
              .collection('posts')
              .where('hashtag', isEqualTo: tag)
              .orderBy('score', descending: true)
              .where('hidden', isEqualTo: 0)
              .limit(QUERY_SIZE)
              .get();
        }
        if (snapshot.docs.length == 0) {
          print("IT IS NULL");
        }
        var doxs = snapshot.docs;
        cardsData.clear();
        for (var doc in doxs) {
          upvoteStatus = UpvotedStatus.DidntVote;
          var upvoted = upvotedSet.contains(doc.id);
          var downvoted = downvotedSet.contains(doc.id);
          var commented = commentedSet.contains(doc.id);
          var reported = reportedSet.contains(doc.id);
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
                commented: commented,
                reported: reported));
          }
        }
        if (snapshot.docs.length < QUERY_SIZE) {
          lastDocumentSnapshot = null;
        } else {
          lastDocumentSnapshot = snapshot.docs.last;
        }
      }
    } catch (e) {
      print(e);
    }
    if (lambda != null) lambda();
  }

  Future<void> getNextBatch({Function lambda, bool trending}) async {
    try {
      if (GlobalController.get().currentUser.isAnonymous) {
        QuerySnapshot snapshot;
        UpvotedStatus upvoteStatus = UpvotedStatus.DidntVote;
        var timestamp = await getCurrentTimestampServer();
        if (!trending) {
          if (lastDocumentSnapshot != null) {
            snapshot = await _firestoreInstance
                .collection('posts')
                .orderBy('postTime', descending: true)
                .where('hidden', isEqualTo: 0)
                .startAfterDocument(lastDocumentSnapshot)
                .limit(QUERY_SIZE)
                .get();
          } else {
            snapshot = await _firestoreInstance
                .collection('posts')
                .orderBy('postTime', descending: true)
                .where('hidden', isEqualTo: 0)
                .limit(QUERY_SIZE)
                .get();
          }
        } else {
          if (lastDocumentSnapshot != null) {
            snapshot = await _firestoreInstance
                .collection('posts')
                .orderBy('score', descending: true)
                .where('hidden', isEqualTo: 0)
                .startAfterDocument(lastDocumentSnapshot)
                .limit(QUERY_SIZE)
                .get();
          } else {
            snapshot = await _firestoreInstance
                .collection('posts')
                .orderBy('score', descending: true)
                .where('hidden', isEqualTo: 0)
                .limit(QUERY_SIZE)
                .get();
          }
        }
        var doxs = snapshot.docs;
        cardsData.clear();
        for (var doc in doxs) {
          upvoteStatus = UpvotedStatus.DidntVote;
          var upvoted = false;
          var downvoted = false;
          var commented = false;
          var reported = false;
          if (upvoted) {
            upvoteStatus = UpvotedStatus.Upvoted;
          } else if (downvoted) {
            upvoteStatus = UpvotedStatus.Downvoted;
          }
          cardsData.add(CardData(
              posterId: doc.get('userid'),
              id: doc.id,
              author: doc.get('author'),
              score: doc.get('score'),
              text: doc.get('body'),
              status: upvoteStatus,
              comments: doc.get('commentsNum'),
              commented: commented,
              reported: reported));
        }
        if (snapshot.docs.length < QUERY_SIZE) {
          lastDocumentSnapshot = null;
          print("LENGTH IS ZERO");
        } else {
          lastDocumentSnapshot = snapshot.docs.last;
        }
      } else {
        var userDataSnapshotList = await _firestoreInstance
            .collection('users')
            .where('uid', isEqualTo: GlobalController.get().currentUserUid)
            .get();
        var userDataSnapshot = userDataSnapshotList.docs[0];

        var upvotedSet = userDataSnapshot.get('upvoted').toSet();
        var downvotedSet = userDataSnapshot.get('downvoted').toSet();
        var commentedSet = userDataSnapshot.get('commented').toSet();
        var reportedSet = userDataSnapshot.get('reportedPosts').toSet();
        QuerySnapshot snapshot;
        UpvotedStatus upvoteStatus = UpvotedStatus.DidntVote;
        if (!trending) {
          if (lastDocumentSnapshot != null) {
            snapshot = await _firestoreInstance
                .collection('posts')
                .orderBy('postTime', descending: true)
                .where('hidden', isEqualTo: 0)
                .startAfterDocument(lastDocumentSnapshot)
                .limit(QUERY_SIZE)
                .get();
          } else {
            snapshot = await _firestoreInstance
                .collection('posts')
                .orderBy('postTime', descending: true)
                .where('hidden', isEqualTo: 0)
                .limit(QUERY_SIZE)
                .get();
          }
        } else {
          if (lastDocumentSnapshot != null) {
            snapshot = await _firestoreInstance
                .collection('posts')
                .orderBy('score', descending: true)
                .where('hidden', isEqualTo: 0)
                .startAfterDocument(lastDocumentSnapshot)
                .limit(QUERY_SIZE)
                .get();
          } else {
            snapshot = await _firestoreInstance
                .collection('posts')
                .orderBy('score', descending: true)
                .where('hidden', isEqualTo: 0)
                .limit(QUERY_SIZE)
                .get();
          }
        }
        var doxs = snapshot.docs;
        cardsData.clear();
        for (var doc in doxs) {
          upvoteStatus = UpvotedStatus.DidntVote;
          var upvoted = upvotedSet.contains(doc.id);
          var downvoted = downvotedSet.contains(doc.id);
          var commented = commentedSet.contains(doc.id);
          var reported = reportedSet.contains(doc.id);
          if (upvoted) {
            upvoteStatus = UpvotedStatus.Upvoted;
          } else if (downvoted) {
            upvoteStatus = UpvotedStatus.Downvoted;
          }
          cardsData.add(CardData(
              posterId: doc.get('userid'),
              id: doc.id,
              author: doc.get('author'),
              score: doc.get('score'),
              text: doc.get('body'),
              status: upvoteStatus,
              comments: doc.get('commentsNum'),
              commented: commented,
              reported: reported));
        }
        if (snapshot.docs.length < QUERY_SIZE) {
          lastDocumentSnapshot = null;
          print("LENGTH IS ZERO");
        } else {
          lastDocumentSnapshot = snapshot.docs.last;
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
