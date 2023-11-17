SHELL := /usr/bin/env bash -o pipefail

# Include optional vars file. Use this file to override any of the variables below
-include Makefile.vars

# Default values for variables that were not in Makefile.vars
PACKAGE_PREFIX ?= prt
PACKAGE_DESC ?= Custom python runtime
PACKAGE_MAINTAINER ?= John Doe
PACKAGE_VERSION ?= $(shell git tag --list 'v*' | sort -V | tail -n1 || echo v0)
ifeq ($(PACKAGE_VERSION),)
PACKAGE_VERSION := v0
endif
PYTHON_VERSION ?= 3.11.5
PRT_ROOT ?= /prt
ARTIFACT_DIR ?= out
CACHE_URL ?= http://172.17.0.1:9000/prt/cache

TEST_IMAGE_BASENAME ?= prt-tester
BUILDER_IMAGE_BASENAME ?= prt-builder

BUILDER_IMAGE_NAME := $(BUILDER_IMAGE_BASENAME)
BUILDER_IMAGE_NAME_ARM := $(BUILDER_IMAGE_BASENAME)-arm
TEST_IMAGE_NAME := $(TEST_IMAGE_BASENAME)
TEST_DEB_IMAGE_NAME := $(TEST_IMAGE_BASENAME)-deb
TEST_IMAGE_NAME_ARM := $(TEST_IMAGE_BASENAME)-arm
TEST_DEB_IMAGE_NAME_ARM := $(TEST_IMAGE_BASENAME)-deb-arm

PACKAGE_NAME_TEMPLATE ?= '$${PACKAGE_PREFIX}$${DEV_BUILD}_$${PACKAGE_VERSION}_$${ARCH}'
DEB_NAME_TEMPLATE ?= $${PACKAGE_PREFIX}$${DEV_BUILD}_$${PACKAGE_VERSION}_$${ARCH}.deb
PACKAGE_EXT ?= .tgz
MANIFEST_EXT ?= .manifest.json

PACKAGE_NAME := $(shell export PACKAGE_PREFIX=$(PACKAGE_PREFIX); export PACKAGE_VERSION=$(PACKAGE_VERSION); export DEV_BUILD=; export ARCH="x86_64"; echo '$(PACKAGE_NAME_TEMPLATE)' | envsubst )$(PACKAGE_EXT)
PACKAGE_NAME_DEV := $(shell export PACKAGE_PREFIX=$(PACKAGE_PREFIX); export PACKAGE_VERSION=$(PACKAGE_VERSION); export DEV_BUILD=-dev; export ARCH="x86_64"; echo '$(PACKAGE_NAME_TEMPLATE)' | envsubst )$(PACKAGE_EXT)
PACKAGE_NAME_ARM := $(shell export PACKAGE_PREFIX=$(PACKAGE_PREFIX); export PACKAGE_VERSION=$(PACKAGE_VERSION); export DEV_BUILD=; export ARCH="aarch64"; echo '$(PACKAGE_NAME_TEMPLATE)' | envsubst )$(PACKAGE_EXT)
PACKAGE_NAME_DEV_ARM := $(shell export PACKAGE_PREFIX=$(PACKAGE_PREFIX); export PACKAGE_VERSION=$(PACKAGE_VERSION); export DEV_BUILD=-dev; export ARCH="aarch64"; echo '$(PACKAGE_NAME_TEMPLATE)' | envsubst )$(PACKAGE_EXT)
DEB_NAME := $(shell export PACKAGE_PREFIX=$(PACKAGE_PREFIX); export PACKAGE_VERSION=$$(echo $(PACKAGE_VERSION) | sed 's/^v//'); export DEV_BUILD=; export ARCH=amd64; echo '$(DEB_NAME_TEMPLATE)' | envsubst)
DEB_NAME_DEV := $(shell export PACKAGE_PREFIX=$(PACKAGE_PREFIX); export PACKAGE_VERSION=$$(echo $(PACKAGE_VERSION) | sed 's/^v//'); export DEV_BUILD=-dev; export ARCH=amd64; echo '$(DEB_NAME_TEMPLATE)' | envsubst)
DEB_NAME_ARM := $(shell export PACKAGE_PREFIX=$(PACKAGE_PREFIX); export PACKAGE_VERSION=$$(echo $(PACKAGE_VERSION) | sed 's/^v//'); export DEV_BUILD=; export ARCH=arm64; echo '$(DEB_NAME_TEMPLATE)' | envsubst)
DEB_NAME_DEV_ARM := $(shell export PACKAGE_PREFIX=$(PACKAGE_PREFIX); export PACKAGE_VERSION=$$(echo $(PACKAGE_VERSION) | sed 's/^v//'); export DEV_BUILD=-dev; export ARCH=arm64; echo '$(DEB_NAME_TEMPLATE)' | envsubst)

