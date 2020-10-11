import 'package:flutter/material.dart';
import 'package:ideashack/Const.dart';
import 'package:autocomplete_textfield/autocomplete_textfield.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:dotted_line/dotted_line.dart';
import 'Analytics.dart';

class SearchScreen extends StatefulWidget {
  SearchScreen(this.callback);
  Function callback;
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).requestFocus(new FocusNode());
      },
      child: SizedBox.expand(
        child: Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(
              colors: [Color(0xFFDBDBDB), Color(0xFFFFFFFF)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            )),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 20,
                ),
                Center(child: Image.asset('assets/search.png', width: 100)),
                SizedBox(height: 20),
                Center(
                  child: Text('Search by tags',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: disabledUpperBarColor)),
                ),
                SizedBox(height: 20),
                SearchBar(widget.callback),
                SizedBox(height: 50),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text('Popular Tags', style: enabledUpperBarStyle),
                ),
                SizedBox(height: 40),
                PopularTags(widget.callback),
              ],
            )),
      ),
    );
  }
}

class PopularTags extends StatefulWidget {
  PopularTags(this.callback);
  Function callback;
  @override
  _PopularTagsState createState() => _PopularTagsState();
}

class _PopularTagsState extends State<PopularTags> {
  Future<QuerySnapshot> popularSnapshot;
  @override
  void initState() {
    super.initState();
    popularSnapshot = Firestore.instance
        .collection('hashtags')
        .orderBy('popularity', descending: true)
        .limit(20)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FutureBuilder(
          future: popularSnapshot,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.active ||
                snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                  child: SpinKitThreeBounce(size: 50, color: Colors.white));
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text('Something went wrong...',
                      style: disabledUpperBarStyle));
            }
            List<Widget> children = [];
            for (DocumentSnapshot item in snapshot.data.docs) {
              children.add(TagData(
                  item.get('tag'), item.get('popularity'), widget.callback));
            }
            return ListView(children: children);
          }),
    );
  }
}

class TagData extends StatelessWidget {
  TagData(this.tag, this.score, this.callback);
  final String tag;
  final int score;
  final Function callback;
  @override
  void tabCallback() {
    AnalyticsController.get().searchIdeaHashtagClicked(tag);
    callback(tag);
  }

  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 30),
      child: InkWell(
        onTap: tabCallback,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(tag, style: disabledUpperBarStyle),
            Expanded(
              child: DottedLine(
                dashColor: Colors.grey,
                lineThickness: 1,
                dashLength: 2,
                dashGapLength: 2,
              ),
            ),
            Text(score.toString() + ' stars',
                style: disabledUpperBarStyle.copyWith(
                    color: Colors.grey, fontWeight: FontWeight.w100))
          ],
        ),
      ),
    );
  }
}

class SearchBar extends StatefulWidget {
  @override
  _SearchBarState createState() => _SearchBarState();
  SearchBar(this.callback);
  final Function callback;
}

class _SearchBarState extends State<SearchBar> {
  Future<QuerySnapshot> snapshot;
  String searchString = "#";
  TextEditingController controller;
  Stream<QuerySnapshot> querySnapshot;
  GlobalKey key;
  GlobalKey key1;
  GlobalKey key2;
  bool hasFocus = false;
  @override
  void initState() {
    key = GlobalKey<AutoCompleteTextFieldState<String>>();
    key1 = GlobalKey<AutoCompleteTextFieldState<String>>();
    key2 = GlobalKey<AutoCompleteTextFieldState<String>>();
    snapshot = Firestore.instance
        .collection('hashtags')
        .orderBy('popularity', descending: true)
        .limit(HASH_TAG_LIMIT)
        .get();
    controller = TextEditingController(text: searchString);
    querySnapshot = Firestore.instance
        .collection('hashtags')
        .orderBy('popularity', descending: true)
        .limit(5)
        .snapshots();
    super.initState();
  }

