SHELL := /usr/bin/env bash -o pipefail
PACKAGE_PREFIX ?= prt
PACKAGE_VERSION ?= $(shell git tag --list 'v*' | sort -V | tail -n1 || echo v0)
PYTHON_VERSION ?= 3.11.5
PRT_ROOT ?= /prt
BUILDER_IMAGE_NAME ?= prt-builder
TEST_IMAGE_NAME ?= prt-tester
ARTIFACT_DIR ?= out
PACKAGE_NAME ?= $(PACKAGE_PREFIX)_$(PACKAGE_VERSION).tgz
PACKAGE_NAME_DEV ?= $(PACKAGE_PREFIX)-dev_$(PACKAGE_VERSION).tgz
FILESERVER ?= localhost:/http/prt/cache
BUILDER_IMAGE_NAME_ARM ?= prt-builder-arm
PACKAGE_NAME_ARM ?= $(PACKAGE_PREFIX)_$(PACKAGE_VERSION)_aarch64.tgz
PACKAGE_NAME_DEV_ARM ?= $(PACKAGE_PREFIX)-dev_$(PACKAGE_VERSION)_aarch64.tgz
TEST_IMAGE_NAME_ARM ?= prt-tester-arm

PACKAGE_NAME_TEMPLATE ?= '$${PACKAGE_PREFIX}$${DEV_BUILD}_$${PACKAGE_VERSION}$${ARCH}'
PACKAGE_EXT ?= .tgz
MANIFEST_EXT ?= .manifest.json

PACKAGE_NAME := $(shell export PACKAGE_PREFIX=$(PACKAGE_PREFIX); export PACKAGE_VERSION=$(PACKAGE_VERSION); export DEV_BUILD=; echo '$(PACKAGE_NAME_TEMPLATE)' | envsubst )$(PACKAGE_EXT)
PACKAGE_NAME_DEV := $(shell export PACKAGE_PREFIX=$(PACKAGE_PREFIX); export PACKAGE_VERSION=$(PACKAGE_VERSION); export DEV_BUILD=-dev; echo '$(PACKAGE_NAME_TEMPLATE)' | envsubst )$(PACKAGE_EXT)
PACKAGE_NAME_ARM := $(shell export PACKAGE_PREFIX=$(PACKAGE_PREFIX); export PACKAGE_VERSION=$(PACKAGE_VERSION); export DEV_BUILD=; export ARCH="_aarch64"; echo '$(PACKAGE_NAME_TEMPLATE)' | envsubst )$(PACKAGE_EXT)
PACKAGE_NAME_DEV_ARM := $(shell export PACKAGE_PREFIX=$(PACKAGE_PREFIX); export PACKAGE_VERSION=$(PACKAGE_VERSION); export ARCH="_aarch64"; export DEV_BUILD=-dev; echo '$(PACKAGE_NAME_TEMPLATE)' | envsubst )$(PACKAGE_EXT)

# Print the values of the variables in a format that can be written to an env file - make env-file > .env
.PHONY: env-file
env-file:
	@echo "PACKAGE_NAME=$(PACKAGE_NAME)"
	@echo "PACKAGE_NAME_DEV=$(PACKAGE_NAME_DEV)"
	@echo "PACKAGE_NAME_ARM=$(PACKAGE_NAME_ARM)"
	@echo "PACKAGE_NAME_DEV_ARM=$(PACKAGE_NAME_DEV_ARM)"
	@echo "PYTHON_VERSION=$(PYTHON_VERSION)"
	@echo "PACKAGE_PREFIX=$(PACKAGE_PREFIX)"
	@echo "PACKAGE_EXT=$(PACKAGE_EXT)"
	@echo "MANIFEST_EXT=$(MANIFEST_EXT)"
	@echo "FILESERVER=$(FILESERVER)"
	@echo "BUILDER_IMAGE_NAME=$(BUILDER_IMAGE_NAME)"
	@echo "TEST_IMAGE_NAME=$(TEST_IMAGE_NAME)"
	@echo "BUILDER_IMAGE_NAME_ARM=$(BUILDER_IMAGE_NAME_ARM)"
	@echo "TEST_IMAGE_NAME_ARM=$(TEST_IMAGE_NAME_ARM)"

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
CACHE=
ifeq ($(NO_CACHE),1)
  CACHE=-e USE_CACHE=0
endif

