import 'dart:async';

import 'package:flutter/material.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

import 'common.dart';
import 'constants.dart';
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
  bool trackAboutToStart = false;

  Timer? updateQueueTimer;

  bool settingUpQueue = false;

  Future<void> tuneIn() async {
    print("Tuning in");
    playbackManager.setTunedInState(TunedInState.tuningIn);
    try {
      await setupPlayer();
      playbackManager.setTunedInState(TunedInState.tunedIn);
      startUpdateQueueTimer();
    } catch (e) {
      playbackManager.setTunedInState(TunedInState.tunedOut);
    }
  }

  void startUpdateQueueTimer() {
    setState(() {
      updateQueueTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
        if (playbackManager.tunedInState == TunedInState.tunedOut) {
          print("Tuned out, cancelling timer");
          timer.cancel();
          return;
        }
        print("Checking for queue / playback updates");
        await updateQueue();
      });
    });
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
    await playbackManager.checkWhetherInSync();

    // Start the timers for updating the queue and checking sync status.
    await Future.delayed(spotifyActionDelay);
    startUpdateQueueTimer();
    playbackManager.startResyncAndCheckTimer();
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
    playbackManager.resyncAndCheckTimer?.cancel();

    playbackManager.headOfRemoteQueue = null;
    playbackManager.latestConsumedTrack = null;

    // Assume we're in sync for now.
    setState(() {
      playbackManager.setOutOfSync(false);
      settingUpQueue = true;
    });

    // The web endpoints explode if nothing is playing before you try to
    // manipulate the queue unless you don't specify a player to use, which
    // it opts to do in case there is no other player active. For this we
    // use another silent track not in the standard set. We do this for all
    // devices though, not just web, because it can't hurt.
    await SpotifySdk.play(spotifyUri: "spotify:track:7IP2ZGoZd8y0CelITiMG1m");
    print("Started playing special track to activate player");
    await Future.delayed(spotifyActionDelay);

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
    playbackManager.startResyncAndCheckTimer();
    startUpdateQueueTimer();
  }

  @override
  Widget build(BuildContext context) {
    if (trackAboutToStart) {
      var body = Column(
        children: const [Text("Track about to start...")],
      );
      return buildTopLevelScaffold(widget.pageSelectorController, body,
          title: "Tuning in");
    }

    List<Widget> children = [];
    switch (playbackManager.tunedInState) {
      case TunedInState.tunedOut:
        children += [getConnectionButton("Tune in!", tuneIn)];
        break;
      case TunedInState.tuningIn:
        children += [
          Text("Tuning in", style: TextStyle(fontSize: 18)),
          Padding(padding: EdgeInsets.only(top: 20)),
          CircularProgressIndicator()
        ];
        break;
      case TunedInState.tunedIn:
        return PlayerPage(widget.pageSelectorController, setupPlayer,
            settingUpQueue, playbackManager.secondsUntilUnpause);
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
    playbackManager.resyncAndCheckTimer?.cancel();
    super.dispose();
  }
}
