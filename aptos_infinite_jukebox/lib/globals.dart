import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify/spotify.dart';

import 'playback_manager.dart';

late SharedPreferences sharedPreferences;
late PlaybackManager playbackManager;

SpotifyApi? spotifyApi;

late bool onWeb;
