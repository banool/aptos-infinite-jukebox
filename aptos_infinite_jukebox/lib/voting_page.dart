import 'dart:async';

import 'package:aptos_sdk_dart/aptos_sdk_dart.dart';
import 'package:built_value/json_object.dart';
import 'package:flutter/material.dart';

import 'common.dart';
import 'constants.dart';
import 'globals.dart';
import 'make_vote_page.dart';
import 'page_selector.dart';

class VotingPage extends StatefulWidget {
  const VotingPage({Key? key, required this.pageSelectorController})
      : super(key: key);

  final PageSelectorController pageSelectorController;

  @override
  State<VotingPage> createState() => VotingPageState();
}

class VotingPageState extends State<VotingPage> {
  late Future<void> initStateAsyncFuture;

  Map<String, int> votes = {};
  String? myVote;

  Timer? checkVotesTimer;

  int queueIndex = 0;

  @override
  void initState() {
    super.initState();
    initStateAsyncFuture = initStateAsync();
    // TODO: Only rebuild on queue changes, not out of sync changes.
    playbackManager.addListener(() {
      print("Rebuilding because playbackManager changed");
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> initStateAsync() async {
    //await updateMyVote();
    //await updateOthersVotes();
    checkVotesTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      //updateMyVote();
      //updateOthersVotes();
    });
  }

  // Get the vote the user made this round.
  Future<void> updateMyVote() async {
    String aptosNodeUrl =
        sharedPreferences.getString(keyAptosNodeUrl) ?? defaultAptosNodeUrl;
    String publicAddress =
        sharedPreferences.getString(keyJukeboxAddress) ?? defaultJukeboxAddress;

    AptosClientHelper aptosClientHelper =
        AptosClientHelper.fromBaseUrl(aptosNodeUrl);

    // Get table handle.
    String? tableHandleRaw = sharedPreferences.getString(keyVotesTableHandle);

    String tableHandle;
    if (tableHandleRaw != null) {
      print("Using table handle from cache");
      tableHandle = tableHandleRaw;
    } else {
      // Pull resources.
      AccountResource resource;
      try {
        resource = await unwrapClientCall(aptosClientHelper.client
            .getAccountsApi()
            .getAccountResource(
                address: publicAddress, resourceType: buildResourceType()));
        // Process info from the resources.
        var inner = resource.data.asMap["inner"];
        tableHandle = inner["next_song_votes"]["handle"];
        print("Retrieved table handle from account resources");
        await sharedPreferences.setString(keyVotesTableHandle, tableHandle);
      } catch (e) {
        print("Failed to pull resource to get table handle: $e");
        return;
      }
    }

    print("Table handle: $tableHandle");

    // Get the table item
    // TODO this doesn't work right now, the value type is wrong.
    // Perhaps this is the wrong approach and I should just use whatever
    // info I retrieved for getOthersVotes.
    TableItemRequest tableItemRequest = (TableItemRequestBuilder()
          ..key = JsonObject(aptosAccount!.address.withPrefix())
          ..keyType = "address"
          ..valueType = buildResourceType())
        .build();
    JsonObject obj;
    try {
      obj = await unwrapClientCall(aptosClientHelper.client
          .getTableApi()
          .getTableItem(
              tableHandle: tableHandle, tableItemRequest: tableItemRequest));
    } catch (e) {
      print("Failed to get table item: $e");
      return;
    }

    setState(() {
      myVote = obj.asMap["song"]["song"];
    });
  }

  // Get all the votes for this round.
  Future<void> updateOthersVotes() async {}

  Widget buildVoteWidgetNotLoggedIn(
      String text, String buttonText, int tabIndexToGoTo) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Padding(
          padding: EdgeInsets.only(left: 25, right: 25),
          child: Text(
            text,
            textAlign: TextAlign.center,
          )),
      Padding(padding: EdgeInsets.only(top: 30)),
      getConnectionButton(buttonText,
          () => widget.pageSelectorController.goToTab(tabIndexToGoTo)),
    ]);
  }

  // TODO: Some page should probably show the current queue.
  // I could do this based on the on chain state, since I need to be able to
  // convert from track ID to track title and back anyway sort of.
  Widget buildVoteWidgetLoggedIn() {
    return getConnectionButton("Vote for a song", () async {
      bool voteSuccess = await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => MakeVotePage(
                  pageSelectorController: widget.pageSelectorController)));
      if (voteSuccess) {
        print("Vote was committed successfully, updating voting state");
        // We should only get to this point if the user voted and
        // we confirmed the transaction was committed.
        await updateMyVote();
        await updateOthersVotes();
      }
    });
  }

  Widget buildVoteSummaryWidget() {
    return FutureBuilder(
        future: initStateAsyncFuture,
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return CircularProgressIndicator();
          }
          return Text("Vote summary");
        });
  }

  Widget buildMyVoteWidget() {
    return FutureBuilder(
        future: initStateAsyncFuture,
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return CircularProgressIndicator();
          }
          if (myVote == null) {
            return Text("You haven't voted in this round");
          }
          return Text("Your vote: ${myVote!}");
        });
  }

  Widget buildUpcomingSongsWidget() {
    if (playbackManager.headOfRemoteQueue == null) {
      return Text("Tune in to see the track queue");
    }
    return FutureBuilder(
        future: playbackManager.fetchQueueTracksFuture,
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.error != null) {
            return Text(
                "Error fetching upcoming track info: ${snapshot.error}");
          }
          return SizedBox(
              height: 80,
              child: PageView.builder(
                itemCount: playbackManager.lastSeenQueueTracks!.length,
                controller: PageController(viewportFraction: 0.6),
                onPageChanged: (int index) =>
                    setState(() => queueIndex = index),
                itemBuilder: (_, i) {
                  return Transform.scale(
                    scale: i == queueIndex ? 1 : 1,
                    child: buildSongListItem(
                        playbackManager.lastSeenQueueTracks![i]),
                  );
                },
              ));
        });
  }

  @override
  Widget build(BuildContext context) {
    Widget voteWidget;
    if (privateKey == null) {
      voteWidget = buildVoteWidgetNotLoggedIn(
          "You must set the private key for your Aptos account in order to vote.",
          "Go to Settings",
          2);
    } else if (spotifyApi == null) {
      voteWidget = buildVoteWidgetNotLoggedIn(
          "You must be logged in to Spotify to vote (to search for songs)",
          "Go to Player",
          0);
    } else {
      voteWidget = buildVoteWidgetLoggedIn();
    }

    Widget body = Column(
      children: [
        Padding(
            padding: EdgeInsets.only(top: 30, bottom: 30),
            child: buildMyVoteWidget()),
        Padding(
            padding: EdgeInsets.only(top: 30, bottom: 30),
            child: buildVoteSummaryWidget()),
        Spacer(),
        Padding(
            padding: EdgeInsets.only(bottom: 0),
            child: buildUpcomingSongsWidget()),
        Padding(
            padding: EdgeInsets.only(top: 50, bottom: 30), child: voteWidget),
      ],
    );

    return buildTopLevelScaffold(
        widget.pageSelectorController, Center(child: body),
        title: "Vote");
  }

  @override
  void dispose() {
    checkVotesTimer?.cancel();
    super.dispose();
  }
}
