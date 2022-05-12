import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:aptos_infinite_jukebox/common.dart';
import 'package:aptos_infinite_jukebox/main.dart';
import 'package:flutter/material.dart';
import 'package:spotify_sdk/models/player_state.dart';
import 'package:spotify_sdk/models/track.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

const ImageDimension desiredImageDimension = ImageDimension.large;

class PlayerPage extends StatefulWidget {
  const PlayerPage(this.trackAboutToStart, this.outOfSync, this.setupPlayer,
      {Key? key})
      : super(key: key);

  final bool trackAboutToStart;
  final bool outOfSync;

  // The player needs this to invoke a resync with the intended player state.
  final Function setupPlayer;

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

          List<Widget> children = [
            Text(
              track.name,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
              textAlign: TextAlign.center,
            ),
            Text(
              track.artist.name ?? "Unknown Artist",
              style: TextStyle(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            Padding(padding: EdgeInsets.only(top: 30)),
            getSpotifyImageWidget(),
            Padding(padding: EdgeInsets.only(top: 30)),
            PlaybackIndicator(
              initialPosition: playerState.playbackPosition,
              trackDuration: track.duration,
              playbackSpeed: playerState.playbackSpeed,
              isPaused: playerState.isPaused,
            ),
          ];

          Widget getSyncButton(
              String text, Color backgroundColor, Color foregroundColor,
              {void Function()? onPressed, bool includeBorder = true}) {
            Border? border;
            if (includeBorder) {
              border = Border.all(color: mainColor, width: 3);
            }
            return Container(
                padding: EdgeInsets.all(5),
                decoration: BoxDecoration(
                    color: backgroundColor,
                    border: border,
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                child: TextButton(
                    onPressed: onPressed,
                    style: ButtonStyle(
                      foregroundColor:
                          MaterialStateProperty.all(foregroundColor),
                    ),
                    child: Text(
                      text,
                      style: TextStyle(fontSize: 18),
                    )));
          }

          Widget syncButton;
          if (widget.outOfSync) {
            syncButton =
                getSyncButton("Out of sync, sync up?", Colors.white, Colors.red,
                    onPressed: () async {
              print("Syncing up...");
              await widget.setupPlayer();
              print("Synced up!");
            });
          } else {
            syncButton = getSyncButton(
                "In sync!", Colors.transparent, Colors.lightGreen,
                includeBorder: false);
          }
          children.add(Padding(padding: EdgeInsets.only(top: 20)));
          children.add(syncButton);

          if (widget.outOfSync) {
            children.add(Padding(padding: EdgeInsets.only(top: 20)));
            children.add(Text(
              "If resyncing doesn't seem to work, it is likely because you already have something in your Spotify queue. The Spotify SDK offers no way to clear it, so you must go clear the queue yourself and then try to resync.",
              textAlign: TextAlign.center,
            ));
          }

          return buildWithScaffold(Padding(
              padding: EdgeInsets.all(30),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: children)));
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
    return Padding(
        padding: EdgeInsets.only(left: 0, right: 0),
        child: LinearProgressIndicator(
          value: position / widget.trackDuration,
          minHeight: 5,
        ));
  }
}
