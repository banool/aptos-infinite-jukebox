# Driver

## Developing
You want to run it like this every few seconds:
```
cargo run -- -d --spotify-client-id 'aaaaaaaaaaaaaaaa' --spotify-client-secret 'bbbbbbbbbbbbbbbbbb' --account-private-key cccccccc
```

## Deploying
The driver is built into a container automatically by GitHub Actions. For my setup, it is then deployed with [banool/server-setup](https://github.com/banool/server-setup).

The container is configured to run the binary repeatedly without shutting down using `run_periodically.sh`. If you want to just run the binary once per container invocation, include something like `--rm --entrypoint /bin/driver`.
