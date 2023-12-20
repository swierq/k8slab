FROM alpine:latest

COPY ./bin/goapp /usr/bin/goapp
RUN apk add --no-cache gcompat

ENTRYPOINT "/usr/bin/goapp"