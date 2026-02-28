# mtpx — MTP Transfer CLI

Command-line tool for transferring files to and from MTP devices, built on SwiftMTP.

## Usage

```
mtpx upload <local-path> [<device>:]<remote-path>
mtpx pull <device>:<remote-path> <local-path>
mtpx ls [<device>:]<remote-path>
mtpx devices [list | add | remove | default]
```

## Device Resolution

When a command needs a target device, `mtpx` resolves it through this chain (first match wins):

1. **Explicit `@alias`** in the command — `mtpx upload file.txt @phone:/Documents/`
2. **`MTPX_DEVICE` environment variable** — alias name or serial string
3. **Single connected device** — auto-selected, no config needed
4. **Default device** in config — the entry with `default = true`
5. **Interactive picker** — numbered list of connected devices; offers to save an alias

The `@` prefix distinguishes device aliases from file paths. Substrings of model names also work as fuzzy matches (e.g., `@pixel` matches "Pixel 8" if unambiguous).

## Device Identification

Devices are identified using a two-tier scheme matching the SwiftMTP `DeviceID` type:

- **Serial** — preferred; a string reported by the device over MTP.
- **Fallback triple** — `(vendor, product, bus)` for devices that don't report serial numbers (common with e-readers). The `bus` component is USB-port-dependent, so the fallback is less stable across reconnections to different ports.

When saving a device alias, `mtpx` records whichever identifier the device provides, preferring serial.

## Configuration

Config file location follows XDG: `$XDG_CONFIG_HOME/mtpx/config.toml`, defaulting to `~/.config/mtpx/config.toml`.

### Format

```toml
[devices.phone]
serial = "ABC123"
model = "Galaxy S24"
default = true

[devices.tablet]
serial = "DEF456"
model = "Pixel Tablet"

[devices.supernote]
vendor = 0x2207
product = 0x0011
bus = 3
model = "Supernote A5X"
```

Each device entry is keyed by its alias name and contains:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `serial` | String | if no fallback | MTP serial number |
| `vendor` | Integer (hex) | if no serial | USB vendor ID |
| `product` | Integer (hex) | if no serial | USB product ID |
| `bus` | Integer | if no serial | USB bus location |
| `model` | String | no | Human-readable model name (informational) |
| `default` | Boolean | no | Use as default when no device specified |

A device entry must have either `serial` or the full `(vendor, product, bus)` triple. At most one device may have `default = true`.

### Environment Variables

| Variable | Description |
|----------|-------------|
| `MTPX_DEVICE` | Device alias name or serial string |
| `XDG_CONFIG_HOME` | Override config directory (default: `~/.config`) |

## Commands

### `mtpx upload <local-path> [<device>:]<remote-path>`

Upload a local file or directory to the device. Creates intermediate directories on the device as needed.

```
mtpx upload photo.jpg @phone:/DCIM/
mtpx upload ./docs/ @tablet:/Documents/sync/
```

### `mtpx pull [<device>:]<remote-path> <local-path>`

Download a file or directory from the device to the local filesystem.

```
mtpx pull @phone:/DCIM/photo.jpg ./
mtpx pull @supernote:/Document/notes/ ./backup/
```

### `mtpx ls [<device>:]<remote-path>`

List files and directories at the given path on the device.

```
mtpx ls @phone:/
mtpx ls /Documents/
```

### `mtpx devices`

Manage device aliases.

| Subcommand | Description |
|------------|-------------|
| `list` (default) | Show saved aliases and their connection status |
| `add <alias>` | Interactively save the connected device as `<alias>` |
| `remove <alias>` | Delete a saved alias |
| `default <alias>` | Set a device as the default |

## Subcommands — Roadmap

### v0.1 — Foundation

- [ ] `devices list` — enumerate connected MTP devices
- [ ] `devices add` — save alias interactively
- [ ] Config file read/write (TOML, XDG path)
- [ ] Device resolution chain (all 5 tiers)
- [ ] `ls` — list remote directory contents

### v0.2 — Transfers

- [ ] `upload` — single file upload with progress
- [ ] `pull` — single file download with progress
- [ ] Directory upload/download (recursive)
- [ ] Create intermediate remote directories

### v0.3 — Polish

- [ ] Shell completions (zsh, bash, fish) via ArgumentParser
- [ ] Fuzzy model-name matching for `@` aliases
- [ ] `devices remove`, `devices default`
- [ ] Exit codes and structured error messages

### Future

- Sync mode (upload only changed files)
- Watch mode (upload on local file change)
- Color output and progress bars

## Dependencies

| Package | Use |
|---------|-----|
| [SwiftMTP](https://codeberg.org/ctietze/swift-mtp) | MTP device access |
| [swift-argument-parser](https://github.com/apple/swift-argument-parser) | CLI argument parsing, subcommands, shell completions |
| [TOMLKit](https://github.com/LebJe/TOMLKit) | TOML config parsing |

## Project Structure

```
mtpx/
  Package.swift
  Sources/
    mtpx/
      Mtpx.swift              — @main AsyncParsableCommand
      Commands/
        Upload.swift
        Pull.swift
        Ls.swift
        Devices.swift
      Device/
        DeviceAlias.swift      — Codable alias model
        DeviceConfig.swift     — reads/writes config.toml
        DeviceResolver.swift   — resolution chain
      Interactive/
        DevicePicker.swift     — terminal numbered-list picker
```

`mtpx` is a standalone Swift package that depends on SwiftMTP via `https://codeberg.org/ctietze/swift-mtp`.
