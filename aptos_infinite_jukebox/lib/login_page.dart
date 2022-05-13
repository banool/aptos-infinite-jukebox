import 'dart:async';

import 'package:aptos_infinite_jukebox/globals.dart';
import 'package:aptos_infinite_jukebox/page_selector.dart';
import 'package:aptos_infinite_jukebox/playback_manager.dart';
import 'package:aptos_infinite_jukebox/player_page.dart';
import 'package:flutter/material.dart';
import 'package:spotify_sdk/models/connection_status.dart';
import 'package:spotify_sdk/models/player_state.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

import 'common.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key, required this.pageSelectorController})
      : super(key: key);

  final PageSelectorController pageSelectorController;

  @override
  State<LoginPage> createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  String? connectionErrorString;

  late Future<void> initStateAsyncFuture;

  // This will be set if we're connecting.
  String? connectingInformation;
  bool tunedIn = false;
  bool trackAboutToStart = false;
  bool outOfSync = false;

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

  Future<void> handleConnectionError(Object error) async {
    await sharedPreferences.remove(keySpotifyAccessToken);
    setState(() {
      connectionErrorString = "$error";
      connectingInformation = null;
      widget.pageSelectorController.tunedIn = false;
    });
  }

  // TODO: Put a timeout on this.
  Future<void> getAccessTokenAndConnect() async {
    try {
      print("Getting new access token");
      setState(() {
        connectingInformation = "Getting new access token";
      });
      String? scope;
      if (onWeb) {
        scope = spotifyAccessTokenScope;
      }
      String accessToken = await SpotifySdk.getAccessToken(
        clientId: spotifyClientId,
        redirectUrl: spotifyRedirectUrl,
        scope: scope,
      );
      // Don't bother storing the token on web.
      if (!onWeb) {
        await sharedPreferences.setString(keySpotifyAccessToken, accessToken);
      }
      print("Got new access token");
      await connectToSpotify(accessToken);
      // connectToSpotify will handle the state if it connects correctly,
      // no need to duplicate that logic here.
    } catch (e) {
      await handleConnectionError(e);
      print("Failed to get new access token");
    }
  }

  Future<void> connectToSpotify(String accessToken) async {
    try {
      print("Trying to connect to Spotify");
      setState(() {
        connectingInformation = "Connecting to Spotify";
      });
      await SpotifySdk.connectToSpotifyRemote(
        clientId: spotifyClientId,
        redirectUrl: spotifyRedirectUrl,
        // TOOD: See whether we need this for web.
        //scope: spotifyAccessTokenScope,
        playerName: appTitle,
        accessToken: accessToken,
      );
      setState(() {
        connectingInformation = null;
        connectionErrorString = null;
      });
      print("Successfully connected to Spotify");
    } catch (e) {
      await handleConnectionError(e);
      print("Failed to connect to Spotify: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (connectingInformation != null && connectionErrorString != null) {
      throw "This here shouldn't be possible";
    }

    List<Widget> children = [];
    if (connectingInformation != null) {
      children += [
        Text(connectingInformation!),
        Padding(padding: EdgeInsets.only(top: 20)),
        CircularProgressIndicator(),
      ];
    } else {
      String connectButtonText;
      if (connectionErrorString != null) {
        connectButtonText = "Try again";
        children += [
          Text("There was an issue connecting to spotify"),
          Text(connectionErrorString!),
          Padding(padding: EdgeInsets.only(top: 10)),
        ];
      } else {
        connectButtonText = "Connect to Spotify";
      }
      children += [
        getConnectionButton(connectButtonText, getAccessTokenAndConnect)
      ];
    }

    Widget body = Center(
        child: Column(
      children: children,
      mainAxisAlignment: MainAxisAlignment.center,
    ));

    return buildTopLevelScaffold(widget.pageSelectorController, body);

    /*
    Widget widget = StreamBuilder<ConnectionStatus>(
        stream: SpotifySdk.subscribeConnectionStatus(),
        builder: (context, snapshot) {
          if (snapshot.data == null) {
            return buildWithScaffold(getNoAccessTokenScreen());
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
            if (!tunedIn) {
              var button = getConnectionButton("Tune in", tuneIn);
              return buildWithScaffold(button);
            } else {
              return PlayerPage(trackAboutToStart, outOfSync, setupPlayer);
            }
          }
        });

    return widget;
    */
  }
}
