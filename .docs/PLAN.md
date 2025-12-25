# macOS Release Action - Implementation Plan

## Overview

A comprehensive GitHub Action for macOS application release workflows. Supports Rust, Swift, and other macOS projects with semantic versioning, app bundling, code signing, and optional notarization.

**Repository:** `whooof/macos-release-action`
**License:** MIT
**Target:** GitHub Marketplace (optional)

---

## Features

- Semantic versioning (patch/minor/major/custom)
- Cargo.toml updates (Rust projects)
- Info.plist updates
- Xcode project updates (Swift projects)
- App bundle creation (.app)
- Universal binary support (arm64 + x86_64)
- Code signing (ad-hoc or Developer ID)
- Notarization (optional, requires Apple credentials)
- Git tagging and pushing
- GitHub Release creation with assets

---

## Repository Structure

```
macos-release-action/
├── .docs/
│   ├── PLAN.md                      # This file
│   └── ARCHITECTURE.md              # Technical details
├── .github/
│   └── workflows/
│       └── test.yml                 # CI tests for the action
├── actions/
│   ├── version-bump/
│   │   └── action.yml               # Calculate new version
│   ├── update-cargo/
│   │   └── action.yml               # Update Cargo.toml
│   ├── update-plist/
│   │   └── action.yml               # Update Info.plist
│   ├── update-xcodeproj/
│   │   └── action.yml               # Update Xcode project
│   ├── create-app-bundle/
│   │   └── action.yml               # Create .app bundle
│   ├── sign-and-notarize/
│   │   └── action.yml               # Sign and notarize
│   ├── tag-release/
│   │   └── action.yml               # Git tag and push
│   └── github-release/
│       └── action.yml               # Create GitHub Release
├── scripts/
│   ├── bump-version.sh              # Semver logic
│   ├── update-cargo.sh              # Cargo.toml manipulation
│   ├── update-plist.sh              # Info.plist manipulation
│   ├── update-xcodeproj.sh          # Xcode project manipulation
│   ├── create-bundle.sh             # App bundle creation
│   ├── create-universal.sh          # Universal binary (lipo)
│   ├── sign-bundle.sh               # Code signing
│   └── notarize.sh                  # Apple notarization
├── action.yml                       # Main all-in-one action
├── README.md                        # Documentation
├── LICENSE                          # MIT License
└── CHANGELOG.md                     # Version history
```

---

## Phase 1: Core Scripts

### 1.1 `scripts/bump-version.sh`

**Purpose:** Calculate new semantic version based on release type.

**Input:**
- `RELEASE_TYPE`: patch | minor | major | custom
- `CURRENT_VERSION`: Current version (e.g., "1.2.3" or "v1.2.3")
- `CUSTOM_VERSION`: Custom version (only for type=custom)
- `TAG_PREFIX`: Prefix for tags (default: "v")

**Output:**
- `NEW_VERSION`: New version without prefix (e.g., "1.2.4")
- `NEW_TAG`: New tag with prefix (e.g., "v1.2.4")
- `IS_PRERELEASE`: "true" if version contains "-" (e.g., "1.0.0-beta.1")

**Logic:**
```bash
1. Strip tag prefix from current version
2. Parse semver: MAJOR.MINOR.PATCH[-PRERELEASE]
3. Based on release_type:
   - patch: PATCH += 1
   - minor: MINOR += 1, PATCH = 0
   - major: MAJOR += 1, MINOR = 0, PATCH = 0
   - custom: Use custom_version directly
4. Validate format
5. Return new version and tag
```

### 1.2 `scripts/update-cargo.sh`

**Purpose:** Update version in Cargo.toml.

**Input:**
- `VERSION`: New version
- `CARGO_PATH`: Path to Cargo.toml (default: "Cargo.toml")

**Logic:**
```bash
1. Check if workspace version exists ([workspace.package] version = "...")
2. If yes, update workspace version
3. Also update [package] version if exists
4. Use sed with proper escaping
5. Verify change was made
```

