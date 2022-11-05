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
const String defaultAptosNodeUrl = "https://fullnode.testnet.aptoslabs.com";
const String defaultJukeboxAddress =
    "b078d693856a65401d492f99ca0d6a29a0c5c0e371bc2521570a86e40d95f823";
const String defaultModuleAddress =
    "b078d693856a65401d492f99ca0d6a29a0c5c0e371bc2521570a86e40d95f823";
const String defaultModuleName = "Jukebox";
const String? defaultPrivateKey = null;

const Duration spotifyActionDelay = Duration(milliseconds: 500);
