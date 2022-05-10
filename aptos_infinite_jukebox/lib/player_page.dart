import 'package:aptos_infinite_jukebox/globals.dart';
import 'package:flutter/material.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

import 'common.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({Key? key}) : super(key: key);

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late Future<void> initStateAsyncFuture;

  @override
  void initState() {
    super.initState();
    initStateAsyncFuture = initStateAsync();
  }

  Future<void> initStateAsync() async {}

  @override
  Widget build(BuildContext context) {
    // We assume ConnectionStatus.connected of SpotifySdk is true.

    Widget body =
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text("Connected"),
      TextButton(
        child: Text("Play song test"),
        onPressed: () async {
          await SpotifySdk.play(
              spotifyUri: "spotify:track:0H8XeaJunhvpBdBFIYi6Sh");
        },
      )
    ]);

    return Scaffold(body: Center(child: body));
  }
}
