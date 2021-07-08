### Description of Changes

(briefly outline the reason for changes, and describe what's been done)

### Breaking Changes

-   None

### Release Checklist

Prepare:

-   [ ] Detail any breaking changes. Breaking changes require a new major version number
-   [ ] Check the example app builds and runs as expected
-   [ ] Add an entry in `CHANGELOG.md`

Bump versions in:

-   [ ] `pubspec.yaml`
-   [ ] `ios/Classes/KumulosSdkFlutterPlugin.m`
-   [ ] `android/src/main/java/com/kumulos/flutter/kumulos_sdk_flutter/KumulosInitProvider.java`
-   [ ] `README.md`

Release:

-   [ ] Squash and merge to master
-   [ ] Delete branch once merged
-   [ ] Create tag from master matching chosen version
-   [ ] Run `dart pub publish --dry-run` to check what will be published
-   [ ] Run `dart pub publish` to upload to https://pub.dev
