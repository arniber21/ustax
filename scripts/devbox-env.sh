# Sourced by the devbox init_hook (devbox.json). POSIX sh; must not exit or fail.
# 1. C headers/libs for opam builds of zarith (gmp from the nix store).
# 2. Put the project-local opam switch (.opam, see scripts/catala-setup.sh) on PATH: catala, clerk, ocaml.
if [ -n "${DEVBOX_PROJECT_ROOT:-}" ]; then
  for d in $(printf '%s' "${buildInputs:-}" | tr ' ' '\n' | grep -E -- '-gmp-' 2>/dev/null); do
    [ -d "$d/include" ] && export CPATH="$d/include${CPATH:+:$CPATH}"
    [ -d "$d/lib" ] && export LIBRARY_PATH="$d/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"
  done
  if [ -d "$OPAMROOT/${USTAX_CATALA_SWITCH:-ustax}/bin" ]; then
    export PATH="$OPAMROOT/${USTAX_CATALA_SWITCH:-ustax}/bin:$PATH"
    export OPAMSWITCH="${USTAX_CATALA_SWITCH:-ustax}"
  fi
fi
true