# Print the values of the variables in a format that can be written to an env file - make env-file > .env
.PHONY: env-file
env-file:
	@echo "PACKAGE_NAME=$(PACKAGE_NAME)"
	@echo "PACKAGE_NAME_DEV=$(PACKAGE_NAME_DEV)"
	@echo "PACKAGE_NAME_ARM=$(PACKAGE_NAME_ARM)"
	@echo "PACKAGE_NAME_DEV_ARM=$(PACKAGE_NAME_DEV_ARM)"
	@echo "DEB_NAME=$(DEB_NAME)"
	@echo "DEB_NAME_DEV=$(DEB_NAME_DEV)"
	@echo "DEB_NAME_ARM=$(DEB_NAME_ARM)"
	@echo "DEB_NAME_DEV_ARM=$(DEB_NAME_DEV_ARM)"
	@echo "PYTHON_VERSION=$(PYTHON_VERSION)"
	@echo "PACKAGE_PREFIX=$(PACKAGE_PREFIX)"
	@echo "PACKAGE_EXT=$(PACKAGE_EXT)"
	@echo "MANIFEST_EXT=$(MANIFEST_EXT)"
	@echo "CACHE_URL=$(CACHE_URL)"
	@echo "BUILDER_IMAGE_NAME=$(BUILDER_IMAGE_NAME)"
	@echo "TEST_IMAGE_NAME=$(TEST_IMAGE_NAME)"
	@echo "TEST_DEB_IMAGE_NAME=$(TEST_DEB_IMAGE_NAME)"
	@echo "BUILDER_IMAGE_NAME_ARM=$(BUILDER_IMAGE_NAME_ARM)"
	@echo "TEST_IMAGE_NAME_ARM=$(TEST_IMAGE_NAME_ARM)"
	@echo "TEST_DEB_IMAGE_NAME_ARM=$(TEST_DEB_IMAGE_NAME_ARM)"
	@echo "PACKAGE_DESC='$(PACKAGE_DESC)'"
	@echo "PACKAGE_MAINTAINER='$(PACKAGE_MAINTAINER)'"

# Print the values of the variables in a format that can be eval to use them - eval $(make env)
.PHONY: env
env:
	@$(MAKE) -s env-file | sed -u "s/^/export /"

# Set verbose flag
V ?= 0
VERBOSE=
ifeq ($(V),1)
  VERBOSE=-e V=1
endif

# Set cache flag
CACHE_ARG=
ifeq ($(USE_PIP_CACHE),0)
  CACHE_ARG = -e USE_PIP_CACHE=0
endif
ifeq ($(USE_CACHE),0)
  CACHE_ARG = -e USE_CACHE=0 -e USE_PIP_CACHE=0
endif

# Make OUTPUT_DIR an absolute path from ARTIFACT_DIR
OUTPUT_DIR := $(shell realpath $(ARTIFACT_DIR))
FULL_PACKAGE_NAME := $(OUTPUT_DIR)/$(PACKAGE_NAME)
FULL_PACKAGE_NAME_ARM := $(OUTPUT_DIR)/$(PACKAGE_NAME_ARM)
FULL_PACKAGE_NAME_DEV := $(OUTPUT_DIR)/$(PACKAGE_NAME_DEV)
FULL_PACKAGE_NAME_DEV_ARM := $(OUTPUT_DIR)/$(PACKAGE_NAME_DEV_ARM)
FULL_DEB_NAME := $(OUTPUT_DIR)/$(DEB_NAME)
FULL_DEB_NAME_ARM := $(OUTPUT_DIR)/$(DEB_NAME_ARM)
FULL_DEB_NAME_DEV := $(OUTPUT_DIR)/$(DEB_NAME_DEV)
FULL_DEB_NAME_DEV_ARM := $(OUTPUT_DIR)/$(DEB_NAME_DEV_ARM)

