import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
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

  void logInCompletedEvent() {
    analytics.logEvent(name: 'logedIn', parameters: getBaseData());
  }

  void consentGiven() {
    analytics.logEvent(name: 'consentGiven', parameters: getBaseData());
  }

  void modalPopupShown(String type) {
    Map<String, dynamic> parameters = getBaseData();
    parameters.addAll({'type': type});
    analytics.logEvent(name: 'modalPopupShown', parameters: parameters);
  }

  void registerModalPopupTapped() {
    analytics.logEvent(name: 'modalPopupRegister', parameters: getBaseData());
  }

  void logAppLaunched() async {
    await analytics.logAppOpen();
  }

  void commentTapped() {
    analytics.logEvent(name: 'commentTapped', parameters: getBaseData());
  }

  void messageTapped() {
    analytics.logEvent(name: 'messageTapped', parameters: getBaseData());
  }

  void tabSelected(String tab) {
    Map<String, dynamic> parameters = getBaseData();
    parameters.addAll({'tab': tab});
    analytics.logEvent(name: 'tabSelected', parameters: parameters);
  }

  void searchIdeaHashtagClicked(String hashtag) {
    Map<String, dynamic> parameters = getBaseData();
    parameters.addAll({'tag': hashtag});
    analytics.logEvent(
        name: 'searchIdeaHashtagClicked', parameters: parameters);
  }

  void hashTagSearched(String hashtag) {
    Map<String, dynamic> parameters = getBaseData();
    parameters.addAll({'tag': hashtag});
    analytics.logEvent(
        name: 'searchIdeaHashtagSearched', parameters: parameters);
  }

  void hashTagCardClicked(String hashtag) {
    Map<String, dynamic> parameters = getBaseData();
    parameters.addAll({'tag': hashtag});
    analytics.logEvent(name: 'cardHashTagClicked', parameters: parameters);
  }

  void shareIdeaEntered() {
    analytics.logEvent(name: 'shareIdeaEntered', parameters: getBaseData());
  }

  void userPanelEntered() {
    analytics.logEvent(name: 'userPanelEntered', parameters: getBaseData());
  }

  void userPanelRegisterTapped() {
    analytics.logEvent(
        name: 'userPanelRegisterTapped', parameters: getBaseData());
  }

  void browseIdeaEntered() {
    analytics.logEvent(name: 'browseIdeasEntered', parameters: getBaseData());
  }

  void userRegistered() {
    analytics.logEvent(name: 'userRegistered', parameters: getBaseData());
  }

  void upvoted(String postId) {
    Map<String, dynamic> parameters = getBaseData();
    parameters.addAll({'postId': postId});
    analytics.logEvent(name: 'upvoted', parameters: parameters);
  }

  void downvoted(String postId) {
    Map<String, dynamic> parameters = getBaseData();
    parameters.addAll({'postId': postId});
    analytics.logEvent(name: 'downvoted', parameters: parameters);
  }

  void reportTappedPost(String postId) {
    Map<String, dynamic> parameters = getBaseData();
    parameters.addAll({'postId': postId});
    analytics.logEvent(name: 'reportTappedPost', parameters: parameters);
  }

  void shareClicked() {
    analytics.logEvent(name: 'shareClicked', parameters: getBaseData());
  }

  void shareTabClicked(String type) {
    Map<String, dynamic> parameters = getBaseData();
    parameters.addAll({'type': type});
    analytics.logEvent(name: 'shareTabClicked', parameters: parameters);
  }

  void deleteIdeaTapped(String postid) {
    Map<String, dynamic> parameters = getBaseData();
    parameters.addAll({'postId': postid});
    analytics.logEvent(name: 'deleteIdeaTapped', parameters: parameters);
  }

  void viewCommentsTapped(String postId) {
    Map<String, dynamic> parameters = getBaseData();
    parameters.addAll({'postId': postId});
    analytics.logEvent(name: 'viewCommentsTapped', parameters: parameters);
  }

  void adShown() {
    analytics.logEvent(name: 'adShown', parameters: getBaseData());
  }

  void postedComment(String postId, String commentId) {
    Map<String, dynamic> parameters = getBaseData();
    parameters.addAll({'postId': postId, 'commentId': commentId});
    analytics.logEvent(name: 'postedComment', parameters: parameters);
  }

  void reportTappedComment(String postId, String commentId) {
    Map<String, dynamic> parameters = getBaseData();
    parameters.addAll({'postId': postId, 'commentId': commentId});
    analytics.logEvent(name: 'reportTappedComment', parameters: parameters);
  }

  void browseEndReached() {
    analytics.logEvent(name: 'browseEndReached', parameters: getBaseData());
  }

  void loadingBatch() {
    analytics.logEvent(name: 'loadingBatch', parameters: getBaseData());
  }

  void swiped() {
    analytics.logEvent(name: 'swiped', parameters: getBaseData());
  }

  void dmSent() {
    analytics.logEvent(name: 'dmSent', parameters: getBaseData());
  }

  void dmInitialized() {
    analytics.logEvent(name: 'dmInitialized', parameters: getBaseData());
  }
}
