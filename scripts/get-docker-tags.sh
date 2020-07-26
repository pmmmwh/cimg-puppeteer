#!/usr/bin/env bash

docker-tags() {
  local image="$1"

  # Docker v2 API endpoints
  tokenUri="https://auth.docker.io/token"
  listUri="https://registry-1.docker.io/v2/$image/tags/list"

  # Get authorization token from the registry
  data=("service=registry.docker.io" "scope=repository:$image:pull")
  token="$(curl -s -G --data-urlencode ${data[0]} --data-urlencode ${data[1]} ${tokenUri} | jq -r '.token')"

  # Get list of image tags
  result="$(curl -s -G -H "Accept: application/json" -H "Authorization: Bearer $token" ${listUri} | jq -r '.tags | @sh')"

  echo ${result}
}

# Ensure the directory containing the output file exists
mkdir -p "$(dirname $2)"

# Get all docker tags, remove quotes and output to file
docker-tags "$1" | sed "s|['\"]||g" >"$2"