# Determine if make is runing interactively or in a script
INTERACTIVE := $(shell if tty -s; then echo "-it"; else echo ""; fi)

# Determine the local CPU architecture
ifeq ($(shell uname -m),x86_64)
  LOCAL_PLATFORM=--platform=amd64
else ifeq ($(shell uname -m),aarch64)
  LOCAL_PLATFORM=--platform=arm64
endif

# Dependecies that should cause rebuild of the builder container image
BUILDER_DEPS = Dockerfile

# Dependecies that should cause rebuild of the package
RUNTIME_DEPS = build-runtime $(shell find ./config -type f -print 2>/dev/null || true)

# Dependecies that should cause rebuild of the dev package
RUNTIME_DEPS_DEV = build-runtime $(shell find ./dev-config -type f -print 2>/dev/null || true)

DEB_DEPS = build-deb $(shell find ./deb-config -type f -print 2>/dev/null || true)

# Build the builder container image
builder-image: .builder-image
.builder-image: $(BUILDER_DEPS)
	docker image build --platform=amd64 --no-cache --progress=plain -t $(BUILDER_IMAGE_NAME) . && \
	id=$$(docker image inspect -f '{{.Id}}' $(BUILDER_IMAGE_NAME)) && echo "$${id}" > .builder-image

builder-image-arm: .builder-image-arm
.builder-image-arm: $(BUILDER_DEPS)
	docker image build --platform=arm64 --progress=plain -t $(BUILDER_IMAGE_NAME_ARM) . && \
	id=$$(docker image inspect -f '{{.Id}}' $(BUILDER_IMAGE_NAME_ARM)) && echo "$${id}" > .builder-image-arm

$(OUTPUT_DIR):
	mkdir -p $(OUTPUT_DIR)

# Build the runtime package
runtime: $(FULL_PACKAGE_NAME)
runtime-dev: $(FULL_PACKAGE_NAME_DEV)
$(FULL_PACKAGE_NAME) $(FULL_PACKAGE_NAME_DEV): .builder-image $(RUNTIME_DEPS) $(RUNTIME_DEPS_DEV) | $(OUTPUT_DIR)
	docker container run --platform=amd64 $(INTERACTIVE) --rm $(VERBOSE) $(CACHE_ARG) \
		-v $(OUTPUT_DIR):/output -e OUTPUT_DIR=/output \
		-v $(shell pwd):/work -w /work \
		-e CACHE_URL="${CACHE_URL}" \
		-e RUNTIME_VER=$(PACKAGE_VERSION) \
		-e PACKAGE_NAME=$(PACKAGE_NAME) \
		-e PACKAGE_NAME_DEV=$(PACKAGE_NAME_DEV) \
		-e PYTHON_VERSION=$(PYTHON_VERSION) \
		$(BUILDER_IMAGE_NAME) \
		./build-runtime
runtime-arm: $(FULL_PACKAGE_NAME_ARM)
runtime-dev-arm: $(FULL_PACKAGE_NAME_DEV_ARM)
$(FULL_PACKAGE_NAME_ARM) $(FULL_PACKAGE_NAME_DEV_ARM): .builder-image-arm $(RUNTIME_DEPS) $(RUNTIME_DEPS_DEV) | $(OUTPUT_DIR)
	docker container run --platform=arm64 $(INTERACTIVE) --rm $(VERBOSE) $(CACHE_ARG) \
		-v $(OUTPUT_DIR):/output -e OUTPUT_DIR=/output \
		-v $(shell pwd):/work -w /work \
		-e CACHE_URL="${CACHE_URL}" \
		-e RUNTIME_VER=$(PACKAGE_VERSION) \
		-e PACKAGE_NAME=$(PACKAGE_NAME_ARM) \
		-e PACKAGE_NAME_DEV=$(PACKAGE_NAME_DEV_ARM) \
		-e PYTHON_VERSION=$(PYTHON_VERSION) \
		-e MTUNE= \
		$(BUILDER_IMAGE_NAME_ARM) \
		./build-runtime

