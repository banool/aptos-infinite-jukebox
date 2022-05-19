import 'dart:async';

import 'package:aptos_infinite_jukebox/globals.dart';
import 'package:aptos_infinite_jukebox/page_selector.dart';
import 'package:flutter/material.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

import 'common.dart';
import 'constants.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key, required this.pageSelectorController})
      : super(key: key);

  final PageSelectorController pageSelectorController;

  @override
  State<LoginPage> createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
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
    if (mounted) {
      setState(() {
        connectingInformation = null;
        widget.pageSelectorController.tunedInState = TunedInState.tunedOut;
      });
    }
    await showDialog(
        context: context,
        builder: (BuildContext context) {
          Future.delayed(Duration(seconds: 5), () {
            Navigator.of(context).pop(true);
          });
          return AlertDialog(
            title: Text("Error connecting to Spotify"),
            content: Text("$error"),
          );
        });
  }

  String? getScope() {
    String? scope;
    if (onWeb) {
      scope = spotifyAccessTokenScope;
    }
    return scope;
  }

  // TODO: Put a timeout on this.
  Future<void> getAccessTokenAndConnect() async {
    try {
      print("Getting new access token");
      setState(() {
        connectingInformation = "Getting new access token";
      });
      String accessToken = await SpotifySdk.getAccessToken(
        clientId: spotifyClientId,
        redirectUrl: spotifyRedirectUrl,
        scope: getScope(),
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
        scope: getScope(),
        playerName: appTitle,
        accessToken: accessToken,
      );
      if (mounted) {
        setState(() {
          connectingInformation = null;
        });
      }
      print("Successfully connected to Spotify");
    } catch (e) {
      await handleConnectionError(e);
      print("Failed to connect to Spotify: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];
    if (connectingInformation != null) {
      children += [
        Text(connectingInformation!),
        Padding(padding: EdgeInsets.only(top: 20)),
        CircularProgressIndicator(),
      ];
    } else {
      String connectButtonText = "Connect to Spotify";
      children += [
        getConnectionButton(connectButtonText, getAccessTokenAndConnect)
      ];
    }

    Widget body = Center(
        child: Column(
      children: children,
      mainAxisAlignment: MainAxisAlignment.center,
    ));

    return buildTopLevelScaffold(widget.pageSelectorController, body,
        title: "Login");

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