### 1.3 `scripts/update-plist.sh`

**Purpose:** Update version in Info.plist.

**Input:**
- `VERSION`: New version
- `PLIST_PATH`: Path to Info.plist
- `BUILD_NUMBER`: Build number (optional, default: GITHUB_RUN_NUMBER or timestamp)

**Logic:**
```bash
1. Use PlistBuddy (native macOS tool)
2. Update CFBundleShortVersionString
3. Update CFBundleVersion (build number)
4. Verify changes
```

### 1.4 `scripts/update-xcodeproj.sh`

**Purpose:** Update version in Xcode project.

**Input:**
- `VERSION`: New version
- `XCODEPROJ_PATH`: Path to .xcodeproj
- `TARGET`: Target name (optional, empty = all targets)

**Logic:**
```bash
1. Find project.pbxproj inside .xcodeproj
2. Update MARKETING_VERSION
3. Update CURRENT_PROJECT_VERSION
4. Handle multiple targets if specified
```

---

## Phase 2: Bundle and Signing Scripts

### 2.1 `scripts/create-bundle.sh`

**Purpose:** Create macOS .app bundle.

**Input:**
- `APP_NAME`: Application name (e.g., "MyApp")
- `BINARY_PATH`: Path to compiled binary
- `PLIST_PATH`: Path to Info.plist
- `ICON_PATH`: Path to .icns icon (optional)
- `RESOURCES`: Additional resources to copy (optional)
- `OUTPUT_DIR`: Output directory (default: same as binary)

**Output:**
- `BUNDLE_PATH`: Path to created .app bundle

**Logic:**
```bash
1. Create directory structure:
   ${APP_NAME}.app/
   └── Contents/
       ├── Info.plist
       ├── MacOS/
       │   └── ${binary}
       └── Resources/
           └── ${icon}.icns
2. Copy binary to MacOS/
3. Copy Info.plist to Contents/
4. Copy icon to Resources/ (if provided)
5. Copy additional resources (if provided)
6. Set executable permissions
```

### 2.2 `scripts/create-universal.sh`

**Purpose:** Create universal binary from arm64 and x86_64 binaries.

**Input:**
- `ARM64_BINARY`: Path to arm64 binary
- `X86_64_BINARY`: Path to x86_64 binary
- `OUTPUT_PATH`: Output path for universal binary

**Logic:**
```bash
1. Verify both binaries exist
2. Verify architectures with `lipo -info`
3. Create universal binary: `lipo -create -output`
4. Verify result
```

### 2.3 `scripts/sign-bundle.sh`

**Purpose:** Sign the app bundle.

**Input:**
- `BUNDLE_PATH`: Path to .app bundle
- `IDENTITY`: Signing identity (empty = ad-hoc)
- `ENTITLEMENTS`: Path to entitlements.plist (optional)

**Logic:**
```bash
1. If identity is empty, use ad-hoc signing:
   codesign --force --deep --sign - "${BUNDLE_PATH}"
2. Otherwise, use Developer ID:
   codesign --force --deep --sign "${IDENTITY}" [--entitlements "${ENTITLEMENTS}"] "${BUNDLE_PATH}"
3. Verify signature: codesign --verify --verbose "${BUNDLE_PATH}"
```

### 2.4 `scripts/notarize.sh`

**Purpose:** Notarize the app bundle with Apple.

**Input:**
- `BUNDLE_PATH`: Path to .app bundle
- `APPLE_ID`: Apple ID email
- `TEAM_ID`: Apple Developer Team ID
- `APP_PASSWORD`: App-specific password

**Logic:**
```bash
1. Create ZIP archive of the bundle
2. Submit for notarization:
   xcrun notarytool submit "${ZIP_PATH}" \
     --apple-id "${APPLE_ID}" \
     --team-id "${TEAM_ID}" \
     --password "${APP_PASSWORD}" \
     --wait
3. Check result
4. Staple ticket to bundle:
   xcrun stapler staple "${BUNDLE_PATH}"
5. Clean up ZIP
```

