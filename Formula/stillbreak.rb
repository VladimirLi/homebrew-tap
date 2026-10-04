class Stillbreak < Formula
  desc "Menu-bar break reminder for macOS driven by real input activity"
  homepage "https://github.com/VladimirLi/Stillbreak"
  license "MIT"
  head "https://github.com/VladimirLi/Stillbreak.git", branch: "main"

  depends_on :macos
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
  end

  def caveats
    <<~EOS
      Homebrew cannot write to /Applications. Quit Stillbreak if it is running, then copy the app there
      (launch at login can fail when the app runs from anywhere else, including this keg):

        rm -rf /Applications/Stillbreak.app
        ditto #{opt_prefix}/Stillbreak.app /Applications/Stillbreak.app

      Then open it from /Applications. It lives in the menu bar and has no Dock icon.

      To upgrade, rebuild and copy again:

        brew reinstall --HEAD stillbreak
        rm -rf /Applications/Stillbreak.app
        ditto #{opt_prefix}/Stillbreak.app /Applications/Stillbreak.app

      To uninstall, quit Stillbreak, turn off "Launch at login" in its Settings, then:

        rm -rf /Applications/Stillbreak.app
        brew uninstall stillbreak

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
  end
end
