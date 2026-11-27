#!/usr/bin/env bash
set -uo pipefail

log_file="$(mktemp)"
trap 'rm -f "$log_file"' EXIT

# sys.boot_completed can become 1 before Android's PackageManager and
# ActivityManager Binder services are actually registered. On slow TCG
# hosted emulators, Flutter's first install can otherwise fail immediately
# with "Can't find service: package" even though ADB reports the device online.
wait_for_android_services() {
  for attempt in $(seq 1 36); do
    package_output="$(adb -s emulator-5554 shell cmd package list packages 2>&1 || true)"
    activity_output="$(adb -s emulator-5554 shell dumpsys activity activities 2>&1 || true)"
    if grep -q '^package:' <<<"$package_output" &&
       ! grep -q "Can't find service:" <<<"$activity_output"; then
      echo "Android PackageManager and ActivityManager are ready."
      return 0
    fi
    if (( attempt % 6 == 0 )); then
      echo "Waiting for Android system services ($((attempt * 5))/180 seconds)."
      echo "PackageManager: $(tail -n 1 <<<"$package_output")"
      echo "ActivityManager: $(tail -n 1 <<<"$activity_output")"
    fi
    sleep 5
  done

  echo "Android system services did not become ready; collecting diagnostics."
  adb -s emulator-5554 shell getprop sys.boot_completed || true
  adb -s emulator-5554 shell ps -A | grep -E 'system_server|systemui' || true
  adb -s emulator-5554 logcat -d -t 500 2>&1 | tail -n 220 || true
  return 1
}

adb -s emulator-5554 wait-for-device
wait_for_android_services

for attempt in 1 2 3; do
  echo "Writer keyboard integration attempt $attempt/3"
  if timeout --signal=TERM --kill-after=30s 20m flutter drive --driver=test_driver/integration_test.dart --target=integration_test/writer_keyboard_test.dart -d emulator-5554 2>&1 | tee "$log_file"; then
    exit 0
  fi

  if ! grep -Eqi 'HTTP 429|status code 429|Could not GET|Gradle threw an error while downloading artifacts|Could not resolve .* from .*' "$log_file"; then
    echo "Writer keyboard integration failed; collecting emulator diagnostics."
    adb devices -l || true
    adb -s emulator-5554 shell dumpsys activity activities 2>&1 | tail -n 80 || true
    adb -s emulator-5554 logcat -d -t 400 2>&1 | tail -n 180 || true
    exit 1
  fi

  if [ "$attempt" -lt 3 ]; then
    echo "Transient Gradle dependency/network error; retrying in $((attempt * 30)) seconds."
    sleep "$((attempt * 30))"
  fi
done

exit 1
