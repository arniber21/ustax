# Devbox: dependencies and CI

All tools the project needs come from [devbox](https://www.jetify.com/devbox) (Nix underneath). `devbox.json` lists them; `devbox.lock` (committed) pins the exact nixpkgs revision and store paths per platform. Tested with devbox 0.18.0 on macOS arm64; CI uses Ubuntu 24.04.

## Install devbox

```sh
curl -fsSL https://get.jetify.com/devbox | bash     # official installer; installs Nix too if missing
```

`INSTALL_DEVBOX=1 make install` runs that line for you. Without devbox, `make` prints it and exits 1.

## Use it

```sh
make install && make run        # clean clone: works; make enters devbox by itself
devbox shell                    # interactive shell with every tool on PATH
devbox run install              # scripts in devbox.json:
devbox run check                #   make check      (Catala type-check + #[test])
devbox run test                 #   test-server, web-test, difftest-selftest
devbox run audit                #   make audit
devbox run run                  #   make run
devbox run comparator           #   make comparator (macOS: Apple `container`; see docs/comparator.md)
devbox run catala-setup         #   only (re)build Catala into .opam
```

Every `make` target works from a plain shell: outside devbox the Makefile re-invokes the goal through `scripts/devbox-exec.sh` (`devbox run -- make <goal>`). Inside `devbox shell`/`devbox run` (`DEVBOX_SHELL_ENABLED` is set) it runs directly. `USTAX_NO_DEVBOX=1 make <target>` skips devbox and uses whatever is on your PATH (you then supply the tools below yourself).

## What it provides

Node 22 (web/ needs >= 18), bun (forensics), ninja (clerk), poppler-utils (`pdftotext`, for sources/), git, curl, jq, python3, elan (Lean itself stays pinned by `lean/lean-toolchain` through elan; `elan toolchain install` runs in `make install`), opam + gmp + pkg-config + make (to build Catala), caddy, and on Linux only, bubblewrap (`lake check`/`lake comparator`). Compilers: the system C compiler is used (Xcode Command Line Tools on macOS, `build-essential` on Ubuntu).

## Catala

nixpkgs has no Catala package, so devbox provides opam and `scripts/catala-setup.sh` builds OCaml 5.4.1 and `catala.1.3.0` (plus `clerk`) into a project-local opam root `.opam/` (gitignored; your `~/.opam` is untouched; opam sandboxing is disabled for this root). First run takes roughly 10-20 minutes; it is skipped when the right version exists (`SKIP_CATALA=1 make install` skips it entirely). `scripts/devbox-env.sh` puts `.opam/ustax/bin` on PATH inside devbox, so no `eval $(opam env)` is needed. Versions are in `devbox.json` `env` (`USTAX_OCAML`, `USTAX_CATALA`).

## How versions are pinned

- `devbox.json` `packages`: version constraints (`nodejs 22`, `bun 1.3.13`, ... or `latest`).
- `devbox.lock`: the resolved nixpkgs commit and store paths. Commit it. `devbox install` / `devbox run` use it as is.
- Lean: `lean/lean-toolchain` and `lean/lake-manifest.json`. Catala: `USTAX_CATALA`. Forensics: `FORENSICS_REV` in `scripts/audit.sh`.

## Update

```sh
devbox update               # re-resolve all packages, rewrite devbox.lock
devbox add <pkg>@<ver>      # add a tool (edits devbox.json and devbox.lock)
```

Then run `devbox run check` and `devbox run test`, and commit both files. The devbox CLI itself is pinned in CI (`devbox-version` in `.github/workflows/ci.yml`).

## CI

`.github/workflows/ci.yml` uses `jetify-com/devbox-install-action` (pinned, `enable-cache: true`) and calls the same scripts: `devbox run catala-setup`, `devbox run check`, `make lean-build/lean-check/lean-comparator` and `devbox run audit` through `devbox run`. The opam root and the elan toolchain are cached separately. See `docs/audit.md` for the bwrap note.

## Known limits

- Fetching the closure needs network access (cache.nixos.org); the first `devbox install` downloads a few hundred MB.
- `nodejs 20` is marked insecure in current nixpkgs, hence Node 22.
- Docker/`container` (for `make docker-*`, `make comparator` on macOS) are not provided by devbox.
