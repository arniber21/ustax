"""Source scan for proof escape hatches (scripts/audit.sh, step 1).

Usage: python3 -I scripts/audit_scan.py <lean-dir>

Scans every .lean file under <lean-dir>/UsTax, except UsTax/Comparator/, after
removing comments and string literals (so a docstring that says "no sorry" does
not trip it). Exit 1 and print file:line for each hit.
"""
import re
import sys
from pathlib import Path

PATTERNS = [
    ("sorry", r"\bsorry\b"),
    ("admit", r"\badmit\b"),
    ("native_decide", r"\bnative_decide\b"),
    ("bv_decide (native axiom)", r"\bbv_decide\b"),
    ("axiom declaration", r"^\s*(?:@\[[^\]]*\]\s*)*(?:private\s+|protected\s+)?axiom\b"),
    ("debug.skipKernelTC", r"skipKernelTC"),
    ("maxHeartbeats 0", r"\bmaxHeartbeats\s+0\b"),
    ("implemented_by", r"\bimplemented_by\b"),
    ("extern", r"\bextern\b"),
    ("unsafe", r"\bunsafe\b"),
]


def blank(text: str) -> str:
    """Replace comments and string literals by spaces, keeping newlines."""
    out = []
    i, n, depth = 0, len(text), 0
    while i < n:
        two = text[i:i + 2]
        if depth > 0:
            if two == "/-":
                depth += 1
                out.append("  ")
                i += 2
            elif two == "-/":
                depth -= 1
                out.append("  ")
                i += 2
            else:
                out.append("\n" if text[i] == "\n" else " ")
                i += 1
        elif two == "/-":
            depth = 1
            out.append("  ")
            i += 2
        elif two == "--":
            while i < n and text[i] != "\n":
                out.append(" ")
                i += 1
        elif text[i] == '"':
            out.append(" ")
            i += 1
            while i < n and text[i] != '"':
                if text[i] == "\\" and i + 1 < n:
                    out.append(" ")
                    i += 1
                out.append("\n" if text[i] == "\n" else " ")
                i += 1
            out.append(" ")
            i += 1
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


def main() -> int:
    root = Path(sys.argv[1]) / "UsTax"
    hits = []
    nfiles = 0
    for f in sorted(root.rglob("*.lean")):
        if f.relative_to(root).parts[0] == "Comparator":
            continue
        nfiles += 1
        for lineno, line in enumerate(blank(f.read_text()).splitlines(), 1):
            for name, pat in PATTERNS:
                if re.search(pat, line):
                    hits.append(f"{f.relative_to(root.parent)}:{lineno}: {name}")
    for h in hits:
        print("  " + h)
    print(f"scanned {nfiles} files, {len(hits)} forbidden construct(s)")
    return 1 if hits else 0


sys.exit(main())
