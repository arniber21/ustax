#!/usr/bin/env python3
"""Derive the 2024 Earned Income Credit (EIC) Table as a CSV.

Reads sources/forms-instructions/i1040gi--2024.pdf pages 46 to 56 (the EIC
Table of the Form 1040 instructions) with `pdftotext -layout` and writes
sources/forms-instructions/derived-eic-table-2024.csv, one row per printed row
"At least X, but less than X + 50" (the first row is 1 to 50, the last is
66,800 to 66,850), with the eight printed credit columns:

  s0 s1 s2 s3     single, head of household, qualifying surviving spouse (and
                  married filing separately under the separated-spouse rule),
                  0, 1, 2, 3 or more qualifying children
  mfj0 .. mfj3    married filing jointly, same children counts

The file is DERIVED from the IRS PDF by this script, not an IRS publication.
Cells printed as "*" or "**" take the value of the footnote of their page
("If the amount you are looking up ... is at least $X but less than $Y, and
you have N qualifying children ... your credit is $V"); the script checks the
footnote's row and child count against the cell.

Run from the repository root: python3 scripts/derive_eic_table.py
Needs `pdftotext` (poppler).
"""
import csv
import re
import subprocess
import sys

PDF = "sources/forms-instructions/i1040gi--2024.pdf"
OUT = "sources/forms-instructions/derived-eic-table-2024.csv"
FIRST_PAGE, LAST_PAGE = 46, 56
COLS = ["s0", "s1", "s2", "s3", "mfj0", "mfj1", "mfj2", "mfj3"]
KIDS = {"no": 0, "one": 1, "two": 2, "three": 3}

TOKEN = re.compile(r"\d{1,3}(?:,\d{3})*|\*+")
NOTE = re.compile(
    r"at least \$([\d,]+) but less than \$([\d,]+), and you have "
    r"(no|one|two|three) qualifying\s+child(?:ren)? who (?:has a|have) valid\s+SSNs?,\s+"
    r"your credit is \$(\d+)")


def num(s):
    return int(s.replace(",", ""))


def page_text(p):
    return subprocess.run(
        ["pdftotext", "-layout", "-f", str(p), "-l", str(p), PDF, "-"],
        check=True, capture_output=True, text=True).stdout


def main():
    rows = {}
    for p in range(FIRST_PAGE, LAST_PAGE + 1):
        text = page_text(p)
        notes = {}
        flat = re.sub(r"\s+", " ", text)
        for m in NOTE.finditer(flat):
            notes[(num(m.group(1)), KIDS[m.group(3)])] = (num(m.group(2)), int(m.group(4)))
        for line in text.splitlines():
            toks = TOKEN.findall(line)
            if len(toks) not in (10, 20):
                continue
            for half in ([toks[:10], toks[10:]] if len(toks) == 20 else [toks]):
                lo, hi = num(half[0]), num(half[1])
                assert hi - lo == 50 or (lo == 1 and hi == 50), (p, half)
                vals = []
                for i, v in enumerate(half[2:]):
                    if v.startswith("*"):
                        key = (lo, i % 4)
                        assert key in notes, (p, lo, i)
                        vals.append(notes[key][1])
                    else:
                        vals.append(num(v))
                assert lo not in rows, ("duplicate row", lo, p)
                rows[lo] = vals
    keys = sorted(rows)
    expected = [1] + list(range(50, keys[-1] + 1, 50))
    assert keys == expected, "rows are not contiguous"
    assert keys[-1] == 66800, keys[-1]
    with open(OUT, "w", newline="") as f:
        f.write("# DERIVED from sources/forms-instructions/i1040gi--2024.pdf pp 46-56 by scripts/derive_eic_table.py.\n")
        f.write("# Not an IRS publication. Columns: single/HoH/QSS (s) and married filing jointly (mfj) by 0, 1, 2, 3+ qualifying children.\n")
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["at_least", "but_less_than"] + COLS)
        for k in keys:
            w.writerow([k, 50 if k == 1 else k + 50] + rows[k])
    print(f"{len(keys)} rows written to {OUT}", file=sys.stderr)


if __name__ == "__main__":
    main()
