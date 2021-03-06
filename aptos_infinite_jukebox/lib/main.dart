import 'package:aptos_infinite_jukebox/page_selector.dart';
import 'package:aptos_infinite_jukebox/playback_manager.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import 'constants.dart';
import 'globals.dart';
import 'make_vote_page.dart';

Future<void> setup() async {
  print("Setup starting");

  WidgetsFlutterBinding.ensureInitialized();

  onWeb = false;
  spotifyRedirectUrl =
      "https://aptos-infinite-jukebox.dport.me/auth_callback.html";
  if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      spotifyRedirectUrl = "spotify-ios-quick-start://spotify-login-callback";
    }
  } else if (defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows) {
    onWeb = true;
  } else {
    onWeb = true;
  }

  // Load shared preferences. We do this first because the later futures,
  // such as loadFavourites and the knobs, depend on it being initialized.
  sharedPreferences = await SharedPreferences.getInstance();

  var privateKeyRaw = sharedPreferences.getString(keyPrivateKey);
  if (privateKeyRaw != null) {
    try {
      instantiateAptosAccount(privateKeyRaw);
    } catch (e) {
      print("Failed to process private key on launch, wiping it");
      await sharedPreferences.remove(keyPrivateKey);
      uninstantiateAptosAccount();
    }
  }

  playbackManager = await PlaybackManager.getPlaybackManager();

  packageInfo = await PackageInfo.fromPlatform();

  print("Setup finished");
}

Future<void> main() async {
  await setup();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: mainColor as MaterialColor,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const PageSelector(),
    );
  }
}
