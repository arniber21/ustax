/-!
# Spike: minimal Lean model of the Catala 1.3.0 OCaml runtime

Mirrors `runtimes/ocaml/catala_runtime.ml` (Catala 1.3.0) for the pieces the
rate-schedule toy needs. Core Lean only (`Rat` and `Int` are in core since 4.2x).
-/

namespace Catala

/-- Catala `money`: an integer number of cents (`type money = Z.t`). -/
abbrev Money := Int
/-- Catala `decimal`: an exact rational (`type decimal = Q.t`, Zarith). -/
abbrev Decimal := Rat
/-- Catala `integer`: unbounded (`Z.t`). -/
abbrev Integer := Int

/-- Runtime errors raised by generated code (`type error`, subset). -/
inductive Error where
  | noValue | conflict | divisionByZero | listEmpty | notSameLength
  deriving Repr, DecidableEq

/-- `round q = sgn(q) * floor(|q| + 1/2)`: half away from zero
(`catala_runtime.ml` `round`, which computes `fdiv (2n + d) (2d)` on `|q|`). -/
def round (q : Rat) : Int :=
  let a := if q < 0 then -q else q
  -- OCaml uses `Z.fdiv`; the divisor `2 * den` is positive, so floor division
  -- equals Lean's Euclidean `/`, which `omega` understands.
  let r := (2 * a.num + a.den) / (2 * (a.den : Int))
  if q < 0 then -r else r

/-- `money * decimal`: exact product, then round to the nearest cent. -/
def mulMonRat (m : Money) (r : Decimal) : Money := round ((m : Rat) * r)

/-- `money / money` is a decimal; division by zero is an error. -/
def divMonMon (m1 m2 : Money) : Except Error Decimal :=
  if m2 = 0 then .error .divisionByZero else .ok ((m1 : Rat) / (m2 : Rat))

/-- `integer of decimal`: `Q.to_bigint`, which truncates toward zero. -/
def intOfRat (q : Rat) : Integer := Int.tdiv q.num q.den

/-- `money * integer` goes through `decimal` (exact, so no rounding happens). -/
def mulMonInt (m : Money) (i : Integer) : Money := mulMonRat m (i : Rat)

/-- `round of money`: to the nearest whole dollar, half away from zero. -/
def roundMoney (m : Money) : Money := round ((m : Rat) / 100) * 100

/-- Stdlib `Money.min`, `Money.max`, `Money.positive`, `Money.sum`. -/
def Money.min (a b : Money) : Money := if a > b then b else a
def Money.max (a b : Money) : Money := if a > b then a else b
def Money.positive (m : Money) : Money := Money.max m 0
def Money.sum (l : List Money) : Money := l.foldl (· + ·) 0

/-- Default calculus: the value of an exception group.
`handle_exceptions`: none present = absent, one present = it, several = Conflict.
Positions are dropped. -/
def handleExceptions {α} (xs : List (Option α)) : Except Error (Option α) :=
  match xs.filterMap id with
  | [] => .ok none
  | [x] => .ok (some x)
  | _ => .error .conflict

/-- `<exceptions> | just :- cons`: exceptions first; otherwise the base case
if its justification holds; otherwise empty. -/
def default {α} (excepts : List (Option α)) (just : Bool) (cons : Unit → α) :
    Except Error (Option α) := do
  match ← handleExceptions excepts with
  | some x => pure (some x)
  | none => pure (if just then some (cons ()) else none)

/-- `ErrorOnEmpty`: a scope variable with no applicable rule is a `NoValue` error. -/
def errorOnEmpty {α} : Option α → Except Error α
  | some x => .ok x
  | none => .error .noValue

-- Unit tests against values printed by the OCaml runtime (see docs/catala-to-lean.md).
#guard round (1/2) = 1
#guard round (3/2) = 2
#guard round (5/2) = 3
#guard round (-1/2) = -1
#guard round (-5/2) = -3
#guard round (249/100) = 2
#guard roundMoney 1250 = 1300
#guard roundMoney (-1250) = -1300
#guard intOfRat (-7/2) = -3
#guard intOfRat (7/2) = 3
#guard mulMonRat 1 (1/2) = 1      -- half a cent rounds away from zero
#guard mulMonRat (-1) (1/2) = -1
#guard (match handleExceptions [some 1, none, some 2] with
  | .error .conflict => true | _ => false)
#guard (match handleExceptions [none, some 2, none] with
  | .ok (some 2) => true | _ => false)

end Catala
