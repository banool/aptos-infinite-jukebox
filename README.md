# Aptos Infinite Jukebox

This project is made up of three major components:
- `aptos_infinite_jukebox`: This is the frontend for the project, made with Flutter. Users install this on their device / open this on the web, hook it up to Spotify, and then tune in to the infinite jukebox.
- `driver`: This runs periodically on a server to drive forward the move module. The driver checks the current song playing, determines if we're near the end of it, and if so, invokes vote resolution to determine which song to put on the queue next.
- `move_module`: This is where the core logic lives, on the [Aptos blockchain](https://aptoslabs.com). An account owner can use this module to instantiate a jukebox. Users can then submit votes for what song plays next. Periodically the driver runs to resolve the votes. The frontend hits the REST endpoint of a fullnode to perform reads (to determine what songs to play) against the module.

Each of these modules has their own README describing how to develop and deploy them.

## Setting up this repo
When first pulling this repo, add this to `.git/hooks/pre-commit`:
```
#!/bin/bash

cd aptos_infinite_jukebox
./bump_version.sh
git add pubspec.yaml
```