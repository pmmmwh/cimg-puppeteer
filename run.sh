#!/usr/bin/env bash

function error() {
  printf "\033[31m%-8s\033[0m %s\n" "error" "$@" >&2
  exit 1
}

function export-to-file() {
  if [[ "$#" -ne 2 || -z "$1" || -z "$2" ]]; then
    error "Not enough arguments - required 2, received $#."
  fi

  local input="$1"
  local output="$2"

  # Since Bash redirects execute before the command,
  # we need a temporary file to act as a buffer for output.
  local tmp_file
  tmp_file=$(mktemp)

  # Output to buffer
  echo "${input}" >"${tmp_file}"

  # Ensure the directory containing the output file exists
  mkdir -p "$(dirname "${output}")"

  # Redirect output from buffer and cleanup
  cat "${tmp_file}" >"${output}"
  rm -f "${tmp_file}"
}

function command-docker-tags() {
  if [[ "$#" -ne 2 || -z "$1" || -z "$2" ]]; then
    error "Insufficient arguments! Required: 2, Received: $#."
  fi

  local image="$1"
  local output="$2"

  # Docker v2 API endpoints
  local tokenUri="https://auth.docker.io/token"
  local listUri="https://registry-1.docker.io/v2/${image}/tags/list"

  # Get authorization token from the registry
  local token
  local data=("service=registry.docker.io" "scope=repository:${image}:pull")
  token="$(curl -s -G --data-urlencode "${data[0]}" --data-urlencode "${data[1]}" ${tokenUri} | jq -r '.token')"

  # Get list of image tags
  local tags
  tags="$(curl -s -G -H "Accept: application/json" -H "Authorization: Bearer ${token}" "${listUri}" | jq -r '.tags | @sh')"

  # Output with spaces as newlines
  export-to-file "$(printf "%s\n" "${tags}" | sed "s|['\"]||g")" "${output}"
}

function command-minor-tags() {
  if [[ "$#" -ne 2 || -z "$1" || -z "$2" ]]; then
    error "Insufficient arguments! Required: 2, Received: $#."
  fi

  local input="$1"
  local output="$2"

  local parts=()
  local tags=()
  while read -r version; do
    # Split version into array of semver parts (x.y.z => (x y z))
    IFS='.' read -ra parts <<<"${version}"

    # Only include minor versions (x.y)
    if [ ${#parts[@]} -eq "2" ]; then
      tags+=("${version}")
    fi
  done <"${input}"

  # Output with spaces as newlines
  export-to-file "$(printf "%s\n" "${tags[@]}")" "${output}"
}

function command-test() {
  if [[ "$#" -ne 2 || -z "$1" || -z "$2" ]]; then
    error "Insufficient arguments! Required: 2, Received: $#."
  fi

  local name="$1"
  local tag="$2"

  local container="test-${tag}"

  # Spawn a new container with an interactive shell to keep it alive
  docker run --detach --init --privileged --tty \
    --name "${container}" --user circleci:circleci \
    "${name}:${tag}" bash 1>/dev/null

  # Copy fixtures and the Makefile into the container
  # shellcheck disable=SC2086
  docker cp ./fixtures/. ${container}:/home/circleci/project/fixtures
  docker cp ./Makefile "${container}":/home/circleci/project/Makefile

  # Parse the container's Node.js version
  local node_version
  local parts=()
  node_version=$(docker exec "${container}" node --version | sed -e "s|^[vV]||g")
  IFS="." read -ra parts <<<"${node_version}"

  local major="${parts[0]}"
  local minor="${parts[1]}"
  local patch="${parts[2]}"

  # Puppeteer@2 is used as a baseline since it supports all available tags for cimg/node_version
  local puppeteer_versions=("2")
  if [[ ($major -eq 10 && $minor -ge 18 && $patch -ge 1) || $major -gt 10 ]]; then
    # All of v3, v4 and v5 of puppeteer support Node.js 10.18.1+
    puppeteer_versions+=("3" "4" "5")
  fi

  # Run tests for all compatible puppeteer versions
  docker exec "${container}" make verify-all puppeteer="${puppeteer_versions[*]}"

  # Cleanup the spawned container
  docker kill "${container}" 1>/dev/null
  # shellcheck disable=SC2086
  docker rm ${container} 1>/dev/null
}

case $# in
0)
  error "Unknown command: $*"
  ;;
esac

case $1 in
docker-tags)
  shift
  command-docker-tags "$@"
  exit 0
  ;;
minor-tags)
  shift
  command-minor-tags "$@"
  exit 0
  ;;
test)
  shift
  command-test "$@"
  exit 0
  ;;
*)
  error "Unknown arguments: $*"
  ;;
esac
