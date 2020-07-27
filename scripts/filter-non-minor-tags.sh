#!/usr/bin/env bash

minor-versions() {
  local input="$1"
  local result=()

  while read version; do
    # Split version into array of semver parts (x.y.z => (x y z))
    IFS='.' read -ra parts <<<"$version"

    # Only include minor versions (x.y)
    if [[ ${#parts[@]} == 2 ]]; then
      result+=($version)
    fi
  done <$input

  # Output with spaces as newlines
  printf "%s\n" "${result[@]}"
}

# Since Bash redirects execute before the command,
# we need a temporary file to act as a buffer for output.
tmp_file=$(mktemp)

# Get all minor versions and output to file
minor-versions "$1" >"${tmp_file}"

# Redirect output from buffer and cleanup
cat ${tmp_file} >"$1"
rm -f ${tmp_file}
