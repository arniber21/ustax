import Spike.Runtime
/-!
# Option (c): the calculator written directly in Lean

Same rule as `catala/rate.catala_en`, written for reading and proving: total
functions, no `Option`/`Except` plumbing, the exception tree flattened into an
`if` chain in the order Catala's exceptions take priority. Reuses the runtime's
rounding (`mulMonRat`, `roundMoney`) so money semantics match Catala exactly.
-/
open Catala

namespace RateC

inductive FilingStatus where
  | single | mfj | mfs | hoh | qss
  deriving Repr, DecidableEq, Inhabited

/-- A bracket: lower bound (cents) and marginal rate. The upper bound is the
next bracket's lower bound. -/
structure Bracket where
  lower : Money
  rate : Decimal

/-- 2024 rate schedules, Rev. Proc. 2023-34 §3.01 (lower bounds in dollars). -/
def schedule : FilingStatus → List Bracket
  | .single => mk [(0, 10), (11600, 12), (47150, 22), (100525, 24), (191950, 32), (243725, 35), (609350, 37)]
  | .mfs => mk [(0, 10), (11600, 12), (47150, 22), (100525, 24), (191950, 32), (243725, 35), (365600, 37)]
  | .hoh => mk [(0, 10), (16550, 12), (63100, 22), (100500, 24), (191950, 32), (243700, 35), (609350, 37)]
  | .mfj | .qss => mk [(0, 10), (23200, 12), (94300, 22), (201050, 24), (383900, 32), (487450, 35), (731200, 37)]
where mk (l : List (Int × Nat)) : List Bracket := l.map fun (d, p) => ⟨d * 100, (p : Rat) / 100⟩

/-- Tax Table lookup key (scope.md §2.1), in cents. -/
def tableKey (ti : Int) : Int :=
  if ti ≤ 0 then 0
  else if ti < 500 then 250
  else if ti < 1500 then 1000
  else if ti < 2500 then 2000
  else if ti < 300000 then ti / 2500 * 2500 + 1250
  else if ti < 10000000 then ti / 5000 * 5000 + 2500
  else ti

/-- Marginal tax on `x` cents: each slice is rounded to the cent (Catala's
`money * decimal`), then the sum is rounded to the dollar. -/
def scheduleTax (fs : FilingStatus) (x : Money) : Money :=
  let bs := schedule fs
  let uppers := (bs.drop 1).map (·.lower) ++ [100000000000]
  roundMoney (Money.sum ((bs.zip uppers).map fun (b, u) =>
    mulMonRat (Money.positive (Money.min x u - b.lower)) b.rate))

/-- Tentative tax (Form 1040 line 16). -/
def tax (fs : FilingStatus) (ti : Money) : Money := scheduleTax fs (tableKey ti)

#guard tax .single 5000000 = 605900
#guard tax .single 100000000 = 32818800
#guard tax .mfj 300 = 0
#guard tax .hoh 299900 = 29900

/-! Proof-cost probe: one lemma on the readable form. -/

theorem tableKey_nonneg (ti : Int) : 0 ≤ tableKey ti := by
  unfold tableKey
  repeat' split
  all_goals omega

theorem tableKey_mono {a b : Int} (h : a ≤ b) : tableKey a ≤ tableKey b := by
  unfold tableKey
  repeat' split
  all_goals omega

end RateC
