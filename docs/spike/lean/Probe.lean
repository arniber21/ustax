import Spike.RateC
open Catala RateC

/-- Variant: no per-slice cent rounding (exact sum, then round to dollar). -/
def exactTax (fs : FilingStatus) (ti : Int) : Int :=
  let x := tableKey ti
  let bs := schedule fs
  let uppers := (bs.drop 1).map (·.lower) ++ [100000000000]
  let s : Rat := ((bs.zip uppers).map fun (b, u) =>
    ((Money.positive (Money.min x u - b.lower) : Int) : Rat) * b.rate).foldl (· + ·) 0
  round (s / 100) * 100

/-- Variant: banker's rounding (half to even) at the dollar. -/
def halfEven (q : Rat) : Int :=
  let f := q.floor
  let d := q - f
  if d > 1/2 then f + 1 else if d < 1/2 then f else if f % 2 == 0 then f else f + 1

def evenTax (fs : FilingStatus) (ti : Int) : Int :=
  let x := tableKey ti
  let bs := schedule fs
  let uppers := (bs.drop 1).map (·.lower) ++ [100000000000]
  halfEven ((Money.sum ((bs.zip uppers).map fun (b, u) =>
    mulMonRat (Money.positive (Money.min x u - b.lower)) b.rate) : Rat) / 100) * 100

def countDiff (f g : Int → Int) (lo hi step : Nat) : Nat := Id.run do
  let mut n := 0
  for k in [0:(hi - lo) / step] do
    let i : Int := lo + k * step
    if f i != g i then n := n + 1
  return n

#eval countDiff (tax .single) (exactTax .single) 10000000 10200000 1
#eval countDiff (tax .single) (evenTax .single) 0 10000000 100