---

## Phase 3: Composite Actions

### 3.1 `actions/version-bump/action.yml`

```yaml
name: 'Version Bump'
description: 'Calculate new semantic version'
author: 'whooof'

inputs:
  release_type:
    description: 'Release type: patch | minor | major | custom'
    required: true
    default: 'patch'
  custom_version:
    description: 'Custom version (only used if release_type=custom)'
    required: false
    default: ''
  tag_prefix:
    description: 'Tag prefix'
    required: false
    default: 'v'
  working_directory:
    description: 'Working directory for git commands'
    required: false
    default: '.'

outputs:
  version:
    description: 'New version (e.g., 1.2.3)'
    value: ${{ steps.bump.outputs.version }}
  tag:
    description: 'New tag (e.g., v1.2.3)'
    value: ${{ steps.bump.outputs.tag }}
  previous_version:
    description: 'Previous version'
    value: ${{ steps.bump.outputs.previous_version }}
  previous_tag:
    description: 'Previous tag'
    value: ${{ steps.bump.outputs.previous_tag }}
  is_prerelease:
    description: 'Is this a prerelease version'
    value: ${{ steps.bump.outputs.is_prerelease }}

runs:
  using: 'composite'
  steps:
    - name: Calculate version
      id: bump
      shell: bash
      working-directory: ${{ inputs.working_directory }}
      run: ${{ github.action_path }}/../../scripts/bump-version.sh
      env:
        RELEASE_TYPE: ${{ inputs.release_type }}
        CUSTOM_VERSION: ${{ inputs.custom_version }}
        TAG_PREFIX: ${{ inputs.tag_prefix }}
```

### 3.2 `actions/update-cargo/action.yml`

```yaml
name: 'Update Cargo.toml'
description: 'Update version in Cargo.toml'
author: 'whooof'

inputs:
  version:
    description: 'New version'
    required: true
  cargo_path:
    description: 'Path to Cargo.toml'
    required: false
    default: 'Cargo.toml'
  update_workspace:
    description: 'Update workspace version if present'
    required: false
    default: 'true'
  update_lock:
    description: 'Run cargo update to update Cargo.lock'
    required: false
    default: 'false'

runs:
  using: 'composite'
  steps:
    - name: Update Cargo.toml
      shell: bash
      run: ${{ github.action_path }}/../../scripts/update-cargo.sh
      env:
        VERSION: ${{ inputs.version }}
        CARGO_PATH: ${{ inputs.cargo_path }}
        UPDATE_WORKSPACE: ${{ inputs.update_workspace }}
        UPDATE_LOCK: ${{ inputs.update_lock }}
```

### 3.3 `actions/update-plist/action.yml`

```yaml
name: 'Update Info.plist'
description: 'Update version in Info.plist'
author: 'whooof'

inputs:
  version:
    description: 'New version'
    required: true
  plist_path:
    description: 'Path to Info.plist'
    required: false
    default: 'Info.plist'
  build_number:
    description: 'Build number (default: GITHUB_RUN_NUMBER)'
    required: false
    default: ''
  update_build_number:
    description: 'Update CFBundleVersion'
    required: false
    default: 'true'

runs:
  using: 'composite'
  steps:
    - name: Update Info.plist
      shell: bash
      run: ${{ github.action_path }}/../../scripts/update-plist.sh
      env:
        VERSION: ${{ inputs.version }}
        PLIST_PATH: ${{ inputs.plist_path }}
        BUILD_NUMBER: ${{ inputs.build_number }}
        UPDATE_BUILD_NUMBER: ${{ inputs.update_build_number }}
```

### 3.4 `actions/update-xcodeproj/action.yml`