# Make OUTPUT_DIR an absolute path from ARTIFACT_DIR
OUTPUT_DIR := $(shell realpath $(ARTIFACT_DIR))
FULL_PACKAGE_NAME := $(OUTPUT_DIR)/$(PACKAGE_NAME)
FULL_PACKAGE_NAME_ARM := $(OUTPUT_DIR)/$(PACKAGE_NAME_ARM)
FULL_PACKAGE_NAME_DEV := $(OUTPUT_DIR)/$(PACKAGE_NAME_DEV)
FULL_PACKAGE_NAME_DEV_ARM := $(OUTPUT_DIR)/$(PACKAGE_NAME_DEV_ARM)

# Determine if make is runing interactively or in a script
INTERACTIVE := $(shell if tty -s; then echo "-it"; else echo ""; fi)

# Dependecies that should cause rebuild of the builder container image
BUILDER_DEPS = Dockerfile

# Build the builder container image
builder-image: .builder-image
.builder-image: $(BUILDER_DEPS)
	docker image build --no-cache -t $(BUILDER_IMAGE_NAME) . && \
	id=$$(docker image inspect -f '{{.Id}}' $(BUILDER_IMAGE_NAME)) && echo "$${id}" > .builder-image

builder-image-arm: .builder-image-arm
.builder-image-arm: $(BUILDER_DEPS)
	docker image build --platform=arm64 --no-cache -t $(BUILDER_IMAGE_NAME_ARM) . && \
	id=$$(docker image inspect -f '{{.Id}}' $(BUILDER_IMAGE_NAME_ARM)) && echo "$${id}" > .builder-image-arm

$(OUTPUT_DIR):
	mkdir -p $(OUTPUT_DIR)

# Build the runtime package
package: $(FULL_PACKAGE_NAME)
$(FULL_PACKAGE_NAME): .builder-image build-runtime | $(OUTPUT_DIR)
	docker container run $(INTERACTIVE) --rm $(VERBOSE) $(CACHE) \
		-v $(OUTPUT_DIR):/output -e OUTPUT_DIR=/output \
		-v $(shell pwd):/work -w /work \
		-e RUNTIME_VER=$(PACKAGE_VERSION) \
		-e PACKAGE_NAME=$(PACKAGE_NAME) \
		-e PACKAGE_NAME_DEV=$(PACKAGE_NAME_DEV) \
		-e PYTHON_VERSION=$(PYTHON_VERSION) \
		$(BUILDER_IMAGE_NAME) \
		./build-runtime
package-arm: $(FULL_PACKAGE_NAME_ARM)
$(FULL_PACKAGE_NAME_ARM): .builder-image-arm build-runtime | $(OUTPUT_DIR)
	docker container run --platform=arm64 $(INTERACTIVE) --rm $(VERBOSE) $(CACHE) \
	-v $(OUTPUT_DIR):/output -e OUTPUT_DIR=/output \
	-v $(shell pwd):/work -w /work \
	-e RUNTIME_VER=$(PACKAGE_VERSION) \
	-e PACKAGE_NAME=$(PACKAGE_NAME_ARM) \
	-e PACKAGE_NAME_DEV=$(PACKAGE_NAME_DEV_ARM) \
	-e PYTHON_VERSION=$(PYTHON_VERSION) \
	-e MTUNE= \
	$(BUILDER_IMAGE_NAME_ARM) \
	./build-runtime
$(FULL_PACKAGE_NAME_DEV): $(FULL_PACKAGE_NAME) ;
$(FULL_PACKAGE_NAME_DEV_ARM): $(FULL_PACKAGE_NAME_ARM) ;

# Test the runtime in a fresh container image
test: $(FULL_PACKAGE_NAME)
	docker image build -t $(TEST_IMAGE_NAME) -f Dockerfile.test --build-arg PRT_PACKAGE=$(ARTIFACT_DIR)/$(PACKAGE_NAME) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --rm $(INTERACTIVE) -v $(shell pwd):/work -w /work -e PRT_ROOT=$(PRT_ROOT) -e RUNTIME_VER=$(PACKAGE_VERSION) $(TEST_IMAGE_NAME) ./test-runtime
test-arm: $(FULL_PACKAGE_NAME_ARM)
	docker image build --platform=arm64 -t $(TEST_IMAGE_NAME_ARM) -f Dockerfile.test --build-arg PRT_PACKAGE=$(ARTIFACT_DIR)/$(PACKAGE_NAME_ARM) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --platform=arm64 --rm $(INTERACTIVE) -v $(shell pwd):/work -w /work -e PRT_ROOT=$(PRT_ROOT) -e RUNTIME_VER=$(PACKAGE_VERSION) $(TEST_IMAGE_NAME_ARM) ./test-runtime
