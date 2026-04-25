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

# Run install from within the given shell so that parent-process detection
# inside dj.sh sees the correct calling shell.
# Usage: install_as <shell> <dj_sh_path>
#
# We write a tiny script file rather than using "shell -c 'single_command'"
# because shells exec-optimize the latter (replacing themselves with the child),
# which would make $PPID inside bash point to the wrong parent.
install_as() {
    local shell="$1" script="$2"
    local tmp
    tmp=$(mktemp)
    printf 'bash "%s" install\n' "$script" > "$tmp"
    "$shell" "$tmp" > /dev/null 2>&1
    rm -f "$tmp"
}

# Run the README install flow from a temp download dir, then remove the script.
# Usage: download_and_install <download_cmd> <shell>
#   download_cmd must write dj.sh into the current directory.
#   shell is wrapped around the install so parent-process detection works.
download_and_install() {
    local download_cmd="$1"
    local wrapper_shell="$2"
    local dl_dir tmp_script
    dl_dir=$(mktemp -d)
    tmp_script=$(mktemp)
    echo 'bash dj.sh install' > "$tmp_script"
    (
        cd "$dl_dir"
        eval "$download_cmd" 2>/dev/null
        "$wrapper_shell" "$tmp_script" > /dev/null 2>&1
        rm dj.sh
    )
    rm -rf "$dl_dir" "$tmp_script"
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

# ── Tests: direct install (bash) ──────────────────────────────────

echo "=== Install (bash): creates directory structure ==="
install_as bash "$DJ_SH"
assert_eq "install dir exists"  "0" "$([ -d "$HOME/.config/.dirjumper" ] && echo 0 || echo 1)"
assert_eq "dj.sh copied"        "0" "$([ -f "$HOME/.config/.dirjumper/dj.sh" ] && echo 0 || echo 1)"
assert_eq "dj.list created"     "0" "$([ -f "$HOME/.config/.dirjumper/dj.list" ] && echo 0 || echo 1)"

echo "=== Install (bash): appends source snippet to .bashrc ==="
assert_eq ".bashrc created"     "0" "$([ -f "$HOME/.bashrc" ] && echo 0 || echo 1)"
assert_contains "bashrc has opening tag"  "# <dirjumper>"  "$(cat "$HOME/.bashrc")"
assert_contains "bashrc has closing tag"  "# </dirjumper>" "$(cat "$HOME/.bashrc")"
assert_contains "bashrc sources dj.sh"    'source "'       "$(cat "$HOME/.bashrc")"

echo "=== Install (bash): idempotent (running twice does not duplicate .bashrc snippet) ==="
install_as bash "$DJ_SH"
count=$(grep -c '# <dirjumper>' "$HOME/.bashrc")
assert_eq "bashrc tag appears only once" "1" "$count"

# ── Tests: direct install (zsh) ──────────────────────────────────

if command -v zsh > /dev/null 2>&1; then
    echo "=== Install (zsh): creates directory structure ==="
    reset_home
    install_as zsh "$DJ_SH"
    assert_eq "install dir exists"  "0" "$([ -d "$HOME/.config/.dirjumper" ] && echo 0 || echo 1)"
    assert_eq "dj.sh copied"        "0" "$([ -f "$HOME/.config/.dirjumper/dj.sh" ] && echo 0 || echo 1)"
    assert_eq "dj.list created"     "0" "$([ -f "$HOME/.config/.dirjumper/dj.list" ] && echo 0 || echo 1)"

    echo "=== Install (zsh): appends source snippet to .zshrc ==="
    assert_eq ".zshrc created"      "0" "$([ -f "$HOME/.zshrc" ] && echo 0 || echo 1)"
    assert_contains "zshrc has opening tag"  "# <dirjumper>"  "$(cat "$HOME/.zshrc")"
    assert_contains "zshrc has closing tag"  "# </dirjumper>" "$(cat "$HOME/.zshrc")"
    assert_contains "zshrc sources dj.sh"    'source "'       "$(cat "$HOME/.zshrc")"

    echo "=== Install (zsh): does not modify .bashrc ==="
    assert_eq ".bashrc not created" "1" "$([ -f "$HOME/.bashrc" ] && echo 0 || echo 1)"

    echo "=== Install (zsh): idempotent (running twice does not duplicate .zshrc snippet) ==="
    install_as zsh "$DJ_SH"
    count=$(grep -c '# <dirjumper>' "$HOME/.zshrc")
    assert_eq "zshrc tag appears only once" "1" "$count"
else
    echo "=== Install (zsh): SKIP (zsh not available) ==="
fi

# ── Tests: installed script is functional ─────────────────────────

echo "=== Install: installed script is functional ==="
export DIRJUMPER_COLOR=0
source "$HOME/.config/.dirjumper/dj.sh"
out=$(dirjumper -v 2>&1)
assert_contains "installed script reports version" "$(cat "$SCRIPT_DIR/VERSION" | tr -d '[:space:]')" "$out"

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

echo "=== README flow (curl, bash): download, install, rm ==="
reset_home
download_and_install "curl -sSL http://localhost:$SERVER_PORT/dj.sh > dj.sh" bash
assert_eq "curl bash: install dir exists" "0" "$([ -d "$HOME/.config/.dirjumper" ] && echo 0 || echo 1)"
assert_eq "curl bash: dj.sh installed"    "0" "$([ -f "$HOME/.config/.dirjumper/dj.sh" ] && echo 0 || echo 1)"
assert_eq "curl bash: dj.list created"    "0" "$([ -f "$HOME/.config/.dirjumper/dj.list" ] && echo 0 || echo 1)"
assert_contains "curl bash: bashrc configured" "# <dirjumper>" "$(cat "$HOME/.bashrc" 2>/dev/null)"

if command -v zsh > /dev/null 2>&1; then
    echo "=== README flow (curl, zsh): download, install, rm ==="
    reset_home
    download_and_install "curl -sSL http://localhost:$SERVER_PORT/dj.sh > dj.sh" zsh
    assert_eq "curl zsh: install dir exists" "0" "$([ -d "$HOME/.config/.dirjumper" ] && echo 0 || echo 1)"
    assert_eq "curl zsh: dj.sh installed"    "0" "$([ -f "$HOME/.config/.dirjumper/dj.sh" ] && echo 0 || echo 1)"
    assert_eq "curl zsh: dj.list created"    "0" "$([ -f "$HOME/.config/.dirjumper/dj.list" ] && echo 0 || echo 1)"
    assert_contains "curl zsh: zshrc configured" "# <dirjumper>" "$(cat "$HOME/.zshrc" 2>/dev/null)"
else
    echo "=== README flow (curl, zsh): SKIP (zsh not available) ==="
fi

echo "=== README flow (wget, bash): download, install, rm ==="
if command -v wget > /dev/null 2>&1; then
    reset_home
    download_and_install "wget -q http://localhost:$SERVER_PORT/dj.sh" bash
    assert_eq "wget bash: install dir exists" "0" "$([ -d "$HOME/.config/.dirjumper" ] && echo 0 || echo 1)"
    assert_eq "wget bash: dj.sh installed"    "0" "$([ -f "$HOME/.config/.dirjumper/dj.sh" ] && echo 0 || echo 1)"
    assert_eq "wget bash: dj.list created"    "0" "$([ -f "$HOME/.config/.dirjumper/dj.list" ] && echo 0 || echo 1)"
    assert_contains "wget bash: bashrc configured" "# <dirjumper>" "$(cat "$HOME/.bashrc" 2>/dev/null)"
else
    echo "  SKIP: wget not available on this system"
fi

echo "=== README flow: installed script works after downloaded copy is removed ==="
reset_home
download_and_install "curl -sSL http://localhost:$SERVER_PORT/dj.sh > dj.sh" bash
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