```yaml
name: 'Update Xcode Project'
description: 'Update version in Xcode project'
author: 'whooof'

inputs:
  version:
    description: 'New version'
    required: true
  xcodeproj_path:
    description: 'Path to .xcodeproj'
    required: true
  target:
    description: 'Target name (empty = all targets)'
    required: false
    default: ''
  build_number:
    description: 'Build number (default: GITHUB_RUN_NUMBER)'
    required: false
    default: ''

runs:
  using: 'composite'
  steps:
    - name: Update Xcode project
      shell: bash
      run: ${{ github.action_path }}/../../scripts/update-xcodeproj.sh
      env:
        VERSION: ${{ inputs.version }}
        XCODEPROJ_PATH: ${{ inputs.xcodeproj_path }}
        TARGET: ${{ inputs.target }}
        BUILD_NUMBER: ${{ inputs.build_number }}
```

### 3.5 `actions/create-app-bundle/action.yml`

```yaml
name: 'Create App Bundle'
description: 'Create macOS .app bundle'
author: 'whooof'

inputs:
  app_name:
    description: 'Application name'
    required: true
  binary_path:
    description: 'Path to compiled binary'
    required: true
  plist_path:
    description: 'Path to Info.plist'
    required: false
    default: 'Info.plist'
  icon_path:
    description: 'Path to .icns icon'
    required: false
    default: ''
  resources:
    description: 'Additional resources to copy (space-separated paths)'
    required: false
    default: ''
  output_dir:
    description: 'Output directory'
    required: false
    default: ''
  architecture:
    description: 'Architecture: arm64 | x86_64 | universal'
    required: false
    default: 'arm64'
  arm64_binary:
    description: 'Path to arm64 binary (for universal)'
    required: false
    default: ''
  x86_64_binary:
    description: 'Path to x86_64 binary (for universal)'
    required: false
    default: ''

outputs:
  bundle_path:
    description: 'Path to created .app bundle'
    value: ${{ steps.bundle.outputs.bundle_path }}

runs:
  using: 'composite'
  steps:
    - name: Create universal binary
      if: inputs.architecture == 'universal'
      shell: bash
      run: ${{ github.action_path }}/../../scripts/create-universal.sh
      env:
        ARM64_BINARY: ${{ inputs.arm64_binary }}
        X86_64_BINARY: ${{ inputs.x86_64_binary }}
        OUTPUT_PATH: ${{ inputs.binary_path }}

    - name: Create bundle
      id: bundle
      shell: bash
      run: ${{ github.action_path }}/../../scripts/create-bundle.sh
      env:
        APP_NAME: ${{ inputs.app_name }}
        BINARY_PATH: ${{ inputs.binary_path }}
        PLIST_PATH: ${{ inputs.plist_path }}
        ICON_PATH: ${{ inputs.icon_path }}
        RESOURCES: ${{ inputs.resources }}
        OUTPUT_DIR: ${{ inputs.output_dir }}
```

### 3.6 `actions/sign-and-notarize/action.yml`

```yaml
name: 'Sign and Notarize'
description: 'Sign and optionally notarize macOS app bundle'
author: 'whooof'

inputs:
  bundle_path:
    description: 'Path to .app bundle'
    required: true
  sign:
    description: 'Sign the bundle'
    required: false
    default: 'true'
  sign_identity:
    description: 'Signing identity (empty = ad-hoc)'
    required: false
    default: ''
  entitlements:
    description: 'Path to entitlements.plist'
    required: false
    default: ''
  notarize:
    description: 'Notarize the bundle'
    required: false
    default: 'false'
  apple_id:
    description: 'Apple ID for notarization'
    required: false
    default: ''
  team_id:
    description: 'Team ID for notarization'
    required: false
    default: ''
  app_password:
    description: 'App-specific password for notarization'
    required: false
    default: ''

outputs:
  signed:
    description: 'Bundle was signed'
    value: ${{ steps.sign.outputs.signed }}
  notarized:
    description: 'Bundle was notarized'
    value: ${{ steps.notarize.outputs.notarized }}

runs:
  using: 'composite'
  steps:
    - name: Sign bundle
      id: sign
      if: inputs.sign == 'true'
      shell: bash
      run: ${{ github.action_path }}/../../scripts/sign-bundle.sh
      env:
        BUNDLE_PATH: ${{ inputs.bundle_path }}
        IDENTITY: ${{ inputs.sign_identity }}
        ENTITLEMENTS: ${{ inputs.entitlements }}

    - name: Notarize bundle
      id: notarize
      if: inputs.notarize == 'true'
      shell: bash
      run: ${{ github.action_path }}/../../scripts/notarize.sh
      env:
        BUNDLE_PATH: ${{ inputs.bundle_path }}
        APPLE_ID: ${{ inputs.apple_id }}
        TEAM_ID: ${{ inputs.team_id }}
        APP_PASSWORD: ${{ inputs.app_password }}
```