# Test the runtime in a fresh container image
test: $(FULL_PACKAGE_NAME)
	docker image build --platform=amd64 --progress=plain --no-cache -t $(TEST_IMAGE_NAME) -f Dockerfile.test --build-arg PRT_PACKAGE=$(ARTIFACT_DIR)/$(PACKAGE_NAME) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --platform=amd64 --rm $(INTERACTIVE) -v $(shell pwd):/work -w /work -e PRT_ROOT=$(PRT_ROOT) -e RUNTIME_VER=$(PACKAGE_VERSION) $(TEST_IMAGE_NAME) ./test-runtime
test-arm: $(FULL_PACKAGE_NAME_ARM)
	docker image build --platform=arm64 --progress=plain --no-cache -t $(TEST_IMAGE_NAME_ARM) -f Dockerfile.test --build-arg PRT_PACKAGE=$(ARTIFACT_DIR)/$(PACKAGE_NAME_ARM) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --platform=arm64 --rm $(INTERACTIVE) -v $(shell pwd):/work -w /work -e PRT_ROOT=$(PRT_ROOT) -e RUNTIME_VER=$(PACKAGE_VERSION) $(TEST_IMAGE_NAME_ARM) ./test-runtime
test-dev: $(FULL_PACKAGE_NAME_DEV)
	docker image build --platform=amd64 --progress=plain --no-cache -t $(TEST_IMAGE_NAME) -f Dockerfile.test --build-arg PRT_PACKAGE=$(ARTIFACT_DIR)/$(PACKAGE_NAME_DEV) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --platform=amd64 --rm $(INTERACTIVE) -v $(shell pwd):/work -w /work -e DEV_INSTALL=1 -e PRT_ROOT=$(PRT_ROOT) -e RUNTIME_VER=$(PACKAGE_VERSION) $(TEST_IMAGE_NAME) ./test-runtime
test-arm-dev: $(FULL_PACKAGE_NAME_DEV_ARM)
	docker image build --platform=arm64 --progress=plain --no-cache -t $(TEST_IMAGE_NAME) -f Dockerfile.test --build-arg PRT_PACKAGE=$(ARTIFACT_DIR)/$(PACKAGE_NAME_DEV_ARM) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --platform=arm64 --rm $(INTERACTIVE) -v $(shell pwd):/work -w /work -e DEV_INSTALL=1 -e PRT_ROOT=$(PRT_ROOT) -e RUNTIME_VER=$(PACKAGE_VERSION) $(TEST_IMAGE_NAME) ./test-runtime
test-deb: deb
	docker image build --platform=amd64 --progress=plain --no-cache -t $(TEST_DEB_IMAGE_NAME) -f Dockerfile.test_deb --build-arg DEB_PACKAGE=$(ARTIFACT_DIR)/$(DEB_NAME) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --platform=amd64 --rm $(INTERACTIVE) -v $(shell pwd):/work -w /work -e DEB_INSTALL=1 -e PRT_ROOT=$(PRT_ROOT) -e RUNTIME_VER=$(PACKAGE_VERSION) $(TEST_DEB_IMAGE_NAME) ./test-runtime
test-deb-arm: deb-arm
	docker image build --platform=arm64 --progress=plain --no-cache -t $(TEST_DEB_IMAGE_NAME_ARM) -f Dockerfile.test_deb --build-arg DEB_PACKAGE=$(ARTIFACT_DIR)/$(DEB_NAME_ARM) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --platform=arm64 --rm $(INTERACTIVE) -v $(shell pwd):/work -w /work -e DEB_INSTALL=1 -e PRT_ROOT=$(PRT_ROOT) -e RUNTIME_VER=$(PACKAGE_VERSION) $(TEST_DEB_IMAGE_NAME_ARM) ./test-runtime
test-deb-dev: deb-dev
	docker image build --platform=amd64 --progress=plain --no-cache -t $(TEST_DEB_IMAGE_NAME) -f Dockerfile.test_deb --build-arg DEB_PACKAGE=$(ARTIFACT_DIR)/$(DEB_NAME_DEV) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --platform=amd64 --rm $(INTERACTIVE) -v $(shell pwd):/work -w /work -e DEB_INSTALL=1 -e DEV_INSTALL=1 -e PRT_ROOT=$(PRT_ROOT) -e RUNTIME_VER=$(PACKAGE_VERSION) $(TEST_DEB_IMAGE_NAME) ./test-runtime
