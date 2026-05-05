#!/usr/bin/env bash
set -euo pipefail

: "${VERSION:?VERSION env var required}"
: "${SHA256:?SHA256 env var required}"
: "${HOMEBREW_TAP_GITHUB_TOKEN:?HOMEBREW_TAP_GITHUB_TOKEN env var required}"

TAP_DIR=$(mktemp -d)
trap 'rm -rf "$TAP_DIR"' EXIT

git clone --depth=1 \
  "https://x-access-token:${HOMEBREW_TAP_GITHUB_TOKEN}@github.com/nilBora/homebrew-apps.git" \
  "$TAP_DIR"

mkdir -p "$TAP_DIR/Casks"
cat > "$TAP_DIR/Casks/Screeny.rb" <<EOF
cask "Screeny" do
  version "${VERSION}"
  sha256 "${SHA256}"

  url "https://github.com/nilBora/Screeny/releases/download/v#{version}/Screeny-#{version}.dmg"
  name "Screeny"
  desc "A minimal macOS menu bar app for instant screenshot capture and annotation."
  homepage "https://github.com/nilBora/Screeny"

  depends_on macos: ">= :ventura"

  app "Screeny.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-d", "-r", "com.apple.quarantine", "#{appdir}/Screeny.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Preferences/com.Screeny.app.plist",
    "~/Library/Caches/com.Screeny.app",
  ]
end
EOF

cd "$TAP_DIR"
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add Casks/Screeny.rb
git commit -m "Screeny ${VERSION}"
git push origin HEAD
