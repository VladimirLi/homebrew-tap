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
      # No Stillbreak app is ever deleted: a replaced or removed app goes to the Trash so it can be restored.
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

      # rename(2) via perl: a directory is never moved *into* an existing destination, and a destination that
      # is a non-empty directory, a file or a symlink makes it fail instead of being replaced. An *empty*
      # directory is replaced whenever rename(2) meets one (nothing is lost): at the destination only if it
      # appears after the up-front checks, since one already there is rejected, and at the generated Trash name
      # even if it predates the helper, because that path is never checked. `mv` would nest the
      # source inside an existing directory and still exit 0, so it is never used to place.
      place() { perl -e 'rename($ARGV[0], $ARGV[1]) or do { print STDERR "$!\\n"; exit 1 }' "$1" "$2"; }

      move_to_trash() {
        mkdir -p "$TRASH"
        trashed="$TRASH/Stillbreak-$(date +%Y%m%d-%H%M%S)-$$.app"
        # If a non-empty directory, file or symlink is already at $trashed, the move fails and $1 stays where
        # it was. An empty directory there is simply replaced by the backup.
        place "$1" "$trashed" 2>/dev/null ||
          fail "could not move $1 to the Trash at $trashed (something is already there, or the Trash is on another volume). $1 was left untouched."
        # Re-check what was actually moved: the destination may have changed since it was validated.
        if [ "$(bundle_id "$trashed")" != "$BUNDLE_ID" ]; then
          if place "$trashed" "$1" 2>/dev/null; then
            fail "$1 changed while it was being checked and is not a Stillbreak app. It was put back unchanged and nothing was installed."
          fi
          fail "$1 was not a Stillbreak app when it was moved. It is in the Trash at $trashed and $1 is occupied, so it was not put back. Restore it yourself if you still need it."
        fi
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

          # Copying takes a while: check again right before touching $DEST.
          refuse_if_running
          previous=
          if [ -e "$DEST" ] || [ -L "$DEST" ]; then
            refuse_unless_stillbreak "$DEST"
            move_to_trash "$DEST"
            previous="$trashed"
          fi
          if ! place "$stage/Stillbreak.app" "$DEST"; then
            if [ -z "$previous" ]; then
              fail "$DEST appeared while installing and was left untouched. Nothing was installed."
            fi
            if place "$previous" "$DEST"; then
              fail "$DEST was taken while installing; the previous Stillbreak was put back. Nothing was installed."
            fi
            fail "$DEST was taken while installing and the previous Stillbreak could not be put back. It is safe in the Trash at $previous. Nothing was installed."
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
      moved to the Trash, never deleted, and anything else already at that path (a different app, a
      file or any folder, even an empty one) is refused. If something other than an empty folder
      appears there mid-install, the helper stops and leaves it alone. When a failed install had
      already moved the previous copy to the Trash, the helper puts it back if the destination is
      free; if it cannot, it stays in the Trash and the helper prints its path. A successful upgrade
      also prints the previous copy's Trash path. An empty folder that appears at that moment is replaced.
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

    # Collisions: the destination changes after validation. Shims stand in for the other process.
    shim_count = 0
    shim = lambda do |name, body|
      dir = testpath/"shims-#{shim_count += 1}"
      dir.mkpath
      (dir/name).write("#!/bin/sh\n#{body}")
      chmod 0755, dir/name
      dir
    end
    scenario = lambda do |label|
      ENV["STILLBREAK_APPLICATIONS_DIR"] = apps = testpath/"Applications-#{label}"
      ENV["STILLBREAK_TRASH_DIR"] = trash = testpath/"Trash-#{label}"
      apps.mkpath
      [apps, trash]
    end
    bundle_id = lambda do |dir|
      shell_output("plutil -extract CFBundleIdentifier raw -o - #{dir}/Contents/Info.plist").strip
    end
    occupy = <<~SH
      mkdir -p "$STILLBREAK_APPLICATIONS_DIR/Stillbreak.app/Contents"
      echo foreign > "$STILLBREAK_APPLICATIONS_DIR/Stillbreak.app/Contents/marker"
    SH

    # 1. Fresh install: a foreign app appears while the copy is being staged. The re-check catches it.
    apps, trash = scenario.call("staging")
    shims = shim.call("ditto", "/usr/bin/ditto \"$@\" || exit 1\n#{occupy}")
    out = shell_output("PATH=#{shims}:$PATH #{helper} install 2>&1", 1)
    assert_match "is not a Stillbreak app", out
    assert_path_exists apps/"Stillbreak.app/Contents/marker"
    refute_path_exists apps/"Stillbreak.app/Stillbreak.app"
    assert_equal ["Stillbreak.app"], apps.children.map { |c| c.basename.to_s }
    refute_path_exists trash

    # 1b. Fresh install: a foreign app appears after every check, right before the final move.
    apps, trash = scenario.call("fresh")
    shims = shim.call("perl", "#{occupy}exec /usr/bin/perl \"$@\"\n")
    out = shell_output("PATH=#{shims}:$PATH #{helper} install 2>&1", 1)
    assert_match "appeared while installing", out
    assert_path_exists apps/"Stillbreak.app/Contents/marker"
    refute_path_exists apps/"Stillbreak.app/Stillbreak.app"
    assert_equal ["Stillbreak.app"], apps.children.map { |c| c.basename.to_s }
    refute_path_exists trash

    # 2. Upgrade: after the old app is moved to the Trash, a foreign app takes its place.
    apps, trash = scenario.call("upgrade")
    system helper, "install"
    after_trash = <<~SH
      /usr/bin/perl "$@" || exit 1
      case "$4" in "$STILLBREAK_TRASH_DIR"/*)
      #{occupy};; esac
    SH
    shims = shim.call("perl", after_trash)
    out = shell_output("PATH=#{shims}:$PATH #{helper} install 2>&1", 1)
    assert_match "could not be put back", out
    assert_match trash.to_s, out
    assert_equal 1, trash.children.count
    assert_equal "com.vladimirli.Stillbreak", bundle_id.call(trash.children.first)
    assert_path_exists apps/"Stillbreak.app/Contents/marker"
    refute_path_exists apps/"Stillbreak.app/Stillbreak.app"
    refute_path_exists apps/"Stillbreak.app/Contents/Info.plist"

    # 3. A foreign app swapped in right before the move to the Trash is put back untouched.
    apps, trash = scenario.call("swap")
    system helper, "install"
    swap = <<~SH
      case "$3" in "$STILLBREAK_APPLICATIONS_DIR"/Stillbreak.app)
        /bin/mv "$3" "$STILLBREAK_TRASH_DIR.side"
        mkdir -p "$3/Contents"
        plutil -create xml1 "$3/Contents/Info.plist"
        plutil -insert CFBundleIdentifier -string com.example.Other "$3/Contents/Info.plist";;
      esac
      exec /usr/bin/perl "$@"
    SH
    shims = shim.call("perl", swap)
    out = shell_output("PATH=#{shims}:$PATH #{helper} install 2>&1", 1)
    assert_match "changed while it was being checked", out
    assert_equal "com.example.Other", bundle_id.call(apps/"Stillbreak.app")
    assert_empty trash.children

    # 4. Something appears at the Trash destination right before the move (a directory, then a file).
    #    The move must fail without nesting the app inside it, and the installed app must stay put.
    #    (A non-empty directory is used: rename(2) does replace an empty one, covered in 5.)
    collisions = {
      "trashdir"  => "mkdir -p \"$4/inner\"",
      "trashfile" => "echo foreign > \"$4\"",
    }
    actions = %w[install uninstall]
    collisions.each do |label, create|
      actions.each do |action|
        apps, trash = scenario.call("#{label}-#{action}")
        system helper, "install"
        collide = <<~SH
          case "$4" in "$STILLBREAK_TRASH_DIR"/*) #{create};; esac
          exec /usr/bin/perl "$@"
        SH
        shims = shim.call("perl", collide)
        out = shell_output("PATH=#{shims}:$PATH #{helper} #{action} 2>&1", 1)
        assert_match "could not move", out
        assert_equal "com.vladimirli.Stillbreak", bundle_id.call(apps/"Stillbreak.app")
        assert_equal 1, trash.children.count
        collided = trash.children.first
        refute_path_exists collided/"Stillbreak.app"
        refute_path_exists collided/"inner/Stillbreak.app"
        assert_equal ["Stillbreak.app"], apps.children.map { |c| c.basename.to_s }
      end
    end

    # 5. An *empty* directory appearing at the Trash name or at the final destination is replaced by
    #    rename(2). That is the documented limit: nothing is lost and nothing is nested.
    apps, trash = scenario.call("emptytrash")
    system helper, "install"
    into_trash = <<~SH
      case "$4" in "$STILLBREAK_TRASH_DIR"/*) mkdir -p "$4";; esac
      exec /usr/bin/perl "$@"
    SH
    shims = shim.call("perl", into_trash)
    shell_output("PATH=#{shims}:$PATH #{helper} uninstall 2>&1")
    refute_path_exists apps/"Stillbreak.app"
    assert_equal 1, trash.children.count
    assert_equal "com.vladimirli.Stillbreak", bundle_id.call(trash.children.first)
    refute_path_exists trash.children.first/"Stillbreak.app"

    apps, trash = scenario.call("emptydest")
    shims = shim.call("perl", "mkdir -p \"$STILLBREAK_APPLICATIONS_DIR/Stillbreak.app\"\nexec /usr/bin/perl \"$@\"")
    shell_output("PATH=#{shims}:$PATH #{helper} install 2>&1")
    assert_equal "com.vladimirli.Stillbreak", bundle_id.call(apps/"Stillbreak.app")
    refute_path_exists apps/"Stillbreak.app/Stillbreak.app"
    assert_equal ["Stillbreak.app"], apps.children.map { |c| c.basename.to_s }
  end
end
