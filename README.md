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
An existing `/Applications/Stillbreak.app` is moved to the Trash (never deleted) before the swap. Both that move and the
final placement use `rename(2)`, which refuses to replace a non-empty folder, a file or a symlink and never nests the app
inside one. It refuses to start if anything already at `/Applications/Stillbreak.app` is not Stillbreak (bundle id
`com.vladimirli.Stillbreak`), including an empty folder, or if Stillbreak is running. If something other than an empty
folder appears at the destination during the install, the helper stops and leaves it alone. On an upgrade it then puts
the previous Stillbreak back only if the destination is free; otherwise the previous copy stays in the Trash and the
helper prints its exact path. On a fresh install, or if a collision at the app destination is caught before the old app is moved, no previous-copy
path is printed because nothing was moved. If the move to the Trash itself fails, the old app stays in `/Applications`;
the error names the Trash path it tried, but nothing was placed there. A successful upgrade also prints the previous copy's Trash path. An empty folder is replaced whenever `rename(2)` meets one: at the
destination, if it appears after the up-front checks (one already there is rejected), and at the generated Trash name,
even if it was there before (the helper does not check that path). Nothing is lost in either case. The checks are
repeated just before the swap, but they are best-effort, not a lock: another process changing `/Applications` at that
exact moment can still cause a safe failure rather than an install. Then open Stillbreak from `/Applications`.

Upgrade: `brew reinstall VladimirLi/tap/stillbreak`, then `stillbreak-app install` again.

Uninstall: quit Stillbreak, turn off "Launch at login" in its Settings, run `stillbreak-app uninstall` (moves the app to
the Trash), then `brew uninstall VladimirLi/tap/stillbreak`. Run the helper first: it is removed with the formula. Then
check System Settings > General > Login Items & Extensions for a leftover Stillbreak entry.

The formula is HEAD-only for now. A stable version will be added once Stillbreak has a tagged release.
