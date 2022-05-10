# Aptos Infinite Jukebox

## Setting up this repo
When first pulling this repo, add this to `.git/hooks/pre-commit`:
```
#!/bin/bash

cd aptos_infinite_jukebox
./bump_version.sh
git add pubspec.yaml
```

## Setting up the aptos CLI
```
cd ~
aptos config init
```

## Setting up the module
Make sure the addresses in Move.toml matches the `account` field in ~/.aptos/config.yml`.

Publish the module:
```
cd ~
aptos move publish --package-dir github/aptos-infinite-jukebox/move_module
```

Run the initialization function, assuming `c40f1c9b9fdc204cf77f68c9bb7029b0abbe8ad9e5561f7794964076a4fbdcfd` is where the module is published:
```
aptos move run --function-id 'c40f1c9b9fdc204cf77f68c9bb7029b0abbe8ad9e5561f7794964076a4fbdcfd::Jukebox::initialize_infinite_jukebox'
```

You can confirm whether this worked by running
```
aptos move run --function-id 'c40f1c9b9fdc204cf77f68c9bb7029b0abbe8ad9e5561f7794964076a4fbdcfd::Jukebox::get_current_song'
```

