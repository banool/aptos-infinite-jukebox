import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:aptos_infinite_jukebox/globals.dart';
import 'package:flutter/material.dart';
import 'package:spotify_sdk/models/connection_status.dart';
import 'package:spotify_sdk/models/image_uri.dart';
import 'package:spotify_sdk/models/player_context.dart';
import 'package:spotify_sdk/models/player_state.dart';
import 'package:spotify_sdk/models/track.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

import 'common.dart';

const ImageDimension desiredImageDimension = ImageDimension.large;

class PlayerPage extends StatefulWidget {
  const PlayerPage(bool trackAboutToStart, {Key? key}) : super(key: key);

  final bool trackAboutToStart = false;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class CurrentTrackInfo {
  String imageUriRaw;
  Future<Uint8List?> loadImageFuture;

  CurrentTrackInfo(this.imageUriRaw, this.loadImageFuture);
}

class _PlayerPageState extends State<PlayerPage> {
  late Future<void> initStateAsyncFuture;

  CurrentTrackInfo? currentTrackInfo;

  @override
  void initState() {
    super.initState();
    initStateAsyncFuture = initStateAsync();
  }

  Future<void> initStateAsync() async {}

  Widget getSpotifyImageWidget() {
    return FutureBuilder(
        future: currentTrackInfo!.loadImageFuture,
        builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
          if (snapshot.hasData) {
            return Image.memory(snapshot.data!);
          } else if (snapshot.hasError) {
            return SizedBox(
                width: desiredImageDimension.value.toDouble(),
                height: desiredImageDimension.value.toDouble(),
                child: Center(
                    child: Column(children: [
                  Text('Error getting image'),
                  TextButton(
                    child: Text("Try loading image again"),
                    onPressed: () => setState(() {}),
                  )
                ])));
          } else {
            return SizedBox(
              width: desiredImageDimension.value.toDouble(),
              height: desiredImageDimension.value.toDouble(),
              child: const CircularProgressIndicator(),
            );
          }
        });
  }

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
    // Here we assume ConnectionStatus.connected of SpotifySdk is true.
    // We also assume a track is playing.

    print("TRACK ABOUT TO START: ${widget.trackAboutToStart}");
    if (widget.trackAboutToStart) {
      return buildWithScaffold(Column(
        children: const [Text("Track about to start...")],
      ));
    }

    return StreamBuilder<PlayerState>(
        stream: SpotifySdk.subscribePlayerState(),
        builder: (context, snapshot) {
          if (snapshot.data == null) {
            return buildWithScaffold(CircularProgressIndicator());
          }
          PlayerState playerState = snapshot.data!;

          if (playerState.track == null) {
            // Just defensive, we should never hit this state.
            return buildWithScaffold(CircularProgressIndicator());
          }

          Track track = playerState.track!;

          if (currentTrackInfo == null ||
              track.imageUri.raw != currentTrackInfo!.imageUriRaw) {
            print("Getting new image");
            var loadImageFuture = SpotifySdk.getImage(
              imageUri: track.imageUri,
              dimension: desiredImageDimension,
            );
            currentTrackInfo =
                CurrentTrackInfo(track.imageUri.raw, loadImageFuture);
          }

          return buildWithScaffold(
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            getSpotifyImageWidget(),
            Padding(padding: EdgeInsets.only(top: 20)),
            PlaybackIndicator(
              initialPosition: playerState.playbackPosition,
              trackDuration: track.duration,
              playbackSpeed: playerState.playbackSpeed,
              isPaused: playerState.isPaused,
            ),
          ]));
        });
  }
}

class PlaybackIndicator extends StatefulWidget {
  const PlaybackIndicator(
      {Key? key,
      required this.initialPosition,
      required this.trackDuration,
      required this.playbackSpeed,
      required this.isPaused})
      : super(key: key);

  final int initialPosition;
  final int trackDuration;
  final double playbackSpeed;
  final bool isPaused;

  @override
  _PlaybackIndicatorState createState() => _PlaybackIndicatorState();
}

class _PlaybackIndicatorState extends State<PlaybackIndicator> {
  late int position;
  late Timer timer;

  @override
  void initState() {
    super.initState();
    position = widget.initialPosition;
    if (!widget.isPaused) {
      timer = Timer.periodic(Duration(milliseconds: 100), (_) {
        setState(() {
          position = min(widget.trackDuration,
              position + (100 * widget.playbackSpeed).toInt());
        });
      });
    }
  }

  @override
  void didUpdateWidget(PlaybackIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    position = widget.initialPosition;
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(value: position / widget.trackDuration);
  }
}
