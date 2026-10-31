/-!
# Money, decimals and rounding with Catala 1.3.0 semantics (issue #39)

The Lean calculator (strategy (c), `docs/catala-to-lean.md`) must round
exactly where, and exactly how, the Catala spec rounds. This module ports the
Catala 1.3.0 runtime primitives and the stdlib `Money` functions the spec uses,
plus the Direct File helpers of `catala/rounding.catala_en`.

Sources, all read for this port:
* `sources/reference-catala/catala/runtimes/ocaml/catala_runtime.ml`
  (`round`, `money_of_decimal`, `money_round`, `integer_of_decimal`,
  `o_mult_mon_rat`, `o_div_mon_rat`, `o_div_mon_mon`);
* `sources/reference-catala/catala/stdlib/money_en.catala_en` and
  `stdlib/ocaml/money_internal.ml` (`Money.*`, `round_to_decimal`);
* `sources/reference-catala/catala/stdlib/decimal_en.catala_en`
  (`Decimal.truncate`);
* `catala/rounding.catala_en` (`round_dollar`, `round_dollar_exact`,
  `truncate_cents`, `stepwise_multiply`).

## Representation

* Catala `money` is an integer number of **cents**: a plain `Int` here.
  There is deliberately no `abbrev Money := Int`: `omega` does not use
  hypotheses whose type mentions the alias (found in the spike, re-checked on
  Lean 4.35), and later modules prove things with `omega`. Every function in
  namespace `UsTax.Money` takes and returns cents.
* Catala `decimal` is an exact rational: core `Rat`. Nothing here rounds a
  `Rat` except the functions documented as rounding.
* Catala `integer` is `Int`.

No `Nat` appears in any money computation (CLAUDE.md section 6).

## Division by zero

