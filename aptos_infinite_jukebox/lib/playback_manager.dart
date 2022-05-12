import 'dart:convert';

import 'package:aptos_infinite_jukebox/common.dart';
import 'package:http/http.dart' as http;

/// If the playback is more than this amount out of sync with the intentional
/// playback position, we consider it to be out of sync and offer the user
/// a button that they can press to resync.
const int outOfSyncThresholdMilli = 2000000;

class PlaybackManager {
  String? latestConsumedTrack;
  String? headOfRemoteQueue;
  DateTime targetTrackStartMilli;

  PlaybackManager(this.latestConsumedTrack, this.headOfRemoteQueue,
      this.targetTrackStartMilli);

  static Future<PlaybackManager> getPlaybackManager() async {
    var playbackManager =
        PlaybackManager(null, null, DateTime.fromMillisecondsSinceEpoch(0));
    return playbackManager;
  }

  /// Call this periodically, much more frequently than the frequency of
  /// songs ending (try every 10 seconds). This will make sure that we are
  /// queueing up new songs as they appear and we know if we're out of sync.
  Future<List<String>> pull() async {
    // TODO: Make these addresses selectable by the user.

    // Get the information from the account.
    var resourceType = "0x$moduleAddress::$moduleName::$moduleName";
    var uri = "$aptosNodeUrl/accounts/$publicAddress/resource/$resourceType";
    var response = await http.get(Uri.parse(uri));
    if (response.statusCode != 200) {
      throw "Failed to pull info";
    }
    var d = jsonDecode(response.body);
    var inner = d["data"]["inner"];

    // Update the target track start time.
    targetTrackStartMilli = DateTime.fromMillisecondsSinceEpoch(
        int.parse(inner["time_to_start_playing"]) ~/ 1000);

    // Get the queue as it is in the account.
    List<String> rawTrackQueue = [];
    for (Map<String, dynamic> o in inner["song_queue"]) {
      rawTrackQueue.add(o["song"]!);
    }

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

  // For now we don't handle when the song has ended.
  int getTargetPlaybackPosition() {
    var now = DateTime.now().millisecondsSinceEpoch;
    return now - targetTrackStartMilli.millisecondsSinceEpoch;
  }
}

// TODO add something to tell users to make sure their system time is correct.

/*
    let resource_type = format!("0x{}::{}::{}", module_address, module_name, module_name);
    let uri = format!(
        "{}/accounts/{}/resource/{}",
        node_url, account_public_address, resource_type
    );
    let client = Client::new();
    let res = client.get(uri).send().await?;
    let res_json: serde_json::Value = serde_json::from_str(&res.text().await?)?;
    // debug!("Raw current song info response: {:#?}", res_json);
    let inner = res_json
        .get("data")
        .context("No field \"data\" in response")?
        .get("inner")
        .context("No field \"inner\" in response")?;
    let track_id = inner
        .get("current_song")
        .context("No field \"current_song\" in data")?
        .get("song")
        .context("No field \"song\" in current_song")?
        .as_str()
        .context("song wasn't a string")?
        .to_owned();
    let time_to_start_playing = inner
        .get("time_to_start_playing")
        .context("No field \"time_to_start_playing\" in data")?
        .as_str()
        .context("time_to_start_playing wasn't a string (which we later convert into u64)")?
        .to_owned()
        .parse::<u64>()?;
    let out = CurrentSongInfo {
        track_id,
        time_to_start_playing,
    };
    */
