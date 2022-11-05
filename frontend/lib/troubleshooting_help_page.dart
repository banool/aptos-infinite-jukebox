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
          "Try clearing your Spotify queue manually. The Spotify SDK doesn't "
              "offer us a way to do it natively, so we attempt to do a janky hack "
              "to clear it. This involes lots of steps and doesn't always work. "
              "Clearing the queue yourself first before trying to resync is a good "
              "way to help.",
          "Make sure your system time is correct. The app cannot sync if your "
              "time is even a few seconds off.",
          "Keep trying. The Spotify SDK really is pretty awful, sometimes it "
              "just takes a few attempts for it to decide to do the steps in the "
              "correct order.",
          "If none of these steps work, it's possible the underlying "
              "infrastructure isn't working, in particular the cron responsible "
              "for driving the state of the jukebox forward. For now contact the "
              "developer to figure out if this is a known ongoing issue."
        ],
        "What do I do if voting doesn't work?": [
          "Make sure your account is topped up. We're in the devnet / testnet "
              "phase right now, so use another wallet to hit the faucet a few "
              "times. ",
          "Make sure your system time is correct. If it is not, the timeout we "
              "calculate for your transaction will be wrong."
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
