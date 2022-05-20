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