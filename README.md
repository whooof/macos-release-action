# macOS Release Action

[![GitHub release](https://img.shields.io/github/v/release/whooof/macos-release-action)](https://github.com/whooof/macos-release-action/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Complete release workflow for macOS applications. Supports Rust, Swift, and other macOS projects.

## Features

- Semantic versioning (patch/minor/major/custom)
- Cargo.toml updates (Rust projects)
- Info.plist updates
- Xcode project updates (Swift projects)
- App bundle creation (.app)
- Universal binary support (arm64 + x86_64)
- Code signing (ad-hoc or Developer ID)
- Notarization (optional)
- Git tagging
- GitHub Release creation

## Quick Start

```yaml
- uses: whooof/macos-release-action@v1
  with:
    release_type: patch
    update_cargo: true
    update_plist: true
    create_bundle: true
    app_name: MyApp
    binary_path: target/release/myapp
```

## All-in-One Usage

```yaml
name: Release

on:
  workflow_dispatch:
    inputs:
      release:
        description: 'Release type'
        required: true
        type: choice
        options: [patch, minor, major, custom]
      custom_version:
        description: 'Custom version (for type=custom)'
        required: false

jobs:
  release:
    runs-on: macos-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Build
        run: cargo build --release

      - uses: whooof/macos-release-action@v1
        with:
          release_type: ${{ github.event.inputs.release }}
          custom_version: ${{ github.event.inputs.custom_version }}
          update_cargo: true
          update_plist: true
          create_bundle: true
          app_name: MyApp
          binary_path: target/release/myapp
          icon_path: icon.icns
          create_release: true
          release_files: "target/release/*.zip"
```

## Modular Usage

Use individual actions for more control:

```yaml
- name: Calculate version
  id: version
  uses: whooof/macos-release-action/actions/version-bump@v1
  with:
    release_type: minor

- name: Update Cargo.toml
  uses: whooof/macos-release-action/actions/update-cargo@v1
  with:
    version: ${{ steps.version.outputs.version }}

- name: Create app bundle
  uses: whooof/macos-release-action/actions/create-app-bundle@v1
  with:
    app_name: MyApp
    binary_path: target/release/myapp

- name: Create release
  uses: whooof/macos-release-action/actions/github-release@v1
  with:
    tag: ${{ steps.version.outputs.tag }}
    files: "*.zip"
```

## Inputs

### Version

| Input | Description | Default |
|-------|-------------|---------|
| `release_type` | Release type: patch, minor, major, custom | `patch` |
| `custom_version` | Version for type=custom | |
| `tag_prefix` | Tag prefix | `v` |

### File Updates

| Input | Description | Default |
|-------|-------------|---------|
| `update_cargo` | Update Cargo.toml | `false` |
| `cargo_path` | Path to Cargo.toml | `Cargo.toml` |
| `update_plist` | Update Info.plist | `false` |
| `plist_path` | Path to Info.plist | `Info.plist` |
| `update_xcodeproj` | Update Xcode project | `false` |
| `xcodeproj_path` | Path to .xcodeproj | |

### App Bundle

| Input | Description | Default |
|-------|-------------|---------|
| `create_bundle` | Create .app bundle | `false` |
| `app_name` | Application name | |
| `binary_path` | Path to binary | |
| `icon_path` | Path to .icns icon | |
| `architecture` | arm64, x86_64, universal | `arm64` |
| `arm64_binary` | arm64 binary (for universal) | |
| `x86_64_binary` | x86_64 binary (for universal) | |

### Signing & Notarization

| Input | Description | Default |
|-------|-------------|---------|
| `sign_bundle` | Sign the bundle | `true` |
| `sign_identity` | Signing identity (empty=ad-hoc) | |
| `entitlements` | Path to entitlements.plist | |
| `notarize` | Notarize bundle | `false` |
| `apple_id` | Apple ID for notarization | |
| `team_id` | Team ID | |
| `app_password` | App-specific password | |

### Git & Release

| Input | Description | Default |
|-------|-------------|---------|
| `create_tag` | Create git tag | `true` |
| `push_tag` | Push tag to remote | `true` |
| `create_release` | Create GitHub Release | `true` |
| `release_files` | Files to attach | |
| `draft` | Create as draft | `false` |

## Outputs

| Output | Description |
|--------|-------------|
| `version` | New version (e.g., 1.2.3) |
| `tag` | New tag (e.g., v1.2.3) |
| `previous_version` | Previous version |
| `bundle_path` | Path to .app bundle |
| `release_url` | GitHub Release URL |
| `is_prerelease` | Is prerelease version |

## Examples

Full workflow examples are available in the [`examples/`](examples/) directory:

| Example | Description |
|---------|-------------|
| [rust-basic.yml](examples/rust-basic.yml) | Basic Rust project release |
| [rust-universal-binary.yml](examples/rust-universal-binary.yml) | Universal binary (arm64 + x86_64) |
| [swift-xcode.yml](examples/swift-xcode.yml) | Swift/Xcode project |
| [with-notarization.yml](examples/with-notarization.yml) | Full signing and notarization |
| [self-hosted-runner.yml](examples/self-hosted-runner.yml) | Self-hosted runner with dynamic selection |
| [modular-workflow.yml](examples/modular-workflow.yml) | Using individual actions for full control |
| [tag-triggered.yml](examples/tag-triggered.yml) | Release triggered by pushing a tag |

### Quick Examples

#### Rust Project

```yaml
- uses: whooof/macos-release-action@v1
  with:
    release_type: patch
    update_cargo: true
    update_plist: true
    create_bundle: true
    app_name: MyApp
    binary_path: target/release/myapp
    icon_path: icon.icns
```

#### Swift Project

```yaml
- uses: whooof/macos-release-action@v1
  with:
    release_type: minor
    update_xcodeproj: true
    xcodeproj_path: MyApp.xcodeproj
    update_plist: true
    plist_path: MyApp/Info.plist
```

#### Universal Binary

```yaml
- uses: whooof/macos-release-action@v1
  with:
    release_type: patch
    create_bundle: true
    app_name: MyApp
    architecture: universal
    arm64_binary: target/aarch64-apple-darwin/release/myapp
    x86_64_binary: target/x86_64-apple-darwin/release/myapp
    binary_path: target/release/myapp
```

#### With Notarization

```yaml
- uses: whooof/macos-release-action@v1
  with:
    release_type: patch
    create_bundle: true
    app_name: MyApp
    binary_path: target/release/myapp
    sign_identity: "Developer ID Application: Name (TEAM_ID)"
    notarize: true
    apple_id: ${{ secrets.APPLE_ID }}
    team_id: ${{ secrets.TEAM_ID }}
    app_password: ${{ secrets.APP_PASSWORD }}
```

#### Self-Hosted Runner

```yaml
jobs:
  release:
    # User controls the runner
    runs-on: [self-hosted, macOS, ARM64]
    steps:
      - uses: whooof/macos-release-action@v1
        with:
          release_type: patch
          # ...
```

## Available Actions

| Action | Description |
|--------|-------------|
| `actions/version-bump` | Calculate new semantic version |
| `actions/update-cargo` | Update Cargo.toml |
| `actions/update-plist` | Update Info.plist |
| `actions/update-xcodeproj` | Update Xcode project |
| `actions/create-app-bundle` | Create .app bundle |
| `actions/sign-and-notarize` | Sign and notarize |
| `actions/tag-release` | Create git tag |
| `actions/github-release` | Create GitHub Release |

## License

MIT License - see [LICENSE](LICENSE) for details.
