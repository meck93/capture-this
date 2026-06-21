# Homebrew Release Process

CaptureThis can be distributed through a personal Homebrew tap as a cask. The cask installs the release DMG and removes the quarantine extended attribute after installation so Homebrew users do not see the Gatekeeper quarantine warning on first launch.

This does not bypass or pre-grant macOS TCC prompts. Screen Recording, Camera, and Microphone prompts still appear normally when the app requests those permissions.

## Repositories

- App repository: `meck93/capture-this`
- Tap repository: `meck93/homebrew-tap`
- Cask path in the tap repository: `Casks/capture-this.rb`

Homebrew users install with:

```bash
brew install --cask meck93/tap/capture-this
```

## GitHub App Credentials

The `Release` workflow updates the tap with a short-lived GitHub App installation token. Configure these in `meck93/capture-this`:

- Repository variable: `HOMEBREW_TAP_APP_CLIENT_ID`
- Repository secret: `HOMEBREW_TAP_APP_PRIVATE_KEY`

The GitHub App must be installed on `meck93/homebrew-tap` with `contents:write` permission. The default `GITHUB_TOKEN` for `meck93/capture-this` cannot push to the separate tap repository.

## Automated Release Steps

Release by pushing a semver-style tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

Or run the `Release` workflow manually from GitHub Actions with:

```text
version = 0.1.0
```

The release workflow will:

1. Generate the Xcode project.
2. Run lint and tests.
3. Build the release app.
4. Package `artifacts/CaptureThis.app.zip` and `artifacts/CaptureThis.dmg`.
5. Create or update the GitHub release for `v0.1.0`.
6. Calculate the SHA-256 for `artifacts/CaptureThis.dmg`.
7. Create a GitHub App installation token for `meck93/homebrew-tap`.
8. Clone `meck93/homebrew-tap`.
9. Copy `Casks/capture-this.rb` from this repository into the tap.
10. Update `Casks/capture-this.rb` with the release version and DMG checksum.
11. Run `brew audit --cask --new Casks/capture-this.rb`.
12. Commit and push the tap update.

The first successful release creates `Casks/capture-this.rb` in the tap if it does not exist yet.

## Local Cask Template

The source cask template lives at `Casks/capture-this.rb` in this repository. Its checked-in version intentionally uses:

```ruby
sha256 "REPLACE_WITH_DMG_SHA256"
```

The release workflow replaces both `version` and `sha256` before committing the cask to `meck93/homebrew-tap`.

## Manual Tap Update

The workflow normally handles the tap update. If you need to do it manually, first build and package the release:

```bash
mise run generate
mise run lint
mise run test
mise run build
mise run release-build
mise run package
```

Create or update the matching GitHub release:

```bash
git tag v0.1.0
git push origin v0.1.0
gh release create v0.1.0 artifacts/CaptureThis.dmg artifacts/CaptureThis.app.zip \
  --title "CaptureThis 0.1.0"
```

Compute the DMG checksum:

```bash
shasum -a 256 artifacts/CaptureThis.dmg
```

Then update the tap cask:

```bash
git clone git@github.com:meck93/homebrew-tap.git
cd homebrew-tap
mkdir -p Casks
cp /path/to/capture-this/Casks/capture-this.rb Casks/capture-this.rb
```

Set the release values:

```ruby
version "0.1.0"
sha256 "DMG_SHA256_FROM_SHASUM"
```

Validate and push:

```bash
brew audit --cask --new Casks/capture-this.rb
git add Casks/capture-this.rb
git commit -m "chore: update CaptureThis to 0.1.0"
git push
```

After the tap update lands, verify installation with:

```bash
brew install --cask --verbose meck93/tap/capture-this
brew uninstall --cask capture-this
```

## Quarantine Handling

The cask includes:

```ruby
postflight do
  system_command "/usr/bin/xattr",
                 args: ["-dr", "com.apple.quarantine", "#{appdir}/CaptureThis.app"],
                 sudo: false
end
```

This is intentionally scoped to Homebrew installs. Direct downloads from GitHub releases should be notarized if they need the same no-warning first-launch experience.
