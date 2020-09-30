import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bad_words/bad_words.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

//GLOBAL LIFECYCLE VARIABLES, I KNOW ITS SHIT I JUST STARTED USING FLUTTER

const double ICON_SELECT_SIZE = 30;
const Color OVERLAY_STUFF_COLOR = Colors.white60;
const Color OVERLAY_STUFF_COLOR_SECONDARY = Color(0x55c2c2c2);
const int minimumCharactersForPost = 55;
const TextStyle MAIN_CARD_TEXT_STYLE = TextStyle(
  fontSize: 25,
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

const double TIME_TILL_DISCARD = MONTH / 4;
const double MAX_POST_DAILY_LIMIT = 4;
const double BASE_DAILY_POSTS = 3;
const int TRENDING_CARD_LIMIT = 90;
const int HASH_TAG_LIMIT = 30;

const Color bottomLeftEnd = Color(0xFFE0C82D);
const Color topRightEnd = Color(0xFFE5D831);

const Color bottomLeftStart = Color(0xFFBF6600);
const Color topRightStart = Color(0xFFC47802);

const Color disabledUpperBarColor = Color(0xFF666666);
const Color enabledUpperBarColor = Color(0xFF494949);

const TextStyle enabledUpperBarStyle = TextStyle(
  color: enabledUpperBarColor,
  fontWeight: FontWeight.bold,
);

const TextStyle disabledOnReloadStyle = TextStyle(color: Color(0x99666666));

const TextStyle enabledOnReloadStyle =
    TextStyle(color: Color(0x99494949), fontWeight: FontWeight.bold);
const TextStyle disabledUpperBarStyle = TextStyle(
  color: disabledUpperBarColor,
);

const TextStyle cardThingsTextStyle =
    TextStyle(color: Color(0xBF894100), fontSize: 20);
const TextStyle cardThingsBelowTextStyle = TextStyle(
    color: Color(0xFF894100), fontSize: 20, fontWeight: FontWeight.bold);
const double cardthingspadding = 8.0;

const Color spinnerColor = Color(0xBFFFFFFF);

const List<Color> splashScreenColors = [Color(0xFFED8A00), Color(0xFFF29C03)];
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
      this.commented,
      this.posterId});
  String text;
  int score;
  String author;
  String id;
  int comments;
  UpvotedStatus status;
  bool commented;
  String posterId;
}

const int MONTH = 2629743;

class GlobalController {
  static GlobalController _instance;
  final FirebaseMessaging firebaseMessaging = FirebaseMessaging();

  static GlobalController get() {
    if (_instance == null) {
      _instance = GlobalController();
    }
    return _instance;
  }

  QueryDocumentSnapshot parameters;
  int MAX_SCORE = 100;
  String encryptionKey;
  int selectedIndex = 1;
  String currentUserUid = "";
  int dailyPosts = 4;
  bool fetchingDailyPosts = false;
  User currentUser = null;
  String fetchToken;
  String serverKey;
  double timeOnStartup;
  String userDocId;

  void initParameters() {
    serverKey = parameters.get('serbian');
  }

  String getUserName() {
    return currentUser.displayName;
  }

  Future<bool> callOnFcmApiSendPushNotifications(
      List<String> userToken, String title, String body, String tag) async {
    final postUrl = 'https://fcm.googleapis.com/fcm/send';
    final data = {
      "priority": "high",
      "registration_ids": userToken,
      "collapse_key": "type_a",
      "notification": {
        "title": title,
        "body": body,
        "sound": "default",
        "tag": tag,
      }
    };

    final headers = {
      'content-type': 'application/json',
      'Authorization': serverKey, // 'key=YOUR_SERVER_KEY'
    };

    final response = await http.post(postUrl,
        body: json.encode(data),
        encoding: Encoding.getByName('utf-8'),
        headers: headers);

    if (response.statusCode == 200) {
      // on success do sth
      print('test ok push CFM');
      return true;
    } else {
      print(' CFM error');
      // on failure do sth
      return false;
    }
  }

  Future<String> fetchPushToken() async {
    fetchToken = await firebaseMessaging.getToken();
    return fetchToken;
  }

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
      if (userDocId == null) {
        userDocId = user.docs[0].id;
      }
      double lastSeen = user.docs[0].get('lastSeen');
      //lol
      int dailyyPosts = user.docs[0].get('dailyPosts').toInt();
      if (lastMidnightSeconds > lastSeen) {
        if (dailyyPosts < BASE_DAILY_POSTS) {
          await Firestore.instance.collection('users').doc(userDocId).update({
            'lastSeen': nowseconds,
            'dailyPosts': BASE_DAILY_POSTS,
          });
          dailyyPosts = BASE_DAILY_POSTS.toInt();
        }
      } else {
        await Firestore.instance
            .collection('users')
            .doc(userDocId)
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

enum CommentsErrorCode { DidntInitializeData, FailedToInitialize }

Future<dynamic> myBackgroundMessageHandler(Map<String, dynamic> message) async {
  if (message.containsKey('data')) {
    // Handle data message
    final dynamic data = message['data'];
  }

  if (message.containsKey('notification')) {
    // Handle notification message
    final dynamic notification = message['notification'];
  }

  // Or do other work.
}

String truncateWithEllipsis(int cutoff, String myString) {
  return (myString.length <= cutoff)
      ? myString
      : '${myString.substring(0, cutoff)}...';
}

enum SelectTab { Trending, New, Custom }
