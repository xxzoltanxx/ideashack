import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:ideashack/Const.dart';
import 'dart:ui' as ui;

class AnalyticsController {
  static AnalyticsController instance;

  static AnalyticsController get() {
    if (instance == null) {
      instance = AnalyticsController();
    }
    return instance;
  }

  void init() {
    analytics = FirebaseAnalytics();
    observer = FirebaseAnalyticsObserver(analytics: analytics);
  }

  FirebaseAnalytics analytics;
  FirebaseAnalyticsObserver observer;

  void setUserId() {
    analytics.setUserId(GlobalController.get().currentUser.uid);
  }

  Map<String, dynamic> getBaseData() {
    return {
      'uid': GlobalController.get().currentUser.uid,
      'locale': ui.window.locale.languageCode,
      'isAnonymous': GlobalController.get().currentUser.isAnonymous,
      'time': getCurrentTimestampLocal()
    };
  }

  void logInCompletedEvent() async {
    try {
      await analytics.logEvent(name: 'logedIn', parameters: getBaseData());
    } catch (e) {
      print(e);
    }
  }

  void consentGiven() async {
    try {
      await analytics.logEvent(name: 'consentGiven', parameters: getBaseData());
    } catch (e) {
      print(e);
    }
  }

  void modalPopupShown(String type) async {
    try {
      Map<String, dynamic> parameters = getBaseData();
      parameters.addAll({'type': type});
      await analytics.logEvent(name: 'modalPopupShown', parameters: parameters);
    } catch (e) {}
  }

  void registerModalPopupTapped() async {
    try {
      await analytics.logEvent(
          name: 'modalPopupRegister', parameters: getBaseData());
    } catch (E) {}
  }

  void logAppLaunched() async {
    try {
      await analytics.logAppOpen();
    } catch (e) {}
  }

  void commentTapped() async {
    try {
      await analytics.logEvent(
          name: 'commentTapped', parameters: getBaseData());
    } catch (e) {}
  }

  void messageTapped() async {
    try {
      await analytics.logEvent(
          name: 'messageTapped', parameters: getBaseData());
    } catch (e) {}
  }

  void tabSelected(String tab) async {
    try {
      Map<String, dynamic> parameters = getBaseData();
      parameters.addAll({'tab': tab});
      await analytics.logEvent(name: 'tabSelected', parameters: parameters);
    } catch (e) {}
  }

  void searchIdeaHashtagClicked(String hashtag) async {
    try {
      Map<String, dynamic> parameters = getBaseData();
      parameters.addAll({'tag': hashtag});
      await analytics.logEvent(
          name: 'searchIdeaHashtagClicked', parameters: parameters);
    } catch (e) {}
  }

  void hashTagSearched(String hashtag) async {
    try {
      Map<String, dynamic> parameters = getBaseData();
      parameters.addAll({'tag': hashtag});
      await analytics.logEvent(
          name: 'searchIdeaHashtagSearched', parameters: parameters);
    } catch (e) {}
  }

  void hashTagCardClicked(String hashtag) async {
    try {
      Map<String, dynamic> parameters = getBaseData();
      parameters.addAll({'tag': hashtag});
      await analytics.logEvent(
          name: 'cardHashTagClicked', parameters: parameters);
    } catch (e) {}
  }

  void shareIdeaEntered() async {
    try {
      await analytics.logEvent(
          name: 'shareIdeaEntered', parameters: getBaseData());
    } catch (e) {}
  }

  void userPanelEntered() async {
    try {
      await analytics.logEvent(
          name: 'userPanelEntered', parameters: getBaseData());
    } catch (e) {}
  }

  void userPanelRegisterTapped() async {
    try {
      await analytics.logEvent(
          name: 'userPanelRegisterTapped', parameters: getBaseData());
    } catch (e) {}
  }

  void browseIdeaEntered() async {
    try {
      await analytics.logEvent(
          name: 'browseIdeasEntered', parameters: getBaseData());
    } catch (e) {}
  }

  void userRegistered() async {
    try {
      await analytics.logEvent(
          name: 'userRegistered', parameters: getBaseData());
    } catch (e) {}
  }

  void upvoted(String postId) async {
    try {
      Map<String, dynamic> parameters = getBaseData();
      parameters.addAll({'postId': postId});
      await analytics.logEvent(name: 'upvoted', parameters: parameters);
    } catch (e) {}
  }

  void downvoted(String postId) async {
    try {
      Map<String, dynamic> parameters = getBaseData();
      parameters.addAll({'postId': postId});
      await analytics.logEvent(name: 'downvoted', parameters: parameters);
    } catch (e) {}
  }

  void reportTappedPost(String postId) async {
    try {
      Map<String, dynamic> parameters = getBaseData();
      parameters.addAll({'postId': postId});
      await analytics.logEvent(
          name: 'reportTappedPost', parameters: parameters);
    } catch (e) {}
  }

  void shareClicked() async {
    try {
      await analytics.logEvent(name: 'shareClicked', parameters: getBaseData());
    } catch (e) {}
  }

  void shareTabClicked(String type) async {
    try {
      Map<String, dynamic> parameters = getBaseData();
      parameters.addAll({'type': type});
      await analytics.logEvent(name: 'shareTabClicked', parameters: parameters);
    } catch (e) {}
  }

  void deleteIdeaTapped(String postid) async {
    try {
      Map<String, dynamic> parameters = getBaseData();
      parameters.addAll({'postId': postid});
      await analytics.logEvent(
          name: 'deleteIdeaTapped', parameters: parameters);
    } catch (e) {}
  }

  void viewCommentsTapped(String postId) async {
    try {
      Map<String, dynamic> parameters = getBaseData();
      parameters.addAll({'postId': postId});
      await analytics.logEvent(
          name: 'viewCommentsTapped', parameters: parameters);
    } catch (e) {}
  }

  void adShown() async {
    try {
      await analytics.logEvent(name: 'adShown', parameters: getBaseData());
    } catch (e) {}
  }

  void postedComment(String postId, String commentId) async {
    try {
      Map<String, dynamic> parameters = getBaseData();
      parameters.addAll({'postId': postId, 'commentId': commentId});
      await analytics.logEvent(name: 'postedComment', parameters: parameters);
    } catch (e) {}
  }

  void reportTappedComment(String postId, String commentId) async {
    try {
      Map<String, dynamic> parameters = getBaseData();
      parameters.addAll({'postId': postId, 'commentId': commentId});
      await analytics.logEvent(
          name: 'reportTappedComment', parameters: parameters);
    } catch (e) {}
  }

  void browseEndReached() async {
    try {
      await analytics.logEvent(
          name: 'browseEndReached', parameters: getBaseData());
    } catch (e) {}
  }

  void loadingBatch() async {
    try {
      await analytics.logEvent(name: 'loadingBatch', parameters: getBaseData());
    } catch (e) {}
  }

  void swiped() async {
    try {
      await analytics.logEvent(name: 'swiped', parameters: getBaseData());
    } catch (e) {}
  }

  void dmSent() async {
    try {
      await analytics.logEvent(name: 'dmSent', parameters: getBaseData());
    } catch (e) {}
  }

  void dmInitialized() async {
    try {
      await analytics.logEvent(
          name: 'dmInitialized', parameters: getBaseData());
    } catch (e) {}
  }
}
