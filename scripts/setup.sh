#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

roc_version=2026-11-04-2622062
roc_sha256=48ad051270b4a6585b3a246ed4f1374cc521ddd1f98b7e11820c6077bcad3071
glue_sha256=0a50e80135ae27f8686f758897ae6214d4e793b2401e1fac3c35ff37e5b85515
pins=$(printf '%s\n' "$roc_version" "$roc_sha256" "$glue_sha256")

if [[ -x .tools/roc/roc && -f .tools/roc/RustGlue.roc && -f .tools/roc/pins ]] &&
    [[ $(<.tools/roc/pins) == "$pins" ]]; then
    exit 0
fi

mkdir -p .tools
tmp=$(mktemp -d .tools/setup.XXXXXX)
trap 'rm -rf "$tmp"' EXIT

curl -fL --retry 3 --connect-timeout 15 "https://github.com/roc-lang/nightlies/releases/download/nightly-$roc_version/roc_nightly-linux_x86_64-$roc_version.tar.gz" -o "$tmp/roc.tar.gz"
printf '%s  %s\n' "$roc_sha256" "$tmp/roc.tar.gz" | sha256sum -c -
mkdir "$tmp/roc"
tar -xzf "$tmp/roc.tar.gz" --strip-components=1 -C "$tmp/roc"

curl -fL --retry 3 --connect-timeout 15 "https://raw.githubusercontent.com/roc-lang/roc/${roc_version##*-}/src/glue/src/RustGlue.roc" -o "$tmp/roc/RustGlue.roc"
printf '%s  %s\n' "$glue_sha256" "$tmp/roc/RustGlue.roc" | sha256sum -c -

mkdir -p .tools/roc
rm -f .tools/roc/pins
mv "$tmp/roc/"* .tools/roc/
printf '%s\n' "$pins" > .tools/roc/pins
