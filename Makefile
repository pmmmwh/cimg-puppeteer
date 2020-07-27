.DEFAULT_GOAL := help

define log-info
	printf "\033[34m%-8s\033[0m %s\n" "info" $(1)
endef

define log-success
	printf "\033[32m%-8s\033[0m %s\n" "success" $(1)
endef

define log-error
	printf "\033[31m%-8s\033[0m %s\n" "error" $(1)
endef

.PHONY: help
help: ## Show this message
	@awk 'BEGIN {FS=":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-24s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

progress ?= auto

.PHONY: build
build: $(foreach version,$(versions),build/$(version)) ## Build specific versions of a Docker image

build/%:
	@$(call log-info,"Building image $(name):$(or $(tag),$(@F))...")
	@DOCKER_BUILDKIT=1 docker build \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		--build-arg VERSION=$(@F) \
		--cache-from cimg/node:$(@F),$(name):$(@F) \
		--file ./Dockerfile \
		--progress $(progress) \
		--tag $(name):$(or $(tag),$(@F)) \
		.
	@$(call log-success,"Image $(name):$(or $(tag),$(@F)) successfully built.")

.PHONY: filter-non-minor-tags
filter-non-minor-tags: ## Filter out all non-semver-minor tags from an input file
	@$(call log-info,"Filtering all semver minor tags in $(input)...")
	@bash ./scripts/filter-non-minor-tags.sh $(input)
	@$(call log-success,"Non-semver-minor tags in $(input) successfully filtered.")

.PHONY: get-tags
get-tags: ## Get all available tags of a Docker image and output to a file
	@$(call log-info,"Fetching all available tags for $(name)...")
	@bash ./scripts/get-docker-tags.sh $(name) $(output)
	@$(call log-success,"Docker tags for $(name) saved to $(output).")

.PHONY: install-chromium-deps
install-chromium-deps: ## Install all native dependencies for Chromium on Ubuntu
	@$(call log-info,"Installing native dependencies for Chromium...")
	@node ./scripts/install-chromium-deps.js
	@$(call log-success,"Native dependencies for Chromium successfully installed.")

.PHONY: verify-all
verify-all: verify-cleanup verify-execution ## Run all verification steps

.PHONY: verify-cleanup
verify-cleanup: ## Verify the built image does not contain unwanted script files
	@if [ -f "/tmp/install-chromium-deps.js" ]; then \
		$(call log-error,"Installation script for Chromium dependencies was not removed!"); \
		exit 1; \
	fi
	@$(call log-success,"Image have properly cleaned up installation scripts!")

.PHONY: verify-execution
verify-execution: ## Verify the built image can run Puppeteer
	@$(call log-info,"Installing the latest version of Puppeteer...")
	@npm install puppeteer
	@$(call log-info,"Testing for successful Puppeteer initialization...")
	@node ./fixtures/puppeteer-init.js
	@$(call log-success,"Image have properly configured prerequisites for Puppeteer.")

.PHONY: test
test: $(foreach version,$(versions),test/$(version)) ## Test specific versions of a Docker image

test/%:
	@$(call log-info,"Running tests on image $(name):$(or $(tag),$(@F))...")
	@CONTAINER="$(name)-$(or $(tag),$(@F))" && \
	docker run \
		--detach --init --privileged --tty \
		--name ${CONTAINER} --user circleci:circleci \
		$(name):$(or $(tag),$(@F)) \
		bash && \
	docker cp ./fixtures/. ${CONTAINER}:/home/circleci/project/fixtures && \
	docker cp ./Makefile ${CONTAINER}:/home/circleci/project/Makefile && \
	docker exec ${CONTAINER} make verify-all && \
	docker kill ${CONTAINER} 1>/dev/null && \
	docker rm ${CONTAINER} 1>/dev/null
	@$(call log-success,"Tests on image $(name):$(or $(tag),$(@F)) passed!")