test-deb-arm-dev: deb-dev-arm
	docker image build --platform=arm64 --progress=plain --no-cache -t $(TEST_DEB_IMAGE_NAME_ARM) -f Dockerfile.test_deb --build-arg DEB_PACKAGE=$(ARTIFACT_DIR)/$(DEB_NAME_DEV_ARM) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --platform=arm64 --rm $(INTERACTIVE) -v $(shell pwd):/work -w /work -e DEB_INSTALL=1 -e DEV_INSTALL=1 -e PRT_ROOT=$(PRT_ROOT) -e RUNTIME_VER=$(PACKAGE_VERSION) $(TEST_DEB_IMAGE_NAME_ARM) ./test-runtime

test-all: test test-dev test-arm test-arm-dev test-deb test-deb-arm test-deb-dev test-deb-arm-dev;

# Get an interactive prompt to a fresh container with the runtime installed
run: $(FULL_PACKAGE_NAME)
	docker image build --platform=amd64 -t $(TEST_IMAGE_NAME) -f Dockerfile.test --build-arg PRT_PACKAGE=$(ARTIFACT_DIR)/$(PACKAGE_NAME) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --platform=amd64 --rm -it -v $(shell pwd):/work -w /work -e PRT_ROOT=$(PRT_ROOT) $(TEST_IMAGE_NAME) /bin/bash
run-arm: $(FULL_PACKAGE_NAME_ARM)
	docker image build --platform=arm64 -t $(TEST_IMAGE_NAME_ARM) -f Dockerfile.test --build-arg PRT_PACKAGE=$(ARTIFACT_DIR)/$(PACKAGE_NAME_ARM) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --platform=arm64 --rm -it -v $(shell pwd):/work -w /work -e PRT_ROOT=$(PRT_ROOT) $(TEST_IMAGE_NAME_ARM) /bin/bash
run-dev: $(FULL_PACKAGE_NAME_DEV)
	docker image build --platform=amd64 -t $(TEST_IMAGE_NAME) -f Dockerfile.test --build-arg PRT_PACKAGE=$(ARTIFACT_DIR)/$(PACKAGE_NAME_DEV) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --platform=amd64 --rm -it -v $(shell pwd):/work -w /work -e PRT_ROOT=$(PRT_ROOT) $(TEST_IMAGE_NAME) /bin/bash
run-dev-arm: $(FULL_PACKAGE_NAME_DEV_ARM)
	docker image build --platform=arm64 -t $(TEST_IMAGE_NAME_ARM) -f Dockerfile.test --build-arg PRT_PACKAGE=$(ARTIFACT_DIR)/$(PACKAGE_NAME_DEV_ARM) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --platform=arm64 --rm -it -v $(shell pwd):/work -w /work -e PRT_ROOT=$(PRT_ROOT) $(TEST_IMAGE_NAME_ARM) /bin/bash

# Build the debian package
deb: $(FULL_DEB_NAME)
deb-dev: $(FULL_DEB_NAME_DEV)
$(FULL_DEB_NAME) $(FULL_DEB_NAME_DEV): $(FULL_PACKAGE_NAME) .builder-image $(DEB_DEPS) | $(OUTPUT_DIR)
	docker container run --platform=amd64 $(INTERACTIVE) --rm $(VERBOSE) $(CACHE_ARG) \
		-v $(OUTPUT_DIR):/output -e OUTPUT_DIR=/output \
		-v $(shell pwd):/work -w /work \
		-e PACKAGE="$(PACKAGE_PREFIX)" \
		-e PACKAGE_ARCH=amd64 \
		-e PACKAGE_VERSION=$(PACKAGE_VERSION) \
		-e PACKAGE_DESC="$(PACKAGE_DESC)" \
		-e PACKAGE_MAINTAINER="$(PACKAGE_MAINTAINER)" \
		-e PACKAGE_NAME=$(PACKAGE_NAME) \
		-e PACKAGE_NAME_DEV=$(PACKAGE_NAME_DEV) \
		-e PRT_ROOT=$(PRT_ROOT) \
		$(BUILDER_IMAGE_NAME) \
		./build-deb
