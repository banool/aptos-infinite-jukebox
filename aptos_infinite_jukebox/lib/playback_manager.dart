import 'dart:async';
import 'dart:math';

import 'package:aptos_infinite_jukebox/constants.dart';
import 'package:aptos_infinite_jukebox/globals.dart';
import 'package:aptos_sdk_dart/aptos_client_helper.dart';
import 'package:aptos_sdk_dart/aptos_sdk_dart.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:spotify/spotify.dart';
import 'package:spotify_sdk/models/player_state.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

import 'common.dart';

// TODO: I really want to be using Events here I believe.

/// If the playback is more than this amount out of sync with the intentional
/// playback position, we consider it to be out of sync and offer the user
/// a button that they can press to resync.
const int outOfSyncThresholdMilli = 10000;

enum TunedInState {
  tunedOut,
  tuningIn,
  tunedIn,
}

class PlaybackManager extends ChangeNotifier {
  String? latestConsumedTrack;
  String? headOfRemoteQueue;
  DateTime targetTrackStartMilli;
  bool _outOfSync = false;
  bool currentlySeeking = false;

  List<String>? lastSeenQueue;
  List<Track>? lastSeenQueueTracks;

  Future? unpauseFuture;

  Future? fetchQueueTracksFuture;

  Timer? resyncAndCheckTimer;

  // This is only used for display purposes.
  int? secondsUntilUnpause;

  TunedInState _tunedInState = TunedInState.tunedOut;

  PlaybackManager(this.latestConsumedTrack, this.headOfRemoteQueue,
      this.targetTrackStartMilli);

  static Future<PlaybackManager> getPlaybackManager() async {
    var playbackManager =
        PlaybackManager(null, null, DateTime.fromMillisecondsSinceEpoch(0));
    return playbackManager;
  }

  bool get outOfSync => _outOfSync;

  void setOutOfSync(bool outOfSync) {
    bool old = _outOfSync;
    _outOfSync = outOfSync;
    if (outOfSync != old) {
      notifyListeners();
    }
  }

  TunedInState get tunedInState => _tunedInState;

  void setTunedInState(TunedInState tunedInState) {
    TunedInState old = _tunedInState;
    _tunedInState = tunedInState;
    if (_tunedInState != old) {
      notifyListeners();
    }
  }

  /// Call this periodically, much more frequently than the frequency of
  /// songs ending (try every 10 seconds). This will make sure that we are
  /// queueing up new songs as they appear and we know if we're out of sync.
  Future<List<String>> pull() async {
    String aptosNodeUrl =
        sharedPreferences.getString(keyAptosNodeUrl) ?? defaultAptosNodeUrl;
    String jukeboxAddress =
        sharedPreferences.getString(keyJukeboxAddress) ?? defaultJukeboxAddress;

    var resourceType = buildResourceType();

    print("Getting latest queue from blockchain");

    // Get the information from the account.
    Dio dio = Dio(BaseOptions(baseUrl: aptosNodeUrl));
    AptosClientHelper aptosClientHelper = AptosClientHelper.fromDio(dio);
    AccountResource resource;
    try {
      resource = await unwrapClientCall(aptosClientHelper.client
          .getAccountsApi()
          .getAccountResource(
              address: jukeboxAddress, resourceType: resourceType));
    } catch (e) {
      print("Failed to pull resource from blockchain: $e");
      return [];
    }

    // Process info from the resources.
    var inner = resource.data.asMap["inner"];

    // Update the target track start time.
    targetTrackStartMilli = DateTime.fromMillisecondsSinceEpoch(
        int.parse(inner["time_to_start_playing"]) ~/ 1000);

    // Get the queue as it is in the account.
    List<String> rawTrackQueue = [];
    for (Map<String, dynamic> o in inner["song_queue"]) {
      rawTrackQueue.add(o["track_id"]!);
    }

    if (!listEquals(lastSeenQueue, rawTrackQueue)) {
      // Don't wait for this to happen.
      fetchQueueTracksFuture = updateQueueTracks(rawTrackQueue);
    }

    lastSeenQueue = rawTrackQueue;

    // Store which song is currently at the head of the queue, for the sake
    // of checking that we're in sync.
    headOfRemoteQueue = rawTrackQueue.first;

    // Determine which tracks are new.
    List<String> newTracksBackwards = [];
    for (String s in rawTrackQueue.reversed.toList()) {
      if (latestConsumedTrack != null && s == latestConsumedTrack) {
        break;
      }
      newTracksBackwards.add(s);
    }

    // Reverse the tracks, so we now essentially have some tail of the queue
    // which contains only songs that we haven't seen yet.
    List<String> newTracks = newTracksBackwards.reversed.toList();

    // Take note of the last track we added to the queue, so we know which
    // tracks to skip next round.
    if (newTracks.isNotEmpty) {
      latestConsumedTrack = newTracks.last;
    }

    return newTracks;
  }

  Future<void> updateQueueTracks(List<String> trackIds) async {
    if (spotifyApi == null) {
      return;
    }

    lastSeenQueueTracks = (await spotifyApi!.tracks.list(trackIds)).toList();
    notifyListeners();
    print("Updated tracks, notifying listeners");
  }

  // For now we don't handle when the song has ended.
  int getTargetPlaybackPosition() {
    var now = DateTime.now().millisecondsSinceEpoch;
    return now - targetTrackStartMilli.millisecondsSinceEpoch;
  }

  // Returns true if it did anything.
  Future<bool> resyncIfSongCorrectAtWrongPlaybackPosition() async {
    if (playbackManager.unpauseFuture != null) {
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
      playbackManager.unpauseFuture =
          Future.delayed(Duration(milliseconds: sleepAmount), (() async {
        await SpotifySdk.resume();
        print("Resumed playback after $sleepAmount milliseconds");
        unpauseFuture = null;
        await Future.delayed(spotifyActionDelay * 5);
      }));
      secondsUntilUnpause = min(sleepAmount ~/ 1000, 1);
      Timer.periodic(Duration(seconds: 1), (timer) {
        if (secondsUntilUnpause == null) {
          timer.cancel();
          return;
        }
        secondsUntilUnpause = secondsUntilUnpause! - 1;
        if (secondsUntilUnpause == 0) {
          secondsUntilUnpause = null;
        }
      });
      notifyListeners();
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
    // Assume we're out of sync if we don't know what song we're meant to be
    // playing.
    if (playbackManager.headOfRemoteQueue == null) {
      playbackManager.setOutOfSync(true);
      return;
    }
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
      bool inSync = (withinToleranceForPlaybackPosition &&
              playingCorrectSong &&
              !playerState.isPaused) ||
          nearEndOfSong;
      playbackManager.setOutOfSync(!inSync);
    }
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

  bool getWhetherPlayingCorrectSong(PlayerState playerState) {
    bool playingCorrectSong = true;
    if (playerState.track != null &&
        playbackManager.headOfRemoteQueue != null) {
      playingCorrectSong =
          playerState.track!.uri.endsWith(playbackManager.headOfRemoteQueue!);
    }
    return playingCorrectSong;
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

  void startResyncAndCheckTimer() {
    resyncAndCheckTimer =
        Timer.periodic(Duration(milliseconds: 250), (timer) async {
      if (tunedInState == TunedInState.tunedOut) {
        print("Tuned out, cancelling timer");
        timer.cancel();
        return;
      }
      debugPrint("noisy: Resyncing if necessary then checking sync status");
      await resyncAndCheck();
    });
  }
}
