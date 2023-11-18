SHELL := /usr/bin/env bash -o pipefail

# Include optional vars file. Use this file to override any of the variables below
-include Makefile.vars

# Default values for variables that were not in Makefile.vars
PRT_PACKAGE_PREFIX ?= prt
PRT_PACKAGE_DESC ?= Custom python runtime
PRT_PACKAGE_MAINTAINER ?= John Doe
PRT_PACKAGE_VERSION ?= $(shell git tag --list 'v*' | sort -V | tail -n1 || echo v0)
ifeq ($(PRT_PACKAGE_VERSION),)
PRT_PACKAGE_VERSION := v0
endif
PRT_PYTHON_VERSION ?= 3.11.5
PRT_ROOT ?= /prt
PRT_ARTIFACT_DIR ?= out
PRT_CACHE_URL ?= http://172.17.0.1:9000/prt/cache

PRT_TEST_IMAGE_BASENAME ?= prt-tester
PRT_BUILDER_IMAGE_BASENAME ?= prt-builder

PRT_BUILDER_IMAGE_NAME_X86 := $(PRT_BUILDER_IMAGE_BASENAME)
PRT_BUILDER_IMAGE_NAME_ARM := $(PRT_BUILDER_IMAGE_BASENAME)-arm
PRT_TEST_IMAGE_NAME_X86 := $(PRT_TEST_IMAGE_BASENAME)
PRT_TEST_IMAGE_NAME_ARM := $(PRT_TEST_IMAGE_BASENAME)-arm
PRT_TEST_DEB_IMAGE_NAME_X86 := $(PRT_TEST_IMAGE_BASENAME)-deb
PRT_TEST_DEB_IMAGE_NAME_ARM := $(PRT_TEST_IMAGE_BASENAME)-deb-arm

PRT_PACKAGE_NAME_TEMPLATE ?= '$${PRT_PACKAGE_PREFIX}$${DEV_BUILD}_$${PRT_PACKAGE_VERSION}_$${ARCH}'
PRT_DEB_NAME_TEMPLATE ?= $${PRT_PACKAGE_PREFIX}$${DEV_BUILD}_$${PRT_PACKAGE_VERSION}_$${ARCH}.deb
PRT_PACKAGE_EXT ?= .tgz
PRT_MANIFEST_EXT ?= .manifest.json

PRT_PACKAGE_NAME_X86 := $(shell export PRT_PACKAGE_PREFIX=$(PRT_PACKAGE_PREFIX); export PRT_PACKAGE_VERSION=$(PRT_PACKAGE_VERSION); export DEV_BUILD=; export ARCH="amd64"; echo '$(PRT_PACKAGE_NAME_TEMPLATE)' | envsubst )$(PRT_PACKAGE_EXT)
PRT_PACKAGE_NAME_DEV_X86 := $(shell export PRT_PACKAGE_PREFIX=$(PRT_PACKAGE_PREFIX); export PRT_PACKAGE_VERSION=$(PRT_PACKAGE_VERSION); export DEV_BUILD=-dev; export ARCH="amd64"; echo '$(PRT_PACKAGE_NAME_TEMPLATE)' | envsubst )$(PRT_PACKAGE_EXT)
PRT_PACKAGE_NAME_ARM := $(shell export PRT_PACKAGE_PREFIX=$(PRT_PACKAGE_PREFIX); export PRT_PACKAGE_VERSION=$(PRT_PACKAGE_VERSION); export DEV_BUILD=; export ARCH="arm64"; echo '$(PRT_PACKAGE_NAME_TEMPLATE)' | envsubst )$(PRT_PACKAGE_EXT)
PRT_PACKAGE_NAME_DEV_ARM := $(shell export PRT_PACKAGE_PREFIX=$(PRT_PACKAGE_PREFIX); export PRT_PACKAGE_VERSION=$(PRT_PACKAGE_VERSION); export DEV_BUILD=-dev; export ARCH="arm64"; echo '$(PRT_PACKAGE_NAME_TEMPLATE)' | envsubst )$(PRT_PACKAGE_EXT)
PRT_DEB_NAME_X86 := $(shell export PRT_PACKAGE_PREFIX=$(PRT_PACKAGE_PREFIX); export PRT_PACKAGE_VERSION=$$(echo $(PRT_PACKAGE_VERSION) | sed 's/^v//'); export DEV_BUILD=; export ARCH=amd64; echo '$(PRT_DEB_NAME_TEMPLATE)' | envsubst)
PRT_DEB_NAME_DEV_X86 := $(shell export PRT_PACKAGE_PREFIX=$(PRT_PACKAGE_PREFIX); export PRT_PACKAGE_VERSION=$$(echo $(PRT_PACKAGE_VERSION) | sed 's/^v//'); export DEV_BUILD=-dev; export ARCH=amd64; echo '$(PRT_DEB_NAME_TEMPLATE)' | envsubst)
PRT_DEB_NAME_ARM := $(shell export PRT_PACKAGE_PREFIX=$(PRT_PACKAGE_PREFIX); export PRT_PACKAGE_VERSION=$$(echo $(PRT_PACKAGE_VERSION) | sed 's/^v//'); export DEV_BUILD=; export ARCH=arm64; echo '$(PRT_DEB_NAME_TEMPLATE)' | envsubst)
PRT_DEB_NAME_DEV_ARM := $(shell export PRT_PACKAGE_PREFIX=$(PRT_PACKAGE_PREFIX); export PRT_PACKAGE_VERSION=$$(echo $(PRT_PACKAGE_VERSION) | sed 's/^v//'); export DEV_BUILD=-dev; export ARCH=arm64; echo '$(PRT_DEB_NAME_TEMPLATE)' | envsubst)

