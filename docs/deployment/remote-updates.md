# Remote Updates

GrowTogetherApp uses two update paths:

1. Shorebird code push for Dart/UI/business-logic patches.
2. Full APK releases for native Android, permission, manifest, plugin, asset, or signing changes.

Android does not allow a normal app to silently install arbitrary APK updates. A full APK update still needs user confirmation. Shorebird patches are the closest fit for the current need: after the first Shorebird APK is installed, later Dart/UI fixes can be published remotely.

## One-time Shorebird setup

Install and sign in:

```bash
curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash
shorebird login
```

Initialize the app:

```bash
shorebird init --display-name "一起进步呀"
```

This creates `shorebird.yaml`. Commit it to git. The `app_id` in that file is how installed apps know which Shorebird patches belong to them.

## First APK with remote update support

Build the first Shorebird release APK:

```bash
SUPABASE_ANON_KEY=sb_publishable_... scripts/shorebird_release_android.sh
```

Install or send this APK once:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Only users who installed a Shorebird-built APK can receive Shorebird patches.

## Publish a remote patch

Use this for Dart/UI/business-logic changes that do not touch native Android code:

```bash
SUPABASE_ANON_KEY=sb_publishable_... scripts/shorebird_patch_android.sh
```

By default this patches the latest Shorebird release. To target a specific installed version:

```bash
RELEASE_VERSION=1.0.0+1 SUPABASE_ANON_KEY=sb_publishable_... scripts/shorebird_patch_android.sh
```

Users receive the patch on app restart. A second restart may be needed before the patched code is visible, depending on when the patch finishes downloading.

## When a full APK is still required

Build and send a full APK when a change includes any of these:

- Android `Manifest`, permissions, Kotlin/Java, Gradle, package name, signing, or native plugins.
- New Flutter plugin dependencies that add native code.
- App icon or bundled assets that must be present before Dart starts.
- Database/backend changes that require a new native capability.
- Version changes intended as a new installable binary.

For full APK testing without Shorebird, keep using:

```bash
SUPABASE_ANON_KEY=sb_publishable_... scripts/build_release_android.sh
```

For full APK testing with Shorebird support, use:

```bash
SUPABASE_ANON_KEY=sb_publishable_... scripts/shorebird_release_android.sh
```
