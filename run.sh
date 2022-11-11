#!/usr/bin/env bash

set -euo pipefail

function error() {
  printf "\033[31m%-8s\033[0m %s\n" "error" "$@" >&2
  exit 1
}

function export-to-file() {
  if [[ "$#" -ne 2 ]]; then
    error "Arguments mismatch: required 2, received $#."
  fi

  if [[ -z "$1" || -z "$2" ]]; then
    error "Received invalid arguments: $1 $2"
  fi

  local input
  local output="$2"

  # Read input - split by space to be array-safe
  read -ra input <<<"$1"

  # Since Bash redirects execute before the command,
  # we need a temporary file to act as a buffer for output.
  local tmp_file
  tmp_file=$(mktemp)

  # Output to buffer with newline as separator between entries
  printf "%s\n" "${input[@]}" >"${tmp_file}"

  # Ensure the directory containing the output file exists
  mkdir -p "$(dirname "${output}")"

  # Redirect output from buffer and cleanup
  cat "${tmp_file}" >"${output}"
  rm -f "${tmp_file}"
}

function command-docker-tags() {
  if [[ "$#" -ne 2 ]]; then
    error "Arguments mismatch: required 2, received $#."
  fi

  if [[ -z "$1" || -z "$2" ]]; then
    error "Received invalid arguments: $1 $2"
  fi

  local image="$1"
  local output="$2"

  # Docker v2 API endpoints
  local tokenUri="https://auth.docker.io/token"
  local listUri="https://registry-1.docker.io/v2/${image}/tags/list"

  # Get authorization token from the registry
  local token
  local data=("service=registry.docker.io" "scope=repository:${image}:pull")
  token="$(curl -s -G --data-urlencode "${data[0]}" --data-urlencode "${data[1]}" ${tokenUri} | jq -r ".token")"

  # Get list of image tags (filters out variant images)
  local tags
  tags="$(curl -s -G -H "Accept: application/json" -H "Authorization: Bearer ${token}" "${listUri}" | jq -r '.tags | map(select(test("-") | not)) | @sh')"

  # Output
  export-to-file "$(echo "${tags}" | tr -d \'\")" "${output}"
}

function command-minor-tags() {
  if [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
    error "Arguments mismatch: required 1 or 2, received $#."
  fi

  if [[ -z "$1" ]]; then
    error "Received invalid arguments: $1 ${2-}"
  fi

  # ShellCheck gets confused if these lines are merged
  local input
  input="$1"
  local output="${2-$input}"

  local parts=()
  local tags=()
  while read -r version; do
    # Split version into array of semver parts (x.y.z => (x y z))
    IFS="." read -ra parts <<<"${version}"

    # Only include minor versions (x.y)
    if [ ${#parts[@]} -eq "2" ]; then
      tags+=("${version}")
    fi
  done <"${input}"

  # Output
  export-to-file "${tags[*]}" "${output}"
}

function command-test() {
  if [[ "$#" -ne 2 ]]; then
    error "Arguments mismatch: required 2, received $#."
  fi

  if [[ -z "$1" || -z "$2" ]]; then
    error "Received invalid arguments: $1 $2"
  fi

  local name="$1"
  local tag="$2"

  # This is intentionally global - it will be used by `trap` for cleanup
  container="test-${tag}"

  # Spawn a new container with an interactive shell to keep it alive
  docker run --detach --init --tty \
    --cap-add=SYS_ADMIN --name "${container}" --user circleci:circleci \
    "${name}:${tag}" bash >/dev/null

  # Copy fixtures and the Makefile into the container
  docker cp ./fixtures/. "${container}":/home/circleci/project/fixtures
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
  if [[ ($major -eq 10 && $minor -eq 18 && $patch -ge 1) || ($major -eq 10 && $minor -gt 18) || $major -gt 10 ]]; then
    # v3-v13 of puppeteer support Node.js 10.18.1+
    puppeteer_versions+=("3" "10")
  elif [[ ($major -eq 14 && $minor -eq 1 && $patch -ge 0) || ($major -eq 14 && $minor -gt 1) || $major -gt 14 ]]; then
    # v14-v19 of puppeteer support Node.js 14.1.0+
    puppeteer_versions+=("14" "19")
  fi

  # Cleanup the spawned container on error or exit
  function cleanup() {
    # Check for container's existence - it might have crashed
    if docker ps -a | grep -q "${container}"; then
      docker kill "${container}" >/dev/null
      docker rm "${container}" >/dev/null
    fi
  }

  trap cleanup err exit

  # Run tests for all compatible puppeteer versions
  docker exec "${container}" make verify-all puppeteer="${puppeteer_versions[*]}"
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
  ;;
minor-tags)
  shift
  command-minor-tags "$@"
  ;;
test)
  shift
  command-test "$@"
  ;;
*)
  error "Unknown arguments: $*"
  ;;
esac