# Print the values of the variables in a format that can be written to an env file - make env-file > .env
.PHONY: env-file
env-file:
	@echo "PRT_PACKAGE_NAME_X86=$(PRT_PACKAGE_NAME_X86)"
	@echo "PRT_PACKAGE_NAME_DEV_X86=$(PRT_PACKAGE_NAME_DEV_X86)"
	@echo "PRT_PACKAGE_NAME_ARM=$(PRT_PACKAGE_NAME_ARM)"
	@echo "PRT_PACKAGE_NAME_DEV_ARM=$(PRT_PACKAGE_NAME_DEV_ARM)"
	@echo "PRT_DEB_NAME_X86=$(PRT_DEB_NAME_X86)"
	@echo "PRT_DEB_NAME_DEV_X86=$(PRT_DEB_NAME_DEV_X86)"
	@echo "PRT_DEB_NAME_ARM=$(PRT_DEB_NAME_ARM)"
	@echo "PRT_DEB_NAME_DEV_ARM=$(PRT_DEB_NAME_DEV_ARM)"
	@echo "PRT_PYTHON_VERSION=$(PRT_PYTHON_VERSION)"
	@echo "PRT_PACKAGE_PREFIX=$(PRT_PACKAGE_PREFIX)"
	@echo "PRT_PACKAGE_EXT=$(PRT_PACKAGE_EXT)"
	@echo "PRT_MANIFEST_EXT=$(PRT_MANIFEST_EXT)"
	@echo "PRT_CACHE_URL=$(PRT_CACHE_URL)"
	@echo "PRT_BUILDER_IMAGE_NAME_X86=$(PRT_BUILDER_IMAGE_NAME_X86)"
	@echo "PRT_TEST_IMAGE_NAME_X86=$(PRT_TEST_IMAGE_NAME_X86)"
	@echo "PRT_TEST_DEB_IMAGE_NAME_X86=$(PRT_TEST_DEB_IMAGE_NAME_X86)"
	@echo "PRT_BUILDER_IMAGE_NAME_ARM=$(PRT_BUILDER_IMAGE_NAME_ARM)"
	@echo "PRT_TEST_IMAGE_NAME_ARM=$(PRT_TEST_IMAGE_NAME_ARM)"
	@echo "PRT_TEST_DEB_IMAGE_NAME_ARM=$(PRT_TEST_DEB_IMAGE_NAME_ARM)"
	@echo "PRT_PACKAGE_DESC='$(PRT_PACKAGE_DESC)'"
	@echo "PRT_PACKAGE_MAINTAINER='$(PRT_PACKAGE_MAINTAINER)'"

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

