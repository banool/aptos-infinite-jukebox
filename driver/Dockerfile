# Start with a Rust alpine image.
FROM rust:1.60 as build

# Copy in the code.
WORKDIR /build
COPY . .

# Add the necessary libraries to build the binaries.
RUN apt-get update && apt-get install -y libclang-dev

# Get the aptos CLI
RUN cargo install --git https://github.com/aptos-labs/aptos-core.git aptos --root /

# Build the binary, strip it to make it smaller.
RUN cargo build --release
RUN strip target/release/driver

# Make a new build stage.
FROM debian:buster-slim

# Copy in the binary from the previous build stage.
COPY --from=build /build/target/release/driver /bin/driver
COPY --from=build /bin/aptos /bin/aptos

# Run it.
ENTRYPOINT ["/bin/driver"]