  void callback() {
    print("TRIGGERED");
    widget.callback(searchString);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: snapshot,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active ||
              snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 50,
                        child: StreamBuilder(
                            stream: querySnapshot,
                            builder: (context, snapshot) {
                              List<String> suggestions = [];
                              if (snapshot.data != null &&
                                  snapshot.data.docs != null)
                                for (var doc in snapshot.data.docs) {
                                  suggestions.add(doc.get('tag'));
                                }
                              return SimpleAutoCompleteTextField(
                                decoration: InputDecoration(
                                  hintText: 'Search tags...',
                                  enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                    color: Colors.grey,
                                  )),
                                  disabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                    color: Colors.grey,
                                  )),
                                  border: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                    color: Colors.grey,
                                  )),
                                ),
                                style: TextStyle(color: disabledUpperBarColor),
                                suggestionsAmount: 5,
                                textSubmitted: (string) {
                                  print('submited');
                                  searchString = string;
                                  AnalyticsController.get()
                                      .hashTagSearched(string);
                                  callback();
                                },
                                controller: controller,
                                key: key2,
                                suggestions: suggestions,
                                textChanged: (str) {
                                  setState(() {
                                    querySnapshot = Firestore.instance
                                        .collection('hashtags')
                                        .where('tag',
                                            isGreaterThanOrEqualTo: str)
                                        .where('tag',
                                            isLessThanOrEqualTo: str + '\uf8ff')
                                        .limit(HASH_TAG_LIMIT)
                                        .snapshots();
                                    searchString = str;
                                  });
                                },
                              );
                            }),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            return Container(
                child: Center(child: Text('Could not fetch tags...')));
          } else {
            if (snapshot.data == null || snapshot.data.docs == null) {
              return Container(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 50,
                          child: SimpleAutoCompleteTextField(
                            decoration: InputDecoration(
                              hintText: 'Search tags...',
                              enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                color: Colors.grey,
                              )),
                              disabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                color: Colors.grey,
                              )),
                              border: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                color: Colors.grey,
                              )),
                            ),
                            style: TextStyle(color: disabledUpperBarColor),
                            suggestionsAmount: 5,
                            textSubmitted: (string) {
                              AnalyticsController.get().hashTagSearched(string);
                              searchString = string;
                              callback();
                            },
                            onFocusChanged: (hasFocus) {},
                            key: key1,
                            suggestions: [],
                            textChanged: (str) {
                              searchString = str;
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else {
              return Container(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 50,
                          child: StreamBuilder(
                              stream: querySnapshot,
                              builder: (context, snapshot) {
                                List<String> suggestionss = [];
                                if (snapshot.data != null &&
                                    snapshot.data.docs != null)
                                  for (var doc in snapshot.data.docs) {
                                    suggestionss.add(doc.get('tag'));
                                  }
                                AutoCompleteTextFieldState<String> state =
                                    key.currentState;
                                if (state != null) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((timeStamp) {
                                    state.updateSuggestionsFocus(
                                        suggestions: suggestionss,
                                        hasFocus: hasFocus);
                                  });
                                }
                                return SimpleAutoCompleteTextField(
                                  onFocusChanged: (focus) {
                                    hasFocus = focus;
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Search tags...',
                                    enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                      color: Colors.grey,
                                    )),
                                    disabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                      color: Colors.grey,
                                    )),
                                    border: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                      color: Colors.grey,
                                    )),
                                  ),
                                  style:
                                      TextStyle(color: disabledUpperBarColor),
                                  suggestionsAmount: 5,
                                  textSubmitted: (string) {
                                    AnalyticsController.get()
                                        .hashTagSearched(string);
                                    print('submited');
                                    searchString = string;
                                    callback();
                                  },
                                  controller: controller,
                                  key: key,
                                  suggestions: suggestionss,
                                  textChanged: (str) {
                                    setState(() {
                                      querySnapshot = Firestore.instance
                                          .collection('hashtags')
                                          .where('tag',
                                              isGreaterThanOrEqualTo: str)
                                          .where('tag',
                                              isLessThanOrEqualTo:
                                                  str + '\uf8ff')
                                          .limit(HASH_TAG_LIMIT)
                                          .snapshots();
                                      searchString = str;
                                    });
                                  },
                                );
                              }),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          }
        });
  }
}
