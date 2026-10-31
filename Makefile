# ustax: Catala formalization of the US income tax subset covered by IRS Direct File.
# Requires opam; run `eval $(opam env --switch=default)` (or your switch) first.
SRC := $(wildcard catala/*.catala_en catala/tests/*.catala_en)

.PHONY: install check run clean
install:   ## install the Catala toolchain (catala + clerk) via opam
	opam install -y catala.1.3.0
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

# lake build + lake check + lake comparator in a Linux container (see docs/comparator.md).
# Needs Apple's `container` CLI with `container system start` done once. MODE=check|comparator|all.
MODE ?= all
.PHONY: comparator
comparator:  ## kernel-replay lean/ and judge it against lean/comparator.json, sandboxed
	./scripts/comparator.sh $(MODE)

# Oracle: dump Direct File reference-engine values for its backend scenarios (see oracle/README.md).
# Needs node >= 18 and a direct-file checkout: set DIRECT_FILE=<path to direct-file/direct-file>.
.PHONY: oracle
oracle:    ## regenerate oracle/facts.csv from the Direct File scenarios
	cd oracle && npm ci --ignore-scripts --no-audit --no-fund && node generate.mjs

# API contract (see docs/api.md): validate api/examples and api/fixtures against api/schema.json.
# Needs node >= 18; ajv is installed locally under api/ (pinned by api/package-lock.json).
.PHONY: api-check api-reasons
api-check: ## validate JSON examples and mock fixtures against api/schema.json
	cd api && npm ci --ignore-scripts --no-audit --no-fund && node scripts/check.mjs
api-reasons: ## regenerate api/knockout-reasons.json from the Catala KnockoutReason enum
	node api/scripts/gen-reasons.mjs

# Differential tests: Catala scope outputs vs oracle/facts.csv (see catala/DIFFTEST.md).
# `make difftest SCOPE=smoke` (default) or SCOPE=all; extra flags via ARGS=--verbose.
SCOPE ?= smoke
.PHONY: difftest difftest-selftest
difftest:  ## run mapped Catala scopes against the oracle, per-scenario pass/fail
	node difftest/run.mjs --scope $(SCOPE) $(ARGS)
difftest-selftest:  ## unit tests of the runner itself (no Catala)
	node --test difftest/selftest.mjs
# Per-person household facts (issue #16): oracle/persons.csv from oracle/generate_persons.mjs.
.PHONY: difftest-persons oracle-persons
difftest-persons:  ## qualifying-child, dependent and benefit-split tests per household member vs oracle/persons.csv
	node difftest/run.mjs --scope qualifying_child,qualifying_relative,dependents_benefit_split --oracle oracle/persons.csv $(ARGS)
oracle-persons:  ## regenerate oracle/persons.csv (needs DIRECT_FILE, as for `make oracle`)
	cd oracle && npm ci --ignore-scripts --no-audit --no-fund && node generate_persons.mjs
# Lean rate schedule vs Catala (clerk run) and vs the oracle (see lean/README.md).
.PHONY: lean-difftest lean-difftest-rates
lean-difftest:  ## Direct File / Catala / Lean three-way, per scenario/fact (SCOPE=<difftest/mappings name>)
	node difftest/lean.mjs --scope $(SCOPE) $(ARGS)
lean-difftest-rates:  ## Lean TentativeTax vs Catala and vs oracle/facts.csv
	node difftest/lean_rates.mjs $(ARGS)

# --- TLS (see docs/tls.md): Caddy terminates HTTPS, Lean server stays on plain loopback HTTP ---
# Requires `caddy` on PATH (brew install caddy); not installed by `make install`.
.PHONY: tls tls-trust tls-check
tls:       ## HTTPS front for the Lean server: https://localhost:8443 -> 127.0.0.1:8080
	caddy run --config deploy/Caddyfile --adapter caddyfile
tls-trust: ## one-time: trust Caddy's local CA so browsers/curl accept the dev cert
	caddy trust
tls-check: ## validate deploy/Caddyfile syntax
	caddy validate --config deploy/Caddyfile --adapter caddyfile

# Proof audit (see docs/audit.md): source scan, axiom audit, forensics smells. Fails on sorry/axiom/etc.
.PHONY: audit
audit:     ## fail on sorry, admit, native_decide, new axioms, vacuous theorems (SKIP_FORENSICS=1 skips step 3)
	./scripts/audit.sh