### 3.7 `actions/tag-release/action.yml`

```yaml
name: 'Tag Release'
description: 'Create and push git tag'
author: 'whooof'

inputs:
  tag:
    description: 'Tag name'
    required: true
  message:
    description: 'Tag message (default: Release {tag})'
    required: false
    default: ''
  push:
    description: 'Push tag to remote'
    required: false
    default: 'true'
  commit_files:
    description: 'Files to commit before tagging (space-separated)'
    required: false
    default: ''
  commit_message:
    description: 'Commit message'
    required: false
    default: ''
  git_user_name:
    description: 'Git user name'
    required: false
    default: 'github-actions[bot]'
  git_user_email:
    description: 'Git user email'
    required: false
    default: 'github-actions[bot]@users.noreply.github.com'

runs:
  using: 'composite'
  steps:
    - name: Configure git
      shell: bash
      run: |
        git config user.name "${{ inputs.git_user_name }}"
        git config user.email "${{ inputs.git_user_email }}"

    - name: Commit changes
      if: inputs.commit_files != ''
      shell: bash
      run: |
        git add ${{ inputs.commit_files }}
        COMMIT_MSG="${{ inputs.commit_message }}"
        if [ -z "$COMMIT_MSG" ]; then
          COMMIT_MSG="Release ${{ inputs.tag }}"
        fi
        git commit -m "$COMMIT_MSG" || echo "Nothing to commit"

    - name: Create tag
      shell: bash
      run: |
        TAG_MSG="${{ inputs.message }}"
        if [ -z "$TAG_MSG" ]; then
          TAG_MSG="Release ${{ inputs.tag }}"
        fi
        git tag -a "${{ inputs.tag }}" -m "$TAG_MSG"

    - name: Push changes and tag
      if: inputs.push == 'true'
      shell: bash
      run: |
        git push origin HEAD
        git push origin "${{ inputs.tag }}"
```

### 3.8 `actions/github-release/action.yml`

```yaml
name: 'GitHub Release'
description: 'Create GitHub Release'
author: 'whooof'

inputs:
  tag:
    description: 'Tag name'
    required: true
  name:
    description: 'Release name (default: tag)'
    required: false
    default: ''
  body:
    description: 'Release body'
    required: false
    default: ''
  files:
    description: 'Files to attach (glob pattern)'
    required: false
    default: ''
  draft:
    description: 'Create as draft'
    required: false
    default: 'false'
  prerelease:
    description: 'Mark as prerelease (auto = detect from version)'
    required: false
    default: 'auto'
  generate_notes:
    description: 'Generate release notes'
    required: false
    default: 'true'
  token:
    description: 'GitHub token'
    required: false
    default: ${{ github.token }}

outputs:
  release_url:
    description: 'URL to the release'
    value: ${{ steps.release.outputs.url }}
  upload_url:
    description: 'URL for uploading assets'
    value: ${{ steps.release.outputs.upload_url }}

runs:
  using: 'composite'
  steps:
    - name: Determine prerelease
      id: prerelease
      shell: bash
      run: |
        if [ "${{ inputs.prerelease }}" = "auto" ]; then
          if [[ "${{ inputs.tag }}" == *"-"* ]]; then
            echo "value=true" >> $GITHUB_OUTPUT
          else
            echo "value=false" >> $GITHUB_OUTPUT
          fi
        else
          echo "value=${{ inputs.prerelease }}" >> $GITHUB_OUTPUT
        fi

    - name: Create release
      id: release
      uses: softprops/action-gh-release@v2
      with:
        tag_name: ${{ inputs.tag }}
        name: ${{ inputs.name || inputs.tag }}
        body: ${{ inputs.body }}
        files: ${{ inputs.files }}
        draft: ${{ inputs.draft }}
        prerelease: ${{ steps.prerelease.outputs.value }}
        generate_release_notes: ${{ inputs.generate_notes }}
      env:
        GITHUB_TOKEN: ${{ inputs.token }}
```

