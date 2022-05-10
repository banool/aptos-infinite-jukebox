import 'package:aptos_infinite_jukebox/globals.dart';
import 'package:aptos_infinite_jukebox/player_page.dart';
import 'package:flutter/material.dart';
import 'package:spotify_sdk/models/connection_status.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

import 'common.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? connectErrorString;

  late Future<void> initStateAsyncFuture;

  bool awaitingReturnFromConnectionAttempt = false;

  @override
  void initState() {
    super.initState();
    initStateAsyncFuture = initStateAsync();
  }

  Future<void> initStateAsync() async {
    String? accessToken = sharedPreferences.getString(keySpotifyAccessToken);
    if (accessToken != null) {
      print("Access token found on launch: $accessToken");
      await connectToSpotify(accessToken);
    }
  }

  Future<void> getNewAccessToken() async {
    try {
      setState(() {
        awaitingReturnFromConnectionAttempt = true;
      });
      String accessToken = await SpotifySdk.getAccessToken(
        clientId: spotifyClientId,
        redirectUrl: spotifyRedirectUrl, /*scope: spotifyAccessTokenScope*/
      );
      await sharedPreferences.setString(keySpotifyAccessToken, accessToken);
      await connectToSpotify(accessToken);
    } catch (e) {
      await sharedPreferences.remove(keySpotifyAccessToken);
      setState(() {
        connectErrorString = "$e";
        awaitingReturnFromConnectionAttempt = false;
      });
    }
  }

  Future<void> connectToSpotify(String accessToken) async {
    try {
      setState(() {
        awaitingReturnFromConnectionAttempt = true;
      });
      await SpotifySdk.connectToSpotifyRemote(
        clientId: spotifyClientId,
        redirectUrl: spotifyRedirectUrl,
        //scope: spotifyAccessTokenScope,
        playerName: appTitle,
        accessToken: accessToken,
      );
      setState(() {
        awaitingReturnFromConnectionAttempt = false;
      });
      print("Successfully connected to Spotify");
    } catch (e) {
      await sharedPreferences.remove(keySpotifyAccessToken);
      setState(() {
        connectErrorString = "$e";
        awaitingReturnFromConnectionAttempt = false;
      });
    }
  }

  Widget getNoAccessTokenScreen({String? errorString}) {
    if (awaitingReturnFromConnectionAttempt) {
      return Column(
        children: const [
          Text("Waiting for authentication with Spotify to complete"),
          Padding(
              padding: EdgeInsets.only(top: 20),
              child: Center(
                child: CircularProgressIndicator(),
              )),
        ],
      );
    }
    return Column(children: [
      Text("Error from previous connection attempt: $errorString"),
      Text("Try again:"),
      TextButton(
          child: Text("Connect to Spotify"), onPressed: getNewAccessToken)
    ]);
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
    Widget widget = StreamBuilder<ConnectionStatus>(
        stream: SpotifySdk.subscribeConnectionStatus(),
        builder: (context, snapshot) {
          if (snapshot.data == null) {
            return buildWithScaffold(CircularProgressIndicator());
          }
          ConnectionStatus connectionStatus = snapshot.data!;

          String? errorString;
          if (connectionStatus.errorCode != null) {
            errorString =
                "Error from Spotify SDK: ${connectionStatus.errorCode}: ${connectionStatus.errorDetails}";
          } else if (connectErrorString != null) {
            errorString = connectErrorString;
          }

          if (errorString != null) {
            return buildWithScaffold(
                getNoAccessTokenScreen(errorString: errorString));
          }

          if (!connectionStatus.connected) {
            // TODO: If there is an access token in storage,
            // handle that here. Likely it means something went
            // wrong elsewhere but we didn't wipe the access token.
            return buildWithScaffold(getNoAccessTokenScreen());
          } else {
            return PlayerPage();
          }
        });

    return widget;
  }
}
