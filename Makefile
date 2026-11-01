# ustax: Catala formalization of the US income tax subset covered by IRS Direct File.
# Dependencies are managed by devbox (devbox.json, docs/devbox.md). Every target below runs inside
# `devbox run` automatically: from a plain shell the rule just below re-invokes `make <goal>` through
# scripts/devbox-exec.sh (which explains how to install devbox if it is missing, or does it with
# INSTALL_DEVBOX=1). USTAX_NO_DEVBOX=1 skips devbox and uses the tools on your PATH.
ifeq ($(DEVBOX_SHELL_ENABLED)$(USTAX_NO_DEVBOX),)
.DEFAULT_GOAL := install
.PHONY: $(or $(MAKECMDGOALS),install)
$(or $(MAKECMDGOALS),install):
	@./scripts/devbox-exec.sh make $@
else
SRC := $(wildcard catala/*.catala_en catala/tests/*.catala_en)

.PHONY: install check run server test-server clean

# rules.md: `make install && make run` must work from a clean clone. Needs elan and Node >= 18;
# opam (Catala) is optional. No sudo. See scripts/install.sh.
install:   ## Lean toolchain (elan, pinned) + lake build + npm ci in web/ + Catala via opam (SKIP_CATALA=1 skips)
	./scripts/install.sh
run:       ## build, then start the API on :8080 and the web dev server on :5173 (Ctrl-C stops both)
	./scripts/run.sh
server:    ## build and run only the Lean HTTP API (PORT, HOST, ALLOW_ORIGIN; see lean/ServerMain.lean)
	cd lean && lake build ustax-server
	PORT=$${PORT:-8080} ALLOW_ORIGIN=$${ALLOW_ORIGIN:-http://localhost:5173} lean/.lake/build/bin/ustax-server
test-server: ## start the server on :18080, run scripts/server_integration.mjs and server_vs_cli.mjs against it, stop it
	cd lean && lake build ustax ustax-server
	./scripts/test_server.sh
check:     ## type-check every Catala source, then run the #[test] scopes
	clerk typecheck $(SRC)
	clerk test
clean:
	rm -rf _build

# --- Lean (see lean/README.md) ---
.PHONY: lean-build forensics
lean-build:  ## build the Lean library (core + Batteries + plausible); LEAN_DIR=<copy> for another checkout
	cd $(LEAN_DIR) && lake build
# Audit Lean with for-all-dev/forensics; clone lives in gitignored .forensics-tool/
forensics:   ## run forensics extractor on lean/, writing forensics-out.json
	@test -d .forensics-tool || git clone https://github.com/for-all-dev/forensics .forensics-tool
	cd .forensics-tool/app && bun server.ts $(CURDIR)/lean --roots UsTax --dump $(CURDIR)/forensics-out.json

# Native kernel replay + Comparator (Linux only: needs bubblewrap, which devbox provides there).
# LEAN_DIR=<copy of lean/> to run outside /home (see docs/audit.md, "bwrap").
LEAN_DIR ?= lean
.PHONY: lean-check lean-comparator
lean-check:      ## lake check: replay the build through the kernel, axiom allow-list (Linux, bwrap)
	cd $(LEAN_DIR) && lake check
lean-comparator: ## lake comparator: challenge vs solution (Linux, bwrap)
	cd $(LEAN_DIR) && lake comparator --config comparator.json

# lake build + lake check + lake comparator in a Linux container (see docs/comparator.md).
# Needs Apple's `container` CLI with `container system start` done once. MODE=check|comparator|all.
MODE ?= all
.PHONY: comparator
comparator:  ## kernel-replay lean/ and judge it against lean/comparator.json, sandboxed
	./scripts/comparator.sh $(MODE)

# Second challenge: the module specs (lean/UsTax/Comparator/Extra.lean), not the main theorems.
.PHONY: comparator-extra
comparator-extra:  ## judge lean/ against lean/comparator.extra.json (module specs), sandboxed
	./scripts/comparator.sh extra

# Oracle: dump Direct File reference-engine values for its backend scenarios (see oracle/README.md).
# Needs node >= 18 and a direct-file checkout: set DIRECT_FILE=<path to direct-file/direct-file>.
.PHONY: oracle
oracle:    ## regenerate oracle/facts.csv from the Direct File scenarios
	cd oracle && npm ci --ignore-scripts --no-audit --no-fund && node generate.mjs

# API contract (see docs/api.md): validate api/examples and api/fixtures against api/schema.json.
# Needs node >= 18; ajv is installed locally under api/ (pinned by api/package-lock.json).
.PHONY: api-check api-reasons api-conformance
api-check: ## validate JSON examples and mock fixtures against api/schema.json
	cd api && npm ci --ignore-scripts --no-audit --no-fund && node scripts/check.mjs
api-conformance: ## Lean request validator vs api/schema.json via ajv (examples + generated mutants)
	cd lean && lake build ustax
	cd api && npm ci --ignore-scripts --no-audit --no-fund
	node scripts/api_conformance.mjs
api-reasons: ## regenerate api/knockout-reasons.json from the Catala KnockoutReason enum
	node api/scripts/gen-reasons.mjs

# Provenance index (docs/provenance.md): api/provenance.json links each API line to Catala, law, Lean theorems and tests.
.PHONY: provenance provenance-check
provenance:       ## regenerate api/provenance.json from catala/, lean/ and sources/ (no network)
	node scripts/gen_provenance.mjs
provenance-check: ## fail if api/provenance.json is stale or does not match api/provenance.schema.json
	cd api && npm ci --ignore-scripts --no-audit --no-fund
	node scripts/gen_provenance.mjs --check

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
difftest-persons:  ## qualifying-child, dependent, benefit-split, CTC/ODC and HoH/QSS tests per household member vs oracle/persons.csv
	node difftest/run.mjs --scope qualifying_child,qualifying_relative,dependents_benefit_split,ctc_odc_person,hoh_qss_persons --oracle oracle/persons.csv $(ARGS)
oracle-persons:  ## regenerate oracle/persons.csv (needs DIRECT_FILE, as for `make oracle`)
	cd oracle && npm ci --ignore-scripts --no-audit --no-fund && node generate_persons.mjs
# Filing-status fact graphs (issue #20): the 27 graphs of direct-file/docs/testing/fact-graphs, oracle/fact_graphs.csv.
# DF_DOCS defaults to the docs/ directory next to $(DIRECT_FILE).
.PHONY: difftest-filing-status-graphs oracle-fact-graphs
difftest-filing-status-graphs:  ## filing-status scope vs the Direct File filing-status fact graphs (oracle/fact_graphs.csv)
	node difftest/run.mjs --scope filing_status --oracle oracle/fact_graphs.csv $(ARGS)
oracle-fact-graphs:  ## regenerate oracle/fact_graphs.csv (needs DIRECT_FILE; graphs in $$DIRECT_FILE/../docs/testing/fact-graphs)
	cd oracle && npm ci --ignore-scripts --no-audit --no-fund && node generate.mjs --out fact_graphs.csv \
	  --scenario-dir "$${DF_DOCS:-$${DIRECT_FILE:-../../direct-file/direct-file}/../docs}/testing/fact-graphs"
# Lean rate schedule vs Catala (clerk run) and vs the oracle (see lean/README.md).
.PHONY: lean-difftest lean-difftest-rates lean-difftest-persons lean-difftest-filing-status-graphs
lean-difftest:  ## Direct File / Catala / Lean three-way, per scenario/fact (SCOPE=<difftest/mappings name>)
	node difftest/lean.mjs --scope $(SCOPE) $(ARGS)
lean-difftest-persons:  ## Direct File / Catala / Lean three-way, per household member (oracle/persons.csv)
	node difftest/lean.mjs --scope qualifying_child,qualifying_relative,dependents_benefit_split,hoh_qss_persons --oracle oracle/persons.csv $(ARGS)
lean-difftest-filing-status-graphs:  ## Direct File / Catala / Lean three-way on the filing-status fact graphs
	node difftest/lean.mjs --scope filing_status --oracle oracle/fact_graphs.csv $(ARGS)
lean-difftest-rates:  ## Lean TentativeTax vs Catala and vs oracle/facts.csv
	node difftest/lean_rates.mjs $(ARGS)

# --- TLS (see docs/tls.md): Caddy terminates HTTPS, Lean server stays on plain loopback HTTP ---
# caddy comes from devbox.
.PHONY: tls tls-trust tls-check
tls:       ## HTTPS front for the Lean server: https://localhost:8443 -> 127.0.0.1:8080
	caddy run --config deploy/Caddyfile --adapter caddyfile
tls-trust: ## one-time: trust Caddy's local CA so browsers/curl accept the dev cert
	caddy trust
tls-check: ## validate deploy/Caddyfile syntax
	caddy validate --config deploy/Caddyfile --adapter caddyfile

# --- Docker (see docs/deploy.md): Dockerfile targets `server` (Lean API :8080) and `web` (Caddy + static app) ---
# DOCKER=docker (default) or DOCKER=container (Apple's CLI; it has no compose, so docker-run needs docker).
DOCKER ?= docker
.PHONY: docker-build docker-run
docker-build: ## build the ustax-server and ustax-web images (checks the pinned toolchain matches)
	@grep -q "$$(cat lean/lean-toolchain)" Dockerfile || { echo "Dockerfile LEAN_TOOLCHAIN differs from lean/lean-toolchain" >&2; exit 1; }
	$(DOCKER) build --target server -t ustax-server .
	$(DOCKER) build --target web -t ustax-web .
docker-run:   ## build and start API (127.0.0.1:8080) and web (http://localhost:8081) with docker compose
	$(DOCKER) compose up --build

# Proof audit (see docs/audit.md): source scan, axiom audit, forensics smells. Fails on sorry/axiom/etc.
.PHONY: audit
audit:     ## fail on sorry, admit, native_decide, new axioms, vacuous theorems (SKIP_FORENSICS=1 skips step 3)
	./scripts/audit.sh

# --- Web frontend (see web/README.md) ---
.PHONY: web-build web-test web-dev
web-build: ## typecheck, lint and production-build the frontend
	cd web && npm ci --no-audit --no-fund && npm run lint && npm run build
web-test:  ## frontend unit tests (vitest + testing-library)
	cd web && npm ci --no-audit --no-fund && npm test
web-dev:   ## frontend dev server on the api/fixtures mock (VITE_API_MOCK=1)
	cd web && npm ci --no-audit --no-fund && VITE_API_MOCK=1 npm run dev
endif
