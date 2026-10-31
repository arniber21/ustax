import UsTax.Cli
import UsTax.Api.Parse

/-!
# `ustax`: run the Lean calculator from the command line

Build with `cd lean && lake build ustax`; the binary is `.lake/build/bin/ustax`.

* `ustax tentative-tax <taxable income> <filing status>` prints Form 1040
  line 16, e.g. `ustax tentative-tax 14999 single` prints `1565.00`.
* `ustax run <Scope>` reads one Catala JSON input object per line on stdin and
  writes one JSON output object per line (`{"error": ...}` for a bad input).
  Same input format as `clerk run -s <Scope> --input=<file>`; used by
  `difftest/lean_rates.mjs`.
* `ustax api-parse` reads one `POST /calculate` body per line on stdin and
  writes one line per body: `<HTTP status> TAB <body>`. Status 200 means the
  request was accepted (the body is the `Repr` of the typed request, so a
  test can see that no field was dropped); otherwise the body is the
  `ErrorResponse` JSON. Used by `scripts/api_conformance.mjs`.
-/

open UsTax Cli

/-- The usage message. -/
def usage : String :=
  "usage: ustax tentative-tax <taxable income> <filing status>\n" ++
  "       ustax api-parse     (request bodies, one per line, on stdin)\n" ++
  "       ustax run <Scope>   (JSON lines on stdin; scopes: " ++
  ", ".intercalate (scopes.map (·.1)) ++ ")"

/-- Run `scope` on each JSON line of `stdin` until end of input, one JSON
output line per input line. -/
def runLines (scope : String) (stdin : IO.FS.Stream) (stdout : IO.FS.Stream) : IO Unit := do
  repeat
    let line ← stdin.getLine
    if line.isEmpty then break
    let line := line.trimAscii.toString
    unless line.isEmpty do
      let out := match Lean.Json.parse line >>= runScope scope with
        | .ok j => j.compress
        | .error e => (Lean.Json.mkObj [("error", e)]).compress
      stdout.putStrLn out

/-- Parse each stdin line as a request body: `status TAB body`. -/
def apiParseLines (stdin : IO.FS.Stream) (stdout : IO.FS.Stream) : IO Unit := do
  repeat
    let line ← stdin.getLine
    if line.isEmpty then break
    let text := if line.endsWith "\n" then (line.dropEnd 1).toString else line
    match Api.parseRequest text with
    | .ok r =>
      let shown := ((repr r).pretty 100000000).replace "\n" " "
      stdout.putStrLn s!"200\t{shown}"
    | .error e => stdout.putStrLn s!"{e.status}\t{e.render}"

/-- Entry point; see the module docstring. -/
def main (args : List String) : IO UInt32 := do
  match args with
  | ["tentative-tax", income, status] =>
    match parseMoney income, FilingStatus.ofString? status with
    | some ti, some fs =>
      IO.println (showMoney (TaxRates.tentativeTaxFor ti fs))
      return 0
    | none, _ => IO.eprintln s!"bad taxable income {income.quote}"; return 2
    | _, none => IO.eprintln s!"bad filing status {status.quote}"; return 2
  | ["api-parse"] =>
    apiParseLines (← IO.getStdin) (← IO.getStdout)
    return 0
  | ["run", scope] =>
    if (scopes.lookup scope).isNone then
      IO.eprintln usage; return 2
    runLines scope (← IO.getStdin) (← IO.getStdout)
    return 0
  | _ => IO.eprintln usage; return 2
