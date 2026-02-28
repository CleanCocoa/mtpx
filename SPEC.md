# mtpx — MTP Transfer CLI

Command-line tool for transferring files to and from MTP devices, built on SwiftMTP.

## Usage

```
mtpx <source> <dest>
mtpx ls <remote-path>
mtpx device [list | add | remove | default]
```

Transfer direction is inferred from which argument is a remote path. A remote path is any path prefixed with a colon — either `@alias:/path` (explicit device) or `:/path` (device resolved automatically).

```
mtpx photo.jpg @phone:/DCIM/          # local → device
mtpx @phone:/DCIM/photo.jpg ./        # device → local
mtpx photo.jpg :/DCIM/                # local → device, device resolved
mtpx :/DCIM/photo.jpg ./              # device → local, device resolved
```

## Remote Path Syntax

A colon-prefixed path is a remote (device) path. The optional `@alias` before the colon selects a specific device:

```
@phone:/DCIM/photo.jpg      explicit device "phone", path /DCIM/photo.jpg
:/Documents/                resolved device, path /Documents/
```

The `@` prefix distinguishes device aliases from path components. Substrings of model names work as fuzzy matches (e.g., `@pixel` matches "Pixel 8" if unambiguous).

When no `@alias` is given, the device is resolved through the resolution chain below.

## Device Resolution

When a command needs a target device and none is specified explicitly, `mtpx` resolves it through this chain (first match wins):

1. **`MTPX_DEVICE` environment variable** — alias name or serial string
2. **Single connected device** — auto-selected, no config needed
3. **Default device** in config — the entry with `default = true`
4. **Interactive picker** — numbered list of connected devices; offers to save an alias (TTY only; errors in non-interactive contexts)

The resolved device is always printed to stderr so the user knows which device was selected.

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

### `mtpx <source> <dest>`

Transfer a file or directory. Exactly one of `<source>` or `<dest>` must be a remote path (colon-prefixed). Creates intermediate directories on the device as needed.

```
mtpx photo.jpg @phone:/DCIM/
mtpx ./docs/ @tablet:/Documents/sync/
mtpx @phone:/DCIM/photo.jpg ./
mtpx @supernote:/Document/notes/ ./backup/
mtpx :/DCIM/photo.jpg ./
```

### `mtpx ls <remote-path>`

List files and directories at the given path on the device.

```
mtpx ls @phone:/
mtpx ls :/Documents/
```

### `mtpx device`

Manage device aliases.

| Subcommand | Description |
|------------|-------------|
| `list` (default) | Show saved aliases and their connection status |
| `add <alias>` | Interactively save the connected device as `<alias>` |
| `remove <alias>` | Delete a saved alias |
| `default` | Show the current default device |
| `default set <alias>` | Set a device as the default |
| `default clear` | Remove the default device setting |

## Roadmap

### 0.1.0 — Foundation

- [ ] `device list` — enumerate connected MTP devices
- [ ] `device add` — save alias interactively
- [ ] Config file read/write (TOML, XDG path)
- [ ] Device resolution chain (all 4 tiers)
- [ ] `ls` — list remote directory contents

### 0.2.0 — Transfers

- [ ] Single file transfer with progress
- [ ] Directory transfer (recursive)
- [ ] Create intermediate remote directories

### 0.3.0 — Polish

- [ ] Shell completions (zsh, bash, fish) via ArgumentParser
- [ ] Fuzzy model-name matching for `@` aliases
- [ ] `device remove`, `device default set`, `device default clear`
- [ ] Exit codes and structured error messages

### Future

- Sync mode (transfer only changed files)
- Watch mode (transfer on local file change)
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
        Transfer.swift
        Ls.swift
        Device.swift
      Device/
        DeviceAlias.swift      — Codable alias model
        DeviceConfig.swift     — reads/writes config.toml
        DeviceResolver.swift   — resolution chain
      Interactive/
        DevicePicker.swift     — terminal numbered-list picker
```

`mtpx` is a standalone Swift package that depends on SwiftMTP via `https://codeberg.org/ctietze/swift-mtp`.