test-dev: $(FULL_PACKAGE_NAME_DEV)
	docker image build -t $(TEST_IMAGE_NAME) -f Dockerfile.test --build-arg PRT_PACKAGE=$(ARTIFACT_DIR)/$(PACKAGE_NAME_DEV) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --rm $(INTERACTIVE) -v $(shell pwd):/work -w /work -e DEV_INSTALL=1 -e PRT_ROOT=$(PRT_ROOT) -e RUNTIME_VER=$(PACKAGE_VERSION) $(TEST_IMAGE_NAME) ./test-runtime
test-arm-dev: $(FULL_PACKAGE_NAME_DEV_ARM)
	docker image build --platform=arm64 -t $(TEST_IMAGE_NAME) -f Dockerfile.test --build-arg PRT_PACKAGE=$(ARTIFACT_DIR)/$(PACKAGE_NAME_DEV_ARM) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --platform=arm64 --rm $(INTERACTIVE) -v $(shell pwd):/work -w /work -e DEV_INSTALL=1 -e PRT_ROOT=$(PRT_ROOT) -e RUNTIME_VER=$(PACKAGE_VERSION) $(TEST_IMAGE_NAME) ./test-runtime
test-all: test test-dev test-arm test-arm-dev ;

# Get an interactive prompt to a fresh container with the runtime installed
run: $(FULL_PACKAGE_NAME)
	docker image build -t $(TEST_IMAGE_NAME) -f Dockerfile.test --build-arg PRT_PACKAGE=$(ARTIFACT_DIR)/$(PACKAGE_NAME) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --rm $(INTERACTIVE) -v $(shell pwd):/work -w /work -e PRT_ROOT=$(PRT_ROOT) $(TEST_IMAGE_NAME) /bin/bash
run-dev: $(FULL_PACKAGE_NAME_DEV)
	docker image build -t $(TEST_IMAGE_NAME) -f Dockerfile.test --build-arg PRT_PACKAGE=$(ARTIFACT_DIR)/$(PACKAGE_NAME_DEV) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --rm $(INTERACTIVE) -v $(shell pwd):/work -w /work -e PRT_ROOT=$(PRT_ROOT) $(TEST_IMAGE_NAME) /bin/bash

# Clean: remove output files
clean:
	$(RM) $(PACKAGE_PREFIX)_*.tgz  $(PACKAGE_PREFIX)_*.json cache_*
	$(RM) -r $(OUTPUT_DIR)

# Clobber: clean output files and delete build containers
clobber: clean
	$(RM) .builder-image*
	docker image rm $(BUILDER_IMAGE_NAME) $(BUILDER_IMAGE_NAME_ARM) $(TEST_IMAGE_NAME) $(TEST_IMAGE_NAME_ARM) || true

# Upload the cache files
upload-cache:
	scp $(OUTPUT_DIR)/cache_* ${FILESERVER}

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
	echo -e "$(GREEN_BOLD)Build the runtime:$(COLOR_RESET)"; \
	echo -e "  make package                          Build the runtime and package it as a tarball in the current directory"; \
	echo -e "  make builder-image                    Build the docker image used to build the runtime"; \
	echo -e "  make package-arm                      Build the runtime (arm64) and package it as a tarball in the current directory"; \
	echo -e "  make builder-image-arm                Build the docker image (arm64) used to build the runtime"; \
	echo ""; \
	echo -e "$(GREEN_BOLD)Testing:$(COLOR_RESET)"; \
	echo -e "  make test                             Install the package in a fresh container and test it"; \
	echo -e "  make test-dev                         Install the dev package in a fresh container and test it"; \
	echo -e "  make test-arm                         Install the ARM64 package in a fresh container and test it"; \
	echo -e "  make test-arm-dev                     Install the ARM64 dev package in a fresh container and test it"; \
	echo -e "  make test-all                     	 Run the tests for all the variations"; \
	echo -e "  make run                              Install the package in a fresh container and get an interactive prompt"; \
	echo -e "  make run-dev                          Install the dev package in a fresh container and get an interactive prompt"; \
	echo ""; \
	echo -e "$(GREEN_BOLD)Cleanup:$(COLOR_RESET)"; \
	echo -e "  make clean                            Delete the package and cache files"; \
	echo -e "  make clobber                          Delete the package, cache files, and docker images"; \
	echo ""; \
	echo -e "$(GREEN_BOLD)Misc:$(COLOR_RESET)"; \
	echo -e "  make upload-cache                     Upload the cache files to the cache server, replacing what is there."; \
	echo ""; \
	} | less -FKqrX
