import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:aptos_infinite_jukebox/constants.dart';
import 'package:aptos_infinite_jukebox/globals.dart';
import 'package:aptos_infinite_jukebox/page_selector.dart';
import 'package:flutter/material.dart';
import 'package:spotify_sdk/models/player_state.dart';
import 'package:spotify_sdk/models/track.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

const ImageDimension desiredImageDimension = ImageDimension.large;

class PlayerPage extends StatefulWidget {
  const PlayerPage(this.pageSelectorController, this.setupPlayer,
      this.clearingQueue, this.secondsUntilUnpause,
      {Key? key})
      : super(key: key);

  final PageSelectorController pageSelectorController;
  final bool clearingQueue;

  // The player needs this to invoke a resync with the intended player state.
  final Function setupPlayer;

  // The player uses this to display a countdown to the next song starting.
  final int? secondsUntilUnpause;

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
    playbackManager.addListener(() {
      print("Rebuilding because outOfSync changed");
      if (mounted) {
        setState(() {});
      }
    });
    initStateAsyncFuture = initStateAsync();
  }

  Future<void> initStateAsync() async {}

  Widget getSpotifyImageWidget() {
    if (widget.clearingQueue) {
      // Don't bother fetching images while clearing the queue.
      return CircularProgressIndicator();
    }
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

  Widget getSyncButton(
      String text, Color backgroundColor, Color foregroundColor,
      {void Function()? onPressed, bool includeBorder = true}) {
    Border? border;
    if (includeBorder) {
      border = Border.all(color: mainColor, width: 2);
    }
    return TextButton(
        onPressed: onPressed,
        style: ButtonStyle(
          foregroundColor: MaterialStateProperty.all(foregroundColor),
        ),
        child: Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: backgroundColor,
                border: border,
                borderRadius: BorderRadius.all(Radius.circular(10))),
            child: Text(
              text,
              style: TextStyle(fontSize: 16),
            )));
  }

  // Here we assume ConnectionStatus.connected of SpotifySdk is true.
  @override
  Widget build(BuildContext context) {
    Widget body = StreamBuilder<PlayerState>(
        stream: SpotifySdk.subscribePlayerState(),
        builder: (context, snapshot) {
          if (snapshot.data == null) {
            return Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(),
            );
          }
          PlayerState playerState = snapshot.data!;

          if (playerState.track == null) {
            // Just defensive, we should never hit this state.
            return Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(),
            );
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
            Padding(padding: EdgeInsets.only(top: 15)),
            Expanded(child: getSpotifyImageWidget()),
            Padding(padding: EdgeInsets.only(top: 30)),
            PlaybackIndicator(
              initialPosition: playerState.playbackPosition,
              trackDuration: track.duration,
              playbackSpeed: playerState.playbackSpeed,
              isPaused: playerState.isPaused,
            ),
          ];

          Widget syncButton;
          if (widget.clearingQueue) {
            syncButton = getSyncButton(
                "Syncing up...", Colors.transparent, Colors.lightBlue,
                includeBorder: false);
          } else if (widget.secondsUntilUnpause != null) {
            syncButton = getSyncButton(
                "Next song starting in ${widget.secondsUntilUnpause}...",
                Colors.transparent,
                Colors.lightBlue,
                includeBorder: false);
          } else if (playbackManager.outOfSync) {
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

          if (playbackManager.outOfSync) {
            children.add(Padding(padding: EdgeInsets.only(top: 20)));
            children.add(Text(
              "If resyncing doesn't seem to work, check out the FAQ under the Settings tab for tips on resolving common issues.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ));
          }

          return Padding(
              padding: EdgeInsets.all(30),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: children));
        });

    return buildTopLevelScaffold(
        widget.pageSelectorController, Center(child: body),
        title: "Tuned in!");
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
  Timer? timer;

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
    timer?.cancel();
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
