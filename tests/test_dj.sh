#!/bin/bash

PASSED=0
FAILED=0

pass() {
    PASSED=$((PASSED + 1))
    echo "  PASS: $1"
}

fail() {
    FAILED=$((FAILED + 1))
    echo "  FAIL: $1" >&2
}

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$expected" = "$actual" ]]; then
        pass "$label"
    else
        fail "$label (expected '$expected', got '$actual')"
    fi
}

assert_contains() {
    local label="$1" needle="$2" haystack="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        pass "$label"
    else
        fail "$label (expected to contain '$needle', got '$haystack')"
    fi
}

assert_not_contains() {
    local label="$1" needle="$2" haystack="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        pass "$label"
    else
        fail "$label (expected NOT to contain '$needle', got '$haystack')"
    fi
}

# Resolve symlinks for path comparisons (macOS /tmp -> /private/tmp)
real_pwd() {
    pwd -P
}

# ── Setup ──────────────────────────────────────────────────────────
ORIG_HOME="$HOME"
export HOME=$(mktemp -d)
mkdir -p "$HOME/.config/.dirjumper"
touch "$HOME/.config/.dirjumper/dj.list"

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export DIRJUMPER_COLOR=0

source "$SCRIPT_DIR/dj.sh"

TMPDIR_A=$(cd "$(mktemp -d)" && pwd -P)
TMPDIR_B=$(cd "$(mktemp -d)" && pwd -P)

cleanup() {
    rm -rf "$HOME" "$TMPDIR_A" "$TMPDIR_B"
    export HOME="$ORIG_HOME"
}
trap cleanup EXIT

# ── Tests ──────────────────────────────────────────────────────────

echo "=== Version ==="
ver=$(dirjumper -v)
file_ver=$(cat "$SCRIPT_DIR/VERSION")
assert_eq "version flag matches VERSION file" \
    "$(echo "$file_ver" | tr -d '[:space:]')" \
    "$(echo "$ver" | tr -d '[:space:]')"

echo "=== Add alias (explicit directory) ==="
out=$(dirjumper -a proj "$TMPDIR_A" 2>&1)
assert_not_contains "add alias (explicit dir) - no errors" "Invalid" "$out"
assert_not_contains "add alias (explicit dir) - no errors" "Error" "$out"
assert_eq "cwd unchanged after add with path" "$SCRIPT_DIR" "$(real_pwd)"
out=$(dirjumper -g proj)
assert_eq "get alias returns correct path" "$TMPDIR_A" "$out"

echo "=== Add alias (current directory) ==="
cd "$TMPDIR_B"
out=$(dirjumper -a work 2>&1)
assert_not_contains "add alias (cwd) - no errors" "Invalid" "$out"
out=$(dirjumper -g work)
assert_eq "get alias from cwd" "$TMPDIR_B" "$out"

echo "=== Jump to alias ==="
cd /tmp
dirjumper proj
assert_eq "cd to bookmarked dir" "$TMPDIR_A" "$(real_pwd)"

echo "=== List aliases ==="
out=$(dirjumper -l)
assert_contains "list shows proj" "proj" "$out"
assert_contains "list shows work" "work" "$out"

echo "=== Rename alias ==="
out=$(dirjumper -r proj project 2>&1)
assert_not_contains "rename - no errors" "Invalid" "$out"
assert_eq "cwd unchanged after rename" "$TMPDIR_A" "$(real_pwd)"
out=$(dirjumper -g project)
assert_eq "renamed alias resolves" "$TMPDIR_A" "$out"
out=$(dirjumper -g proj 2>/dev/null || true)
assert_eq "old name gone after rename" "" "$out"

echo "=== Delete alias ==="
dirjumper -d work
out=$(dirjumper -g work 2>/dev/null || true)
assert_eq "alias removed after delete" "" "$out"

echo "=== Duplicate alias rejected ==="
out=$(dirjumper -a project "$TMPDIR_B" 2>&1)
assert_contains "duplicate alias shows error" "already exist" "$out"

echo "=== Invalid alias rejected ==="
out=$(dirjumper -a '/../bad' "$TMPDIR_A" 2>&1)
assert_contains "invalid alias shows error" "Invalid" "$out"

echo "=== Help flag ==="
out=$(dirjumper -h 2>&1)
assert_contains "help mentions -a" "-a" "$out"
assert_contains "help mentions -d" "-d" "$out"

echo "=== Custom alias name ==="
DIRJUMPER_ALIAS='go'
source "$SCRIPT_DIR/dj.sh"
assert_eq "custom alias variable" "go" "$DIRJUMPER_ALIAS"
DIRJUMPER_ALIAS='j'
source "$SCRIPT_DIR/dj.sh"

echo "=== No-arg lists aliases ==="
out=$(dirjumper)
assert_contains "no-arg shows existing alias" "project" "$out"

echo "=== Prefix collision ==="
out=$(dirjumper -a pro "$TMPDIR_B" 2>&1)
assert_not_contains "add shorter alias - no errors" "Invalid" "$out"
out_pro=$(dirjumper -g pro)
out_project=$(dirjumper -g project)
assert_eq "shorter alias resolves correctly" "$TMPDIR_B" "$out_pro"
assert_eq "longer alias still resolves" "$TMPDIR_A" "$out_project"
dirjumper -d pro

echo "=== Nonexistent alias ==="
out=$(dirjumper -g nonexistent 2>/dev/null || true)
assert_eq "nonexistent alias returns empty" "" "$out"

echo "=== Jump to nonexistent alias ==="
before=$(real_pwd)
out=$(dirjumper nonexistent 2>&1 || true)
assert_contains "jump to missing alias shows error" "not found" "$out"
assert_eq "stays in original dir after failed jump" "$before" "$(real_pwd)"

# ── Summary ────────────────────────────────────────────────────────
echo
echo "================================"
echo "  $PASSED passed, $FAILED failed"
echo "================================"
if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
