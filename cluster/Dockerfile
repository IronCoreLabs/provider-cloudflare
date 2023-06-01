# Build the manager binary
FROM golang:1.19 as builder

WORKDIR /workspace
# Copy the Go Modules manifests
COPY go.mod go.mod
COPY go.sum go.sum
# cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN go mod download

# Copy the go source
COPY ./ ./

# Build
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GO111MODULE=on go build -a -o provider cmd/provider/main.go

# This container collects the shared libs we'll need in the final container.
FROM alpine:3.18 as libs
# Bootstrap apk in /newroot from /.
RUN mkdir -p /newroot/etc/apk
RUN cp -r /etc/apk/repositories /etc/apk/keys /newroot/etc/apk/
# Add the packages needed by our final stage.
RUN apk add --root /newroot --initdb ca-certificates-bundle
# Remove cache and empty directories.
RUN rm -r /newroot/var/cache/apk /newroot/etc/apk

FROM scratch as final
WORKDIR /
COPY --from=libs /newroot/ /
COPY --from=builder /workspace/provider .
COPY package /

EXPOSE 8080
ENTRYPOINT ["/provider"]