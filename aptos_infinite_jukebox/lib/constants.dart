import 'package:flutter/material.dart';

const String appTitle = "Aptos Infinite Jukebox";
const Color mainColor = Colors.blueGrey;

const String spotifyClientId = "e02b0452a18948a9a963b35bd4a4f743";
late String spotifyRedirectUrl;

const String spotifyAccessTokenScope =
    "app-remote-control,user-modify-playback-state,playlist-read-private,playlist-modify-public,user-read-currently-playing";

const Color spotifyGreen = Color.fromRGBO(101, 212, 110, 1.0);

// Shared preferences keys.
const String keySpotifyAccessToken = "keySpotifyAccessToken";
const String defaultAptosNodeUrl = "https://fullnode.devnet.aptoslabs.com";
const String defaultPublicAddress =
    "c40f1c9b9fdc204cf77f68c9bb7029b0abbe8ad9e5561f7794964076a4fbdcfd";
const String defaultModuleAddress =
    "c40f1c9b9fdc204cf77f68c9bb7029b0abbe8ad9e5561f7794964076a4fbdcfd";
const String defaultModuleName = "JukeboxV7";

// Shared preferences defaults.
const String keyAptosNodeUrl = "keyAptosNodeUrl";
const String keyPublicAddress = "keyPublicAddress";
const String keyModuleAddress = "keyModuleAddress";
const String keyModuleName = "keyModuleName";
