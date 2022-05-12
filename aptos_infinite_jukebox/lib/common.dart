import 'package:flutter/material.dart';

const String appTitle = "Aptos Infinite Jukebox";
const Color mainColor = Colors.blueGrey;
const String spotifyClientId = "e02b0452a18948a9a963b35bd4a4f743";

late String spotifyRedirectUrl;

const String spotifyAccessTokenScope =
    "app-remote-control,user-modify-playback-state,playlist-read-private,playlist-modify-public,user-read-currently-playing";

const String keySpotifyAccessToken = "keySpotifyAccessToken";

const String aptosNodeUrl = "https://fullnode.devnet.aptoslabs.com";
const String publicAddress =
    "c40f1c9b9fdc204cf77f68c9bb7029b0abbe8ad9e5561f7794964076a4fbdcfd";
const String moduleAddress =
    "c40f1c9b9fdc204cf77f68c9bb7029b0abbe8ad9e5561f7794964076a4fbdcfd";
const String moduleName = "JukeboxV7";
