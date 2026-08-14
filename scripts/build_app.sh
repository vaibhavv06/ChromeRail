#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
destination=${1:-"${project_dir}/dist/ChromeRail.app"}
export CLANG_MODULE_CACHE_PATH=/private/tmp/chromerail-clang-cache
export SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/chromerail-swift-cache

swift build --disable-sandbox --package-path "$project_dir" -c release --product ChromeRail
binary_path=$(swift build --disable-sandbox --package-path "$project_dir" -c release --show-bin-path)/ChromeRail

mkdir -p "$destination/Contents/MacOS" "$destination/Contents/Resources"
cp "$binary_path" "$destination/Contents/MacOS/ChromeRail"
cp "$project_dir/Resources/Info.plist" "$destination/Contents/Info.plist"
codesign --force --deep --sign - "$destination"
codesign --verify --deep --strict --verbose=2 "$destination"
echo "$destination"
