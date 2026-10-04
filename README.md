# homebrew-tap

Homebrew tap for VladimirLi's apps.

## Stillbreak

[Stillbreak](https://github.com/VladimirLi/Stillbreak) is a menu-bar break reminder for macOS. The formula builds it
from source on your Mac from the latest `main`. It takes a few minutes and needs macOS 14 (Sonoma) or newer and Swift
6.3+ (the Xcode or Command Line Tools). A locally built app is not quarantined, so it opens without the first-launch
"could not verify" warning.

```sh
brew tap VladimirLi/tap
brew install --HEAD VladimirLi/tap/stillbreak
```

Use the qualified name. Homebrew 7 does not load formulae from an untrusted third-party tap, so the short form
`brew install --HEAD stillbreak` fails until you run `brew trust --formula VladimirLi/tap/stillbreak`.

The formula builds the app into its own keg and does not manage `/Applications`. Launch at login can fail from any
other location, so it installs a helper, `stillbreak-app`, that puts a copy there. Quit Stillbreak first if it is running:

```sh
stillbreak-app install
```

The helper verifies the app's signature, copies it to a staging folder in `/Applications`, and only then swaps it in.
An existing `/Applications/Stillbreak.app` is moved to the Trash (never deleted) and restored if the swap fails. If an
app with that name is not Stillbreak (bundle id `com.vladimirli.Stillbreak`), or Stillbreak is running, it stops and
changes nothing. Then open Stillbreak from `/Applications`.

Upgrade: `brew reinstall VladimirLi/tap/stillbreak`, then `stillbreak-app install` again.

Uninstall: quit Stillbreak, turn off "Launch at login" in its Settings, run `stillbreak-app uninstall` (moves the app to
the Trash), then `brew uninstall VladimirLi/tap/stillbreak`. Run the helper first: it is removed with the formula. Then
check System Settings > General > Login Items & Extensions for a leftover Stillbreak entry.

The formula is HEAD-only for now. A stable version will be added once Stillbreak has a tagged release.
