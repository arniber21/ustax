import UsTax.Money

/-!
# Rounding-placement regression tests (spike, `docs/spike/lean/Probe.lean`)

The spike measured how much two plausible-looking rounding variants change the
TY2024 single-filer tax (`docs/catala-to-lean.md` section 3.2):

* dropping the per-slice cent rounding (exact sum, one dollar rounding at the
  end) changes the tax on **971 of 200,000** cent values from $100,000 to
  $102,000;
* replacing half-away-from-zero by half-to-even at the dollar step changes it
  on **30,700 of 100,000** dollar values below $100,000.

These `#guard`s recompute both counts with this library, so a change to
`roundRat`, `mulRate` or `roundDollar` that alters rounding placement or tie
behaviour fails the build. The single-filer brackets and the Tax Table key are
a **test fixture** copied from `docs/spike/lean/Spike/RateC.lean`; the real
rate module is issue #41.
-/

namespace UsTax.Money.Regression

/-- TY2024 single brackets (Rev. Proc. 2023-34 section 3.01): lower bound in
cents and marginal rate. Test fixture. -/
def singleBrackets : List (Int × Rat) :=
  [(0, 10), (11600, 12), (47150, 22), (100525, 24), (191950, 32), (243725, 35),
    (609350, 37)].map fun (d, p) => (d * 100, (p : Rat) / 100)

/-- Tax Table midpoint key (scope.md section 2.1), in cents. Test fixture. -/
def tableKey (ti : Int) : Int :=
  if ti ≤ 0 then 0
  else if ti < 500 then 250
  else if ti < 1500 then 1000
  else if ti < 2500 then 2000
  else if ti < 300000 then ti / 2500 * 2500 + 1250
  else if ti < 10000000 then ti / 5000 * 5000 + 2500
  else ti

/-- The slice of `x` taxed at each bracket's rate, with the bracket's rate. -/
def slices (x : Int) : List (Int × Rat) :=
  let uppers := (singleBrackets.drop 1).map (·.1) ++ [100000000000]
  (singleBrackets.zip uppers).map fun ((l, r), u) => (positive (min x u - l), r)

/-- Catala placement: each slice rounded to the cent, the sum to the dollar. -/
def taxCatala (ti : Int) : Int :=
  roundDollar (sum ((slices (tableKey ti)).map fun (s, r) => mulRate s r))

/-- Variant: no per-slice cent rounding; the exact sum is rounded once. -/
def taxExactSum (ti : Int) : Int :=
  let exact : Rat := ((slices (tableKey ti)).map fun (s, r) => (s : Rat) * r).foldl (· + ·) 0
  roundRat (exact / 100) * 100

/-- Half to even (banker's rounding), the wrong tie rule. -/
def roundHalfEven (q : Rat) : Int :=
  let f := q.floor
  let d := q - f
  if d > 1/2 then f + 1 else if d < 1/2 then f else if f % 2 == 0 then f else f + 1

/-- Variant: per-slice cent rounding kept, but half to even at the dollar. -/
def taxHalfEven (ti : Int) : Int :=
  roundHalfEven ((sum ((slices (tableKey ti)).map fun (s, r) => mulRate s r) : Rat) / 100) * 100

/-- Number of `k < count` with `f (lo + k * step) ≠ g (lo + k * step)`. -/
def countDiff (f g : Int → Int) (lo step : Int) (count : Nat) : Nat :=
  (List.range count).countP fun (k : Nat) =>
    let i := lo + (k : Int) * step
    f i != g i

-- Sanity: Single $50,000 is $6,059 in the 2024 Tax Table.
#guard taxCatala 5000000 = 605900

-- Every cent from $100,000 to $102,000 (200,000 values): 971 differ.
#guard countDiff taxCatala taxExactSum 10000000 1 200000 = 971

-- Every dollar below $100,000 (100,000 values): 30,700 differ.
#guard countDiff taxCatala taxHalfEven 0 100 100000 = 30700

end UsTax.Money.Regression
