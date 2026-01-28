# Repository Guidelines

## Project Structure & Module Organization
- `Sources/` holds application code, grouped by domain: `App/`, `Features/`, `Services/`, `Models/`, and `Extensions/`.
- `Resources/` contains app assets and bundled resources.
- `Tests/` hosts XCTest-based unit tests.
- `Config/` stores `Info.plist` and entitlements.
- `project.yml` is the XcodeGen source of truth; `CaptureThis.xcodeproj` is generated.
- `Scripts/` contains packaging helpers (e.g., `package.sh`).
- `artifacts/` is the output directory for release bundles.
- `docs/` contains product/research notes.

## Build, Test, and Development Commands
Use `mise` tasks (see `.mise.toml`):
- `mise install` installs Swift, XcodeGen, SwiftLint, and SwiftFormat.
- `mise run generate` regenerates the Xcode project from `project.yml`.
- `mise run build` builds a Debug macOS app.
- `mise run test` runs unit tests.
- `mise run lint` runs SwiftLint and SwiftFormat in lint mode.
- `mise run format` auto-formats Swift sources.
- `mise run release-build` builds a Release app bundle.
- `mise run package` creates `.app.zip` and `.dmg` in `artifacts/`.

## Quality Gates
Always run and fix failures in `mise run lint`, `mise run test`, and `mise run build` for any change. If `project.yml` or build settings change, run `mise run generate` first to refresh `CaptureThis.xcodeproj`. Do not hand off work with red gates.

## Coding Style & Naming Conventions
- Swift code uses 2-space indentation and LF line endings (SwiftFormat).
- SwiftLint enforces a 120/160 line length (warning/error) and minimum identifier length of 2.
- Name test files `*Tests.swift` and test methods with `test...`.
- Keep new features scoped to existing folders (e.g., `Features/` for user flows).

## Testing Guidelines
- Tests are written with XCTest in `Tests/`.
- Run tests with `mise run test` before submitting changes.
- Add or update tests when touching behavior (especially in `Services/` and `Features/`).

## Commit & Pull Request Guidelines
Commits follow a Conventional style (`type(scope): summary`), for example `fix(ci): add missing settings`. Keep summaries imperative and under 72 characters, squash noisy WIPs, and include `project.yml`/`Config/` updates when required to build. PRs should describe user impact, list verification commands, link related issues, attach UI screenshots when visuals change, and call out entitlement/signing or `Info.plist` updates. Ensure `mise run lint`, `mise run test`, and `mise run build` succeed before requesting review.

## Security & Environment Notes
Never commit signing assets (`*.p12`, `*.mobileprovision`), API keys, or `.env*` files. Keep secrets out of `Config/Info.plist`, and update entitlements in `Config/CaptureThis.entitlements` only when adding capabilities.

## Code Search & Refactoring Tools
### Xcode Refactor vs ripgrep
**Use Xcode refactoring when structure matters.** It understands symbols and updates references without touching comments/strings.

- Refactors: rename types/functions, change initializer signatures, update protocol conformances.
- Safe API migrations across `Sources/`.

**Use `rg` when text is enough.** It is fastest for literals, TODOs, config values, or non-code assets.

**Rule of thumb:**
- Need correctness and you plan to change code → Xcode Refactor.
- Need raw speed or you are just hunting text → `rg`.

**Snippets:**

```bash
rg -n 'NSStatusItem' -t swift Sources
```

```bash
rg -n 'TODO|FIXME' -t swift
```

```bash
open CaptureThis.xcodeproj
```
