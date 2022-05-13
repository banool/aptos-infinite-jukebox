# Start with a Rust alpine image.
FROM rust:1.60 as build

# Copy in the code.
WORKDIR /build
COPY . .

# Add the necessary libraries to build / get the binaries.
RUN apt-get update && apt-get install -y libclang-dev wget unzip

# Download the aptos CLI.
RUN wget https://github.com/aptos-labs/aptos-core/releases/download/cli-latest/aptos-v0.1.0-linux-x86_64.zip -O aptos.zip

# Move it into position.
RUN unzip aptos.zip

# Build the binary, strip it to make it smaller.
RUN cargo build --release
RUN strip target/release/driver

# Make a new build stage.
FROM debian:buster-slim

# Copy in the binaries from the previous build stage.
COPY --from=build /build/target/release/driver /bin/driver
COPY --from=build /build/aptos /bin/aptos

# TODO: Add glibc here or whatever is needed
RUN apt-get update && apt-get install -y libssl-dev 

# Run the driver.
ENTRYPOINT ["/bin/driver"]
