#!/bin/sh
# Run a command inside the project's devbox environment (devbox.json). Used by the Makefile
# so that `make <target>` works from a plain shell.
#   scripts/devbox-exec.sh make check
# If devbox is missing: print the official one-line installer and exit 1, or run it
# when INSTALL_DEVBOX=1. Skipped entirely when USTAX_NO_DEVBOX=1 (you provide the tools).
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER='curl -fsSL https://get.jetify.com/devbox | bash'

# Devbox's own launcher lives in ~/.local/bin on some setups; Nix in /nix/var/nix/profiles/default/bin.
PATH="$PATH:$HOME/.local/bin:/usr/local/bin:/nix/var/nix/profiles/default/bin"
export PATH

if ! command -v devbox >/dev/null 2>&1; then
  if [ "${INSTALL_DEVBOX:-0}" = 1 ]; then
    echo "devbox not found: running the official installer (INSTALL_DEVBOX=1)" >&2
    sh -c "$INSTALLER" </dev/null || { echo "error: devbox installer failed" >&2; exit 1; }
    PATH="$PATH:$HOME/.local/bin:/usr/local/bin"
    command -v devbox >/dev/null 2>&1 || { echo "error: devbox still not on PATH; open a new shell and re-run" >&2; exit 1; }
  else
    cat >&2 <<EOF
error: devbox is not installed. This project gets all its tools (Node, elan, opam, ninja, ...) from devbox.
Install it (one line, official installer; it also installs Nix if needed):

    $INSTALLER

then open a new shell and re-run. Or let make do it:  INSTALL_DEVBOX=1 make install
Already have every tool yourself?  USTAX_NO_DEVBOX=1 make <target>
EOF
    exit 1
  fi
fi

export DEVBOX_NO_PROMPT=true
cd "$REPO"
exec devbox run -- "$@"
