import 'dart:async';

import 'package:aptos_infinite_jukebox/common.dart';
import 'package:aptos_infinite_jukebox/vote_results_page.dart';
import 'package:flutter/material.dart';

import 'page_selector.dart';

class MakeVotePage extends StatefulWidget {
  const MakeVotePage({Key? key, required this.pageSelectorController})
      : super(key: key);

  final PageSelectorController pageSelectorController;

  @override
  State<MakeVotePage> createState() => MakeVotePageState();
}

class MakeVotePageState extends State<MakeVotePage> {
  late Future<void> initStateAsyncFuture;

  final _searchFieldController = TextEditingController();

  // A list of Spotify track IDs I believe.
  // Or perhaps an object that will have the track name, artist, etc. in it.
  List<String> searchResults = [];

  // This will be set once the user selects the song they want to vote for.
  String? selectedResult;

  @override
  void initState() {
    super.initState();
    initStateAsyncFuture = initStateAsync();
  }

  Future<void> initStateAsync() async {}

  // Limit this to 25 or something.
  // Or dynamically generate the cards as the user scrolls.
  // Something to avoid fetching all those images.
  List<String> searchSpotify(String searchTerm) {
    // TODO
    return ["test"];
  }

  void search(String searchTerm) {
    setState(() {
      if (searchTerm == "") {
        searchResults = [];
      } else {
        searchResults = searchSpotify(searchTerm);
      }
    });
  }

  void clearSearch() {
    setState(() {
      searchResults = [];
      _searchFieldController.clear();
    });
  }

  Widget buildListWidget(BuildContext context) {
    return ListView.builder(
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        return ListTile(title: buildSongListItem(searchResults[index]));
      },
    );
  }

  // This input will need to be a spotify track object instead that lets me
  // get an image for the leading piece.
  Widget buildSongListItem(String item, {bool includeClearButton = false}) {
    Widget? trailing;
    if (includeClearButton) {
      trailing = IconButton(
        icon: Icon(Icons.cancel),
        onPressed: () {
          setState(() {
            selectedResult = null;
          });
        },
      );
    }
    return Card(
        child: ListTile(
      leading: Text("todo make this a small image"),
      title: Text("Song name"),
      subtitle: Text("Song artist"),
      trailing: trailing,
      onTap: () {
        setState(() {
          selectedResult = item;
        });
      },
    ));
  }

  Widget buildSearchWidget(BuildContext context) {
    Widget body = Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 10, left: 32, right: 32, top: 0),
              child: Form(
                  key: ValueKey("searchPage.searchForm"),
                  child: Column(children: <Widget>[
                    TextField(
                      controller: _searchFieldController,
                      decoration: InputDecoration(
                        hintText: 'Search Spotify for a song',
                        suffixIcon: IconButton(
                          onPressed: () {
                            clearSearch();
                          },
                          icon: Icon(Icons.clear),
                        ),
                      ),
                      // The validator receives the text that the user has entered.
                      onChanged: (String value) {
                        search(value);
                      },
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      keyboardType: TextInputType.visiblePassword,
                      autocorrect: false,
                    ),
                  ])),
            ),
            Expanded(
              child: buildListWidget(context),
            ),
          ],
        ),
      ),
    );
    return body;
  }

  // When doing this, darken the page and display a circular loading indicator
  // with maybe some text explaining what the app is doing.
  // This should return some object either explaining success or failure.
  // We should then pushReplacement a new page showing what happened.
  Future<void> submitVote() async {
    print("todo");
    // todo submit the transaction, wait for it.
    // Push the results page. When we come back here, pop immediately.
    bool success = true;
    String explanation = "hey";
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => VoteResultsPage(
                widget.pageSelectorController, success, explanation)));

    // If we're hear, it means the user has looked at the results of the
    // vote attempt. Pop immediately back to the root voting page.
    Navigator.pop(context, success);
  }

  Widget buildSongSelectedWidget(BuildContext context) {
    String ss = selectedResult!;

    return Column(
      children: [
        Padding(
            padding: EdgeInsets.all(18),
            child: buildSongListItem(ss, includeClearButton: true)),
        // Include some settings here around, e.g. max gas spend,
        // Show the user the current balance of their wallet.
        // Use a futurebuilder but just inline the future here.
        Expanded(child: Container()),
        Padding(
            padding: EdgeInsets.only(bottom: 30),
            child: getConnectionButton("Submit Vote", submitVote)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Disable swipe back with WillPopScope, only hitting the back button
    // or casting a vote (which will trigger a scope pop manually) is allowed.
    // This is necessary because you can't define a return value from just
    // swiping back right now.
    Widget body;
    if (selectedResult == null) {
      body = buildSearchWidget(context);
    } else {
      body = buildSongSelectedWidget(context);
    }

    return WillPopScope(
        child: buildTopLevelScaffold(widget.pageSelectorController, body,
            title: "Vote",
            isSubPage: true,
            leadingAppBarButton: IconButton(
                icon: Icon(Icons.close),
                onPressed: () {
                  Navigator.of(context).pop(false);
                })),
        onWillPop: () async => false);
  }

  @override
  void dispose() {
    super.dispose();
  }
}
