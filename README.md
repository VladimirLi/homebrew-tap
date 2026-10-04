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

Homebrew cannot write to `/Applications`, so copy the built app there yourself (launch at login can fail from any other
location):

```sh
rm -rf /Applications/Stillbreak.app
ditto "$(brew --prefix stillbreak)/Stillbreak.app" /Applications/Stillbreak.app
```

Then open Stillbreak from `/Applications`.

Upgrade: `brew reinstall VladimirLi/tap/stillbreak`, then repeat the two commands above.

Uninstall: quit Stillbreak, turn off "Launch at login" in its Settings, run `rm -rf /Applications/Stillbreak.app` and
`brew uninstall VladimirLi/tap/stillbreak`, then check System Settings > General > Login Items & Extensions for a
leftover Stillbreak entry.

The formula is HEAD-only for now. A stable version will be added once Stillbreak has a tagged release.
