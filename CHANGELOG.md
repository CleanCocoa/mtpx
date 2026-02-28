# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.0]: https://github.com/ctm/mtpx/releases/tag/0.1.0
