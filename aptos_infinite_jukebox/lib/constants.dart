import 'package:flutter/material.dart';

const String appTitle = "Aptos Infinite Jukebox";

const Color spotifyGreen = Color.fromRGBO(101, 212, 110, 1.0);
const Color mainColor = Colors.indigo;

const String spotifyClientId = "e02b0452a18948a9a963b35bd4a4f743";
late String spotifyRedirectUrl;

const String spotifyAccessTokenScope =
    "streaming user-read-email user-read-private user-read-currently-playing user-read-playback-state user-read-playback-position user-modify-playback-state";

// Shared preferences keys.
const String keySpotifyAccessToken = "keySpotifyAccessToken";
const String keyAptosNodeUrl = "keyAptosNodeUrl";
const String keyJukeboxAddress = "keyJukeboxAddress";
const String keyModuleAddress = "keyModuleAddress";
const String keyModuleName = "keyModuleName";
const String keyPrivateKey = "keyPrivateKey";
const String keyVotesTableHandle = "keyVotesTableHandle";

// Shared preferences defaults.
const String defaultAptosNodeUrl = "https://fullnode.devnet.aptoslabs.com";
const String defaultJukeboxAddress =
    "c40f1c9b9fdc204cf77f68c9bb7029b0abbe8ad9e5561f7794964076a4fbdcfd";
const String defaultModuleAddress =
    "c40f1c9b9fdc204cf77f68c9bb7029b0abbe8ad9e5561f7794964076a4fbdcfd";
const String defaultModuleName = "JukeboxV12";
const String? defaultPrivateKey = null;
