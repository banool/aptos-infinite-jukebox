import 'dart:async';

import 'package:aptos_infinite_jukebox/globals.dart';
import 'package:aptos_infinite_jukebox/playback_manager.dart';
import 'package:aptos_infinite_jukebox/player_page.dart';
import 'package:flutter/material.dart';
import 'package:spotify_sdk/models/connection_status.dart';
import 'package:spotify_sdk/models/player_state.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

import 'common.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? connectErrorString;

  late Future<void> initStateAsyncFuture;

  bool awaitingReturnFromConnectionAttempt = false;

  bool tunedIn = false;
  bool trackAboutToStart = false;
  bool outOfSync = false;

  @override
  void initState() {
    super.initState();
    initStateAsyncFuture = initStateAsync();
  }

  Future<void> initStateAsync() async {
    String? accessToken = sharedPreferences.getString(keySpotifyAccessToken);
    if (accessToken != null) {
      print("Access token found on launch: $accessToken");
      await connectToSpotify(accessToken);
    }
  }

  // TODO: Put a timeout on this.
  Future<void> getNewAccessToken() async {
    try {
      setState(() {
        awaitingReturnFromConnectionAttempt = true;
      });
      String accessToken = await SpotifySdk.getAccessToken(
        clientId: spotifyClientId,
        redirectUrl: spotifyRedirectUrl, /*scope: spotifyAccessTokenScope*/
      );
      await sharedPreferences.setString(keySpotifyAccessToken, accessToken);
      await connectToSpotify(accessToken);
    } catch (e) {
      await sharedPreferences.remove(keySpotifyAccessToken);
      setState(() {
        connectErrorString = "$e";
        awaitingReturnFromConnectionAttempt = false;
        tunedIn = false;
      });
    }
  }

  Future<void> connectToSpotify(String accessToken) async {
    try {
      setState(() {
        awaitingReturnFromConnectionAttempt = true;
      });
      await SpotifySdk.connectToSpotifyRemote(
        clientId: spotifyClientId,
        redirectUrl: spotifyRedirectUrl,
        //scope: spotifyAccessTokenScope,
        playerName: appTitle,
        accessToken: accessToken,
      );
      setState(() {
        awaitingReturnFromConnectionAttempt = false;
      });
      print("Successfully connected to Spotify");
    } catch (e) {
      await sharedPreferences.remove(keySpotifyAccessToken);
      setState(() {
        connectErrorString = "$e";
        awaitingReturnFromConnectionAttempt = false;
        tunedIn = false;
      });
    }
  }

  Widget getNoAccessTokenScreen({String? errorString}) {
    if (awaitingReturnFromConnectionAttempt) {
      return Column(
        children: const [
          Text("Waiting for authentication with Spotify to complete"),
          Padding(
              padding: EdgeInsets.only(top: 20),
              child: Center(
                child: CircularProgressIndicator(),
              )),
        ],
      );
    }
    List<Widget> children = [];
    if (errorString != null) {
      children += [
        Text("Try again:"),
        Text("Error from previous connection attempt: $errorString"),
      ];
    }
    children += [
      TextButton(
          child: Text("Connect to Spotify"), onPressed: getNewAccessToken)
    ];
    return Column(children: children);
  }

  Future<void> tuneIn() async {
    await SpotifySdk.pause();
    await setupPlayer();
    setState(() {
      tunedIn = true;
    });
    Timer.periodic(Duration(seconds: 10), (_) {
      print("Checking for queue / playback updates");
      updateQueue();
    });
  }

  /// Call this function periodically to ensure that new songs are added to
  /// the queue and we know whether we're in sync with the expected playback.
  Future<void> updateQueue() async {
    List<String> tracksToQueue = await playbackManager.pull();
    for (String trackId in tracksToQueue) {
      var spotifyUri = "spotify:track:$trackId";
      await SpotifySdk.queue(spotifyUri: spotifyUri);
      print("Added track to queue: $spotifyUri");
    }
    PlayerState? playerState = await SpotifySdk.getPlayerState();
    if (playerState != null) {
      setState(() {
        bool withinToleranceForPlaybackPosition =
            (playbackManager.getTargetPlaybackPosition() -
                        playerState.playbackPosition)
                    .abs() >
                outOfSyncThresholdMilli;
        // TODO: Check that we're playing the correct song too perhaps.
        outOfSync = withinToleranceForPlaybackPosition;
      });
    }
  }

  Future<void> setupPlayer() async {
    // Unfortunately there is no way to clear a queue, but realistically
    // we need a way to do this here.
    await updateQueue();
    int playbackPosition = playbackManager.getTargetPlaybackPosition();
    print("Playback position: $playbackPosition");
    if (playbackPosition > 0) {
      // We should already be playing the track, start playing it.
      await SpotifySdk.skipNext();
      await SpotifySdk.seekTo(positionedMilliseconds: playbackPosition);
      //await playTrack(playbackManager.targetTrackId,
      //   playbackPosition: playbackPosition);
    } else {
      // The track will start soon. Schedule it for then.
      setState(() {
        trackAboutToStart = true;
      });
      Future.delayed(Duration(milliseconds: -playbackPosition), () async {
        await SpotifySdk.skipNext();
        setState(() {
          trackAboutToStart = false;
        });
      });
    }
  }

  /*
  Future<void> playTrack(String trackId, {int? playbackPosition}) async {
    await SpotifySdk.queue(spotifyUri: uri);
    if (playbackPosition != null) {
      await SpotifySdk.seekTo(positionedMilliseconds: playbackPosition);
    }
    setState(() {
      trackAboutToStart = false;
    });
    var playerState = await SpotifySdk.getPlayerState();
    var trackLengthMilliseconds = playerState!.track!.duration;
    // Handle the case where we try to scrub to a position in the song after
    // the end of the track. This can happen if the driver isn't working.
    // In this case we want to stop playing again. Unfortunately we have to
    // check this here since we don't know the song duration until we play it.
    // Update: TODO: This doesn't work well, it plays the song for a moment,
    // then it ends, then Spotify just plays another song related to that song.
    /*
    if (playbackPosition != null &&
        playbackPosition > trackLengthMilliseconds) {
      await SpotifySdk.pause();
      // Set this so we check again in 1 second.
      trackLengthMilliseconds = 1000;
    }
    */
    int delay = trackLengthMilliseconds - (playbackPosition ?? 0);
    Future.delayed(Duration(milliseconds: delay), () async {
      print("Reached end of song, pausing player");
      await SpotifySdk.pause();
      // TODO I think the best way to make this actually work is to use the
      // queue function. Similarly, the smart contract should maintain said
      // queue, so clients can queue up the next 10 songs and periodically
      // check in to add more songs to the queue. This is easier than trying
      // to time playing the next song with the driver.
      // TODO: I need a button that lets users resync with the intended
      // playback position if they fall a bit out of sync.
      await syncPlayer();
    });
    // TODO: Also, make it that if tunedIn turns to false, cancel that timer.
    // Also make it that tunedIn turns to false if the connection breaks.
    // Perhaps tunedIn should be deprecated in favor of subscribing to the player state.
  }
  */

  Widget buildWithScaffold(Widget body) {
    return Scaffold(
        body: Center(
            child: Column(
      children: [body],
      mainAxisAlignment: MainAxisAlignment.center,
    )));
  }

  @override
  Widget build(BuildContext context) {
    Widget widget = StreamBuilder<ConnectionStatus>(
        stream: SpotifySdk.subscribeConnectionStatus(),
        builder: (context, snapshot) {
          if (snapshot.data == null) {
            return buildWithScaffold(getNoAccessTokenScreen());
          }
          ConnectionStatus connectionStatus = snapshot.data!;

          String? errorString;
          if (connectionStatus.errorCode != null) {
            errorString =
                "Error from Spotify SDK: ${connectionStatus.errorCode}: ${connectionStatus.errorDetails}";
          } else if (connectErrorString != null) {
            errorString = connectErrorString;
          }

          if (errorString != null) {
            return buildWithScaffold(
                getNoAccessTokenScreen(errorString: errorString));
          }

          if (!connectionStatus.connected) {
            // TODO: If there is an access token in storage,
            // handle that here. Likely it means something went
            // wrong elsewhere but we didn't wipe the access token.
            return buildWithScaffold(getNoAccessTokenScreen());
          } else {
            if (!tunedIn) {
              return buildWithScaffold(TextButton(
                onPressed: tuneIn,
                child: Text("Tune in"),
              ));
            } else {
              return PlayerPage(trackAboutToStart);
            }
          }
        });

    return widget;
  }
}
