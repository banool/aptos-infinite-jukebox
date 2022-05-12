# Start with a Rust alpine image.
FROM rust:1.60-alpine3.15 as build

# Copy in the code.
WORKDIR /build
COPY . .

# Add necessary dependencies.
RUN apk add --no-cache openssl openssl-dev musl-dev

# Build the binary, strip it to make it smaller.
RUN cargo build --release
RUN strip target/release/driver

# Make a new build stage.
FROM alpine:3.15

# Copy in the binary from the previous build stage.
COPY --from=build /build/target/release/driver .

# Run it.
ENTRYPOINT ["/driver"]
