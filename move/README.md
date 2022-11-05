# Move Module
All steps are relative to this directory.

## Setting up the aptos CLI
```
aptos config init
```
Select testnet. You'll then need to use a faucet to get some funds in the account.

## Setting up the module
Make sure the addresses in Move.toml matches the `account` field in ~/.aptos/config.yml`.

Publish the module:
```
aptos move publish
```

Run the initialization function, assuming you're happy to have a jukebox initialized to the same account where you published the module:
```
aptos move run --function-id "$(yq .profiles.default.account < .aptos/config.yaml)::jukebox::initialize_jukebox"
```

## Voting
To vote with just the CLI, try something like this:
```
aptos move run --function-id "$(yq .profiles.default.account < .aptos/config.yaml)::jukebox::vote" --args address:`yq .profiles.default.account < .aptos/config.yaml` string:2GCZDNEHjBeTSr99hurnaf
```

## Uprading the version of aptos-framework
You'll see that in Move.toml, the version of aptos-framework is pinned to a particular revision of the repo. This is important, because over time we land changes to the framework that aren't immediately reflected in the devnet. While those changes (ideally) would work on a test net running from that same revision, a newer version of the framework might not work on the current test net. Each time a new devnet is released, we can (and might have to) pin to a later revision.

## Troubleshooting
- When testing / publishing, you might find some unexpected weird compilation errors. It's possible that we haven't invalidated the move package cache properly. In that case, run `rm ~/.move`.
- The build dependencies aren't the only thing that matter, you need to make sure you're using the correct version of the CLI as well. You may even need to test with one version but publish with another.

## Deploying IterableTable

```
git clone git@github.com:aptos-labs/aptos-core.git
git switch banool/iterable_table_dport
```

Then run `aptos init` in `aptos-move/move-examples/data_structures` for testnet and publish the module.
