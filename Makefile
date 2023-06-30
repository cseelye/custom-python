SHELL := /usr/bin/env bash
PACKAGE_PREFIX ?= prt
PACKAGE_VERSION ?= 1.0.0
PYTHON_VERSION ?= 3.11.4
PRT_ROOT ?= /prt
BUILDER_IMAGE_NAME ?= prt-builder
TEST_IMAGE_NAME ?= prt-test

PACKAGE_NAME=$(PACKAGE_PREFIX)_$(PACKAGE_VERSION).tgz

builder-image: .builder-image

.builder-image: Dockerfile
	docker image build -t $(BUILDER_IMAGE_NAME) .
	id=$$(docker image inspect -f '{{.Id}}' $(BUILDER_IMAGE_NAME)) && echo "$${id}" > .builder-image


package: $(PACKAGE_NAME)
$(PACKAGE_NAME): .builder-image
	docker container run --rm -it -v $(shell pwd):/output -w /output -e OUTPUT_DIR=/output -e PACKAGE_NAME=$(PACKAGE_NAME) -e PYTHON_VERSION=$(PYTHON_VERSION) $(BUILDER_IMAGE_NAME) ./build-runtime

test-install:
	docker image build -t $(TEST_IMAGE_NAME) -f Dockerfile.test --build-arg PRT_PACKAGE=$(PACKAGE_NAME) --build-arg PRT_ROOT=$(PRT_ROOT) . && \
	docker container run --rm -it $(TEST_IMAGE_NAME) $(PRT_ROOT)/bin/python --version

clobber: clean
clean:
	$(RM) .builder-image
	docker image rm $(BUILDER_IMAGE_NAME)
