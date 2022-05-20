# Start with a Rust alpine image.
FROM rust:1.60 as build

# Copy in the code.
WORKDIR /build
COPY . .

# Add the necessary libraries to build.
RUN apt-get update && apt-get install -y libclang-dev

# Build the binary, strip it to make it smaller.
RUN cargo build --release
RUN strip target/release/driver

# Make a new build stage.
FROM debian:bullseye-slim

# Copy in the binaries from the previous build stage.
COPY --from=build /build/target/release/driver /bin/driver

# Run the driver.
ENTRYPOINT ["/bin/driver"]
