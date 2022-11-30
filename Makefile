# Set the shell to bash always
SHELL := /bin/bash

CRANK=$(HOME)/crank

# Options
ORG_NAME=gcr.io/ironcore-dev-1
PROVIDER_NAME=provider-cloudflare
VERSION=v0.0.1-4

build: generate test
	@CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -o ./bin/$(PROVIDER_NAME)-controller cmd/provider/main.go

images: image pkg

image: generate
	docker build . -t $(ORG_NAME)/$(PROVIDER_NAME)-controller:$(VERSION) -f cluster/Dockerfile

pkg:
	rm -rf package/temp
	mkdir -p package/temp/root
	sed 's/image: \([^:]*\):.*/image: \1:$(VERSION)/' < package/crossplane.yaml > package/temp/root/package.yaml
	find package/crds -name \*.yaml | while read F ; do echo "---" >> package/temp/root/package.yaml ; cat $$F >> package/temp/root/package.yaml ; done
	tar -C package/temp/root -cf package/temp/layer.tar .
	docker import package/temp/layer.tar $(ORG_NAME)/$(PROVIDER_NAME):$(VERSION)
	rm -rf package/temp

push: image-push pkg-push

clamscan: image-scan pkg-scan

image-scan: image
	docker save -o /tmp/docker.tar $(ORG_NAME)/$(PROVIDER_NAME)-controller:$(VERSION)
	clamscan /tmp/docker.tar

pkg-scan: pkg
	docker save -o /tmp/docker.tar $(ORG_NAME)/$(PROVIDER_NAME):$(VERSION)
	clamscan /tmp/docker.tar

image-push: image
	docker push $(ORG_NAME)/$(PROVIDER_NAME)-controller:$(VERSION)

pkg-push: pkg
	docker push $(ORG_NAME)/$(PROVIDER_NAME):$(VERSION)

run: generate
	kubectl apply -f package/crds/ -R
	go run cmd/provider/main.go -d

all: image image-push install

generate:
	go generate ./...
	@find package/crds -name *.yaml -exec sed -i.sed -e '1,2d' {} \;
	@find package/crds -name *.yaml.sed -delete

lint:
	$(LINT) run

tidy:
	go mod tidy

test:
	go test -v ./...

# Tools

KIND=$(shell which kind)
LINT=$(shell which golangci-lint)

.PHONY: generate tidy lint clean build image all run