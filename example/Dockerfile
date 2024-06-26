# syntax=docker.io/docker/dockerfile:1.7

FROM golang:1.22-bookworm as builder
WORKDIR /app
COPY go.* ./
RUN go mod download
COPY *.go ./
RUN CGO_ENABLED=0 go build -ldflags="-s"

# NB we use the bookworm-slim (instead of scratch) image so we can enter the container to execute bash etc.
FROM debian:12-slim
RUN <<EOF
#!/bin/bash
set -euxo pipefail
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates
rm -rf /var/lib/apt/lists/*
EOF
# see https://docs.aws.amazon.com/documentdb/latest/developerguide/connect_programmatically.html#connect_programmatically-tls_enabled
ADD --chmod=444 https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem /
COPY --from=builder /app/example /
EXPOSE 8080
WORKDIR /
ENTRYPOINT ["/example"]
