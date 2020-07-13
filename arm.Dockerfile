FROM messense/rust-musl-cross:armv7-musleabihf AS build

# install elm
RUN curl -L -o elm.gz https://github.com/elm/compiler/releases/download/0.19.1/binary-for-linux-64-bit.gz \
    && gunzip elm.gz \
    && chmod +x elm \
    && mv elm /usr/local/bin/

RUN mkdir -p /home/rust/src
WORKDIR /home/rust/src
COPY . /home/rust/src

RUN cargo build --release
RUN musl-strip target/armv7-unknown-linux-musleabihf/release/web

RUN elm make src-ui/Main.elm --output static/elm.js

FROM alpine as certs

RUN apk update && apk add ca-certificates

FROM busybox:musl

WORKDIR /
COPY --from=build /home/rust/src/target/armv7-unknown-linux-musleabihf/release/web /bin/kodi_helper
COPY --from=build /home/rust/src/static /static

COPY --from=certs /etc/ssl/certs /etc/ssl/certs
ENV SSL_CERT_FILE /etc/ssl/certs/ca-certificates.crt
ENV SSL_CERT_DIR /etc/ssl/certs
