#!/bin/sh
# Install Catala (pinned) into a project-local opam root (.opam, gitignored), inside devbox.
# nixpkgs has no Catala package, so opam (from devbox) builds OCaml and catala from source:
# no touching ~/.opam. Idempotent: does nothing when the right catala is already there.
# Env (set by devbox.json): OPAMROOT, USTAX_CATALA_SWITCH, USTAX_OCAML, USTAX_CATALA.
# Takes ~10-20 min the first time (compiles OCaml 5.4.1 and ~40 packages).
set -eu
SW="${USTAX_CATALA_SWITCH:-ustax}"
OCAMLV="${USTAX_OCAML:-5.4.1}"
CATALAV="${USTAX_CATALA:-1.3.0}"
: "${OPAMROOT:?run inside devbox (devbox run catala-setup)}"
export OPAMYES=1

if [ "$(PATH="$OPAMROOT/$SW/bin:$PATH" catala --version 2>/dev/null | head -1)" = "$CATALAV" ] \
   && [ -x "$OPAMROOT/$SW/bin/clerk" ]; then
  echo "catala $CATALAV already installed in $OPAMROOT/$SW"
else
  if [ ! -d "$OPAMROOT" ]; then
    # Sandboxing off: opam's bwrap/sandbox-exec sandbox is not needed for a throwaway local root
    # and fails inside unprivileged containers and on locked-down CI runners.
    opam init --bare --no-setup --disable-sandboxing --disable-shell-hook
  fi
  opam switch list --short 2>/dev/null | grep -qx "$SW" \
    || opam switch create "$SW" "ocaml-base-compiler.$OCAMLV"
  opam install --switch "$SW" "catala.$CATALAV"
fi

export PATH="$OPAMROOT/$SW/bin:$PATH"
catala --version | head -1
clerk --version | head -1
