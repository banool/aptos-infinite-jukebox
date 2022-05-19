import 'dart:async';

import 'package:flutter/material.dart';
import 'package:spotify_sdk/models/player_state.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

import 'common.dart';
import 'globals.dart';
import 'page_selector.dart';
import 'playback_manager.dart';
import 'player_page.dart';

const Duration spotifyActionDelay = Duration(milliseconds: 1000);

class LoggedInPage extends StatefulWidget {
  const LoggedInPage({Key? key, required this.pageSelectorController})
      : super(key: key);

  final PageSelectorController pageSelectorController;

  @override
  State<LoggedInPage> createState() => LoggedInPageState();
}

class LoggedInPageState extends State<LoggedInPage> {
  bool trackAboutToStart = false;

  Timer? updateQueueTimer;
  Future? unpauseFuture;

  bool clearingQueue = false;

  Future<void> tuneIn() async {
    print("Tuning in");
    setState(() {
      widget.pageSelectorController.tunedInState = TunedInState.tuningIn;
    });
    try {
      await setupPlayer();
      setState(() {
        widget.pageSelectorController.tunedInState = TunedInState.tunedIn;
      });
      startUpdateQueueTimer();
    } catch (e) {
      setState(() {
        widget.pageSelectorController.tunedInState = TunedInState.tunedOut;
      });
    }
  }

