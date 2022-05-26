# Aptos Infinite Jukebox

This project is made up of three major components:
- `aptos_infinite_jukebox`: This is the frontend for the project, made with Flutter. Users install this on their device / open this on the web, hook it up to Spotify, and then tune in to the infinite jukebox.
- `driver`: This runs periodically on a server to drive forward the move module. The driver checks the current song playing, determines if we're near the end of it, and if so, invokes vote resolution to determine which song to put on the queue next.
- `move_module`: This is where the core logic lives, on the [Aptos blockchain](https://aptoslabs.com). An account owner can use this module to instantiate a jukebox. Users can then submit votes for what song plays next. Periodically the driver runs to resolve the votes. The frontend hits the REST endpoint of a fullnode to perform reads (to determine what songs to play) against the module.

In addition to the core feature components, there is also code for deploying the project under `deployment` and `.github`.

Each of these components has their own README explaining how to develop and deploy them.

## Learning
For reasons I won't go in to here, I found myself with a couple of weeks of free time to work at the periphery of the Aptos ecosystem. I wanted to build a dapp on Aptos, but found that there was a lack of open source, end to end examples showing everything you need to build out a dapp on Aptos. In particular many of the examples didn't dive deep into certain features of the blockchain, such as tables, dealing with the on chain / off chain boundary, etc. To this end I've written a guide of sorts, that aims to teach you certain concepts by pointing you to where I implemented them right there in the code.

If you're interested in learning about Aptos through this project, check out [LEARNING.md](./LEARNING.md).

## Setting up this repo
When first pulling this repo, add this to `.git/hooks/pre-commit`:
```
#!/bin/bash

cd aptos_infinite_jukebox
./bump_version.sh
git add pubspec.yaml
```