# Make OUTPUT_DIR an absolute path from PRT_ARTIFACT_DIR
OUTPUT_DIR := $(shell realpath $(PRT_ARTIFACT_DIR))
FULL_PACKAGE_NAME_X86 := $(OUTPUT_DIR)/$(PRT_PACKAGE_NAME_X86)
FULL_PACKAGE_NAME_ARM := $(OUTPUT_DIR)/$(PRT_PACKAGE_NAME_ARM)
FULL_PACKAGE_NAME_DEV_X86 := $(OUTPUT_DIR)/$(PRT_PACKAGE_NAME_DEV_X86)
FULL_PACKAGE_NAME_DEV_ARM := $(OUTPUT_DIR)/$(PRT_PACKAGE_NAME_DEV_ARM)
FULL_DEB_NAME_X86 := $(OUTPUT_DIR)/$(PRT_DEB_NAME_X86)
FULL_DEB_NAME_ARM := $(OUTPUT_DIR)/$(PRT_DEB_NAME_ARM)
FULL_DEB_NAME_DEV_X86 := $(OUTPUT_DIR)/$(PRT_DEB_NAME_DEV_X86)
FULL_DEB_NAME_DEV_ARM := $(OUTPUT_DIR)/$(PRT_DEB_NAME_DEV_ARM)

# Determine if make is runing interactively or in a script
INTERACTIVE := $(shell if tty -s; then echo "-it"; else echo ""; fi)

# Determine the local CPU architecture
ifeq ($(shell uname -m),x86_64)
  LOCAL_ARCH = x86
else ifeq ($(shell uname -m),aarch64)
  LOCAL_ARCH = arm
endif

# Dependecies that should cause rebuild of the builder container image
BUILDER_DEPS = Dockerfile

# Dependecies that should cause rebuild of the tar package
RUNTIME_DEPS = build-runtime $(shell find ./config -type f -print 2>/dev/null || true)

# Dependecies that should cause rebuild of the dev tar package
RUNTIME_DEPS_DEV = build-runtime $(shell find ./dev-config -type f -print 2>/dev/null || true)

# Dependecies that should cause rebuild of the debian package
DEB_DEPS = build-deb $(shell find ./deb-config -type f -print 2>/dev/null || true)


# Build the builder container image
builder-image-x86: .builder-image-x86
.builder-image-x86: $(BUILDER_DEPS)
	docker image build --platform=amd64 --no-cache --progress=plain -t $(PRT_BUILDER_IMAGE_NAME_X86) . && \
	id=$$(docker image inspect -f '{{.Id}}' $(PRT_BUILDER_IMAGE_NAME_X86)) && echo "$${id}" > .builder-image-x86

builder-image-arm: .builder-image-arm
.builder-image-arm: $(BUILDER_DEPS)
	docker image build --platform=arm64 --progress=plain -t $(PRT_BUILDER_IMAGE_NAME_ARM) . && \
	id=$$(docker image inspect -f '{{.Id}}' $(PRT_BUILDER_IMAGE_NAME_ARM)) && echo "$${id}" > .builder-image-arm

$(OUTPUT_DIR):
	mkdir -p $(OUTPUT_DIR)


# Build the runtime package
runtime: runtime-$(LOCAL_ARCH)
runtime-dev: runtime-dev-$(LOCAL_ARCH)

runtime-x86: $(FULL_PACKAGE_NAME_X86)
runtime-dev-x86: $(FULL_PACKAGE_NAME_DEV_X86)
$(FULL_PACKAGE_NAME_X86) $(FULL_PACKAGE_NAME_DEV_X86): .builder-image-x86 $(RUNTIME_DEPS) $(RUNTIME_DEPS_DEV) | $(OUTPUT_DIR)
	docker container run --platform=amd64 $(INTERACTIVE) --rm $(VERBOSE) $(CACHE_ARG) \
		-v $(OUTPUT_DIR):/output -e OUTPUT_DIR=/output \
		-v $(shell pwd):/work -w /work \
		-e PRT_CACHE_URL="${PRT_CACHE_URL}" \
		-e PRT_PACKAGE_VERSION=$(PRT_PACKAGE_VERSION) \
		-e PRT_PACKAGE_NAME=$(PRT_PACKAGE_NAME_X86) \
		-e PRT_PACKAGE_NAME_DEV=$(PRT_PACKAGE_NAME_DEV_X86) \
		-e PRT_PYTHON_VERSION=$(PRT_PYTHON_VERSION) \
		$(PRT_BUILDER_IMAGE_NAME_X86) \
		./build-runtime