  void startUpdateQueueTimer() {
    setState(() {
      updateQueueTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
        if (widget.pageSelectorController.tunedInState ==
            TunedInState.tunedOut) {
          print("Tuned out, cancelling timer");
          timer.cancel();
          return;
        }
        print("Checking for queue / playback updates");
        await updateQueue();
      });
    });
  }

  bool getWhetherPlayingCorrectSong(PlayerState playerState) {
    bool playingCorrectSong = true;
    if (playerState.track != null &&
        playbackManager.headOfRemoteQueue != null) {
      playingCorrectSong =
          playerState.track!.uri.endsWith(playbackManager.headOfRemoteQueue!);
    }
    return playingCorrectSong;
  }

  bool getWhetherWithinPlaybackPositionInTolerance(PlayerState playerState) {
    int targetPosition = playbackManager.getTargetPlaybackPosition();
    int actualPosition = playerState.playbackPosition;
    bool withinToleranceForPlaybackPosition =
        (targetPosition - actualPosition).abs() < outOfSyncThresholdMilli;

    print(
        "withinToleranceForPlaybackPosition: $withinToleranceForPlaybackPosition (defined as abs($targetPosition - $actualPosition) < $outOfSyncThresholdMilli)");
    return withinToleranceForPlaybackPosition;
  }

  Future<void> resyncIfSongCorrectAtWrongPlaybackPosition() async {
    PlayerState? playerState;
    try {
      playerState = await SpotifySdk.getPlayerState();
    } catch (e) {
      print(
          "Failed to get player state for trying to sync up playback position: $e");
      return;
    }
    if (getWhetherPlayingCorrectSong(playerState!) &&
        !getWhetherWithinPlaybackPositionInTolerance(playerState)) {
      int target = playbackManager.getTargetPlaybackPosition();
      if (target < 0) {
        if (unpauseFuture != null) {
          print(
              "There is already an unpause future, doing nothing to resync playback position");
        } else {
          int sleepAmount = -target;
          print(
              "We're ahead of the correct position, pausing for $sleepAmount milliseconds");
          await SpotifySdk.pause();
          setState(() {
            unpauseFuture =
                Future.delayed(Duration(milliseconds: sleepAmount), (() async {
              setState(() {
                unpauseFuture = null;
              });
              await SpotifySdk.resume();
              print("Resumed playback after $sleepAmount milliseconds");
            }));
          });
        }
      } else {
        print(
            "Playing the correct song but behind the correct position, automatically seeking to the correct spot");
        await SpotifySdk.seekTo(positionedMilliseconds: target);
      }
    }
  }

  Future<void> checkWhetherInSync() async {
    PlayerState? playerState;
    try {
      playerState = await SpotifySdk.getPlayerState();
    } catch (e) {
      print("Failed to get player state when checking sync state: $e");
      return;
    }
    if (playerState != null) {
      // With the way the voting works, the player will somtimes say it is
      // out of sync near the end of a song, since the head will have updated
      // but we're still finishing off the previous song. If we're in the last
      // x seconds of the song, we just assume we're in sync.
      bool nearEndOfSong = false;
      if (playerState.track != null) {
        nearEndOfSong =
            playerState.track!.duration - playerState.playbackPosition < 20000;
      }
      bool playingCorrectSong = getWhetherPlayingCorrectSong(playerState);
      print("playingCorrectSong: $playingCorrectSong");
      bool withinToleranceForPlaybackPosition =
          getWhetherWithinPlaybackPositionInTolerance(playerState);
      bool inSync = withinToleranceForPlaybackPosition &&
          (playingCorrectSong || nearEndOfSong);
      playbackManager.setOutOfSync(!inSync);
    }
  }

  /// Call this function periodically to ensure that new songs are added to
  /// the queue and we know whether we're in sync with the expected playback.
  Future<void> updateQueue() async {
    List<String> tracksToQueue = await playbackManager.pull();
    for (String trackId in tracksToQueue) {
      var spotifyUri = "spotify:track:$trackId";
      await SpotifySdk.queue(spotifyUri: spotifyUri);
      await Future.delayed(spotifyActionDelay);
      print("Added track to queue: $spotifyUri");
    }
    await resyncIfSongCorrectAtWrongPlaybackPosition();
    await Future.delayed(spotifyActionDelay);
    await checkWhetherInSync();
  }

  // This is a very janky way of clearing the queue, since the Spotify SDK
  // doesn't offer a native way to do it. This leaves the dummy track playing,
  // which needs to be cleared aferward once we queue up the intended tracks.
  Future<void> clearQueue() async {
    setState(() {
      clearingQueue = true;
    });
    // Queue up a track.
    print("Adding dummy track");
    String uri = "spotify:track:7p5bQJB4XsZJEEn6Tb7EaL";
    await SpotifySdk.queue(spotifyUri: uri);
    await Future.delayed(spotifyActionDelay);

    // Skip tracks until we see the track we queued up, which tells us we're at
    // the end of the queue.
    print("Skipping track until we see the dummy track");
    bool firstIteration = true;
    while (true) {
      var playerState = await SpotifySdk.getPlayerState();
      if (playerState == null || playerState.track == null) {
        print("Waiting for Spotify to report a track playing");
        await Future.delayed(spotifyActionDelay);
        continue;
      }
      if (playerState.track!.uri == uri) {
        print("Found dummy track, queue cleared, leaving dummy track playing");
        if (firstIteration) {
          // Handle the rare case where the dummy track was already playing.
          await SpotifySdk.skipNext();
        }
        break;
      }
      print("Skipping track");
      await SpotifySdk.skipNext();
      await Future.delayed(spotifyActionDelay);
      firstIteration = false;
    }
    setState(() {
      clearingQueue = false;
    });
  }

  // TODO: There seems to be a bug where we skip a song in the queue for some reason.
  // Particularly I think you need to tune in, let it advance to the next song,
  // then observe that it is playing the wrong song. Though on later testing
  // it seems correct, perhaps I just hadn't manually cleared the queue properly.
  // TODO: Over time we expect some sync drift. Be a little smarter about resyncing
  // if the user requests it, where instead of adding everything to queue, we
  // just seek to correct location if the correct song is playing. This has its
  // own downsides ofc because the user might be playing the correct song now
  // but not have the correct songs queued up.
  // TODO: As it is now, the Spotify SDK cannot seem to do anything on web
  // even with a successful login. This includes queueing, playing, getting
  // the player state, etc.
  // TODO: The periodic updateQueue only works if the app is foregrounded.
  Future<void> setupPlayer() async {
    print("Setting up player afresh");

    playbackManager.headOfRemoteQueue = null;
    playbackManager.latestConsumedTrack = null;
    updateQueueTimer?.cancel();

    // Assume we're in sync for now.
    setState(() {
      playbackManager.setOutOfSync(false);
    });

    // Clear the queue, leaving the dummy track playing. Pause if necessary.
    await clearQueue();

    // Add the intended songs onto the queue.
    await updateQueue();

    // Determine whether to tell the user we're waiting for the song to start
    // or whether to play the song now, skipping to the intended position.
    int playbackPosition = playbackManager.getTargetPlaybackPosition();
    print("Playback position: $playbackPosition");
    if (playbackPosition > 0) {
      // Skip the dummy track.
      await SpotifySdk.skipNext();

      // Skip to the correct position in the track.
      await SpotifySdk.seekTo(positionedMilliseconds: playbackPosition);

      await Future.delayed(spotifyActionDelay);

      // Confirm our sync status, which will invoke a UI re-render to display
      // said status to the user.
      await checkWhetherInSync();

      await Future.delayed(spotifyActionDelay);
      startUpdateQueueTimer();

      print("Set up player midway through song");
    } else {
      // The track will start soon. Schedule it for then.
      setState(() {
        trackAboutToStart = true;
      });
      Future.delayed(Duration(milliseconds: -playbackPosition), () async {
        // Skip the dummy track.
        await SpotifySdk.skipNext();

        setState(() {
          trackAboutToStart = false;
        });

        await Future.delayed(spotifyActionDelay);

        // Confirm our sync status, which will invoke a UI re-render to display
        // said status to the user.
        await checkWhetherInSync();

        await Future.delayed(spotifyActionDelay);
        startUpdateQueueTimer();

        print("Set up player after waiting for song to start");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (trackAboutToStart) {
      var body = Column(
        children: const [Text("Track about to start...")],
      );
      return buildTopLevelScaffold(widget.pageSelectorController, body,
          title: "Tuning in...");
    }

    List<Widget> children = [];
    switch (widget.pageSelectorController.tunedInState) {
      case TunedInState.tunedOut:
        children += [getConnectionButton("Tune in!", tuneIn)];
        break;
      case TunedInState.tuningIn:
        children += [Text("Tuning in...")];
        break;
      case TunedInState.tunedIn:
        return PlayerPage(
            widget.pageSelectorController, setupPlayer, clearingQueue);
    }

    Widget body = Center(
        child: Column(
      children: children,
      mainAxisAlignment: MainAxisAlignment.center,
    ));
    return buildTopLevelScaffold(widget.pageSelectorController, body,
        title: "Tune in?");
  }
}
