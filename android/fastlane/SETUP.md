## Kviz DBase fastlane setup

Run commands from `D:\AndroidProjects\kviz\android`.

Install fastlane dependencies:

```powershell
bundle install
```

If Bundler tries to write into `C:\Ruby32-x64` and fails, install gems locally:

```powershell
bundle config set path vendor/bundle
bundle install
```

Build a signed release AAB only:

```powershell
bundle exec fastlane android build_aab
```

Build and upload to Google Play internal testing:

```powershell
bundle exec fastlane android internal
```

Build and upload to Google Play closed testing:

```powershell
bundle exec fastlane android closed
```

Useful options:

```powershell
bundle exec fastlane android internal version:1.0.1
bundle exec fastlane android closed track:alpha
```

The lanes use `..\scripts\build_aab.ps1`, which bumps `build_number.txt`,
updates `pubspec.yaml`, reads `KVIZ_GOOGLE_SERVER_CLIENT_ID` from
`secrets\dart_defines.properties`, enables Dart obfuscation, writes split debug
info under `build\symbols\android`, and creates:

```text
build\app\outputs\bundle\release\app-release.aab
```

Google Play upload credentials are read from:

```text
secrets\google-play-service-account.json
```

You can override that path with `SUPPLY_JSON_KEY` or `GOOGLE_PLAY_JSON_KEY`.
This must be a Google Play Publishing API service-account JSON with access to
package `rs.in.dbase.kviz`; `google-services.json` is not enough.

Before upload, enable the Google Play Android Developer API for the Google Cloud
project behind that service account:

```text
https://console.developers.google.com/apis/api/androidpublisher.googleapis.com/overview?project=224945393225
```
