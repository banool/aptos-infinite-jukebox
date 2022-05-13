import 'dart:async';

import 'package:aptos_infinite_jukebox/globals.dart';
import 'package:aptos_infinite_jukebox/login_page.dart';
import 'package:aptos_infinite_jukebox/page_selector.dart';
import 'package:aptos_infinite_jukebox/playback_manager.dart';
import 'package:aptos_infinite_jukebox/player_page.dart';
import 'package:flutter/material.dart';
import 'package:spotify_sdk/models/connection_status.dart';
import 'package:spotify_sdk/models/player_state.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

import 'constants.dart';
import 'logged_in_page.dart';

class PlayerSelector extends StatefulWidget {
  const PlayerSelector({Key? key, required this.pageSelectorController})
      : super(key: key);

  final PageSelectorController pageSelectorController;

  @override
  State<PlayerSelector> createState() => PlayerSelectorState();
}

class PlayerSelectorState extends State<PlayerSelector> {
  @override
  Widget build(BuildContext context) {
    Widget w = StreamBuilder<ConnectionStatus>(
        stream: SpotifySdk.subscribeConnectionStatus(),
        builder: (context, snapshot) {
          if (snapshot.data == null) {
            print("No subscription status");
            return LoginPage(
                pageSelectorController: widget.pageSelectorController);
          }
          ConnectionStatus connectionStatus = snapshot.data!;
          print("Connected: ${connectionStatus.connected}");

          Widget page;
          if (connectionStatus.connected) {
            page = LoggedInPage(
                pageSelectorController: widget.pageSelectorController);
          } else {
            page = LoginPage(
                pageSelectorController: widget.pageSelectorController);
          }

          return page;

          /*
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
          */
        });

    return w;
  }
}
