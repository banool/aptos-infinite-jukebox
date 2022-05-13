# Driver

## Developing
You want to run it like this every few seconds:
```
cargo run -- -d --spotify-client-id 'aaaaaaaaaaaaaaaa' --spotify-client-secret 'bbbbbbbbbbbbbbbbbb' --account-private-key cccccccc --account-public-address 'ddddddddd'
```

## Deploying
The driver is built into a container automatically by GitHub Actions. For my setup, it is then deployed with [banool/server-setup](https://github.com/banool/server-setup).