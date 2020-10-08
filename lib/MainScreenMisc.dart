import 'package:flutter/material.dart';
import 'package:social_share/social_share.dart';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/rendering.dart';
import 'dart:io';
import 'package:social_share/social_share.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:typed_data';

class DislikeIndicator extends StatelessWidget {
  DislikeIndicator(this.animationProgress, this.didSwipe, this.opacity);

  double opacity;
  double animationProgress;
  bool didSwipe;
  @override
  Widget build(BuildContext context) {
    if (!didSwipe) {
      animationProgress = opacity / 255.0;
    }
    if (didSwipe && opacity == 0) {
      animationProgress = 0;
    }
    return Center(
      child: Transform.scale(
          scale: (didSwipe && opacity != 0) ? 1 : animationProgress,
          child: Transform.rotate(
              angle: 3.14,
              child: Image.asset('assets/thumbs-up.png',
                  width: 200,
                  color: didSwipe
                      ? Color.lerp(Colors.white, Colors.red, animationProgress)
                      : Colors.white))),
    );
  }
}

class LikeIndicator extends StatelessWidget {
  LikeIndicator(this.animationProgress, this.didSwipe, this.opacity);

  double animationProgress;
  bool didSwipe;
  double opacity;
  @override
  Widget build(BuildContext context) {
    if (!didSwipe) {
      animationProgress = opacity / 255.0;
    }
    if (didSwipe && opacity == 0) {
      animationProgress = 0;
    }
    return Center(
      child: Transform.scale(
        scale: (didSwipe && opacity != 0) ? 1 : animationProgress,
        child: Image.asset('assets/thumbs-up.png',
            width: 200,
            color: didSwipe
                ? Color.lerp(Colors.white, Colors.green, animationProgress)
                : Colors.white),
      ),
    );
  }
}

class DeleteIdeaPopup extends StatefulWidget {
  DeleteIdeaPopup(this.future, this.callback);
  Future<void> future;
  Function callback;
  @override
  _DeleteIdeaPopupState createState() => _DeleteIdeaPopupState();
}

class _DeleteIdeaPopupState extends State<DeleteIdeaPopup> {
  bool triggeredCallback = false;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: Text('Deleting idea...'),
        content: FutureBuilder(
          future: widget.future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting ||
                snapshot.connectionState == ConnectionState.active) {
              return Container(
                width: 200,
                height: 200,
                child: Center(
                    child: SpinKitThreeBounce(color: Colors.white, size: 50)),
              );
            }
            if (snapshot.connectionState == ConnectionState.done) {
              if (!triggeredCallback) {
                WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                  widget.callback();
                });
                triggeredCallback = true;
              }
              return Container(
                  width: 200,
                  height: 200,
                  child: Center(child: Text('Deleted!')));
            }
            return Container(
              width: 200,
              height: 200,
              child: Center(
                  child: SpinKitThreeBounce(color: Colors.white, size: 50)),
            );
          },
        ));
  }
}

class ReportPopup extends StatefulWidget {
  ReportPopup(this.future, this.anonymous, this.reported);
  final bool reported;
  final Future<void> future;
  final bool anonymous;
  @override
  _ReportPopupState createState() => _ReportPopupState();
}

class _ReportPopupState extends State<ReportPopup> {
  @override
  Widget build(BuildContext context) {
    if (widget.reported) {
      return AlertDialog(
          title: Text("Reporting..."),
          content: Container(
              width: 200,
              height: 200,
              child: Center(
                  child: Text(
                'You already reported this post!',
                textAlign: TextAlign.center,
              ))));
    }
    return AlertDialog(
        title: Text("Reporting..."),
        content: FutureBuilder(
          future: widget.future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting ||
                snapshot.connectionState == ConnectionState.active) {
              return Container(
                  child: Center(
                      child:
                          SpinKitThreeBounce(size: 50, color: Colors.white)));
            }
            if (snapshot.hasError) {
              return Container(
                  width: 200,
                  height: 200,
                  child: Center(
                      child: Text(
                    'Something went wrong, try again!',
                    textAlign: TextAlign.center,
                  )));
            }
            if (snapshot.connectionState == ConnectionState.done) {
              String text;
              if (widget.anonymous == true) {
                text =
                    "Report received, bear in mind that anonymous reports don't hold much value";
              } else {
                text = "Report received! We'll look into it!";
              }
              return Container(
                  width: 200,
                  height: 200,
                  child: Center(
                      child: Text(
                    text,
                    textAlign: TextAlign.center,
                  )));
            }
            return Container(
                child: Center(
                    child: SpinKitThreeBounce(size: 50, color: Colors.white)));
          },
        ));
  }
}

class SharePopup extends StatefulWidget {
  SharePopup(this.repaint, this.text);
  RenderRepaintBoundary repaint;
  String text;
  @override
  _SharePopupState createState() => _SharePopupState();
}

class _SharePopupState extends State<SharePopup> {
  Future<void> imageConstructFuture;
  ui.Image image;
  ByteData byteData;
  String pathStr;

  Future<void> getImageBytes() async {
    image = await widget.repaint.toImage();
    byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory path = await getApplicationDocumentsDirectory();
    pathStr = path.path + '/share.png';
    new File(pathStr).writeAsBytes(byteData.buffer
        .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    print(pathStr);
  }

  @override
  void initState() {
    imageConstructFuture = getImageBytes();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Center(child: Text('Share')),
      content: FutureBuilder(
        future: imageConstructFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active ||
              snapshot.connectionState == ConnectionState.waiting) {
            return Container(
                width: 200,
                height: 200,
                child: SpinKitThreeBounce(color: Colors.white));
          }
          if (image == null) {
            image = snapshot.data;
          }
          return Container(
              width: 200,
              height: 350,
              child: Column(
                children: [
                  Image.memory(byteData.buffer.asUint8List(), height: 100),
                  SizedBox(height: 20),
                  InkWell(
                    onTap: () {
                      Platform.isAndroid
                          ? SocialShare.shareFacebookStory(
                              pathStr,
                              "#ffffff",
                              "#000000",
                              "https://www.google.com",
                              appId: '240400507128183',
                            )
                          : SocialShare.shareFacebookStory(
                              pathStr,
                              "#ffffff",
                              "#000000",
                              "https://www.google.com",
                            );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Share on facebook'),
                        Icon(FontAwesomeIcons.facebookSquare)
                      ],
                    ),
                  ),
                  SizedBox(height: 30),
                  InkWell(
                    onTap: () {
                      SocialShare.shareTwitter('${widget.text}',
                          hashtags: ['spark', 'idea', 'changetheworld'],
                          url: 'http://test.com',
                          trailingText:
                              'download Spark for more brilliant ideas');
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Share on twitter'),
                        Icon(FontAwesomeIcons.twitterSquare)
                      ],
                    ),
                  ),
                  SizedBox(height: 30),
                  InkWell(
                    onTap: () {
                      SocialShare.shareInstagramStory(pathStr, "#ffffff",
                          "#000000", "https://deep-link-url");
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Share on instagram'),
                        Icon(FontAwesomeIcons.instagramSquare)
                      ],
                    ),
                  ),
                  SizedBox(height: 30),
                  InkWell(
                    onTap: () {
                      SocialShare.shareSms(
                          '${widget.text} - download Spark for more brilliant ideas',
                          url: "",
                          trailingText: "");
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Share via SMS'),
                        Icon(FontAwesomeIcons.sms)
                      ],
                    ),
                  )
                ],
              ));
        },
      ),
    );
  }
}
