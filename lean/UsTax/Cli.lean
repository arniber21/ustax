import Lean.Data.Json
import UsTax.TaxRates

/-!
# Command-line and JSON boundary of the Lean calculator

The `ustax` executable (`lean/Main.lean`) is a thin wrapper over this module.
Each Catala scope implemented in Lean gets one entry in `scopes`: a function
from the scope's **Catala JSON input** (the object `clerk run -s <Scope>
--input=<file>` accepts; `catala json-schema -s <Scope>` prints its shape) to
a JSON object of the scope's outputs, keyed by the Catala output names. So the
differential test feeds the same input object to Catala and to Lean and
compares outputs by name.

Money crosses the boundary as a decimal string or JSON number of dollars with
at most two decimals (`"14999"`, `"123456.78"`, `-3.5`), parsed exactly to
cents: never through a float. Outputs are strings with two decimals
(`"1565.00"`). Enumerations are their Catala case names (`"Single"`); Direct
File's spelling (`"single"`) is accepted too.
-/

namespace UsTax.Cli

open Lean (Json JsonNumber)

/-- Parse dollars (`"1,234.5"`, `"-$3.50"`, `"7"`) to cents, exactly. At most
two decimals; anything else is `none`. -/
def parseMoney (s : String) : Option Int := do
  let s := s.trimAscii.toString
  let (neg, s) := if s.startsWith "-" then (true, (s.drop 1).toString) else (false, s)
  let s := if s.startsWith "$" then (s.drop 1).toString else s
  let s := s.replace "," ""
  let (whole, frac) ← match s.splitOn "." with
    | [w] => some (w, "")
    | [w, f] => some (w, f)
    | _ => none
  guard (whole.length > 0 && frac.length ≤ 2)
  guard ((whole ++ frac).all Char.isDigit)
  let cents := whole.toNat! * 100 + (frac ++ "00".drop frac.length).toNat!
  return if neg then -(cents : Int) else cents

/-- Cents to dollars with two decimals: `156500` is `"1565.00"`. -/
def showMoney (c : Int) : String :=
  let a := c.natAbs
  let cents := toString (a % 100)
  (if c < 0 then "-" else "") ++ toString (a / 100) ++ "." ++
    (if cents.length < 2 then "0" ++ cents else cents)

/-- Money from a Catala JSON input value: a string or an exact JSON number. -/
def moneyOfJson : Json → Except String Int
  | .str s => match parseMoney s with
    | some c => .ok c
    | none => .error s!"bad money {s.quote}"
  | .num n =>
    if n.exponent ≤ 2 then .ok (n.mantissa * 10 ^ (2 - n.exponent))
    else
      let d : Int := 10 ^ (n.exponent - 2)
      if n.mantissa % d = 0 then .ok (n.mantissa / d)
      else .error s!"money with more than two decimals: {n}"
  | j => .error s!"bad money {j.compress}"

/-- A filing status from its Catala or Direct File name. -/
def filingStatusOfJson (j : Json) : Except String FilingStatus := do
  let s ← j.getStr?
  match FilingStatus.ofString? s with
  | some fs => .ok fs
  | none => .error s!"bad filing status {s.quote}"

/-- Field `k` of a JSON object. -/
def field (j : Json) (k : String) : Except String Json :=
  match j.getObjVal? k with
  | .ok v => .ok v
  | .error _ => .error s!"missing input {k}"

/-- Catala scope `Tax_rates.TentativeTax` on its JSON input. -/
def runTentativeTax (j : Json) : Except String Json := do
  let i : TaxRates.TentativeTaxIn :=
    { taxableIncome := ← moneyOfJson (← field j "taxable_income")
      filingStatus := ← filingStatusOfJson (← field j "filing_status") }
  let o := TaxRates.tentativeTax i
  return Json.mkObj [
    ("rounded_taxable_income", showMoney o.roundedTaxableIncome),
    ("tentative_tax_from_taxable_income", showMoney o.tentativeTaxFromTaxableIncome),
    ("tentative_tax_cumulative_form", showMoney o.tentativeTaxCumulativeForm)]

/-- The scopes implemented in Lean, by Catala scope name. Add one line per
new module. -/
def scopes : List (String × (Json → Except String Json)) :=
  [("TentativeTax", runTentativeTax)]

/-- Run scope `name` on one JSON input. -/
def runScope (name : String) (input : Json) : Except String Json :=
  match scopes.lookup name with
  | some f => f input
  | none => .error s!"unknown scope {name}; known: {scopes.map (·.1)}"

#guard parseMoney "14999" == some 1499900
#guard parseMoney "123,456.78" == some 12345678
#guard parseMoney "-$3.5" == some (-350)
#guard parseMoney "0.01" == some 1
#guard parseMoney "1.234" == none
#guard parseMoney "abc" == none
#guard parseMoney "" == none
#guard showMoney 156500 == "1565.00"
#guard showMoney (-350) == "-3.50"
#guard showMoney 7 == "0.07"
#guard (do moneyOfJson (← Json.parse "123456.78")).toOption == some 12345678
#guard (do moneyOfJson (← Json.parse "-3.5")).toOption == some (-350)
#guard (do moneyOfJson (← Json.parse "1e3")).toOption == some 100000
#guard ((do moneyOfJson (← Json.parse "0.125")) matches .error _)
#guard (do let o ← runScope "TentativeTax" (← Json.parse
    "{\"taxable_income\": \"14999\", \"filing_status\": \"Single\"}"); return o.compress).toOption ==
  some "{\"rounded_taxable_income\":\"14975.00\",\"tentative_tax_cumulative_form\":\"1565.00\",\"tentative_tax_from_taxable_income\":\"1565.00\"}"

end UsTax.Cli
