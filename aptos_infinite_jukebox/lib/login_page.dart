import 'dart:async';

import 'package:aptos_infinite_jukebox/globals.dart';
import 'package:aptos_infinite_jukebox/page_selector.dart';
import 'package:flutter/material.dart';
import 'package:spotify/spotify.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

import 'common.dart';
import 'constants.dart';
import 'playback_manager.dart';

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
    String? accessToken;
    try {
      accessToken = readAccessTokenFromStorage();
    } catch (e) {
      await sharedPreferences.remove(keySpotifyAccessToken);
    }
    if (accessToken != null) {
      print("Access token found on launch: $accessToken");
      await connectToSpotify(accessToken);
    }
  }

  int getNowInSeconds() {
    return DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  Future<void> writeAccessTokenToStorage(String accessToken) async {
    await sharedPreferences.setString(
        keySpotifyAccessToken, "$accessToken==::==${getNowInSeconds()}");
  }

  // Assume access tokens only last 3600 seconds.
  String? readAccessTokenFromStorage() {
    String? accessTokenRaw = sharedPreferences.getString(keySpotifyAccessToken);
    if (accessTokenRaw == null) {
      return null;
    }
    var s = accessTokenRaw.split("==::==");
    String accessToken = s[0];
    int timeStored = int.parse(s[1]);
    if (getNowInSeconds() - timeStored > 3500) {
      return null;
    }
    return accessToken;
  }

  Future<void> handleConnectionError(Object error) async {
    await sharedPreferences.remove(keySpotifyAccessToken);
    if (mounted) {
      setState(() {
        connectingInformation = null;
        playbackManager.setTunedInState(TunedInState.tunedOut);
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
      await writeAccessTokenToStorage(accessToken);
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
        scope: getScope(),
        playerName: appTitle,
        accessToken: accessToken,
      );
      spotifyApi = SpotifyApi.withAccessToken(accessToken);
      if (mounted) {
        setState(() {
          connectingInformation = null;
        });
      } else {
        widget.pageSelectorController.refresh();
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
  }
}
