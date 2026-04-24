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

# ── Helpers ────────────────────────────────────────────────────────

# Reset HOME to a clean state between sub-tests
reset_home() {
    rm -rf "$HOME"
    export HOME=$(mktemp -d)
}

# Run the README install flow from a temp download dir, then remove the script.
# Usage: readme_install <download_cmd>
#   download_cmd must write dj.sh into the current directory.
readme_install() {
    local download_cmd="$1"
    local dl_dir
    dl_dir=$(mktemp -d)
    (
        cd "$dl_dir"
        eval "$download_cmd" 2>/dev/null
        bash dj.sh install > /dev/null 2>&1
        rm dj.sh
    )
    rm -rf "$dl_dir"
}

# ── Setup ──────────────────────────────────────────────────────────
ORIG_HOME="$HOME"
export HOME=$(mktemp -d)

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DJ_SH="$SCRIPT_DIR/dj.sh"

cleanup() {
    # Stop the HTTP server if it was started
    [[ -n "$SERVER_PID" ]] && kill "$SERVER_PID" 2>/dev/null
    rm -rf "$HOME"
    export HOME="$ORIG_HOME"
}
trap cleanup EXIT

# ── Tests: direct install ──────────────────────────────────────────

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

# ── Tests: README flow (download → install → rm) ───────────────────
#
# Spin up a local HTTP server serving the repo root so wget/curl fetch
# the local dj.sh rather than hitting GitHub, keeping the tests offline
# and always testing the current working copy.

SERVER_PORT=17351
python3 -m http.server "$SERVER_PORT" --directory "$SCRIPT_DIR" > /dev/null 2>&1 &
SERVER_PID=$!
# Wait briefly for the server to be ready
for i in $(seq 1 10); do
    curl -sf "http://localhost:$SERVER_PORT/dj.sh" > /dev/null 2>&1 && break
    sleep 0.2
done

echo "=== README flow (curl): download, install, rm ==="
reset_home
readme_install "curl -sSL http://localhost:$SERVER_PORT/dj.sh > dj.sh"
assert_eq "curl: install dir exists" "0" "$([ -d "$HOME/.config/.dirjumper" ] && echo 0 || echo 1)"
assert_eq "curl: dj.sh installed"    "0" "$([ -f "$HOME/.config/.dirjumper/dj.sh" ] && echo 0 || echo 1)"
assert_eq "curl: dj.list created"    "0" "$([ -f "$HOME/.config/.dirjumper/dj.list" ] && echo 0 || echo 1)"
assert_contains "curl: bashrc configured" "# <dirjumper>" "$(cat "$HOME/.bashrc" 2>/dev/null)"

echo "=== README flow (wget): download, install, rm ==="
if command -v wget > /dev/null 2>&1; then
    reset_home
    readme_install "wget -q http://localhost:$SERVER_PORT/dj.sh"
    assert_eq "wget: install dir exists" "0" "$([ -d "$HOME/.config/.dirjumper" ] && echo 0 || echo 1)"
    assert_eq "wget: dj.sh installed"    "0" "$([ -f "$HOME/.config/.dirjumper/dj.sh" ] && echo 0 || echo 1)"
    assert_eq "wget: dj.list created"    "0" "$([ -f "$HOME/.config/.dirjumper/dj.list" ] && echo 0 || echo 1)"
    assert_contains "wget: bashrc configured" "# <dirjumper>" "$(cat "$HOME/.bashrc" 2>/dev/null)"
else
    echo "  SKIP: wget not available on this system"
fi

echo "=== README flow: installed script works after downloaded copy is removed ==="
reset_home
readme_install "curl -sSL http://localhost:$SERVER_PORT/dj.sh > dj.sh"
export DIRJUMPER_COLOR=0
source "$HOME/.config/.dirjumper/dj.sh"
out=$(dirjumper -v 2>&1)
assert_contains "post-rm: installed script reports version" \
    "$(cat "$SCRIPT_DIR/VERSION" | tr -d '[:space:]')" "$out"

# ── Summary ────────────────────────────────────────────────────────
echo
echo "================================"
echo "  $PASSED passed, $FAILED failed"
echo "================================"
if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