---

## Phase 4: Main Action (All-in-One)

### `action.yml`

```yaml
name: 'macOS Release Action'
description: 'Complete release workflow for macOS applications'
author: 'whooof'
branding:
  icon: 'package'
  color: 'blue'

inputs:
  # === Version ===
  release_type:
    description: 'Release type: patch | minor | major | custom'
    required: true
    default: 'patch'
  custom_version:
    description: 'Custom version (only for release_type=custom)'
    required: false
    default: ''
  tag_prefix:
    description: 'Tag prefix'
    required: false
    default: 'v'

  # === Cargo (Rust) ===
  update_cargo:
    description: 'Update Cargo.toml version'
    required: false
    default: 'false'
  cargo_path:
    description: 'Path to Cargo.toml'
    required: false
    default: 'Cargo.toml'

  # === Info.plist ===
  update_plist:
    description: 'Update Info.plist version'
    required: false
    default: 'false'
  plist_path:
    description: 'Path to Info.plist'
    required: false
    default: 'Info.plist'

  # === Xcode ===
  update_xcodeproj:
    description: 'Update Xcode project version'
    required: false
    default: 'false'
  xcodeproj_path:
    description: 'Path to .xcodeproj'
    required: false
    default: ''

  # === App Bundle ===
  create_bundle:
    description: 'Create macOS .app bundle'
    required: false
    default: 'false'
  app_name:
    description: 'Application name'
    required: false
    default: ''
  binary_path:
    description: 'Path to compiled binary'
    required: false
    default: ''
  icon_path:
    description: 'Path to .icns icon'
    required: false
    default: ''
  resources:
    description: 'Additional resources to copy'
    required: false
    default: ''
  bundle_output_dir:
    description: 'Output directory for bundle'
    required: false
    default: ''
  architecture:
    description: 'Architecture: arm64 | x86_64 | universal'
    required: false
    default: 'arm64'
  arm64_binary:
    description: 'Path to arm64 binary (for universal)'
    required: false
    default: ''
  x86_64_binary:
    description: 'Path to x86_64 binary (for universal)'
    required: false
    default: ''

  # === Signing ===
  sign_bundle:
    description: 'Sign the bundle'
    required: false
    default: 'true'
  sign_identity:
    description: 'Signing identity (empty = ad-hoc)'
    required: false
    default: ''
  entitlements:
    description: 'Path to entitlements.plist'
    required: false
    default: ''

  # === Notarization ===
  notarize:
    description: 'Notarize the bundle'
    required: false
    default: 'false'
  apple_id:
    description: 'Apple ID for notarization'
    required: false
    default: ''
  team_id:
    description: 'Team ID for notarization'
    required: false
    default: ''
  app_password:
    description: 'App-specific password for notarization'
    required: false
    default: ''

  # === Git ===
  create_tag:
    description: 'Create git tag'
    required: false
    default: 'true'
  push_tag:
    description: 'Push tag to remote'
    required: false
    default: 'true'
  commit_files:
    description: 'Files to commit (auto-detected if update_* is true)'
    required: false
    default: ''

  # === GitHub Release ===
  create_release:
    description: 'Create GitHub Release'
    required: false
    default: 'true'
  release_files:
    description: 'Files to attach to release'
    required: false
    default: ''
  release_name:
    description: 'Release name (default: {app_name} {tag})'
    required: false
    default: ''
  draft:
    description: 'Create release as draft'
    required: false
    default: 'false'
  generate_notes:
    description: 'Generate release notes'
    required: false
    default: 'true'

outputs:
  version:
    description: 'New version'
    value: ${{ steps.version.outputs.version }}
  tag:
    description: 'New tag'
    value: ${{ steps.version.outputs.tag }}
  previous_version:
    description: 'Previous version'
    value: ${{ steps.version.outputs.previous_version }}
  bundle_path:
    description: 'Path to .app bundle'
    value: ${{ steps.bundle.outputs.bundle_path }}
  release_url:
    description: 'GitHub Release URL'
    value: ${{ steps.release.outputs.release_url }}
  is_prerelease:
    description: 'Is prerelease version'
    value: ${{ steps.version.outputs.is_prerelease }}

runs:
  using: 'composite'
  steps:
    # 1. Calculate version
    - name: Calculate version
      id: version
      uses: ./actions/version-bump
      with:
        release_type: ${{ inputs.release_type }}
        custom_version: ${{ inputs.custom_version }}
        tag_prefix: ${{ inputs.tag_prefix }}

    # 2. Update Cargo.toml
    - name: Update Cargo.toml
      if: inputs.update_cargo == 'true'
      uses: ./actions/update-cargo
      with:
        version: ${{ steps.version.outputs.version }}
        cargo_path: ${{ inputs.cargo_path }}

    # 3. Update Info.plist
    - name: Update Info.plist
      if: inputs.update_plist == 'true'
      uses: ./actions/update-plist
      with:
        version: ${{ steps.version.outputs.version }}
        plist_path: ${{ inputs.plist_path }}

    # 4. Update Xcode project
    - name: Update Xcode project
      if: inputs.update_xcodeproj == 'true'
      uses: ./actions/update-xcodeproj
      with:
        version: ${{ steps.version.outputs.version }}
        xcodeproj_path: ${{ inputs.xcodeproj_path }}

    # 5. Create app bundle
    - name: Create app bundle
      id: bundle
      if: inputs.create_bundle == 'true'
      uses: ./actions/create-app-bundle
      with:
        app_name: ${{ inputs.app_name }}
        binary_path: ${{ inputs.binary_path }}
        plist_path: ${{ inputs.plist_path }}
        icon_path: ${{ inputs.icon_path }}
        resources: ${{ inputs.resources }}
        output_dir: ${{ inputs.bundle_output_dir }}
        architecture: ${{ inputs.architecture }}
        arm64_binary: ${{ inputs.arm64_binary }}
        x86_64_binary: ${{ inputs.x86_64_binary }}

    # 6. Sign and notarize
    - name: Sign and notarize
      if: inputs.create_bundle == 'true' && inputs.sign_bundle == 'true'
      uses: ./actions/sign-and-notarize
      with:
        bundle_path: ${{ steps.bundle.outputs.bundle_path }}
        sign: ${{ inputs.sign_bundle }}
        sign_identity: ${{ inputs.sign_identity }}
        entitlements: ${{ inputs.entitlements }}
        notarize: ${{ inputs.notarize }}
        apple_id: ${{ inputs.apple_id }}
        team_id: ${{ inputs.team_id }}
        app_password: ${{ inputs.app_password }}

    # 7. Determine files to commit
    - name: Determine commit files
      id: commit_files
      shell: bash
      run: |
        FILES="${{ inputs.commit_files }}"
        if [ "${{ inputs.update_cargo }}" = "true" ]; then
          FILES="$FILES ${{ inputs.cargo_path }}"
        fi
        if [ "${{ inputs.update_plist }}" = "true" ]; then
          FILES="$FILES ${{ inputs.plist_path }}"
        fi
        echo "files=$FILES" >> $GITHUB_OUTPUT

    # 8. Tag release
    - name: Tag release
      if: inputs.create_tag == 'true'
      uses: ./actions/tag-release
      with:
        tag: ${{ steps.version.outputs.tag }}
        push: ${{ inputs.push_tag }}
        commit_files: ${{ steps.commit_files.outputs.files }}

    # 9. Create GitHub Release
    - name: Create GitHub Release
      id: release
      if: inputs.create_release == 'true'
      uses: ./actions/github-release
      with:
        tag: ${{ steps.version.outputs.tag }}
        name: ${{ inputs.release_name || format('{0} {1}', inputs.app_name, steps.version.outputs.tag) }}
        files: ${{ inputs.release_files }}
        draft: ${{ inputs.draft }}
        prerelease: 'auto'
        generate_notes: ${{ inputs.generate_notes }}
```

