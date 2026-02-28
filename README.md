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

## Development

```
git config core.hooksPath .githooks
```

Built on [SwiftMTP](https://codeberg.org/ctietze/swift-mtp).
