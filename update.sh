#!/bin/bash
# Update pinned Claude packages from Anthropic's stable APT indexes.
set -euo pipefail
export LC_ALL=C
cd "$(dirname "$0")"

REPOSITORY="https://downloads.claude.ai/claude-desktop/apt/stable"
MANIFEST="com.anthropic.Claude.yml"
METAINFO="com.anthropic.Claude.metainfo.xml"

fail() {
    echo "Update failed: $*" >&2
    exit 1
}

report() {
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        printf 'updated=%s\nclaude=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"
    fi
}

task_tmp=$(mktemp -d)
trap 'rm -rf "$task_tmp"' EXIT

# Match each pinned URL together with its SHA-256 line.
source_pattern='([[:blank:]]+url: https://downloads[.]claude[.]ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_)([0-9]+([.][0-9]+)+)_(amd64|arm64)[.]deb'
sed -nE "\@^${source_pattern}\$@ {
    N
    s@^${source_pattern}\n[[:blank:]]+sha256: ([0-9a-f]{64})\$@\2 \4 \5@p
}" "$MANIFEST" > "$task_tmp/pins"
mapfile -t pins < "$task_tmp/pins"
[[ ${#pins[@]} == 2 ]] || fail "Expected exactly one pinned Debian source per architecture"
read -r current first_arch _ <<< "${pins[0]}"
read -r other_version second_arch _ <<< "${pins[1]}"
[[ "$first_arch" != "$second_arch" ]] || fail "Duplicate pinned architecture"
[[ "$current" == "$other_version" ]] || fail "Pinned package versions disagree between architectures"

for arch in amd64 arm64; do
    curl --fail --silent --show-error --location --retry 3 --max-time 60 \
        "$REPOSITORY/dists/stable/main/binary-$arch/Packages" > "$task_tmp/$arch.Packages"
    awk -v architecture="$arch" '
        BEGIN { RS = ""; FS = "\n" }
        function error(message) {
            print "Update failed: " message > "/dev/stderr"
            failed = 1
            exit 1
        }
        {
            delete field
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^[[:blank:]]/) continue
                separator = index($i, ":")
                if (!separator) error("Malformed APT package index")
                value = substr($i, separator + 1)
                sub(/^[[:blank:]]+/, "", value)
                field[substr($i, 1, separator - 1)] = value
            }
            if (field["Package"] != "claude-desktop") next
            if (field["Architecture"] != architecture) error("Unexpected package architecture")
            version = field["Version"]
            if (version !~ /^[0-9]+([.][0-9]+)+$/) next
            expected = "pool/main/c/claude-desktop/claude-desktop_" version "_" architecture ".deb"
            if (field["Filename"] != expected) error("Unexpected package filename")
            checksum = field["SHA256"]
            if (length(checksum) != 64 || checksum ~ /[^0-9a-f]/) error("Invalid SHA-256")
            if (seen[version]++) error("Duplicate package version")
            print version "\t" checksum
            count++
        }
        END {
            if (!failed && !count) {
                print "Update failed: No Claude releases for " architecture > "/dev/stderr"
                failed = 1
            }
            if (failed) exit 1
        }
    ' "$task_tmp/$arch.Packages" > "$task_tmp/$arch.packages"
    cut -f1 "$task_tmp/$arch.packages" | sort -u > "$task_tmp/$arch.versions"
done

latest=$(comm -12 "$task_tmp/amd64.versions" "$task_tmp/arm64.versions" | sort -V | tail -n1)
[[ -n "$latest" ]] || fail "No release is available for both architectures"
if [[ "$latest" == "$current" || $(printf '%s\n%s\n' "$current" "$latest" | sort -V | tail -n1) == "$current" ]]; then
    echo "Keeping Claude $current; newest common upstream version is $latest"
    report 0 "$current"
    exit 0
fi

# Prepare all edits in temporary files before changing the checkout.
cp "$MANIFEST" "$task_tmp/$MANIFEST"
escaped_current=${current//./\\.}
for arch in amd64 arm64; do
    checksum=$(awk -v version="$latest" '$1 == version { print $2 }' "$task_tmp/$arch.packages")
    sed -E "/^[[:blank:]]+url: .*claude-desktop_${escaped_current}_${arch}[.]deb\$/ {
        s@claude-desktop_${escaped_current}_${arch}[.]deb@claude-desktop_${latest}_${arch}.deb@
        n
        s/^([[:blank:]]+sha256: )[0-9a-f]{64}\$/\1${checksum}/
    }" "$task_tmp/$MANIFEST" > "$task_tmp/manifest.next"
    mv "$task_tmp/manifest.next" "$task_tmp/$MANIFEST"
done

awk -v version="$latest" -v today="$(date -u +%F)" '
    /^[[:blank:]]*<releases>$/ { releases = 1 }
    releases && !inserted && /^[[:blank:]]*<release[[:blank:]]/ {
        match($0, /^[[:blank:]]*/)
        print substr($0, 1, RLENGTH) "<release version=\"" version "\" date=\"" today "\"/>"
        inserted = 1
    }
    { print }
    END { if (!inserted) exit 1 }
' "$METAINFO" > "$task_tmp/$METAINFO" || fail "Cannot locate AppStream releases"

readme_target="The manifest currently packages Claude Desktop **${current}**"
matches=$(grep -Fc "$readme_target" README.md || true)
[[ "$matches" == 1 ]] || fail "Cannot locate the current Claude version in README.md"
sed "s/\(The manifest currently packages Claude Desktop \*\*\)${escaped_current}\(\*\*\)/\1${latest}\2/" \
    README.md > "$task_tmp/README.md"

for file in "$MANIFEST" "$METAINFO" README.md; do
    cp "$task_tmp/$file" "$file"
done
echo "Updated Claude $current -> $latest"
report 3 "$latest"