---

## Phase 5: Documentation

### README.md Structure

1. **Header** - Name, badges, description
2. **Features** - Bullet list of capabilities
3. **Quick Start** - Minimal example
4. **All-in-One Usage** - Full example with all options
5. **Modular Usage** - Individual action examples
6. **Inputs Reference** - Table of all inputs
7. **Outputs Reference** - Table of all outputs
8. **Examples**
   - Rust project (Cargo.toml + Info.plist)
   - Swift project (Xcode)
   - Universal binary
   - With notarization
   - Manual workflow_dispatch trigger
9. **Architecture Support** - arm64, x86_64, universal
10. **Signing and Notarization** - Detailed guide
11. **Migration Guide** - For existing projects
12. **Contributing**
13. **License**

---

## Phase 6: Testing

### `.github/workflows/test.yml`

Tests to implement:
1. **Version bump tests** - All release types
2. **Cargo.toml update test** - Mock Rust project
3. **Info.plist update test** - Mock plist
4. **Bundle creation test** - Create minimal bundle
5. **Signing test** - Ad-hoc signing
6. **Integration test** - Full workflow on test project

---

## Usage Examples (Final)

### Rust Project (KeyChart style)

```yaml
jobs:
  release:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Build
        run: cargo build --release
      
      - uses: whooof/macos-release-action@v1
        with:
          release_type: ${{ github.event.inputs.release }}
          custom_version: ${{ github.event.inputs.custom_version }}
          update_cargo: true
          update_plist: true
          create_bundle: true
          app_name: KeyChart
          binary_path: target/release/keychart
          icon_path: icon.icns
          release_files: target/release/KeyChart.app.zip
```

