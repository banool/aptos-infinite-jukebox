import 'dart:async';

import 'package:flutter/material.dart';
import 'package:spotify_sdk/models/player_state.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

import 'common.dart';
import 'globals.dart';
import 'page_selector.dart';
import 'playback_manager.dart';
import 'player_page.dart';

class LoggedInPage extends StatefulWidget {
  const LoggedInPage({Key? key, required this.pageSelectorController})
      : super(key: key);

  final PageSelectorController pageSelectorController;

  @override
  State<LoggedInPage> createState() => LoggedInPageState();
}

class LoggedInPageState extends State<LoggedInPage> {
  bool outOfSync = false;
  bool trackAboutToStart = false;

  /*
  // This is janky but I'm only subscribed to the connection status
  // in the builder, so I have to schedule this state change here.
  // Perhaps I need some out of band thing to subscribe to it also?
  WidgetsBinding.instance!.addPostFrameCallback((_) => setState(() {
        if (tunedIn) {
          print("Setting tunedIn to false due to disconnection");
          tunedIn = false;
        }
      }));
  */

  Future<void> tuneIn() async {
    await SpotifySdk.pause();
    await setupPlayer();
    setState(() {
      widget.pageSelectorController.tunedIn = true;
    });
    Timer.periodic(Duration(seconds: 10), (timer) async {
      if (!widget.pageSelectorController.tunedIn) {
        print("Tuned out, cancelling timer");
        timer.cancel();
        return;
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

  @override
  Widget build(BuildContext context) {
    if (widget.pageSelectorController.tunedIn) {
      return PlayerPage(trackAboutToStart, outOfSync, setupPlayer);
    }

    List<Widget> children = [];
    children += [getConnectionButton("Tune in!", tuneIn)];

    Widget body = Center(
        child: Column(
      children: children,
      mainAxisAlignment: MainAxisAlignment.center,
    ));
    return buildTopLevelScaffold(widget.pageSelectorController, body);
  }
}
