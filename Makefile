# ustax: Catala formalization of the US income tax subset covered by IRS Direct File.
# Requires opam; run `eval $(opam env --switch=default)` (or your switch) first.
SRC := $(wildcard catala/*.catala_en)

.PHONY: install check run clean
install:   ## install the Catala toolchain (catala + clerk) via opam
	opam install -y catala
	clerk start
check:     ## type-check every Catala source
	clerk typecheck $(SRC)
run: check
clean:
	rm -rf _build
