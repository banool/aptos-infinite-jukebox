# Move Module

## Setting up the aptos CLI
```
cd ~
aptos config init
```

If you already have a config but you need to recreate the account, e.g. for a new devnet release, do this:
```
aptos config init --private-key `yq .profiles.default.private_key < ~/.aptos/config.yml`
```

This also works:
```
aptos account create --private-key `yq .profiles.default.private_key < ~/.aptos/config.yml` --account `yq .profiles.default.account < ~/.aptos/config.yml`
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
aptos move run --function-id 'c40f1c9b9fdc204cf77f68c9bb7029b0abbe8ad9e5561f7794964076a4fbdcfd::JukeboxV<latest>::initialize_jukebox' --max-gas 10000
```

You can confirm whether this worked by running
```
aptos move run --function-id 'c40f1c9b9fdc204cf77f68c9bb7029b0abbe8ad9e5561f7794964076a4fbdcfd::JukeboxV<latest>::get_current_song'
```

## Voting
To vote with just the CLI, try something like this:
```
aptos move run --function-id c40f1c9b9fdc204cf77f68c9bb7029b0abbe8ad9e5561f7794964076a4fbdcfd::JukeboxV<latest>::vote  --max-gas 10000 --args address:c40f1c9b9fdc204cf77f68c9bb7029b0abbe8ad9e5561f7794964076a4fbdcfd --args string:2GCZDNEHjBeTSr99hurnaf
```

## Uprading the version of aptos-framework
You'll see that in Move.toml, the version of aptos-framework is pinned to a particular revision of the repo. This is important, because over time we land changes to the framework that aren't immediately reflected in the devnet. While those changes (ideally) would work on a test net running from that same revision, a newer version of the framework might not work on the current test net. Each time a new devnet is released, we can (and might have to) pin to a later revision.

## Troubleshooting
- When testing / publishing, you might find some unexpected weird compilation errors. It's possible that we haven't invalidated the move package cache properly. In that case, run `rm ~/.move`.
- The build dependencies aren't the only thing that matter, you need to make sure you're using the correct version of the CLI as well. You may even need to test with one version but publish with another.