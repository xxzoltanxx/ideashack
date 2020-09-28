import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'Const.dart';

class OverlayWidget extends StatefulWidget {
  OverlayWidget({this.setTrendingFunc, this.noCards, this.trending});
  final Function setTrendingFunc;
  final bool noCards;
  final bool trending;
  @override
  _OverlayWidgetState createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;
  bool sortingByNew = true;

  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 100),
    );
    _controller.addListener(() {
      setState(() {});
    });
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
                onTap: () {
                  widget.setTrendingFunc(false);
                },
                child: Text('New')),
            SizedBox(width: 20),
            GestureDetector(
                onTap: () {
                  widget.setTrendingFunc(true);
                },
                child: Text('Trending'))
          ],
        ),
        Container(
            child: Align(
          alignment: Alignment.bottomRight,
          child: Stack(children: [
            Transform.scale(
              alignment: Alignment.centerLeft,
              scale: _controller.value,
              child: Container(
                  child: Row(children: [
                GestureDetector(
                  onTap: () {
                    _controller.animateBack(0.0);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white12,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child:
                          Icon(FontAwesomeIcons.times, size: ICON_SELECT_SIZE),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child:
                      Icon(FontAwesomeIcons.facebook, size: ICON_SELECT_SIZE),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(FontAwesomeIcons.twitter, size: ICON_SELECT_SIZE),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child:
                      Icon(FontAwesomeIcons.whatsapp, size: ICON_SELECT_SIZE),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(FontAwesomeIcons.sms, size: ICON_SELECT_SIZE),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child:
                      Icon(FontAwesomeIcons.instagram, size: ICON_SELECT_SIZE),
                ),
              ])),
            ),
            GestureDetector(
              onTap: () {
                _controller.forward();
              },
              child: Transform.scale(
                scale: (1 - _controller.value),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white12,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(FontAwesomeIcons.share,
                        size: ICON_SELECT_SIZE, color: OVERLAY_STUFF_COLOR),
                  ),
                ),
              ),
            ),
          ]),
        )),
      ],
    );
  }
}
