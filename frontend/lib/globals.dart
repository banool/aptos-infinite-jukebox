import 'package:aptos_sdk_dart/aptos_sdk_dart.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify/spotify.dart';

import 'playback_manager.dart';

late SharedPreferences sharedPreferences;
late PlaybackManager playbackManager;
late PackageInfo packageInfo;
late bool onWeb;

SpotifyApi? spotifyApi;

AptosAccount? aptosAccount;
HexString? privateKey;
