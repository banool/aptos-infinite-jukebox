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

## Deploying IterableTable

First, clone aptos-core, then make these changes:
```
diff --git i/aptos-move/move-examples/data_structures/Move.toml w/aptos-move/move-examples/data_structures/Move.toml
index ba1120d3bf..9256bf206e 100644
--- i/aptos-move/move-examples/data_structures/Move.toml
+++ w/aptos-move/move-examples/data_structures/Move.toml
@@ -6,4 +6,4 @@ version = "0.0.1"
 AptosStdlib = { local = "../../framework/aptos-stdlib" }

 [addresses]
-std = "0x1"
+dport_collections = "0xb078d693856a65401d492f99ca0d6a29a0c5c0e371bc2521570a86e40d95f823"
diff --git i/aptos-move/move-examples/data_structures/sources/big_vector.move w/aptos-move/move-examples/data_structures/sources/big_vector.move
index ee620850e6..838f78ec22 100644
--- i/aptos-move/move-examples/data_structures/sources/big_vector.move
+++ w/aptos-move/move-examples/data_structures/sources/big_vector.move
@@ -1,4 +1,4 @@
-module aptos_std::big_vector {
+module dport_collections::big_vector {
     use std::error;
     use std::vector;
     use aptos_std::table_with_length::{Self, TableWithLength};
diff --git i/aptos-move/move-examples/data_structures/sources/bucket_table.move w/aptos-move/move-examples/data_structures/sources/bucket_table.move
index 44d8f5c755..bc7de0fce4 100644
--- i/aptos-move/move-examples/data_structures/sources/bucket_table.move
+++ w/aptos-move/move-examples/data_structures/sources/bucket_table.move
@@ -2,7 +2,7 @@
 /// Compare to Table, it uses less storage slots but has higher chance of collision, it's a trade-off between space and time.
 /// Compare to other implementation, linear hashing splits one bucket a time instead of doubling buckets when expanding to avoid unexpected gas cost.
 /// BucketTable uses faster hash function SipHash instead of cryptographically secure hash functions like sha3-256 since it tolerates collisions.
-module aptos_std::bucket_table {
+module dport_collections::bucket_table {
     use std::error;
     use std::vector;
     use aptos_std::aptos_hash::sip_hash_from_value;
diff --git i/aptos-move/move-examples/data_structures/sources/iterable_table.move w/aptos-move/move-examples/data_structures/sources/iterable_table.move
index 82509c0b6f..9aed0eb9f7 100644
--- i/aptos-move/move-examples/data_structures/sources/iterable_table.move
+++ w/aptos-move/move-examples/data_structures/sources/iterable_table.move
@@ -1,4 +1,4 @@
-module aptos_std::iterable_table {
+module dport_collections::iterable_table {
     use std::option::{Self, Option};
     use aptos_std::table_with_length::{Self, TableWithLength};
```

You might need to change the address in Move.toml above if you don't have the private key to that account anymore.

Then run `aptos init` in `aptos-move/move-examples/data_structures` for testnet and publish the module.
