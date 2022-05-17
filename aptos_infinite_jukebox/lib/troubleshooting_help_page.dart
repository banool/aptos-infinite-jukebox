import 'package:aptos_infinite_jukebox/page_selector.dart';
import 'package:flutter/material.dart';

import 'help_page_common.dart';

Widget getTroubleshootingHelpPage(
    PageSelectorController pageSelectorController) {
  return HelpPage(
      pageSelectorController: pageSelectorController,
      title: "App FAQ",
      items: const {
        "What do I do if playback won't sync?": [
          "Make sure your Spotify queue is empty prior to trying to "
              "sync up. The Spotify SDK doesn't offer a way for us to clear it "
              "for you, so you must do it yourself.",
          "Make sure your system time is correct. The app cannot sync if your "
              "time is even a few seconds off.",
          "If none of these steps work, it's possible the underlying "
              "infrastructure isn't working, in particular the cron responsible "
              "for driving the state of the jukebox forward. For now contact the "
              "developer to figure out if this is a known ongoing issue."
        ],
        "What do I do if voting doesn't work?": [
          "Make sure your account is topped up. We're in the devnet / testnet "
              "phase right now, so use another wallet to hit the faucet a few "
              "times. ",
          "Make sure you're entering a Spotify song link / track ID. You can "
              "get this from going to Spotify, right clicking / tapping on the 3 "
              "dots for a song, and hitting \"Copy Song Link\"",
          "Please don't put in an invalid song link because we can't handle "
              "it right now lol."
        ],
        "Is it safe to store my private key in this app?": [
          "It depends on your trust model. Do you trust Apple / Google? Do you "
              "trust their backup services? Do you maintain good personal security "
              "of your phone? Do you trust that the source code I have posted "
              "to GitHub is the code this app is actually running? You'll have "
              "to make the call based on how you feel about these risks. "
        ],
      });
}