runtime-arm: $(FULL_PACKAGE_NAME_ARM)
runtime-dev-arm: $(FULL_PACKAGE_NAME_DEV_ARM)
$(FULL_PACKAGE_NAME_ARM) $(FULL_PACKAGE_NAME_DEV_ARM): .builder-image-arm $(RUNTIME_DEPS) $(RUNTIME_DEPS_DEV) | $(OUTPUT_DIR)
	docker container run --platform=arm64 $(INTERACTIVE) --rm $(VERBOSE) $(CACHE_ARG) \
		-v $(OUTPUT_DIR):/output -e OUTPUT_DIR=/output \
		-v $(shell pwd):/work -w /work \
		-e PRT_CACHE_URL="${PRT_CACHE_URL}" \
		-e PRT_PACKAGE_VERSION=$(PRT_PACKAGE_VERSION) \
		-e PRT_PACKAGE_NAME=$(PRT_PACKAGE_NAME_ARM) \
		-e PRT_PACKAGE_NAME_DEV=$(PRT_PACKAGE_NAME_DEV_ARM) \
		-e PRT_PYTHON_VERSION=$(PRT_PYTHON_VERSION) \
		-e MTUNE= \
		$(PRT_BUILDER_IMAGE_NAME_ARM) \
		./build-runtime


# Test the runtime in a fresh container image
test: test-$(LOCAL_ARCH)
test-dev: test-dev-$(LOCAL_ARCH)
test-deb: test-deb-$(LOCAL_ARCH)
test-deb-dev: test-deb-dev-$(LOCAL_ARCH)

test-x86: $(FULL_PACKAGE_NAME_X86)
	docker image build --platform=amd64 --progress=plain --no-cache -t $(PRT_TEST_IMAGE_NAME_X86) -f Dockerfile.test --build-arg PRT_PACKAGE=$(PRT_ARTIFACT_DIR)/$(PRT_PACKAGE_NAME_X86) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --platform=amd64 --rm $(INTERACTIVE) -v $(shell pwd):/work -w /work -e PRT_ROOT=$(PRT_ROOT) -e PRT_PACKAGE_VERSION=$(PRT_PACKAGE_VERSION) $(PRT_TEST_IMAGE_NAME_X86) ./test-runtime
test-arm: $(FULL_PACKAGE_NAME_ARM)
	docker image build --platform=arm64 --progress=plain --no-cache -t $(PRT_TEST_IMAGE_NAME_ARM) -f Dockerfile.test --build-arg PRT_PACKAGE=$(PRT_ARTIFACT_DIR)/$(PRT_PACKAGE_NAME_ARM) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --platform=arm64 --rm $(INTERACTIVE) -v $(shell pwd):/work -w /work -e PRT_ROOT=$(PRT_ROOT) -e PRT_PACKAGE_VERSION=$(PRT_PACKAGE_VERSION) $(PRT_TEST_IMAGE_NAME_ARM) ./test-runtime
test-dev-x86: $(FULL_PACKAGE_NAME_DEV_X86)
	docker image build --platform=amd64 --progress=plain --no-cache -t $(PRT_TEST_IMAGE_NAME_X86) -f Dockerfile.test --build-arg PRT_PACKAGE=$(PRT_ARTIFACT_DIR)/$(PRT_PACKAGE_NAME_DEV_X86) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --platform=amd64 --rm $(INTERACTIVE) -v $(shell pwd):/work -w /work -e DEV_INSTALL=1 -e PRT_ROOT=$(PRT_ROOT) -e PRT_PACKAGE_VERSION=$(PRT_PACKAGE_VERSION) $(PRT_TEST_IMAGE_NAME_X86) ./test-runtime
