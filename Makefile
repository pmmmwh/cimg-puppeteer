.DEFAULT_GOAL := help

define log-info
	printf "\033[34m%-8s\033[0m %s\n" "info" $(1)
endef

define log-success
	printf "\033[32m%-8s\033[0m %s\n" "success" $(1)
endef

define log-error
	printf "\033[31m%-8s\033[0m %s\n" "error" $(1) >&2
endef

.PHONY: help
help: ## Show this message
	@awk 'BEGIN {FS=":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-24s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

progress ?= auto

.PHONY: build
build: $(foreach build-version,$(versions),build/$(build-version)) ## Build specific versions of a Docker image

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
	@bash ./run.sh minor-tags $(input)
	@$(call log-success,"Non-semver-minor tags in $(input) successfully filtered.")

.PHONY: get-tags
get-tags: ## Get all available tags of a Docker image and output to a file
	@$(call log-info,"Fetching all available tags for $(name)...")
	@bash ./run.sh docker-tags $(name) $(output)
	@$(call log-success,"Docker tags for $(name) saved to $(output).")

.PHONY: hadolint
hadolint: ## Run hadolint on project Dockerfile
	@$(call log-info,"Running hadolint on Dockerfile...")
	@hadolint Dockerfile
	@$(call log-success,"Dockerfile successfully passed hadolint.")

.PHONY: install-chromium-deps
install-chromium-deps: ## Install all native dependencies for Chromium on Ubuntu
	@$(call log-info,"Installing native dependencies for Chromium...")
	@node ./install-chromium-deps.js
	@$(call log-success,"Native dependencies for Chromium successfully installed.")

.PHONY: publish
publish: $(foreach publish-version,$(versions),publish/$(publish-version)) ## Publish specific versions of a Docker image

publish/%:
	@$(call log-info,"Publishing image $(name):$(or $(tag),$(@F))...")
	@docker push docker.io/$(name):$(or $(tag),$(@F))
	@$(call log-success,"Image $(name):$(or $(tag),$(@F)) successfully published.")

.PHONY: shellcheck
shellcheck: ## Run shellcheck on all project shell files
	@$(call log-info,"Running shellcheck on all shell scripts...")
	@find . -type f -name "*.sh" | xargs shellcheck
	@$(call log-success,"All shell scripts successfully passed shellcheck.")

.PHONY: test
test: $(foreach test-version,$(versions),test/$(test-version)) ## Test specific versions of a Docker image

test/%:
	@$(call log-info,"Running tests on image $(name):$(or $(tag),$(@F))...")
	@bash ./run.sh "test" $(name) $(or $(tag),$(@F))
	@$(call log-success,"Tests on image $(name):$(or $(tag),$(@F)) passed!")

.PHONY: verify-all
verify-all: verify-cleanup verify-execution ## Run all verification steps

.PHONY: verify-cleanup
verify-cleanup: ## Verify the built image does not contain unwanted script files
	@if [ -f "/tmp/install-chromium-deps.js" ]; then \
		$(call log-error,"Installation script for Chromium dependencies was not removed!"); \
		exit 1; \
	fi
	@if [ -n "$$(ls -A /var/lib/apt/lists 2>/dev/null)" ]; then \
		$(call log-error,"Some APT package lists were not removed!"); \
		exit 1; \
	fi
	@$(call log-success,"Image have been properly cleaned up!")

.PHONY: verify-execution
verify-execution: $(foreach pptr-version,$(or $(puppeteer),"latest"),verify-execution/$(pptr-version)) ## Verify the built image can run Puppeteer

verify-execution/%:
	@$(call log-info,"Installing Puppeteer@$(@F)...")
	@PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=1 npm install --loglevel error --no-save puppeteer@$(@F)
	@$(call log-info,"Downloading Chromium...")
	@node ./fixtures/chromium-download.js
	@$(call log-info,"Testing for successful Puppeteer initialization...")
	@node ./fixtures/puppeteer-init.js
	@$(call log-success,"Image have properly configured prerequisites for Puppeteer@$(@F).")
