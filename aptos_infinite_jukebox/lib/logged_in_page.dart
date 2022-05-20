import 'dart:async';
import 'dart:math';

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
  Timer? resyncAndCheckTimer;
  Future? unpauseFuture;

  // This is only used for display purposes.
  int? secondsUntilUnpause;

  bool settingUpQueue = false;

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

  void startResyncAndCheckTimer() {
    setState(() {
      resyncAndCheckTimer =
          Timer.periodic(Duration(milliseconds: 200), (timer) async {
        if (widget.pageSelectorController.tunedInState ==
            TunedInState.tunedOut) {
          print("Tuned out, cancelling timer");
          timer.cancel();
          return;
        }
        debugPrint("noisy: Resyncing if necessary then checking sync status");
        await resyncAndCheck();
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
    debugPrint(
        "noisy: withinToleranceForPlaybackPosition: $withinToleranceForPlaybackPosition (defined as abs($targetPosition - $actualPosition) < $outOfSyncThresholdMilli)");
    return withinToleranceForPlaybackPosition;
  }

  // Returns true if it did anything.
  Future<bool> resyncIfSongCorrectAtWrongPlaybackPosition() async {
    if (unpauseFuture != null) {
      debugPrint(
          "noisy: There is already an unpause future, doing nothing to resync playback position");
      return false;
    }
    if (playbackManager.currentlySeeking) {
      debugPrint("noisy: We're seeking right now, doing nothing to resync");
      return false;
    }
    PlayerState? playerState;
    try {
      playerState = await SpotifySdk.getPlayerState();
    } catch (e) {
      debugPrint(
          "noisy: Failed to get player state for trying to sync up playback position: $e");
      return false;
    }
    if (!getWhetherPlayingCorrectSong(playerState!)) {
      debugPrint("noisy: Playing wrong song, will not attempt to auto sync");
      return false;
    }
    if (getWhetherWithinPlaybackPositionInTolerance(playerState)) {
      debugPrint("noisy: Playback position within tolerance, not auto syncing");
      return false;
    }
    int target = playbackManager.getTargetPlaybackPosition();
    if (target < 0) {
      int sleepAmount = -target;
      print(
          "We're ahead of the correct position, pausing for $sleepAmount milliseconds");
      await SpotifySdk.pause();
      setState(() {
        unpauseFuture =
            Future.delayed(Duration(milliseconds: sleepAmount), (() async {
          await SpotifySdk.resume();
          print("Resumed playback after $sleepAmount milliseconds");
          setState(() {
            unpauseFuture = null;
          });
          await Future.delayed(spotifyActionDelay * 5);
        }));
        secondsUntilUnpause = min(sleepAmount ~/ 1000, 1);
      });
      Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          if (secondsUntilUnpause == null) {
            timer.cancel();
            return;
          }
          secondsUntilUnpause = secondsUntilUnpause! - 1;
          if (secondsUntilUnpause == 0) {
            secondsUntilUnpause = null;
          }
        });
      });
    } else {
      print(
          "Playing the correct song but behind the correct position, automatically seeking to the correct spot");
      playbackManager.currentlySeeking = true;
      await SpotifySdk.seekTo(positionedMilliseconds: target);
      await Future.delayed(spotifyActionDelay * 5);
      playbackManager.currentlySeeking = false;
    }
    return true;
  }

  Future<void> checkWhetherInSync() async {
    PlayerState? playerState;
    try {
      playerState = await SpotifySdk.getPlayerState();
    } catch (e) {
      debugPrint(
          "noisy: Failed to get player state when checking sync state: $e");
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
      debugPrint("noisy: playingCorrectSong: $playingCorrectSong");
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
  }

  /// Call this function periodically to make sure that if we're out of
  /// tolerance of the playback position on the correct track, we resync, which
  /// includes potentially pausing to wait for the new song to start, and then
  /// check the sync status.
  Future<void> resyncAndCheck() async {
    bool resynced = await resyncIfSongCorrectAtWrongPlaybackPosition();
    if (resynced) {
      resyncAndCheckTimer?.cancel();
      await Future.delayed(Duration(seconds: 5), (() {
        startResyncAndCheckTimer();
      }));
    } else {
      await checkWhetherInSync();
    }
  }

  String getRandomTrackId() {
    return ([
      "7p5bQJB4XsZJEEn6Tb7EaL",
      "0DIRDVwOuY3TGHuE4AhCWW",
      "76N9U7cOiYgSpDmLP4wTJ5",
      "7cctPQS83y620UQtMd1ilL",
    ]..shuffle())
        .first;
  }

  // This is a very janky way of clearing the queue, since the Spotify SDK
  // doesn't offer a native way to do it. This leaves the dummy track playing,
  // which needs to be cleared aferward once we queue up the intended tracks.
  Future<void> clearQueue() async {
    // Queue up a track.
    print("Adding dummy track");
    String uri = "spotify:track:${getRandomTrackId()}";
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
  }

  Future<void> startPlaying({int? playbackPosition}) async {
    // Skip the dummy track.
    await SpotifySdk.skipNext();

    // Skip to the correct position in the track.
    if (playbackPosition != null) {
      await SpotifySdk.seekTo(positionedMilliseconds: playbackPosition);
    }

    await Future.delayed(spotifyActionDelay);

    // Confirm our sync status, which will invoke a UI re-render to display
    // said status to the user.
    await checkWhetherInSync();

    // Start the timers for updating the queue and checking sync status.
    await Future.delayed(spotifyActionDelay);
    startUpdateQueueTimer();
    startResyncAndCheckTimer();
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

    updateQueueTimer?.cancel();
    resyncAndCheckTimer?.cancel();

    playbackManager.headOfRemoteQueue = null;
    playbackManager.latestConsumedTrack = null;

    // Assume we're in sync for now.
    setState(() {
      playbackManager.setOutOfSync(false);
      settingUpQueue = true;
    });

    // Clear the queue, leaving the dummy track playing. Pause if necessary.
    await clearQueue();

    // Add the intended songs onto the queue.
    await updateQueue();
    await Future.delayed(spotifyActionDelay);

    setState(() {
      settingUpQueue = false;
    });

    // Skip the dummy track.
    await SpotifySdk.skipNext();

    // Start the timers for checking the queue and sync status. We don't
    // explicitly try to sync up our playback status here, we let these timers
    // do it instead.
    startResyncAndCheckTimer();
    startUpdateQueueTimer();
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
        return PlayerPage(widget.pageSelectorController, setupPlayer,
            settingUpQueue, secondsUntilUnpause);
    }

    Widget body = Center(
        child: Column(
      children: children,
      mainAxisAlignment: MainAxisAlignment.center,
    ));
    return buildTopLevelScaffold(widget.pageSelectorController, body,
        title: "Tune in?");
  }

  @override
  void dispose() {
    updateQueueTimer?.cancel();
    resyncAndCheckTimer?.cancel();
    super.dispose();
  }
}
