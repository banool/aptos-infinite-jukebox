# Move Module

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
aptos move run --function-id 'c40f1c9b9fdc204cf77f68c9bb7029b0abbe8ad9e5561f7794964076a4fbdcfd::JukeboxV<latest>::initialize_jukebox' --max-gas 10000
```

You can confirm whether this worked by running
```
aptos move run --function-id 'c40f1c9b9fdc204cf77f68c9bb7029b0abbe8ad9e5561f7794964076a4fbdcfd::JukeboxV<latest>::get_current_song'
```
