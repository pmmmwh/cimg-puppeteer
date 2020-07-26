.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this message
	@awk 'BEGIN {FS=":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-24s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: build
build: $(versions) ## Build specific versions of a Docker image

# TODO: Add cache with $(name):$@
$(versions):
	@DOCKER_BUILDKIT=1 docker build \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		--build-arg VERSION=$@ \
		--cache-from cimg/node:$@ \
		--file ./Dockerfile \
		--tag $(name):$(or $(tag),$@) \
		.

.PHONY: get-tags
get-tags: ## Get all available tags of a Docker image and output to a file
	@printf "\033[34m%-8s\033[0m %s\n" \
		"info" \
		"Fetching all available tags for $(name)..."
	@bash ./scripts/get-docker-tags.sh $(name) $(output)
	@printf "\033[32m%-8s\033[0m %s\n" \
		"success" \
		"Docker tags for $(name) saved to $(output)."

.PHONY: install-chromium-deps
install-chromium-deps: ## Install all native dependencies for Chromium on Ubuntu
	@printf "\033[34m%-8s\033[0m %s\n" \
		"info" \
		"Installing native dependencies for Chromium..."
	@node ./scripts/install-chromium-deps.js
	@printf "\033[32m%-8s\033[0m %s\n" \
		"success" \
		"Native dependencies for Chromium successfully installed."

.PHONY: test
test: ## Test the built Docker image to make sure Puppeteer works
	@if [ -f "/tmp/install-chromium-deps.js" ]; then \
		printf "\033[31m%-8s\033[0m %s\n" \
			"error" \
			"Installation script for Chromium dependencies was not removed!"; \
		exit 1; \
	fi
	@printf "\033[34m%-8s\033[0m %s\n" \
		"info" \
		"Installing the latest version of Puppeteer..."
	@yarn add puppeteer
	@printf "\033[34m%-8s\033[0m %s\n" \
		"info" \
		"Testing for successful Puppeteer initialization..."
	@node ./fixtures/puppeteer-init.js
	@printf "\033[32m%-8s\033[0m %s\n" \
		"success" \
		"Image have properly configured prerequisites for Puppeteer."
