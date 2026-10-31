# ustax: Catala formalization of the US income tax subset covered by IRS Direct File.
# Requires opam; run `eval $(opam env --switch=default)` (or your switch) first.
SRC := $(wildcard catala/*.catala_en catala/tests/*.catala_en)

.PHONY: install check run clean
install:   ## install the Catala toolchain (catala + clerk) via opam
	opam install -y catala
	clerk start
check:     ## type-check every Catala source, then run the #[test] scopes
	clerk typecheck $(SRC)
	clerk test
run: check
clean:
	rm -rf _build

# --- Lean (see lean/README.md) ---
.PHONY: lean-build forensics
lean-build:  ## build the Lean library (core + Batteries + plausible)
	cd lean && lake build
# Audit Lean with for-all-dev/forensics; clone lives in gitignored .forensics-tool/
forensics:   ## run forensics extractor on lean/, writing forensics-out.json
	@test -d .forensics-tool || git clone https://github.com/for-all-dev/forensics .forensics-tool
	cd .forensics-tool/app && bun server.ts $(CURDIR)/lean --dump $(CURDIR)/forensics-out.json

# Oracle: dump Direct File reference-engine values for its backend scenarios (see oracle/README.md).
# Needs node >= 18 and a direct-file checkout: set DIRECT_FILE=<path to direct-file/direct-file>.
.PHONY: oracle
oracle:    ## regenerate oracle/facts.csv from the Direct File scenarios
	cd oracle && npm ci --ignore-scripts --no-audit --no-fund && node generate.mjs

# Differential tests: Catala scope outputs vs oracle/facts.csv (see catala/DIFFTEST.md).
# `make difftest SCOPE=smoke` (default) or SCOPE=all; extra flags via ARGS=--verbose.
SCOPE ?= smoke
.PHONY: difftest difftest-selftest
difftest:  ## run mapped Catala scopes against the oracle, per-scenario pass/fail
	node difftest/run.mjs --scope $(SCOPE) $(ARGS)
difftest-selftest:  ## unit tests of the runner itself (no Catala)
	node --test difftest/selftest.mjs
