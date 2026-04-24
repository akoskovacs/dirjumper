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

# ── Setup ──────────────────────────────────────────────────────────
ORIG_HOME="$HOME"
export HOME=$(mktemp -d)

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DJ_SH="$SCRIPT_DIR/dj.sh"

cleanup() {
    rm -rf "$HOME"
    export HOME="$ORIG_HOME"
}
trap cleanup EXIT

# ── Tests ──────────────────────────────────────────────────────────

echo "=== Install: creates directory structure ==="
bash "$DJ_SH" install > /dev/null 2>&1
assert_eq "install dir exists"  "0" "$([ -d "$HOME/.config/.dirjumper" ] && echo 0 || echo 1)"
assert_eq "dj.sh copied"        "0" "$([ -f "$HOME/.config/.dirjumper/dj.sh" ] && echo 0 || echo 1)"
assert_eq "dj.list created"     "0" "$([ -f "$HOME/.config/.dirjumper/dj.list" ] && echo 0 || echo 1)"

echo "=== Install: appends source snippet to .bashrc ==="
assert_eq ".bashrc created"     "0" "$([ -f "$HOME/.bashrc" ] && echo 0 || echo 1)"
assert_contains "bashrc has opening tag"  "# <dirjumper>"  "$(cat "$HOME/.bashrc")"
assert_contains "bashrc has closing tag"  "# </dirjumper>" "$(cat "$HOME/.bashrc")"
assert_contains "bashrc sources dj.sh"    'source "'       "$(cat "$HOME/.bashrc")"

echo "=== Install: installed script is functional ==="
export DIRJUMPER_COLOR=0
source "$HOME/.config/.dirjumper/dj.sh"
out=$(dirjumper -v 2>&1)
assert_contains "installed script reports version" "$(cat "$SCRIPT_DIR/VERSION" | tr -d '[:space:]')" "$out"

echo "=== Install: idempotent (running twice does not duplicate .bashrc snippet) ==="
bash "$DJ_SH" install > /dev/null 2>&1
count=$(grep -c '# <dirjumper>' "$HOME/.bashrc")
assert_eq "bashrc tag appears only once" "1" "$count"

# ── Summary ────────────────────────────────────────────────────────
echo
echo "================================"
echo "  $PASSED passed, $FAILED failed"
echo "================================"
if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
