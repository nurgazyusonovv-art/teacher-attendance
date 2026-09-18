#!/bin/bash
set -euo pipefail

teacher_mobile_dir="$(cd "$(dirname "$0")/.." && pwd)"
export TEACHER_ANDROID_STORE_FILE="$teacher_mobile_dir/android/keystores/teacher-release.jks"
export TEACHER_ANDROID_KEY_ALIAS=teacher-release
if [[ ! -f "$TEACHER_ANDROID_STORE_FILE" ]]; then
  echo 'Release keystore is missing. Restore the original key; do not generate a replacement.' >&2
  exit 1
fi
export TEACHER_ANDROID_STORE_PASSWORD
TEACHER_ANDROID_STORE_PASSWORD="$(security find-generic-password -a teacher-release -s teacher-attendance-android-release -w)"
export TEACHER_ANDROID_KEY_PASSWORD="$TEACHER_ANDROID_STORE_PASSWORD"
cd "$teacher_mobile_dir"
exec flutter build apk --release --split-per-abi \
  --target-platform android-arm,android-arm64 \
  --dart-define=API_BASE_URL=https://teacher-attendance-api-hfh2.onrender.com/api/v1
