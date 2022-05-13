import 'dart:async';

import 'package:aptos_infinite_jukebox/globals.dart';
import 'package:aptos_infinite_jukebox/playback_manager.dart';
import 'package:aptos_infinite_jukebox/player_page.dart';
import 'package:flutter/material.dart';
import 'package:spotify_sdk/models/connection_status.dart';
import 'package:spotify_sdk/models/player_state.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

import 'common.dart';

// TODO DELETE THIS PAGE ONCE OYU KNOW THE REFACTOR WORKS

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
      print("Getting new access token");
      setState(() {
        awaitingReturnFromConnectionAttempt = true;
      });
      String? scope;
      if (onWeb) {
        scope = spotifyAccessTokenScope;
      }
      String accessToken = await SpotifySdk.getAccessToken(
        clientId: spotifyClientId,
        redirectUrl: spotifyRedirectUrl,
        scope: scope,
      );
      // Don't bother storing the token on web.
      if (!onWeb) {
        await sharedPreferences.setString(keySpotifyAccessToken, accessToken);
      }
      print("Got new access token");
      await connectToSpotify(accessToken);
    } catch (e) {
      await sharedPreferences.remove(keySpotifyAccessToken);
      setState(() {
        connectErrorString = "$e";
        awaitingReturnFromConnectionAttempt = false;
        tunedIn = false;
      });
      print("Failed to get new access token");
    }
  }

  Future<void> connectToSpotify(String accessToken) async {
    try {
      print("Trying to connect to Spotify");
      setState(() {
        awaitingReturnFromConnectionAttempt = true;
      });
      await SpotifySdk.connectToSpotifyRemote(
        clientId: spotifyClientId,
        redirectUrl: spotifyRedirectUrl,
        // TOOD: See whether we need this for web.
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
      print("Failed to connect to Spotify: $e");
    }
  }

  Widget getNoAccessTokenScreen({String? errorString}) {
    // This is janky but I'm only subscribed to the connection status
    // in the builder, so I have to schedule this state change here.
    // Perhaps I need some out of band thing to subscribe to it also?
    WidgetsBinding.instance!.addPostFrameCallback((_) => setState(() {
          if (tunedIn) {
            print("Setting tunedIn to false due to disconnection");
            tunedIn = false;
          }
        }));
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
        Text("Disconnected from Spotify: $errorString"),
      ];
    }
    children += [getConnectionButton("Connect to Spotify", getNewAccessToken)];
    return Column(children: children);
  }

  Future<void> tuneIn() async {
    await SpotifySdk.pause();
    await setupPlayer();
    setState(() {
      tunedIn = true;
    });
    Timer.periodic(Duration(seconds: 10), (timer) async {
      if (!tunedIn) {
        print("Tuned out, cancelling timer");
        timer.cancel();
      }
      print("Checking for queue / playback updates");
      await updateQueue();
    });
  }

  Future<void> checkWhetherInSync() async {
    PlayerState? playerState = await SpotifySdk.getPlayerState();
    if (playerState != null) {
      // With the way the voting works, the player will somtimes say it is
      // out of sync near the end of a song, since the head will have updated
      // but we're still finishing off the previous song. If we're in the last
      // 10 seconds of the song, we just assume we're in sync.
      bool nearEndOfSong = false;
      if (playerState.track != null) {
        nearEndOfSong =
            playerState.track!.duration - playerState.playbackPosition < 10000;
      }
      bool withinToleranceForPlaybackPosition =
          (playbackManager.getTargetPlaybackPosition() -
                      playerState.playbackPosition)
                  .abs() <
              outOfSyncThresholdMilli;
      bool playingCorrectSong = true;
      if (playerState.track != null &&
          playbackManager.headOfRemoteQueue != null) {
        playingCorrectSong =
            playerState.track!.uri.endsWith(playbackManager.headOfRemoteQueue!);
      }
      print(
          "withinToleranceForPlaybackPosition: $withinToleranceForPlaybackPosition");
      print("playingCorrectSong: $playingCorrectSong");
      bool inSync = withinToleranceForPlaybackPosition &&
          (playingCorrectSong || nearEndOfSong);
      setState(() {
        outOfSync = !inSync;
      });
    }
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
    await checkWhetherInSync();
  }

  // TODO: There seems to be a bug where we skip a song in the queue for some reason.
  // Particularly I think you need to tune in, let it advance to the next song,
  // then observe that it is playing the wrong song. Though on later testing
  // it seems correct, perhaps I just hadn't manually cleared the queue properly.
  // TODO: Over time we expect some sync drift. Be a little smarter about resyncing
  // if the user requests it, where instead of adding everything to queue, we
  // just seek to correct location if the correct song is playing.
  // TODO: With the way the voting works, the player will often say it is
  // out of sync near the end of a song, since the head will have updated but
  // we're still finishing off the previous song. If we're in the last 10 seconds
  // of the song, assume we're in sync.
  Future<void> setupPlayer() async {
    // Unfortunately there is no way to clear a queue, but realistically
    // we need a way to do this here, otherwise it's going to get all fucky.
    // Calling skipNext a bunch of times first leads to poor results.
    playbackManager.headOfRemoteQueue = null;
    playbackManager.latestConsumedTrack = null;
    await updateQueue();
    int playbackPosition = playbackManager.getTargetPlaybackPosition();
    print("Playback position: $playbackPosition");
    if (playbackPosition > 0) {
      // We should already be playing the track, start playing it.
      await SpotifySdk.skipNext();
      await SpotifySdk.seekTo(positionedMilliseconds: playbackPosition);
      //await playTrack(playbackManager.targetTrackId,
      //   playbackPosition: playbackPosition);
      await checkWhetherInSync();
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
        await checkWhetherInSync();
      });
    }
  }

  Widget buildWithScaffold(Widget body) {
    return Scaffold(
        body: Center(
            child: Column(
      children: [body],
      mainAxisAlignment: MainAxisAlignment.center,
    )));
  }

  Widget getConnectionButton(String text, void Function() onPressed) {
    Border? border;
    return Container(
        padding: EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
        decoration: BoxDecoration(
            color: Color.fromRGBO(101, 212, 110, 1.0),
            border: border,
            borderRadius: BorderRadius.all(Radius.circular(20))),
        child: TextButton(
            onPressed: onPressed,
            style: ButtonStyle(
              foregroundColor: MaterialStateProperty.all(Colors.white),
            ),
            child: Text(
              text,
              style: TextStyle(fontSize: 18),
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
              var button = getConnectionButton("Tune in", tuneIn);
              return buildWithScaffold(button);
            } else {
              return PlayerPage(trackAboutToStart, outOfSync, setupPlayer);
            }
          }
        });

    return widget;
  }
}
