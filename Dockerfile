FROM golang:1.22-alpine3.19 AS build_base

RUN apk add --no-cache git

# Set the Current Working Directory inside the container
WORKDIR /tmp/bloger-app

# We want to populate the module cache based on the go.{mod,sum} files.
COPY go.mod ./
COPY go.sum ./

RUN go mod download

COPY . ./

# Unit tests
# RUN CGO_ENABLED=0 go test -v ./...

# Build the Go app
RUN go build -ldflags="-s -w" -o ./out/bloger .

# Creahe base image
FROM debian:12-slim AS base

RUN addgroup --gid 666 --system blogergroup \
    && adduser --uid 666 --system --home /home/blogeruser --ingroup blogergroup blogeruser \
    && mkdir -p /etc/sudoers.d \
    && echo 'blogeruser ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/blogeruser \
    && chmod 0440 /etc/sudoers.d/blogeruser

USER 666:666

# Create release image
FROM base AS bloger_release

WORKDIR /app
COPY --from=build_base /tmp/bloger-app/out/bloger ./

ENTRYPOINT ["./bloger"]
CMD ["release"]

# Create debug image
FROM base AS bloger_debug

WORKDIR /app

# install debug tool
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl unzip groff procps sudo ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build_base /tmp/bloger-app/out/bloger ./

ENTRYPOINT ["./bloger"]
CMD ["debug"]