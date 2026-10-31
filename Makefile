# ustax: Catala formalization of the US income tax subset covered by IRS Direct File.
CATALA ?= opam exec -- catala
SRC    := $(wildcard catala/*.catala_en)

.PHONY: install check run clean
install:   ## install the Catala compiler via opam (needs opam; slow the first time)
	opam init -y --bare 2>/dev/null || true
	opam switch create ustax 5.1.1 -y 2>/dev/null || true
	opam install -y catala
check:     ## type-check every Catala source
	@for f in $(SRC); do echo "== $$f"; $(CATALA) typecheck $$f || exit 1; done
run: check
clean:
	rm -rf _build