Catala raises `DivisionByZero` for `money / decimal 0`, `money / $0` and
`decimal / 0`. Lean's `Rat` has `x / 0 = 0` and `0⁻¹ = 0`, so the Lean
functions return a value there (`0`) instead of failing. Callers must keep
divisors nonzero, as the Catala spec must; the differential test (#42) records
Catala errors as outcomes and so shows any input where this differs.
-/

namespace UsTax

/-- `a / b` rounded to the nearest integer, ties away from zero, for `b > 0`.
Integer-only form of Catala's `round` (`roundRat`); see
`Money.roundRat_eq_roundDiv`. Stated with Lean's `/` (Euclidean division) on a
positive divisor, which is floor division there and is what `omega` reads. -/
def roundDiv (a b : Int) : Int :=
  if a < 0 then -((2 * -a + b) / (2 * b)) else (2 * a + b) / (2 * b)

example : roundDiv 5 2 = 3 ∧ roundDiv (-5) 2 = -3 ∧ roundDiv 249 100 = 2 := by decide

namespace Money

/-! ## Runtime primitives (`catala_runtime.ml`) -/

/-- Catala `round` on a decimal: `sgn q * floor (|q| + 1/2)`, ties away from
zero. The runtime computes `Z.fdiv (2n + d) (2d)` on `|q| = n/d`; the divisor
`2d` is positive, so OCaml's floor division `Z.fdiv` equals Lean's `/`. -/
def roundRat (q : Rat) : Int :=
  let a := if q < 0 then -q else q
  let r := (2 * a.num + a.den) / (2 * (a.den : Int))
  if q < 0 then -r else r

/-- Catala `integer of decimal` (`Q.to_bigint`): truncation toward zero. -/
def intOfRat (q : Rat) : Int := Int.tdiv q.num q.den

/-- Catala `decimal of money`: the amount in dollars, exact. -/
def toRat (m : Int) : Rat := (m : Rat) / 100

/-- Catala `money of decimal`: dollars to cents, rounded to the nearest cent,
ties away from zero (`money_of_decimal`). -/
def ofRat (d : Rat) : Int := roundRat (d * 100)

/-- Catala `money * decimal` (`o_mult_mon_rat`): the exact product in cents,
rounded to the nearest cent, ties away from zero. Every `money * rate` in a
Catala source is a cent-rounding point. -/
def mulRate (m : Int) (r : Rat) : Int := roundRat ((m : Rat) * r)

/-- Catala `money * integer` (`o_mult_mon_int`): goes through `decimal`, so it
is exact (`mulInt_eq`). -/
def mulInt (m i : Int) : Int := mulRate m (i : Rat)

/-- Catala `money / decimal` (`o_div_mon_rat`): multiply by the inverse, then
round to the cent. Precondition `r ≠ 0` (Catala raises `DivisionByZero`). -/
def divRate (m : Int) (r : Rat) : Int := mulRate m r⁻¹

/-- Catala `money / integer` (`o_div_mon_int`). Precondition `i ≠ 0`. -/
def divInt (m i : Int) : Int := divRate m (i : Rat)

/-- Catala `money / money` (`o_div_mon_mon`): an exact decimal, no rounding.
Precondition `m₂ ≠ 0`. -/
def divMoney (m₁ m₂ : Int) : Rat := (m₁ : Rat) / (m₂ : Rat)

/-- Catala `round of money` (`money_round`): to the nearest whole dollar, ties
away from zero. It is Direct File `Round` (`setScale(0, HALF_UP)`) on every
sign, and `R.round_dollar` in `catala/rounding.catala_en`. -/
def roundDollar (m : Int) : Int := roundRat ((m : Rat) / 100) * 100

/-! ## Stdlib `Decimal` -/

/-- Stdlib `Decimal.truncate`, ported literally: removes the fractional part,
toward zero. Equal to `intOfRat` (`truncateRat_eq`). -/
def truncateRat (d : Rat) : Rat :=
  if d = 0 then 0
  else if d > 0 then (roundRat (d - 1/2) : Rat)
  else (roundRat (d + 1/2) : Rat)

/-! ## Stdlib `Money` (`money_en.catala_en`), ported literally -/

/-- `Money.min`: the smaller of the two. -/
def min (m₁ m₂ : Int) : Int := if m₁ > m₂ then m₂ else m₁

/-- `Money.max`: the bigger of the two. Direct File `GreaterOf`. -/
def max (m₁ m₂ : Int) : Int := if m₁ > m₂ then m₁ else m₂

/-- `Money.ceiling of m, cap`: `m`, capped at `cap` from above. -/
def ceiling (m cap : Int) : Int := min m cap

/-- `Money.floor of m, low`: `m`, bounded below by `low`. -/
def floor (m low : Int) : Int := max m low

/-- `Money.positive`: `m` if it is positive, else `$0`
(Direct File `GreaterOf(x, 0)`). -/
def positive (m : Int) : Int := floor m 0

/-- `Money.in_excess of m, ref`: how much `m` exceeds `ref`, else `$0`. -/
def inExcess (m ref : Int) : Int := max 0 (m - ref)

/-- `Money.in_default of m, ref`: how much `m` falls short of `ref`, else `$0`. -/
def inDefault (m ref : Int) : Int := max 0 (ref - m)

/-- `Money.sum`: a left fold from `$0`. -/
def sum (l : List Int) : Int := l.foldl (· + ·) 0

/-- `Money.truncate`: removes the cents, toward zero ($7.61 to $7,
-$7.61 to -$7). Literal port: `round of (m - $0.5)` for positive `m`. -/
def truncate (m : Int) : Int :=
  if m = 0 then 0
  else if m > 0 then roundDollar (m - 50)
  else roundDollar (m + 50)

/-- `Money.round_by_excess`: up to the next whole dollar ($4.34 to $5,
-$4.34 to -$4). Literal port. -/
def roundByExcess (m : Int) : Int :=
  if m ≥ 0 then roundDollar (m + 49) else roundDollar (m + 50)

/-- `Money.round_by_default`: down to the previous whole dollar ($3.78 to $3,
-$3.78 to -$4). Literal port. -/
def roundByDefault (m : Int) : Int :=
  if m > 0 then roundDollar (m - 50) else roundDollar (m - 49)

/-- `Money.round_to_decimal of m, n`, a literal port of the OCaml external
`Money_internal.round_to_decimal` (`stdlib/ocaml/money_internal.ml`):

* `n ≥ 2`: `m` unchanged;
* `n = 1`: `money_round (m * 10) / 10`;
* `n ≤ 0`: `money_round (m / 10^(-n)) * 10^(-n)`.

Both divisions are `Z.div`, which truncates toward zero: `Int.tdiv` here.
The `n ≤ 0` case divides the **cents**, so it is "round to `10^(-n)` cents
after a truncation", not "round to `10^(-n)` dollars". It equals rounding to
`10^(2-n)` cents only together with the `+ $499.99` offset of
`roundUpToThousand`, and only for nonnegative amounts. (OCaml's `Z.to_int n`
overflows for `|n| ≥ 2^62`; Catala then fails, Lean does not.) -/
def roundToDecimal (m n : Int) : Int :=
  if n ≥ 2 then m
  else if n = 1 then Int.tdiv (roundDollar (m * 10)) 10
  else
    let pow10 : Int := 10 ^ (-n).toNat
    roundDollar (Int.tdiv m pow10) * pow10

/-- Round up to the next multiple of $1,000 (Schedule 8812 line 10 style), the
Catala idiom verified in `sources/CATALA_PATTERNS.md` section 1:
`Money.round_to_decimal of (m + $499.99), -3`. For `m ≥ 0` it is the ceiling
to $1,000 (`roundUpToThousand_eq_ceil`); for negative `m` it is **not** a
ceiling (-$999.99 gives -$1,000), so callers must pass a nonnegative amount. -/
def roundUpToThousand (m : Int) : Int := roundToDecimal (m + 49999) (-3)

/-! ## Direct File helpers (`catala/rounding.catala_en`, module `Rounding`) -/

/-- `R.round_dollar_exact of m, r`: `$1 * (round of ((m / $1) * r))`. Rounds
the exact product once, to the dollar, with no cent rounding first. -/
def roundDollarExact (m : Int) (r : Rat) : Int :=
  mulRate 100 (roundRat (divMoney m 100 * r) : Rat)

/-- `R.truncate_cents of d`: Direct File `TruncateCents`, `d` dollars kept to
two decimals, toward zero (`$0.01 * (Decimal.truncate of (d * 100.0))`). -/
def truncateCents (d : Rat) : Int := mulRate 1 (truncateRat (d * 100))

/-- `R.stepwise_multiply of m, num, den`: Direct File `StepwiseMultiply`,
`Dollar(m.intValue / den * num)`: drop the cents (toward zero), integer-divide
the dollars by `den` (toward zero), multiply by `num`. With `50, 50` it is the
bottom of the $50 Tax Table row containing `m`. Precondition `den ≠ 0`. -/
def stepwiseMultiply (m num den : Int) : Int :=
  let wholeDollars : Rat := divMoney (truncate m) 100
  mulRate 100 (truncateRat (wholeDollars / (den : Rat)) * (num : Rat))

/-! ## Unit tests

Values from the Catala 1.3.0 OCaml runtime (`docs/spike/ocaml/rt.ml`), the
stdlib docstrings, `catala/tests/test_rounding.catala_en` and
`sources/CATALA_PATTERNS.md` section 1. Amounts are in cents. -/

-- Catala `round` (runtime, `rt.ml`).
#guard roundRat (1/2) = 1
#guard roundRat (3/2) = 2
#guard roundRat (5/2) = 3
#guard roundRat (-1/2) = -1
#guard roundRat (-5/2) = -3
#guard roundRat (249/100) = 2
#guard roundRat 0 = 0
-- `integer of decimal` truncates; `round` does not.
#guard intOfRat (-7/2) = -3
#guard intOfRat (7/2) = 3
-- Cent rounding of products, ties away from zero (`rt.ml`).
#guard mulRate 1 (1/2) = 1
#guard mulRate (-1) (1/2) = -1
#guard mulRate 5 (1/4) = 1
#guard ofRat (1/200) = 1
#guard divRate 100 3 = 33
#guard divInt 100 3 = 33
#guard mulInt 1234 3 = 3702
-- Dollar rounding: the conventions issue's tie cases ($0.50, $1.50, $2.50,
-- -$0.50) and the rest of `test_rounding.catala_en`.
#guard roundDollar 50 = 100
#guard roundDollar 150 = 200
#guard roundDollar 250 = 300
#guard roundDollar (-50) = -100
#guard roundDollar 49 = 0
#guard roundDollar 51 = 100
#guard roundDollar 139 = 100
#guard roundDollar 249 = 200
#guard roundDollar (-49) = 0
#guard roundDollar (-150) = -200
#guard roundDollar (-251) = -300
#guard roundDollar 0 = 0
#guard roundDollar 1460000 = 1460000
#guard roundDollar 1250 = 1300
#guard roundDollar (-1250) = -1300
#guard roundDollar (-1249) = -1200
-- Banker's rounding (half to even) would give 200 and 1200 here.
#guard roundDollar 250 ≠ 200 ∧ roundDollar 1250 ≠ 1200
-- Double rounding versus one rounding of the exact product.
#guard mulRate 1000000 (11154958/100000000) = 111550
#guard roundDollar (mulRate 1000000 (11154958/100000000)) = 111600
#guard roundDollarExact 1000000 (11154958/100000000) = 111500
#guard roundDollarExact 1000000 (11155/100000) = 111600
#guard roundDollarExact (-1000000) (11155/100000) = -111600
-- TruncateCents.
#guard truncateCents (1239/1000) = 123
#guard truncateCents (12/10) = 120
#guard truncateCents (11154958/10000) = 111549
#guard truncateCents (-1239/1000) = -123
#guard truncateCents 0 = 0
-- StepwiseMultiply.
#guard stepwiseMultiply 1234599 50 50 = 1230000
#guard stepwiseMultiply 1235000 50 50 = 1235000
#guard stepwiseMultiply 1234999 50 50 = 1230000
#guard stepwiseMultiply 299900 25 25 = 297500
#guard stepwiseMultiply 4999 50 50 = 0
#guard stepwiseMultiply 199999 1000 1000 = 100000
#guard stepwiseMultiply (-7550) 50 50 = -5000
#guard stepwiseMultiply 1100 7 2 = 3500
-- Stdlib `Money` docstring examples.
#guard truncate 761 = 700
#guard truncate (-761) = -700
#guard roundByExcess 434 = 500
#guard roundByExcess (-434) = -400
#guard roundByDefault 378 = 300
#guard roundByDefault (-378) = -400
#guard roundToDecimal 12345 1 = 12350
#guard roundToDecimal 12345 (-2) = 10000
-- Checked with `catala interpret` (Catala 1.3.0), 2026-10-31.
#guard roundToDecimal (-12345) 1 = -12350
#guard roundToDecimal (-12345) (-2) = -10000
#guard truncate (-750) = -700
#guard sum [1000, 2500, 500] = 4000
#guard sum [] = 0
#guard positive (-5) = 0 ∧ positive 5 = 5
#guard min 3 (-4) = -4 ∧ max 3 (-4) = 3
#guard inExcess 700 500 = 200 ∧ inExcess 300 500 = 0
#guard inDefault 300 500 = 200 ∧ inDefault 700 500 = 0
-- Round up to $1,000 (CATALA_PATTERNS.md section 1, verified on 1.3.0).
#guard roundUpToThousand 100000 = 100000
#guard roundUpToThousand 100001 = 200000
#guard roundUpToThousand 0 = 0
#guard roundUpToThousand 1 = 100000
-- ... and it is not a ceiling below zero: -$999.99 gives -$1,000.
#guard roundUpToThousand (-99999) = -100000

end Money
end UsTax
