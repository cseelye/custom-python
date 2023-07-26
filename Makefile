SHELL := /usr/bin/env bash -o pipefail
PACKAGE_PREFIX ?= prt
PACKAGE_VERSION ?= $(shell git tag --list 'v*' | sort -V | tail -n1 || echo v0)
PYTHON_VERSION ?= 3.11.4
PRT_ROOT ?= /prt
BUILDER_IMAGE_NAME ?= prt-builder
TEST_IMAGE_NAME ?= prt-tester

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

# Test the runtime in a fresh container image
test: $(PACKAGE_NAME)
	docker image build -t $(TEST_IMAGE_NAME) -f Dockerfile.test --build-arg PRT_PACKAGE=$(PACKAGE_NAME) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --rm $(INTERACTIVE) -v $(shell pwd):/work -w /work -e PRT_ROOT=$(PRT_ROOT) $(TEST_IMAGE_NAME) ./test-runtime

# Test the package by installing it into a fresh container
test-install: $(PACKAGE_NAME)
	docker image build -t $(TEST_IMAGE_NAME) -f Dockerfile.test --build-arg PRT_PACKAGE=$(PACKAGE_NAME) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --rm $(INTERACTIVE) $(TEST_IMAGE_NAME) $(PRT_ROOT)/bin/python --version

# Cleanup everything
clobber: clean
clean:
	$(RM) .builder-image
	docker image rm $(BUILDER_IMAGE_NAME) $(TEST_IMAGE_NAME) || true
	$(RM) $(PACKAGE_PREFIX)_*.tgz
	$(RM) $(PACKAGE_PREFIX)_*.json

# Color variables
STYLE_REG=0
STYLE_BOLD=1
STYLE_DIM=2
STYLE_IT=3
STYLE_UNDER=4
STYLE_STRIKE=9
COLOR_BLACK=30
COLOR_RED=31
COLOR_GREEN=32
COLOR_YELLOW=33
COLOR_BLUE=34
COLOR_MAGENTA=35
COLOR_CYAN=36
COLOR_WHITE=37
COLOR_AMBER=208

COLOR_RESET=\033[0m
STRIKE=\033[$(STYLE_STRIKE)m
RED=\033[$(STYLE_REG);$(COLOR_RED)m
RED_BOLD=\033[$(STYLE_BOLD);$(COLOR_RED)m
YELLOW=\033[$(STYLE_REG);$(COLOR_YELLOW)m
YELLOW_BOLD=\033[$(STYLE_BOLD);$(COLOR_YELLOW)m
GREEN=\033[$(STYLE_REG);$(COLOR_GREEN)m
GREEN_BOLD=\033[$(STYLE_BOLD);$(COLOR_GREEN)m
CYAN=\033[$(STYLE_REG);$(COLOR_CYAN)m
CYAN_BOLD=\033[$(STYLE_BOLD);$(COLOR_CYAN)m
BLUE=\033[$(STYLE_REG);$(COLOR_BLUE)m
BLUE_BOLD=\033[$(STYLE_BOLD);$(COLOR_BLUE)m
MAGENTA=\033[$(STYLE_REG);$(COLOR_MAGENTA)m
MAGENTA_BOLD=\033[$(STYLE_BOLD);$(COLOR_MAGENTA)m
WHITE=\033[$(STYLE_REG);$(COLOR_WHITE)m
WHITE_BOLD=\033[$(STYLE_BOLD);$(COLOR_WHITE)m
AMBER=\033[$(STYLE_REG);38;5;$(COLOR_AMBER)m
AMBER_BOLD=\033[$(STYLE_BOLD);38;5;$(COLOR_AMBER)m

# Print help about recipes
.PHONY: help
help:
	@ \
	{ \
	echo ""; \
	echo -e "$(GREEN_BOLD)Build the runtime:$(COLOR_RESET)"; \
	echo -e "  make package                          Build the runtime and package it as a tarball in the current directory"; \
	echo -e "  make builder-image                    Build the docker image used to build the runtime"; \
	echo ""; \
	echo -e "$(GREEN_BOLD)Testing:$(COLOR_RESET)"; \
	echo -e "  make test-install                     Install the package in a fresh container and make sure it can be run there"; \
	echo ""; \
	echo -e "$(GREEN_BOLD)Cleanup:$(COLOR_RESET)"; \
	echo -e "  make clean                            Delete the package and the builder image"; \
	} | less -FKqrX
