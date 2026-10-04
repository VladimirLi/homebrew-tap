class Stillbreak < Formula
  desc "Menu-bar break reminder for macOS driven by real input activity"
  homepage "https://github.com/VladimirLi/Stillbreak"
  license "MIT"
  head "https://github.com/VladimirLi/Stillbreak.git", branch: "main"

  depends_on macos: :sonoma

  def install
    # Not `depends_on xcode:`: that requires Xcode.app, and the Command Line
    # Tools alone are enough to build this package.
    swift = which("swift")
    odie "Swift 6.3+ is required. Install the Command Line Tools (xcode-select --install) or Xcode." if swift.nil?

    swift_version = Utils.safe_popen_read(swift, "--version")[/Swift version (\d+(?:\.\d+)*)/, 1]
    if swift_version.nil? || Version.new(swift_version) < Version.new("6.3")
      odie "Swift 6.3+ is required to build Stillbreak, found #{swift_version || "an unknown version"}. " \
           "Update the Command Line Tools (softwareupdate) or Xcode."
    end

    system "scripts/package-app.sh"
    prefix.install ".build/Stillbreak.app"

    (bin/"stillbreak-app").write <<~SH
      #!/bin/sh
      # Copies the built Stillbreak.app into /Applications, or moves that copy to the Trash.
      # Nothing is ever deleted: a replaced or removed app goes to the Trash so it can be restored.
      set -eu

      SRC="#{opt_prefix}/Stillbreak.app"
      APPS="${STILLBREAK_APPLICATIONS_DIR:-/Applications}"
      TRASH="${STILLBREAK_TRASH_DIR:-$HOME/.Trash}"
      PROCESS="${STILLBREAK_PROCESS_NAME:-Stillbreak}"
      DEST="$APPS/Stillbreak.app"
      BUNDLE_ID=com.vladimirli.Stillbreak

      fail() { echo "stillbreak-app: $*" >&2; exit 1; }

      bundle_id() { plutil -extract CFBundleIdentifier raw -o - "$1/Contents/Info.plist" 2>/dev/null || true; }

      refuse_if_running() {
        if pgrep -x "$PROCESS" >/dev/null 2>&1; then
          fail "Stillbreak is running. Quit it (menu bar icon > Quit) and run this again."
        fi
      }

      refuse_unless_stillbreak() {
        [ "$(bundle_id "$1")" = "$BUNDLE_ID" ] ||
          fail "$1 is not a Stillbreak app ($BUNDLE_ID). Leaving it alone; move it away yourself if you want it replaced."
      }

      move_to_trash() {
        mkdir -p "$TRASH"
        trashed="$TRASH/Stillbreak-$(date +%Y%m%d-%H%M%S)-$$.app"
        [ ! -e "$trashed" ] || fail "$trashed already exists."
        mv "$1" "$trashed"
      }

      case "${1:-}" in
        install)
          [ -d "$SRC" ] || fail "$SRC not found. Run: brew reinstall VladimirLi/tap/stillbreak"
          [ "$(bundle_id "$SRC")" = "$BUNDLE_ID" ] || fail "$SRC is not a Stillbreak app."
          codesign --verify --deep --strict "$SRC" || fail "$SRC failed signature verification."
          [ -d "$APPS" ] && [ -w "$APPS" ] || fail "$APPS is not a writable directory."
          if [ -e "$DEST" ] || [ -L "$DEST" ]; then
            refuse_unless_stillbreak "$DEST"
          fi
          refuse_if_running

          stage=$(mktemp -d "$APPS/.Stillbreak-stage.XXXXXX") || fail "cannot create a staging directory in $APPS."
          trap 'rm -rf "$stage"' EXIT
          ditto "$SRC" "$stage/Stillbreak.app"
          codesign --verify --deep --strict "$stage/Stillbreak.app" || fail "the staged copy failed signature verification; $DEST was not touched."

          previous=
          if [ -e "$DEST" ] || [ -L "$DEST" ]; then
            move_to_trash "$DEST"
            previous="$trashed"
          fi
          if ! mv "$stage/Stillbreak.app" "$DEST"; then
            [ -z "$previous" ] || mv "$previous" "$DEST"
            fail "could not place the new app; the previous one was restored."
          fi
          echo "Installed $DEST."
          [ -z "$previous" ] || echo "The previous copy is in the Trash: $previous"
          echo "Open it from /Applications. It lives in the menu bar and has no Dock icon."
          ;;
        uninstall)
          if [ ! -e "$DEST" ] && [ ! -L "$DEST" ]; then
            echo "Nothing to remove: $DEST does not exist."
            exit 0
          fi
          refuse_unless_stillbreak "$DEST"
          refuse_if_running
          move_to_trash "$DEST"
          echo "Moved $DEST to the Trash: $trashed"
          ;;
        *)
          echo "usage: stillbreak-app install | uninstall" >&2
          exit 2
          ;;
      esac
    SH
    chmod 0555, bin/"stillbreak-app"
  end

  def caveats
    <<~EOS
      This formula builds Stillbreak into its keg and does not manage /Applications itself. Launch at
      login can fail when the app runs from anywhere else, so copy it there with the helper. Quit
      Stillbreak first if it is running:

        stillbreak-app install

      The copy is verified before anything is replaced. An existing /Applications/Stillbreak.app is
      moved to the Trash, never deleted, and a different app with that name is left alone.
      Then open Stillbreak from /Applications. It lives in the menu bar and has no Dock icon.

      To upgrade, rebuild and copy again:

        brew reinstall VladimirLi/tap/stillbreak
        stillbreak-app install

      To uninstall, quit Stillbreak, turn off "Launch at login" in its Settings, then (the helper is
      removed with the formula, so run it first):

        stillbreak-app uninstall
        brew uninstall VladimirLi/tap/stillbreak

      Check System Settings > General > Login Items & Extensions afterwards and remove any
      leftover Stillbreak entry.
    EOS
  end

  test do
    app = prefix/"Stillbreak.app"
    assert_equal "com.vladimirli.Stillbreak",
                 shell_output("plutil -extract CFBundleIdentifier raw -o - #{app}/Contents/Info.plist").strip
    assert_equal "true",
                 shell_output("plutil -extract LSUIElement raw -o - #{app}/Contents/Info.plist").strip
    system "codesign", "--verify", "--deep", "--strict", app

    # Exercise the install helper against scratch directories, never the real /Applications.
    ENV["STILLBREAK_APPLICATIONS_DIR"] = apps = testpath/"Applications"
    ENV["STILLBREAK_TRASH_DIR"] = trash = testpath/"Trash"
    ENV["STILLBREAK_PROCESS_NAME"] = "stillbreak-test-no-such-process"
    apps.mkpath
    helper = bin/"stillbreak-app"

    system helper, "install"
    system "codesign", "--verify", "--deep", "--strict", apps/"Stillbreak.app"

    system helper, "install"
    assert_equal 1, trash.children.count

    (apps/"Stillbreak.app/Contents/Info.plist").unlink
    assert_match "is not a Stillbreak app", shell_output("#{helper} install 2>&1", 1)
    assert_match "is not a Stillbreak app", shell_output("#{helper} uninstall 2>&1", 1)
    assert_path_exists apps/"Stillbreak.app"
    rm_r apps/"Stillbreak.app"

    system helper, "install"
    system helper, "uninstall"
    refute_path_exists apps/"Stillbreak.app"
    assert_equal 2, trash.children.count
  end
end
