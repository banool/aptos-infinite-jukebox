import 'package:aptos_infinite_jukebox/login_page.dart';
import 'package:aptos_infinite_jukebox/page_selector.dart';
import 'package:flutter/material.dart';
import 'package:spotify_sdk/models/connection_status.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

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
    ConnectionStatus? connectionStatus =
        InheritedSpotifyConnectionStatus.of(context).connectionStatus;
    if (connectionStatus == null) {
      print("No subscription status");
      return LoginPage(pageSelectorController: widget.pageSelectorController);
    }

    Widget page;
    if (connectionStatus.connected) {
      page =
          LoggedInPage(pageSelectorController: widget.pageSelectorController);
    } else {
      page = LoginPage(pageSelectorController: widget.pageSelectorController);
    }

    return page;
  }
}
