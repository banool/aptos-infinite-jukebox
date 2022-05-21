import 'dart:convert';

import 'package:aptos_infinite_jukebox/constants.dart';
import 'package:aptos_infinite_jukebox/globals.dart';
import 'package:aptos_sdk_dart/aptos_client_helper.dart';
import 'package:aptos_sdk_dart/aptos_sdk_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:spotify/spotify.dart';

import 'common.dart';

// TODO: I really want to be using Events here I believe.

/// If the playback is more than this amount out of sync with the intentional
/// playback position, we consider it to be out of sync and offer the user
/// a button that they can press to resync.
const int outOfSyncThresholdMilli = 10000;

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
    AptosClientHelper aptosClientHelper =
        AptosClientHelper.fromBaseUrl(aptosNodeUrl);
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
}