deb-arm: $(FULL_DEB_NAME_ARM)
deb-dev-arm: $(FULL_DEB_NAME_DEV_ARM)
$(FULL_DEB_NAME_ARM) $(FULL_DEB_NAME_DEV_ARM): $(FULL_PACKAGE_NAME_ARM) .builder-image $(DEB_DEPS) | $(OUTPUT_DIR)
	docker container run --platform=arm64 $(INTERACTIVE) --rm $(VERBOSE) $(CACHE_ARG) \
		-v $(OUTPUT_DIR):/output -e OUTPUT_DIR=/output \
		-v $(shell pwd):/work -w /work \
		-e PACKAGE="$(PACKAGE_PREFIX)" \
		-e PACKAGE_ARCH=arm64 \
		-e PACKAGE_VERSION=$(PACKAGE_VERSION) \
		-e PACKAGE_DESC="$(PACKAGE_DESC)" \
		-e PACKAGE_MAINTAINER="$(PACKAGE_MAINTAINER)" \
		-e PACKAGE_NAME=$(PACKAGE_NAME_ARM) \
		-e PACKAGE_NAME_DEV=$(PACKAGE_NAME_DEV_ARM) \
		-e PRT_ROOT=$(PRT_ROOT) \
		$(BUILDER_IMAGE_NAME_ARM) \
		./build-deb

# Clean: remove output files
clean:
	$(RM) $(PACKAGE_PREFIX)_*.tgz  $(PACKAGE_PREFIX)_*.json

# Clobber: clean output files and delete build containers
clobber: clean
	$(RM) -r $(OUTPUT_DIR)
	$(RM) .builder-image*
	docker image rm $(BUILDER_IMAGE_NAME) $(BUILDER_IMAGE_NAME_ARM) $(TEST_IMAGE_NAME) $(TEST_IMAGE_NAME_ARM) || true

# Upload the cache files
upload-cache:
	for ff in $$(ls $(OUTPUT_DIR)/cache_*); do curl --upload-file $${ff} $(CACHE_URL)/$$(basename $${ff}); done


# Print the value of a variable
print-%  : ; @echo $*=$($*)

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
	echo "Each target has an AMD64 and ARM64 variant"; \
	echo ""; \
	echo -e "$(GREEN_BOLD)Build the runtime:$(COLOR_RESET)"; \
	echo -e "  make runtime                          Build the runtime and package it as a tarball in the output directory"; \
	echo -e "  make runtime-arm"; \
	echo -e "  make deb                              Build the runtime and package it as a deb in the output directory"; \
	echo -e "  make deb-arm"; \
	echo -e "  make builder-image                    Build the docker image used to build the runtime"; \
	echo -e "  make builder-image-arm"; \
	echo ""; \
	echo -e "$(MAGENTA)NO_PACKAGE_CACHE=1$(COLOR_RESET) can be used to build without using cached pip packages"; \
	echo -e "$(MAGENTA)NO_CACHE=1$(COLOR_RESET) can be used to build without using any cached python/pip packages"; \
	echo ""; \
	echo -e "$(GREEN_BOLD)Testing:$(COLOR_RESET)"; \
	echo -e "  make test                             Install the tar package in a fresh container and test it"; \
	echo -e "  make test-arm"; \
	echo -e "  make test-dev                         Install the dev tar package in a fresh container and test it"; \
	echo -e "  make test-dev-arm"; \
	echo -e "  make test-deb                         Install the debian package in a fresh container and test it"; \
	echo -e "  make test-deb-arm"; \
	echo -e "  make test-deb-dev                     Install the dev debian package in a fresh container and test it"; \
	echo -e "  make test-deb-dev-arm"; \
	echo ""; \
	echo -e "  make test-all                         Run the tests for all the variations"; \
	echo ""; \
	echo -e "  make run                              Install the package in a fresh container and get an interactive prompt"; \
	echo -e "  make run-arm"; \
	echo -e "  make run-dev                          Install the dev package in a fresh container and get an interactive prompt"; \
	echo -e "  make run-dev-arm"; \
	echo ""; \
	echo -e "$(GREEN_BOLD)Cleanup:$(COLOR_RESET)"; \
	echo -e "  make clean                            Delete the runtime package"; \
	echo -e "  make clobber                          Delete the runtime package, cache files, and docker images"; \
	echo ""; \
	echo -e "$(GREEN_BOLD)Misc:$(COLOR_RESET)"; \
	echo -e "  make upload-cache                     Upload the cache files to the cache server, replacing what is there."; \
	echo ""; \
	} | less -FKqrX
