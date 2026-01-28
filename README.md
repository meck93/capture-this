# CaptureThis

Menu bar–only macOS screen recorder (V1 scaffold).

## Requirements

- macOS 15+
- Xcode + Command Line Tools
- [mise](https://mise.jdx.dev) for tool management

## Getting started

```bash
mise install
mise run generate
```

## Common commands

```bash
mise run build
mise run test
mise run lint
mise run format
```

## Release artifacts (local)

```bash
mise run generate
mise run release-build
mise run package
```

Artifacts are written to `artifacts/`.
## Quick smoke checklist

- Permissions: toggle Camera/Microphone on and start a recording; verify system permission prompts appear.
- Cancel flow: during countdown press Escape; during picker press Cancel; during recording press Escape to discard.
- Notifications: after finishing a recording, confirm the system notification appears and actions work.
