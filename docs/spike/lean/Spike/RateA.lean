import Spike.Runtime
/-!
# Option (a): mechanical hand port of the Catala-generated OCaml / scalc

Line-by-line transcription of `out/rate.ml` (`catala ocaml`), keeping the
default-calculus structure (Optional per exception level, `NoValue` on empty).
This is what a translator (option b) would also emit, modulo naming.
-/
open Catala

namespace RateA

inductive FilingStatus where
  | single | marriedFilingJointly | marriedFilingSeparately | headOfHousehold
  | qualifyingSurvivingSpouse
  deriving Repr, DecidableEq, Inhabited

structure Bracket where
  lower : Money
  upper : Money
  rate : Decimal

structure TaxScheduleIn where
  filingStatus : FilingStatus
  taxableIncome : Money

structure TaxSchedule where
  tax : Money
  deriving Repr

def b (l u : Int) (r : Rat) : Bracket := ⟨l * 100, u * 100, r⟩

def taxSchedule (i : TaxScheduleIn) : Except Error TaxSchedule := do
  let filingStatus := i.filingStatus
  let taxableIncome := i.taxableIncome
  let brackets : Option (List Bracket) := some <|
    match filingStatus with
    | .single => [b 0 11600 (1/10), b 11600 47150 (3/25), b 47150 100525 (11/50),
        b 100525 191950 (6/25), b 191950 243725 (8/25), b 243725 609350 (7/20),
        b 609350 1000000000 (37/100)]
    | .marriedFilingSeparately => [b 0 11600 (1/10), b 11600 47150 (3/25),
        b 47150 100525 (11/50), b 100525 191950 (6/25), b 191950 243725 (8/25),
        b 243725 365600 (7/20), b 365600 1000000000 (37/100)]
    | .headOfHousehold => [b 0 16550 (1/10), b 16550 63100 (3/25),
        b 63100 100500 (11/50), b 100500 191950 (6/25), b 191950 243700 (8/25),
        b 243700 609350 (7/20), b 609350 1000000000 (37/100)]
    | .marriedFilingJointly | .qualifyingSurvivingSpouse => [b 0 23200 (1/10),
        b 23200 94300 (3/25), b 94300 201050 (11/50), b 201050 383900 (6/25),
        b 383900 487450 (8/25), b 487450 731200 (7/20), b 731200 1000000000 (37/100)]
  -- exception tree, innermost exception first (scalc lines 74-120)
  let r3 : Option Money :=
    if taxableIncome < 2500 then
      some (if taxableIncome ≤ 0 then 0 else if taxableIncome < 500 then 250
            else if taxableIncome < 1500 then 1000 else 2000)
    else none
  let r2 ← match r3 with
    | none =>
      if taxableIncome < 300000 then do
        let q ← divMonMon taxableIncome 2500
        pure (some (mulMonInt 2500 (intOfRat q) + 1250))
      else pure none
    | some x => pure (some x)
  let r1 ← match r2 with
    | none =>
      if taxableIncome < 10000000 then do
        let q ← divMonMon taxableIncome 5000
        pure (some (mulMonInt 5000 (intOfRat q) + 2500))
      else pure none
    | some x => pure (some x)
  let roundedTaxableIncome : Option Money :=
    match r1 with
    | none => some taxableIncome
    | some x => some x
  let rti ← errorOnEmpty roundedTaxableIncome
  let bs ← errorOnEmpty brackets
  let tax := roundMoney (Money.sum (bs.map fun b =>
    mulMonRat (Money.positive (Money.min rti b.upper - b.lower)) b.rate))
  pure { tax }

def tax (fs : FilingStatus) (ti : Money) : Option Money :=
  match taxSchedule ⟨fs, ti⟩ with
  | .ok r => some r.tax
  | .error _ => none

-- the four Catala unit tests
#guard tax .single 5000000 = some 605900
#guard tax .single 100000000 = some 32818800
#guard tax .marriedFilingJointly 300 = some 0
#guard tax .headOfHousehold 299900 = some 29900

end RateA
