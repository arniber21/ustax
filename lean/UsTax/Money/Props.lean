import UsTax.Money
import Plausible

/-!
# Property tests for `UsTax.Money` (plausible)

Each statement below was tested with plausible before its proof in
`UsTax/Money/Lemmas.lean` was written (CLAUDE.md section 5). They run on every
build as `#eval` checks: a counterexample fails the build. They use
`Testable.check`, not the `plausible` tactic, so nothing is admitted.

Rationals are generated as `a / b` with `a : Int` and `b` a positive `Nat`.
-/

namespace UsTax.Money.Props
open Plausible

/-- `#prop p`: run plausible on `p` with 500 random instances. A
counterexample is an error, so it fails the build. -/
local macro "#prop " p:term : command =>
  `(command| #eval Testable.check $p { numInst := 500 })

-- roundDiv: monotone in the numerator, odd, within half of the quotient.
#prop (∀ a c : Int, ∀ b : Nat, a ≤ c → roundDiv a (b + 1) ≤ roundDiv c (b + 1))
#prop (∀ a : Int, ∀ b : Nat, roundDiv (-a) (b + 1) = -roundDiv a (b + 1))

-- Catala `round` on a/b is `roundDiv a b`.
#prop (∀ a : Int, ∀ b : Nat,
  roundRat ((a : Rat) / ((b + 1 : Nat) : Rat)) = roundDiv a (b + 1))
-- `integer of decimal` on a/b truncates.
#prop (∀ a : Int, ∀ b : Nat,
  intOfRat ((a : Rat) / ((b + 1 : Nat) : Rat)) = Int.tdiv a (b + 1))
-- `round` is monotone.
#prop (∀ a c : Int, ∀ b d : Nat,
  (a : Rat) / ((b + 1 : Nat) : Rat) ≤ (c : Rat) / ((d + 1 : Nat) : Rat) →
  roundRat ((a : Rat) / ((b + 1 : Nat) : Rat)) ≤ roundRat ((c : Rat) / ((d + 1 : Nat) : Rat)))

-- roundDollar: integer form, monotone, idempotent, odd, within 50 cents.
#prop (∀ m : Int, roundDollar m =
  if m < 0 then -((-m + 50) / 100 * 100) else (m + 50) / 100 * 100)
#prop (∀ m n : Int, m ≤ n → roundDollar m ≤ roundDollar n)
#prop (∀ m : Int, roundDollar (roundDollar m) = roundDollar m)
#prop (∀ k : Int, roundDollar (100 * k) = 100 * k)
#prop (∀ m : Int, roundDollar (-m) = -roundDollar m)
#prop (∀ m : Int, roundDollar m - m ≤ 50 ∧ m - roundDollar m ≤ 50)

-- money * rate with rate p/q.
#prop (∀ m p : Int, ∀ q : Nat,
  mulRate m ((p : Rat) / ((q + 1 : Nat) : Rat)) = roundDiv (m * p) (q + 1))
#prop (∀ m n : Int, ∀ p q : Nat, m ≤ n →
  mulRate m ((p : Rat) / ((q + 1 : Nat) : Rat)) ≤ mulRate n ((p : Rat) / ((q + 1 : Nat) : Rat)))
#prop (∀ m i : Int, mulInt m i = m * i)

-- Stdlib truncate / round_by_excess / round_by_default as integer formulas.
#prop (∀ m : Int, truncate m = Int.tdiv m 100 * 100)
#prop (∀ m : Int, roundByDefault m = m / 100 * 100)
#prop (∀ m : Int, roundByExcess m = -((-m) / 100 * 100))

-- Direct File helpers.
#prop (∀ a : Int, ∀ b : Nat,
  truncateCents ((a : Rat) / ((b + 1 : Nat) : Rat)) = Int.tdiv (a * 100) (b + 1))
#prop (∀ m n : Int, ∀ d : Nat,
  stepwiseMultiply m n (d + 1) = Int.tdiv (Int.tdiv m 100) (d + 1) * n * 100)
#prop (∀ m n : Int, m ≤ n →
  stepwiseMultiply m 50 50 ≤ stepwiseMultiply n 50 50)

-- Round up to $1,000: a ceiling for nonnegative amounts.
#prop (∀ m : Nat,
  roundUpToThousand m = ((m : Int) + 99999) / 100000 * 100000)
-- Same, spread over amounts up to about $1,000 (generated Nats are small).
#prop (∀ m : Nat,
  roundUpToThousand (m * 997) = ((m * 997 : Int) + 99999) / 100000 * 100000)

-- min / max / positive.
#prop (∀ a b : Int, min a b ≤ a ∧ min a b ≤ b ∧ (min a b = a ∨ min a b = b))
#prop (∀ a b : Int, a ≤ max a b ∧ b ≤ max a b ∧ (max a b = a ∨ max a b = b))
#prop (∀ m : Int, 0 ≤ positive m ∧ m ≤ positive m)
#prop (∀ m n : Int, m ≤ n → positive m ≤ positive n)

-- sum.
#prop (∀ l₁ l₂ : List Int, sum (l₁ ++ l₂) = sum l₁ + sum l₂)

end UsTax.Money.Props
