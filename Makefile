.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this message
	@awk 'BEGIN {FS=":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-24s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: build
build: build/$(versions) ## Build specific versions of a Docker image

# TODO: Add cache with $(name):$@
build/$(versions):
	@printf "\033[34m%-8s\033[0m %s\n" \
		"info" \
		"Building image $(name):$(or $(tag),$(@F))..."
	@DOCKER_BUILDKIT=1 docker build \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		--build-arg VERSION=$(@F) \
		--cache-from cimg/node:$(@F) \
		--file ./Dockerfile \
		--tag $(name):$(or $(tag),$(@F)) \
		.
	@printf "\033[32m%-8s\033[0m %s\n" \
		"success" \
		"Image $(name):$(or $(tag),$(@F)) successfully built."

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

.PHONY: verify-all
verify-all: verify-cleanup verify-execution ## Run all verification steps

.PHONY: verify-cleanup
verify-cleanup: ## Verify the built image does not contain unwanted script files
	@if [ -f "/tmp/install-chromium-deps.js" ]; then \
		printf "\033[31m%-8s\033[0m %s\n" \
			"error" \
			"Installation script for Chromium dependencies was not removed!"; \
		exit 1; \
	fi

.PHONY: verify-execution
verify-execution: ## Verify the built image can run Puppeteer
	@printf "\033[34m%-8s\033[0m %s\n" \
		"info" \
		"Installing the latest version of Puppeteer..."
	@npm install puppeteer
	@printf "\033[34m%-8s\033[0m %s\n" \
		"info" \
		"Testing for successful Puppeteer initialization..."
	@node ./fixtures/puppeteer-init.js
	@printf "\033[32m%-8s\033[0m %s\n" \
		"success" \
		"Image have properly configured prerequisites for Puppeteer."

.PHONY: test
test: test/$(versions) ## Test specific versions of a Docker image

test/$(versions):
	@docker run \
		--detach --init --privileged --tty \
		--name $(name) --user circleci:circleci \
		$(name):$(or $(tag),$(@F)) \
		bash && \
	docker cp ./fixtures/. $(name):/home/circleci/project/fixtures && \
	docker cp ./Makefile $(name):/home/circleci/project/Makefile && \
	docker exec $(name) make verify-all && \
	docker kill $(name) 1>/dev/null && \
	docker rm $(name) 1>/dev/null
