# Start with a Rust alpine image.
FROM rust:1.60-alpine3.15 as build

# Copy in the code.
WORKDIR /build
COPY . .

# Add necessary dependencies.
RUN apk add --no-cache openssl openssl-dev musl-dev

# Get the aptos CLI
RUN cargo install --git https://github.com/aptos-labs/aptos-core.git aptos --root /

# Build the binary, strip it to make it smaller.
RUN cargo build --release
RUN strip target/release/driver

# Make a new build stage.
FROM alpine:3.15

# Copy in the binary from the previous build stage.
COPY --from=build /build/target/release/driver /bin/driver
COPY --from=build /bin/aptos /bin/aptos

# Add the necessary libraries for running this binary.
RUN apk add --no-cache libc6-compat

# Run it.
ENTRYPOINT ["/bin/driver"]
