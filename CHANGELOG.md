# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.0] - 2026-03-01

### Added

- GitHub Actions CI (macOS 26 + Linux via swift:6.2-noble)
- Linux build support (swift-mtp 0.11.0)

## [0.5.0] - 2026-02-28

### Added

- `sync` command to download only changed files from a device directory
- `--dry-run` / `-n` flag to preview sync without transferring

## [0.4.0] - 2026-02-28

### Added

- `device list` shows connected devices alongside saved aliases
- `device add` is fully interactive when run without arguments
- Config file location shown in `--help` banner

### Changed

- `device add` alias name is now optional (prompted interactively)

## [0.1.0] - 2026-02-28

### Added

- Transfer command for MTP file operations (push/pull with progress output)
- `ls` command for listing remote MTP directory contents
- Device management commands: `list`, `add`, `remove`, `default`
- Device resolution with 4-tier fallback and interactive picker
- Configuration system and remote path parsing
- Swift package with editor and format config
- Pre-commit hook for swift-format lint

### Fixed

- Deduplicate progress output and show filename during transfers

[0.6.0]: https://codeberg.org/ctietze/mtpx/releases/tag/0.6.0
[0.5.0]: https://codeberg.org/ctietze/mtpx/releases/tag/0.5.0
[0.4.0]: https://codeberg.org/ctietze/mtpx/releases/tag/0.4.0
[0.1.0]: https://codeberg.org/ctietze/mtpx/releases/tag/0.1.0
