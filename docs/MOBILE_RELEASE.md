# Mobile distribution

## Version

Current version: **1.1.3 (build 5)**, defined in `mobile/pubspec.yaml`.

2026-09-14: signed artifacts in `releases/teacher-1.1.3-build5-arm64.apk`,
`releases/teacher-1.1.3-build5-arm32.apk` and
`releases/ios-1.1.3-build5/teacher_mobile.ipa`. Cache fixes and 12/15-second
connection/response timeouts included. Analyzer clean; 36 tests passed.
Backend geofence changes require a separate production deployment.
iOS uses `FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER`; its bundle ID and the user's
signing configuration have not changed. This change does not upload to TestFlight.
## iOS Transporter

Latest UI release: `releases/ios-1.1.2-build4/teacher_mobile.ipa`, version 1.1.2,
build 4. Android: `releases/teacher-1.1.2-build4-arm64.apk` and
`releases/teacher-1.1.2-build4-arm32.apk`. Existing release signing reused.
No Transporter upload performed. Previous build 3 artifacts below are retained.

Exported `releases/ios-1.1.1-build3/teacher_mobile.ipa` on 2026-09-10 using
Cloud Managed Apple Distribution signing and an App Store provisioning profile.
Version is 1.1.1, build 3; bundle ID is `com.school.teacher.teacherMobile`.
Export settings are in `mobile/ios/TransporterExportOptions.plist` (export only,
no automatic upload or version changes). User-owned iOS configuration is preserved.

Add this IPA to Transporter, validate, then Deliver using the existing Apple account.
App Store Connect validation, upload, and TestFlight processing have not been run.
Generated archives and export artifacts are excluded from Git under `releases/`.

## Android APK

Run on the signing Mac:

```sh
bash mobile/scripts/build_android_release.sh
```

The script builds release APKs for ARM64 and ARMv7 using the production API.
It obtains the signing password from macOS Keychain, not a committed properties file.
Flutter's split-per-ABI version codes for build 4 are 2004 (ARM64) and 1004 (ARMv7).
Use the same split build scheme for subsequent updates.

- Private keystore: `mobile/android/keystores/teacher-release.jks`
- Alias: `teacher-release`
- Keychain service: `teacher-attendance-android-release`
- Keychain account: `teacher-release`

Keep an encrypted backup of the keystore and its password in an owner-controlled
secure backup location. Both are necessary for future updates. Never send them with
the APK, put them in Git, or replace the key for an already distributed application.

The previous 1.0.0 APK was signed with Android Debug. The new release key was created
with the owner's approval on 2026-09-10. Users must uninstall the old test app once
before installing this release. Server records are unaffected; local login/cache is
removed, so users must sign in again. Subsequent releases must reuse this release key.

Real-device camera/GPS acceptance testing is still required; a successful build and
signature check do not replace that test.