test-dev-arm: $(FULL_PACKAGE_NAME_DEV_ARM)
	docker image build --platform=arm64 --progress=plain --no-cache -t $(PRT_TEST_IMAGE_NAME_X86) -f Dockerfile.test --build-arg PRT_PACKAGE=$(PRT_ARTIFACT_DIR)/$(PRT_PACKAGE_NAME_DEV_ARM) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --platform=arm64 --rm $(INTERACTIVE) -v $(shell pwd):/work -w /work -e DEV_INSTALL=1 -e PRT_ROOT=$(PRT_ROOT) -e PRT_PACKAGE_VERSION=$(PRT_PACKAGE_VERSION) $(PRT_TEST_IMAGE_NAME_X86) ./test-runtime
test-deb-x86: deb-x86
	docker image build --platform=amd64 --progress=plain --no-cache -t $(PRT_TEST_DEB_IMAGE_NAME_X86) -f Dockerfile.test_deb --build-arg DEB_PACKAGE=$(PRT_ARTIFACT_DIR)/$(PRT_DEB_NAME_X86) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --platform=amd64 --rm $(INTERACTIVE) -v $(shell pwd):/work -w /work -e DEB_INSTALL=1 -e PRT_ROOT=$(PRT_ROOT) -e PRT_PACKAGE_VERSION=$(PRT_PACKAGE_VERSION) $(PRT_TEST_DEB_IMAGE_NAME_X86) ./test-runtime
test-deb-arm: deb-arm
	docker image build --platform=arm64 --progress=plain --no-cache -t $(PRT_TEST_DEB_IMAGE_NAME_ARM) -f Dockerfile.test_deb --build-arg DEB_PACKAGE=$(PRT_ARTIFACT_DIR)/$(PRT_DEB_NAME_ARM) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --platform=arm64 --rm $(INTERACTIVE) -v $(shell pwd):/work -w /work -e DEB_INSTALL=1 -e PRT_ROOT=$(PRT_ROOT) -e PRT_PACKAGE_VERSION=$(PRT_PACKAGE_VERSION) $(PRT_TEST_DEB_IMAGE_NAME_ARM) ./test-runtime
test-deb-dev-x86: deb-dev-x86
	docker image build --platform=amd64 --progress=plain --no-cache -t $(PRT_TEST_DEB_IMAGE_NAME_X86) -f Dockerfile.test_deb --build-arg DEB_PACKAGE=$(PRT_ARTIFACT_DIR)/$(PRT_DEB_NAME_DEV_X86) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --platform=amd64 --rm $(INTERACTIVE) -v $(shell pwd):/work -w /work -e DEB_INSTALL=1 -e DEV_INSTALL=1 -e PRT_ROOT=$(PRT_ROOT) -e PRT_PACKAGE_VERSION=$(PRT_PACKAGE_VERSION) $(PRT_TEST_DEB_IMAGE_NAME_X86) ./test-runtime
test-deb-dev-arm: deb-dev-arm
	docker image build --platform=arm64 --progress=plain --no-cache -t $(PRT_TEST_DEB_IMAGE_NAME_ARM) -f Dockerfile.test_deb --build-arg DEB_PACKAGE=$(PRT_ARTIFACT_DIR)/$(PRT_DEB_NAME_DEV_ARM) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --platform=arm64 --rm $(INTERACTIVE) -v $(shell pwd):/work -w /work -e DEB_INSTALL=1 -e DEV_INSTALL=1 -e PRT_ROOT=$(PRT_ROOT) -e PRT_PACKAGE_VERSION=$(PRT_PACKAGE_VERSION) $(PRT_TEST_DEB_IMAGE_NAME_ARM) ./test-runtime

test-all: test-x86 test-dev-x86 test-arm test-dev-arm test-deb-x86 test-deb-arm test-deb-dev-x86 test-deb-dev-arm;


# Get an interactive prompt to a fresh container with the runtime installed
run: run-$(LOCAL_ARCH)
run-dev: run-dev-$(LOCAL_ARCH)

run-x86: $(FULL_PACKAGE_NAME_X86)
	docker image build --platform=amd64 -t $(PRT_TEST_IMAGE_NAME_X86) -f Dockerfile.test --build-arg PRT_PACKAGE=$(PRT_ARTIFACT_DIR)/$(PRT_PACKAGE_NAME_X86) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --platform=amd64 --rm -it -v $(shell pwd):/work -w /work -e PRT_ROOT=$(PRT_ROOT) $(PRT_TEST_IMAGE_NAME_X86) /bin/bash
