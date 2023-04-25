###################################################################################
## Multistage docker build for creating a smallest possible docker container
###################################################################################

ARG GO_VERSION=1.17

## Stage 1
## Prepare dev environment for building service

FROM golang:${GO_VERSION}-alpine AS dev

RUN apk update && apk add --no-cache git ca-certificates tzdata tree && update-ca-certificates

ENV APP_NAME="service" \
    APP_PORT=8080

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

RUN mkdir /var/app
COPY --from=0 /workdir /var/app
WORKDIR /var/app
RUN mkdir vendor
RUN tree

RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    "${USER}"

RUN ls -l
## Build
RUN echo "vendor"
RUN (([ ! -d "./vendor" ] && go mod download && go mod vendor) || true)
RUN echo "build"
RUN go build -ldflags="-s -w" -mod vendor -o ${APP_BUILD_NAME} cmd/main.go

RUN chmod +x ${APP_BUILD_NAME}

## Stage 3
## Assemble final service container from an empty scratch image

FROM scratch AS service

ENV APP_BUILD_PATH="/var/app" \
    APP_BUILD_NAME="service"

WORKDIR ${APP_BUILD_PATH}

COPY --from=build ${APP_BUILD_PATH}/${APP_BUILD_NAME} ${APP_BUILD_PATH}/
COPY --from=build /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /etc/passwd /etc/passwd
COPY --from=build /etc/group /etc/group

EXPOSE ${APP_PORT}

USER serviceuser:serviceuser

ENTRYPOINT ["/var/app/service"]
CMD ""