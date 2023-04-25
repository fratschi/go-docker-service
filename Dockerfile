###################################################################################
## Multistage docker build for creating a smallest possible docker container
###################################################################################

ARG GO_VERSION=1.17

## Stage 1
## Prepare dev environment for building service

FROM golang:${GO_VERSION}-alpine AS dev

RUN apk update && apk add --no-cache git ca-certificates tzdata && update-ca-certificates

ENV GO111MODULE="on" \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOFLAGS="-mod=vendor"

EXPOSE ${APP_PORT}
ENTRYPOINT ["sh"]

## Stage 2
## Downloading required modules and building go service in separate build environment

FROM dev as build

ENV USER=serviceuser
ENV UID=10001

RUN mkdir /var/app && mkdir vendor
COPY --from=0 /workdir /var/app
WORKDIR /var/app

RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    "${USER}"

## Build
RUN (([ ! -d "./vendor" ] && go mod download && go mod vendor) || true) && RUN go build -ldflags="-s -w" -mod vendor -o service ./cmd/main.go
RUN chmod +x service

## Stage 3
## Assemble final service container from an empty scratch image

FROM scratch AS service

COPY --from=build /var/app/service /service
COPY --from=build /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /etc/passwd /etc/passwd
COPY --from=build /etc/group /etc/group

EXPOSE 8080

USER serviceuser:serviceuser

ENTRYPOINT ["/service"]
CMD ""