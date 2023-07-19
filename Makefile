SHELL := /usr/bin/env bash -o pipefail
PACKAGE_PREFIX ?= prt
PACKAGE_VERSION ?= $(shell git tag --list 'v*' | sort -V | tail -n1 || echo v0)
PYTHON_VERSION ?= 3.11.4
PRT_ROOT ?= /prt
BUILDER_IMAGE_NAME ?= prt-builder
TEST_IMAGE_NAME ?= prt-test

PACKAGE_NAME ?= $(PACKAGE_PREFIX)_$(PACKAGE_VERSION).tgz
INTERACTIVE = $(shell if tty -s; then echo "-it"; else echo ""; fi)

# Dependecies that should cause rebuild of the builder container image
BUILDER_DEPS = Dockerfile build-runtime pip.conf $(wildcard post-patch/*.patch) $(wildcard python-requirements/*.txt)

# Build the builder container image
builder-image: .builder-image
.builder-image: $(BUILDER_DEPS)
	docker image build -t $(BUILDER_IMAGE_NAME) . && \
	id=$$(docker image inspect -f '{{.Id}}' $(BUILDER_IMAGE_NAME)) && echo "$${id}" > .builder-image

# Build the runtime package
package: $(PACKAGE_NAME)
$(PACKAGE_NAME): .builder-image build-runtime
	docker container run $(INTERACTIVE) --rm -v $(shell pwd):/output -w /output -e OUTPUT_DIR=/output -e PACKAGE_NAME=$(PACKAGE_NAME) -e PYTHON_VERSION=$(PYTHON_VERSION) $(BUILDER_IMAGE_NAME) ./build-runtime

# Test the package by installing it into a fresh container
test-install:
	docker image build -t $(TEST_IMAGE_NAME) -f Dockerfile.test --build-arg PRT_PACKAGE=$(PACKAGE_NAME) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --rm $(INTERACTIVE) $(TEST_IMAGE_NAME) $(PRT_ROOT)/bin/python --version

# Cleanup everything
clobber: clean
clean:
	$(RM) .builder-image
	docker image rm $(BUILDER_IMAGE_NAME) $(TEST_IMAGE_NAME) || true