### Swift Project

```yaml
      - uses: whooof/macos-release-action@v1
        with:
          release_type: minor
          update_xcodeproj: true
          xcodeproj_path: MyApp.xcodeproj
          update_plist: true
          plist_path: MyApp/Info.plist
          create_bundle: false  # Xcode creates bundle
          create_release: true
          release_files: build/MyApp.app.zip
```

### Universal Binary

```yaml
      - uses: whooof/macos-release-action@v1
        with:
          release_type: patch
          create_bundle: true
          app_name: MyApp
          architecture: universal
          arm64_binary: target/aarch64-apple-darwin/release/myapp
          x86_64_binary: target/x86_64-apple-darwin/release/myapp
          binary_path: target/release/myapp  # Output path
```

### With Notarization

```yaml
      - uses: whooof/macos-release-action@v1
        with:
          release_type: patch
          create_bundle: true
          app_name: MyApp
          binary_path: target/release/myapp
          sign_bundle: true
          sign_identity: "Developer ID Application: My Name (TEAM_ID)"
          notarize: true
          apple_id: ${{ secrets.APPLE_ID }}
          team_id: ${{ secrets.TEAM_ID }}
          app_password: ${{ secrets.APP_PASSWORD }}
```

---

## Implementation Order

1. Scripts (Phase 1 + 2)
2. Individual actions (Phase 3)
3. Main action (Phase 4)
4. Documentation (Phase 5)
5. Tests (Phase 6)
6. Update KeyChart to use new action
