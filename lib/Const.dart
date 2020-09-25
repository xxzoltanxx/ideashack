import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bad_words/bad_words.dart';

//GLOBAL LIFECYCLE VARIABLES, I KNOW ITS SHIT I JUST STARTED USING FLUTTER

const double ICON_SELECT_SIZE = 30;
const Color OVERLAY_STUFF_COLOR = Colors.white60;
const Color OVERLAY_STUFF_COLOR_SECONDARY = Color(0x55c2c2c2);
const int minimumCharactersForPost = 55;
const TextStyle MAIN_CARD_TEXT_STYLE = TextStyle(
  fontFamily: 'Merriweather',
  fontSize: 20,
);
const TextStyle AUTHOR_CARD_TEXT_STYLE = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w100, fontStyle: FontStyle.italic);
const TextStyle LOGINTEXTSTYLE =
    TextStyle(fontSize: 20, fontWeight: FontWeight.w300, color: Colors.black45);
const TextStyle SPLASH_TEXT_STYLE =
    TextStyle(fontSize: 50, fontWeight: FontWeight.w700, color: Colors.white);
const String loremIpsum =
    'Lorem Ipsum is simply dummy text for dumb motherfuckers and designers.';
CardData testCardData =
    CardData(text: loremIpsum, score: 20, author: 'Anonymous');

const int MAX_SCORE = 100;
const double TIME_TILL_DISCARD = MONTH / 4;
const double MAX_POST_DAILY_LIMIT = 4;
const double BASE_DAILY_POSTS = 3;
const int TRENDING_CARD_LIMIT = 90;

String formatedNumberString(int num) {
  if (num > 1000000) {
    return '${(num / 1000000)}m';
  } else if (num > 1000) {
    return '${(num / 1000)}k';
  } else {
    return num.toString();
  }
}

enum InfoSheet {
  Posted,
  Commented,
  Profane,
}

enum UpvotedStatus { DidntVote, Upvoted, Downvoted }

class CardData {
  CardData(
      {@required this.text,
      @required this.score,
      @required this.author,
      @required this.id,
      this.comments,
      this.status,
      this.commented});
  String text;
  int score;
  String author;
  String id;
  List<dynamic> comments;
  UpvotedStatus status;
  bool commented;
}

const int MONTH = 2629743;

class GlobalController {
  static GlobalController _instance;

  static GlobalController get() {
    if (_instance == null) {
      _instance = GlobalController();
    }
    return _instance;
  }

  int selectedIndex = 1;
  String currentUserUid = "";
  int dailyPosts = 4;
  bool fetchingDailyPosts = false;
  String userDocUid = null;

  void checkLastTimestampsAndUpdatePosts(Function callback) async {
    try {
      fetchingDailyPosts = true;
      final now = await getCurrentTimestampServer();
      DateTime time =
          new DateTime.fromMillisecondsSinceEpoch((now * 1000).toInt());
      final lastMidnight = new DateTime(time.year, time.month, time.day);

      final nowseconds = now;
      final lastMidnightSeconds = lastMidnight.millisecondsSinceEpoch / 1000;

      var user = await Firestore.instance
          .collection('users')
          .where('uid', isEqualTo: currentUserUid)
          .get();
      if (userDocUid == null) {
        userDocUid = user.docs[0].id;
      }
      double lastSeen = user.docs[0].get('lastSeen');
      //lol
      int dailyyPosts = user.docs[0].get('dailyPosts').toInt();
      if (lastMidnightSeconds > lastSeen) {
        if (dailyyPosts < BASE_DAILY_POSTS) {
          await Firestore.instance.collection('users').doc(userDocUid).update({
            'lastSeen': nowseconds,
            'dailyPosts': BASE_DAILY_POSTS,
          });
          dailyyPosts = BASE_DAILY_POSTS.toInt();
        }
      } else {
        await Firestore.instance
            .collection('users')
            .doc(userDocUid)
            .update({'lastSeen': nowseconds});
      }
      dailyPosts = dailyyPosts;
      fetchingDailyPosts = false;
    } catch (e) {
      print(e);
    }
    callback(dailyPosts);
  }
}

Future<double> getCurrentTimestampServer() async {
  await Firestore.instance
      .collection('timestamp')
      .doc('1')
      .update({'timestamp': FieldValue.serverTimestamp()});
  var timestampField =
      await Firestore.instance.collection('timestamp').doc('1').get();
  var timestamp = timestampField.get('timestamp').millisecondsSinceEpoch / 1000;
  return timestamp;
}

final spamFilter = Filter();
