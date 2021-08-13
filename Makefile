GO    := GO15VENDOREXPERIMENT=1 go
PROMU := $(GOPATH)/bin/promu
pkgs   = $(shell $(GO) list ./... | grep -v /vendor/)

PREFIX                  ?= $(shell pwd)
BIN_DIR                 ?= $(shell pwd)
DOCKER_IMAGE_NAME       ?= kafka-exporter
DOCKER_IMAGE_TAG        ?= $(subst /,-,$(shell git rev-parse --abbrev-ref HEAD))
TAG 					:= $(shell echo `if [ "$(TRAVIS_BRANCH)" = "master" ] || [ "$(TRAVIS_BRANCH)" = "" ] ; then echo "latest"; else echo $(TRAVIS_BRANCH) ; fi`)

DOCKER_ARCHS            ?= amd64 s390x

BUILD_DOCKER_ARCHS = $(addprefix docker-,$(DOCKER_ARCHS))
PUSH_DOCKER_ARCHS = $(addprefix docker-push-,$(DOCKER_ARCHS))

all: format build test

style:
	@echo ">> checking code style"
	@! gofmt -d $(shell find . -path ./vendor -prune -o -name '*.go' -print) | grep '^'

test:
	@echo ">> running tests"
	@$(GO) test -short $(pkgs)

format:
	@echo ">> formatting code"
	@$(GO) fmt $(pkgs)

vet:
	@echo ">> vetting code"
	@$(GO) vet $(pkgs)

build: promu
	@echo ">> building binaries"
	@$(PROMU) build --prefix $(PREFIX)

crossbuild: promu
	@echo ">> crossbuilding binaries"
	@$(PROMU) crossbuild --go=1.16

tarball: promu
	@echo ">> building release tarball"
	@$(PROMU) tarball --prefix $(PREFIX) $(BIN_DIR)

docker: crossbuild $(BUILD_DOCKER_ARCHS)
$(BUILD_DOCKER_ARCHS): docker-%:
	@echo ">> building docker images"
	@docker build -t "$(DOCKER_IMAGE_NAME)-linux-$*:$(DOCKER_IMAGE_TAG)" \
			--build-arg ARCH="$*" \
			--build-arg OS="linux" \
			.

push: $(PUSH_DOCKER_ARCHS)
$(PUSH_DOCKER_ARCHS): docker-push-%:
	@echo ">> pushing docker image, $(DOCKER_USERNAME),$(DOCKER_IMAGE_NAME),$(TAG)"
	@docker login -u $(DOCKER_USERNAME) -p $(DOCKER_PASSWORD)
	@docker tag "$(DOCKER_IMAGE_NAME)-linux-$*:$(DOCKER_IMAGE_TAG)" "$(DOCKER_USERNAME)/$(DOCKER_IMAGE_NAME)-linux-$*:$(TAG)"
	@docker push "$(DOCKER_USERNAME)/$(DOCKER_IMAGE_NAME)-linux-$*:$(TAG)"

docker-manifest: crossbuild
	@echo ">> crossbuilding docker images"
	@DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create -a "$(DOCKER_USERNAME)/$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)" $(foreach ARCH,$(DOCKER_ARCHS),$(DOCKER_USERNAME)/$(DOCKER_IMAGE_NAME)-linux-$(ARCH):$(DOCKER_IMAGE_TAG))
	@DOCKER_CLI_EXPERIMENTAL=enabled docker manifest push "$(DOCKER_USERNAME)/$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)"

release: promu github-release
	@echo ">> pushing binary to github with ghr"
	@$(PROMU) crossbuild tarballs
	@$(PROMU) release .tarballs

promu:
	@GOOS=$(shell uname -s | tr A-Z a-z) \
		GOARCH=$(subst x86_64,amd64,$(patsubst i%86,386,$(shell uname -m))) \
		$(GO) get -u github.com/prometheus/promu

github-release:
	@GOOS=$(shell uname -s | tr A-Z a-z) \
		GOARCH=$(subst x86_64,amd64,$(patsubst i%86,386,$(shell uname -m))) \
		$(GO) get -u github.com/aktau/github-release

.PHONY: all style format build test vet tarball docker promu docker-manifest $(BUILD_DOCKER_ARCHS) $(PUSH_DOCKER_ARCHS)
