#!/usr/bin/env bash
set -uo pipefail

log_file="$(mktemp)"
trap 'rm -f "$log_file"' EXIT

for attempt in 1 2 3; do
  echo "Writer keyboard integration attempt $attempt/3"
  if flutter drive --driver=test_driver/integration_test.dart --target=integration_test/writer_keyboard_test.dart -d emulator-5554 2>&1 | tee "$log_file"; then
    exit 0
  fi

  if ! grep -Eqi 'HTTP 429|status code 429|Could not GET|Gradle threw an error while downloading artifacts|Could not resolve .* from .*' "$log_file"; then
    exit 1
  fi

  if [ "$attempt" -lt 3 ]; then
    echo "Transient Gradle dependency/network error; retrying in $((attempt * 30)) seconds."
    sleep "$((attempt * 30))"
  fi
done

exit 1
