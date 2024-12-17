FROM rust:alpine3.20 as builder
RUN apk add --no-cache musl-dev
WORKDIR /usr/src/kayfabe-lobby
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo 'pub fn main() {}' > src/main.rs && cargo build --release && rm -rf src
COPY src ./src
RUN touch src/main.rs && cargo install --path .

FROM alpine:3.20
COPY --from=builder /usr/local/cargo/bin/kayfabe-lobby-server /usr/local/bin/kayfabe-lobby-server
ENV RUST_LOG=debug
CMD ["kayfabe-lobby-server"]