run-arm: $(FULL_PACKAGE_NAME_ARM)
	docker image build --platform=arm64 -t $(PRT_TEST_IMAGE_NAME_ARM) -f Dockerfile.test --build-arg PRT_PACKAGE=$(PRT_ARTIFACT_DIR)/$(PRT_PACKAGE_NAME_ARM) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --platform=arm64 --rm -it -v $(shell pwd):/work -w /work -e PRT_ROOT=$(PRT_ROOT) $(PRT_TEST_IMAGE_NAME_ARM) /bin/bash
run-dev-x86: $(FULL_PACKAGE_NAME_DEV_X86)
	docker image build --platform=amd64 -t $(PRT_TEST_IMAGE_NAME_X86) -f Dockerfile.test --build-arg PRT_PACKAGE=$(PRT_ARTIFACT_DIR)/$(PRT_PACKAGE_NAME_DEV_X86) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --platform=amd64 --rm -it -v $(shell pwd):/work -w /work -e PRT_ROOT=$(PRT_ROOT) $(PRT_TEST_IMAGE_NAME_X86) /bin/bash
run-dev-arm: $(FULL_PACKAGE_NAME_DEV_ARM)
	docker image build --platform=arm64 -t $(PRT_TEST_IMAGE_NAME_ARM) -f Dockerfile.test --build-arg PRT_PACKAGE=$(PRT_ARTIFACT_DIR)/$(PRT_PACKAGE_NAME_DEV_ARM) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --platform=arm64 --rm -it -v $(shell pwd):/work -w /work -e PRT_ROOT=$(PRT_ROOT) $(PRT_TEST_IMAGE_NAME_ARM) /bin/bash


# Build the debian package
deb: deb-$(LOCAL_ARCH)
deb-dev: deb-dev-$(LOCAL_ARCH)

deb-x86: $(FULL_DEB_NAME_X86)
deb-dev-x86: $(FULL_DEB_NAME_DEV_X86)
$(FULL_DEB_NAME_X86) $(FULL_DEB_NAME_DEV_X86): $(FULL_PACKAGE_NAME_X86) .builder-image-x86 $(DEB_DEPS) | $(OUTPUT_DIR)
	docker container run --platform=amd64 $(INTERACTIVE) --rm $(VERBOSE) $(CACHE_ARG) \
		-v $(OUTPUT_DIR):/output -e OUTPUT_DIR=/output \
		-v $(shell pwd):/work -w /work \
		-e PRT_PACKAGE="$(PRT_PACKAGE_PREFIX)" \
		-e PRT_PACKAGE_VERSION=$(PRT_PACKAGE_VERSION) \
		-e PRT_PACKAGE_DESC="$(PRT_PACKAGE_DESC)" \
		-e PRT_PACKAGE_MAINTAINER="$(PRT_PACKAGE_MAINTAINER)" \
		-e PRT_PACKAGE_NAME=$(PRT_PACKAGE_NAME_X86) \
		-e PRT_PACKAGE_NAME_DEV=$(PRT_PACKAGE_NAME_DEV_X86) \
		-e PRT_ROOT=$(PRT_ROOT) \
		$(PRT_BUILDER_IMAGE_NAME_X86) \
		./build-deb
deb-arm: $(FULL_DEB_NAME_ARM)
deb-dev-arm: $(FULL_DEB_NAME_DEV_ARM)
$(FULL_DEB_NAME_ARM) $(FULL_DEB_NAME_DEV_ARM): $(FULL_PACKAGE_NAME_ARM) .builder-image-arm $(DEB_DEPS) | $(OUTPUT_DIR)
	docker container run --platform=arm64 $(INTERACTIVE) --rm $(VERBOSE) $(CACHE_ARG) \
		-v $(OUTPUT_DIR):/output -e OUTPUT_DIR=/output \
		-v $(shell pwd):/work -w /work \
		-e PRT_PACKAGE="$(PRT_PACKAGE_PREFIX)" \
		-e PRT_PACKAGE_VERSION=$(PRT_PACKAGE_VERSION) \
		-e PRT_PACKAGE_DESC="$(PRT_PACKAGE_DESC)" \
		-e PRT_PACKAGE_MAINTAINER="$(PRT_PACKAGE_MAINTAINER)" \
		-e PRT_PACKAGE_NAME=$(PRT_PACKAGE_NAME_ARM) \
		-e PRT_PACKAGE_NAME_DEV=$(PRT_PACKAGE_NAME_DEV_ARM) \
		-e PRT_ROOT=$(PRT_ROOT) \
		$(PRT_BUILDER_IMAGE_NAME_ARM) \
		./build-deb

