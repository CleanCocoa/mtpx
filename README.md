# mtpx

Transfer files to and from MTP devices (Android phones, e-readers, DAPs) from the terminal.

## Install

```
brew install libmtp
mint install codeberg.org/ctietze/mtpx
```

## Quick Start

Add your device interactively:

```
$ mtpx device add
Connected devices:

  1. Samsung Galaxy S24
  2. Boox Tab Ultra

Select device (1-2): 1
Alias: phone
Saved alias 'phone'.
```

Then transfer files using `@alias:/path` syntax:

```
mtpx photo.jpg @phone:/DCIM/
mtpx @phone:/DCIM/photo.jpg ./
```

The colon separates the device alias from the remote path. Without an alias, mtpx auto-selects when only one device is connected:

```
mtpx photo.jpg :/DCIM/
```

## Tab Completion

Enable shell completions for remote MTP paths:

```
# zsh
mtpx --generate-completion-script zsh > ~/.zsh/completions/_mtpx

# bash
mtpx --generate-completion-script bash > /usr/local/etc/bash_completion.d/mtpx

# fish
mtpx --generate-completion-script fish > ~/.config/fish/completions/mtpx.fish
```

Then tab through remote directories just like local files:

```
mtpx ls @phone:/DCIM/<TAB>
# → Camera/  Screenshots/  ...

mtpx @phone:/DCIM/Camera/<TAB> ./
# → IMG_001.jpg  IMG_002.jpg  ...
```

Completions are cached for 30 seconds so rapid tabs stay responsive.

## Commands

### transfer (default)

```
mtpx <source> <destination>
mtpx -r <source> <destination>    # recursive for directories
```

Direction is inferred: whichever argument has a colon prefix is the remote side.

### sync

```
mtpx sync @phone:/DCIM/ ./backup/      # download only changed files
mtpx sync --dry-run @sn:/Note/ ./notes/ # preview what would download
```

Compares remote files against the local copy by size and modification date. Only files that are new or have changed on the device are downloaded — unchanged files are skipped.

### ls

```
mtpx ls @phone:/DCIM/
```

### device

```
mtpx device list                  # show aliases and connected devices
mtpx device add [name]            # interactive setup (name prompted if omitted)
mtpx device remove <name>
mtpx device default <name>        # set default for multi-device setups
mtpx device default --clear
```

## Device Aliases

Aliases map a short name to a specific device by serial number. This avoids ambiguity when multiple devices are connected and gives you a stable name for scripts and tab completion.

When no `@alias` is given, mtpx resolves the device through this chain:

1. `MTPX_DEVICE` environment variable
2. Single connected device (auto-selected)
3. Default device from config
4. Interactive picker (TTY only)

Config lives at `~/.config/mtpx/config.toml`:

```toml
default = "phone"

[aliases.phone]
serial = "ABC123DEF456"

[aliases.tablet]
vendor = "Boox"
product = "Tab Ultra"
bus = 2
```

## Example: Supernote Workflows

Set up your Supernote once:

```
$ mtpx device add
Found Ratta Supernote
Alias: sn
Saved alias 'sn'.
```

Push a book to read:

```
mtpx book.pdf @sn:/Document/
mtpx book.epub @sn:/Document/Books/
```

Pull your notes:

```
mtpx @sn:/Note/meeting.note ./
mtpx -r @sn:/Note/ ./notes-backup/
```

### Syncing Only Changed Notes

Use `sync` to keep a local mirror of your notes without re-downloading everything each time. Only files that are new or modified on the Supernote are transferred:

```
mtpx sync @sn:/Note/ ./notes-backup/
```

Preview what would be downloaded before transferring:

```
mtpx sync --dry-run @sn:/Note/ ./notes-backup/
```

This compares each remote file's size and modification date against the local copy. Unchanged files are skipped, so repeated syncs are fast even for large note collections.

Browse what's on the device:

```
mtpx ls @sn:/
mtpx ls @sn:/Document/
mtpx ls @sn:/EXPORT/
```

## Development

```
git config core.hooksPath .githooks
```

Built on [SwiftMTP](https://codeberg.org/ctietze/swift-mtp).