# Clean: remove output files
clean:
	$(RM) $(PRT_ARTIFACT_DIR)/$(PRT_PACKAGE_PREFIX)*

# Clobber: clean output files and delete build containers
clobber: clean
	$(RM) -r $(OUTPUT_DIR)
	$(RM) .builder-image*
	docker image rm $(PRT_BUILDER_IMAGE_NAME_X86) $(PRT_BUILDER_IMAGE_NAME_ARM) $(PRT_TEST_IMAGE_NAME_X86) $(PRT_TEST_IMAGE_NAME_ARM) $(PRT_TEST_DEB_IMAGE_NAME_X86) $(PRT_TEST_DEB_IMAGE_NAME_ARM) || true

# Upload the cache files
upload-cache:
	for ff in $$(ls $(OUTPUT_DIR)/cache_*); do curl --upload-file $${ff} $(PRT_CACHE_URL)/$$(basename $${ff}); done


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
	echo "Each target will run the local/native version automatically, or you can run the explicit AMD64 or ARM64 variant"; \
	echo ""; \
	echo -e "$(GREEN_BOLD)Build the runtime:$(COLOR_RESET)"; \
	echo -e "  make runtime                      Build the runtime and package it as a tarball in the output directory"; \
	echo -e "  make runtime-x86"; \
	echo -e "  make runtime-arm"; \
	echo -e "  make deb                          Build the runtime and package it as a deb in the output directory"; \
	echo -e "  make deb-x86"; \
	echo -e "  make deb-arm"; \
	echo -e "  make builder-image-x86            Build the docker image used to build the runtime"; \
	echo -e "  make builder-image-arm"; \
	echo ""; \
	echo -e "$(MAGENTA)NO_PACKAGE_CACHE=1$(COLOR_RESET) can be used to build without using cached pip packages"; \
	echo -e "$(MAGENTA)NO_CACHE=1$(COLOR_RESET) can be used to build without using any cached python/pip packages"; \
	echo ""; \
	echo -e "$(GREEN_BOLD)Testing:$(COLOR_RESET)"; \
	echo -e "  make test                         Install the tar package in a fresh container and test it"; \
	echo -e "  make test-x86"; \
	echo -e "  make test-arm"; \
	echo -e "  make test-dev                     Install the dev tar package in a fresh container and test it"; \
	echo -e "  make test-dev-x86"; \
	echo -e "  make test-dev-arm"; \
	echo -e "  make test-deb                     Install the debian package in a fresh container and test it"; \
	echo -e "  make test-deb-x86"; \
	echo -e "  make test-deb-arm"; \
	echo -e "  make test-deb-dev                 Install the dev debian package in a fresh container and test it"; \
	echo -e "  make test-deb-dev-x86"; \
	echo -e "  make test-deb-dev-arm"; \
	echo ""; \
	echo -e "  make test-all                     Run the tests for all the variations"; \
	echo ""; \
	echo -e "  make run                          Install the package in a fresh container and get an interactive prompt"; \
	echo -e "  make run-x86"; \
	echo -e "  make run-arm"; \
	echo -e "  make run-dev                      Install the dev package in a fresh container and get an interactive prompt"; \
	echo -e "  make run-dev-x86"; \
	echo -e "  make run-dev-arm"; \
	echo ""; \
	echo -e "$(GREEN_BOLD)Cleanup:$(COLOR_RESET)"; \
	echo -e "  make clean                        Delete the runtime packages"; \
	echo -e "  make clobber                      Delete the runtime packages, cache files, and docker images"; \
	echo ""; \
	echo -e "$(GREEN_BOLD)Misc:$(COLOR_RESET)"; \
	echo -e "  make upload-cache                 Upload the cache files to the cache server, replacing what is there."; \
	echo ""; \
	} | less -FKqrX
