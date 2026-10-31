import UsTax.Money
import UsTax.Audit

/-!
# Lemmas about `UsTax.Money`

The lemmas later proofs need (issue #39): integer forms of every rounding
function (so `omega` can finish goals), monotonicity, idempotence, sign and
nonnegativity facts, and the `min` / `max` / `positive` / `sum` laws.

Method: every Catala rounding of a rational `a / b` (`b > 0`) is reduced to
`roundDiv a b` or `Int.tdiv a b` on integers. The bridge is
`roundRat_eq_roundDiv` (definitional, on `q.num` and `q.den`) plus the
cross-multiplication lemma `le_of_cross`: an integer function that is monotone
in the numerator and invariant under scaling both arguments respects
`a / b ≤ c / d`, so its value on `q.num / q.den` equals its value on any other
representation `a / b` of `q`. No Mathlib.

The statements were property-tested with plausible first
(`UsTax/Money/Props.lean`).
-/

open scoped Rat

namespace UsTax

/-! ## Integer division facts -/

/-- Truncating division (`Z.div` in OCaml) as Euclidean division of the
absolute value of the dividend. -/
theorem tdiv_eq_if (a b : Int) :
    Int.tdiv a b = if a < 0 then -((-a) / b) else a / b := by
  split
  · rw [show a = -(-a) by omega, Int.neg_tdiv, Int.tdiv_eq_ediv_of_nonneg (by omega),
      Int.neg_neg]
  · exact Int.tdiv_eq_ediv_of_nonneg (by omega)

theorem tdiv_mono {a c b : Int} (hb : 0 < b) (h : a ≤ c) : Int.tdiv a b ≤ Int.tdiv c b := by
  rw [tdiv_eq_if a b, tdiv_eq_if c b]
  split <;> split
  · have := Int.ediv_le_ediv hb (show -c ≤ -a by omega)
    omega
  · have := Int.ediv_nonneg (show 0 ≤ -a by omega) (Int.le_of_lt hb)
    have := Int.ediv_nonneg (show 0 ≤ c by omega) (Int.le_of_lt hb)
    omega
  · omega
  · exact Int.ediv_le_ediv hb h

/-- A function of `(numerator, positive denominator)` that is monotone in the
numerator and unchanged by scaling both arguments respects the order of the
fractions: `a / b ≤ c / d` (cross-multiplied) gives `f a b ≤ f c d`. -/
theorem le_of_cross (f : Int → Int → Int)
    (mono : ∀ {a c b : Int}, 0 < b → a ≤ c → f a b ≤ f c b)
    (scale : ∀ {a b k : Int}, 0 < k → f (k * a) (k * b) = f a b)
    {a b c d : Int} (hb : 0 < b) (hd : 0 < d) (h : a * d ≤ c * b) : f a b ≤ f c d := by
  rw [← scale (a := a) (b := b) hd, ← scale (a := c) (b := d) hb, Int.mul_comm d a,
    Int.mul_comm b c, Int.mul_comm d b]
  exact mono (Int.mul_pos hb hd) h

/-! ## `roundDiv` -/

theorem roundDiv_mono {a c b : Int} (hb : 0 < b) (h : a ≤ c) : roundDiv a b ≤ roundDiv c b := by
  unfold roundDiv
  have h2 : 0 < 2 * b := by omega
  split <;> split
  · have := Int.ediv_le_ediv h2 (show 2 * -c + b ≤ 2 * -a + b by omega)
    omega
  · have := Int.ediv_nonneg (show 0 ≤ 2 * -a + b by omega) (Int.le_of_lt h2)
    have := Int.ediv_nonneg (show 0 ≤ 2 * c + b by omega) (Int.le_of_lt h2)
    omega
  · omega
  · exact Int.ediv_le_ediv h2 (by omega)

theorem roundDiv_mul_left {a b k : Int} (hk : 0 < k) :
    roundDiv (k * a) (k * b) = roundDiv a b := by
  unfold roundDiv
  have hneg : k * a < 0 ↔ a < 0 := by
    constructor
    · intro h; apply Classical.byContradiction; intro h'
      have := Int.mul_nonneg (Int.le_of_lt hk) (Int.not_lt.mp h'); omega
    · intro h; exact Int.mul_neg_of_pos_of_neg hk h
  have e1 : 2 * -(k * a) + k * b = k * (2 * -a + b) := by
    simp only [Int.mul_add, Int.mul_neg, Int.mul_left_comm 2 k a]
  have e2 : 2 * (k * a) + k * b = k * (2 * a + b) := by
    rw [Int.mul_add, Int.mul_left_comm]
  have e3 : 2 * (k * b) = k * (2 * b) := Int.mul_left_comm 2 k b
  by_cases ha : a < 0
  · simp only [hneg.mpr ha, ha, ite_true, e1, e3, Int.mul_ediv_mul_of_pos _ _ hk]
  · simp only [show ¬ k * a < 0 from fun h => ha (hneg.mp h), ha, ite_false, e2, e3,
      Int.mul_ediv_mul_of_pos _ _ hk]

theorem roundDiv_le_of_cross {a b c d : Int} (hb : 0 < b) (hd : 0 < d) (h : a * d ≤ c * b) :
    roundDiv a b ≤ roundDiv c d :=
  le_of_cross roundDiv roundDiv_mono roundDiv_mul_left hb hd h

theorem roundDiv_neg (a : Int) {b : Int} (hb : 0 < b) : roundDiv (-a) b = -roundDiv a b := by
  unfold roundDiv
  by_cases h : a < 0
  · simp only [show ¬ -a < 0 by omega, h, ite_true, ite_false, Int.neg_neg]
  · by_cases h0 : a = 0
    · subst h0
      simp only [Int.neg_zero, Int.lt_irrefl, ite_false, Int.mul_zero, Int.zero_add]
      rw [Int.ediv_eq_zero_of_lt (by omega) (by omega)]
      rfl
    · simp only [show -a < 0 by omega, h, ite_true, ite_false, Int.neg_neg]

/-- `roundDiv` at the integer `k = (k * b) / b`. -/
theorem roundDiv_mul_self (k : Int) {b : Int} (hb : 0 < b) : roundDiv (k * b) b = k := by
  have h := roundDiv_mul_left (a := k) (b := 1) hb
  rw [Int.mul_comm b k, Int.mul_one] at h
  rw [h]; unfold roundDiv; split <;> omega

/-- The step behind `Decimal.truncate`: rounding `n / b - 1/2` (ties away from
zero) gives `n / b` floored, for `n > 0`. -/
theorem roundDiv_sub_half {n b : Int} (hn : 0 < n) :
    roundDiv (n * 2 - b) (b * 2) = n / b := by
  unfold roundDiv
  split
  · rw [Int.ediv_eq_zero_of_lt (by omega) (by omega),
      Int.ediv_eq_zero_of_lt (a := n) (by omega) (by omega)]
    rfl
  · rw [show 2 * (n * 2 - b) + b * 2 = 4 * n by omega, show 2 * (b * 2) = 4 * b by omega,
      Int.mul_ediv_mul_of_pos _ _ (by decide)]

namespace Money

/-! ## Rationals: numerator and denominator -/

theorem den_pos (q : Rat) : 0 < (q.den : Int) := by
  have := q.den_nz
  omega

theorem lt_zero_iff_num (q : Rat) : q < 0 ↔ q.num < 0 := by
  constructor
  · intro h; apply Classical.byContradiction; intro h'
    exact Rat.not_lt.mpr (Rat.num_nonneg.mp (Int.not_lt.mp h')) h
  · intro h; apply Classical.byContradiction; intro h'
    have := Rat.num_nonneg.mpr (Rat.not_lt.mp h'); omega

/-- `a /. b` and its normal form `num /. den` are the same fraction. -/
theorem divInt_cross (a b : Int) (hb : 0 < b) : (a /. b).num * b = a * (a /. b).den := by
  have h := Rat.num_divInt_den (a /. b)
  exact (Rat.divInt_eq_divInt_iff (by have := den_pos (a /. b); omega) (by omega)).mp h

theorem div_eq_divInt (a b : Int) : (a : Rat) / (b : Rat) = a /. b :=
  (Rat.divInt_eq_div a b).symm

/-- Lifts an integer function with the hypotheses of `le_of_cross` to equality
on two representations of the same fraction. -/
theorem eq_of_divInt (f : Int → Int → Int)
    (mono : ∀ {a c b : Int}, 0 < b → a ≤ c → f a b ≤ f c b)
    (scale : ∀ {a b k : Int}, 0 < k → f (k * a) (k * b) = f a b)
    (a b : Int) (hb : 0 < b) : f (a /. b).num (a /. b).den = f a b := by
  have h := divInt_cross a b hb
  exact Int.le_antisymm (le_of_cross f mono scale (den_pos _) hb (Int.le_of_eq h))
    (le_of_cross f mono scale hb (den_pos _) (Int.le_of_eq h.symm))

/-! ## Catala `round` -/

/-- Catala `round` is `roundDiv` on the normal form. -/
theorem roundRat_eq_roundDiv (q : Rat) : roundRat q = roundDiv q.num q.den := by
  unfold roundRat roundDiv
  by_cases h : q < 0
  · have hn := (lt_zero_iff_num q).mp h
    simp [h, hn, Rat.neg_num, Rat.neg_den]
  · have hn : ¬ q.num < 0 := fun hn => h ((lt_zero_iff_num q).mpr hn)
    simp [h, hn]

theorem roundRat_divInt (a b : Int) (hb : 0 < b) : roundRat (a /. b) = roundDiv a b := by
  rw [roundRat_eq_roundDiv]
  exact eq_of_divInt roundDiv roundDiv_mono roundDiv_mul_left a b hb

/-- Catala `round` of `a / b` (`b > 0`) is the integer function `roundDiv`. -/
theorem roundRat_div (a b : Int) (hb : 0 < b) : roundRat ((a : Rat) / (b : Rat)) = roundDiv a b := by
  rw [div_eq_divInt]; exact roundRat_divInt a b hb

/-- Catala `round` is monotone. -/
theorem roundRat_mono {q r : Rat} (h : q ≤ r) : roundRat q ≤ roundRat r := by
  rw [roundRat_eq_roundDiv, roundRat_eq_roundDiv]
  exact roundDiv_le_of_cross (den_pos q) (den_pos r) ((Rat.le_iff q r).mp h)

/-- Catala `round` leaves integers unchanged. -/
theorem roundRat_intCast (z : Int) : roundRat (z : Rat) = z := by
  rw [roundRat_eq_roundDiv, Rat.num_intCast, Rat.den_intCast]
  unfold roundDiv; split <;> omega

theorem roundRat_zero : roundRat 0 = 0 := roundRat_intCast 0

theorem roundRat_neg (q : Rat) : roundRat (-q) = -roundRat q := by
  rw [roundRat_eq_roundDiv, roundRat_eq_roundDiv, Rat.neg_num, Rat.neg_den,
    roundDiv_neg _ (den_pos q)]

/-! ## Catala `integer of decimal` and `Decimal.truncate` -/

theorem intOfRat_divInt (a b : Int) (hb : 0 < b) : intOfRat (a /. b) = Int.tdiv a b := by
  unfold intOfRat
  exact eq_of_divInt Int.tdiv tdiv_mono (fun hk => Int.mul_tdiv_mul_of_pos _ _ hk) a b hb

/-- `integer of (a / b)` truncates toward zero. -/
theorem intOfRat_div (a b : Int) (hb : 0 < b) : intOfRat ((a : Rat) / (b : Rat)) = Int.tdiv a b := by
  rw [div_eq_divInt]; exact intOfRat_divInt a b hb

theorem intOfRat_intCast (z : Int) : intOfRat (z : Rat) = z := by
  unfold intOfRat; simp

/-- The literal port of stdlib `Decimal.truncate` is `integer of decimal`. -/
theorem truncateRat_eq (d : Rat) : truncateRat d = (intOfRat d : Rat) := by
  have hd := den_pos d
  have hq : d = d.num /. d.den := (Rat.num_divInt_den d).symm
  unfold truncateRat
  by_cases h0 : d = 0
  · subst h0; simp [intOfRat]
  · simp only [h0, ite_false]
    have half : (1 / 2 : Rat) = (1 : Int) /. 2 := by
      rw [div_eq_divInt 1 2 |>.symm]; rfl
    have hnum0 : d.num ≠ 0 := fun h => h0 (by rw [hq, h, Rat.zero_divInt])
    by_cases hpos : d > 0
    · simp only [hpos, ite_true]
      have hn : 0 < d.num := by
        have : ¬ d.num < 0 := fun h =>
          (Rat.not_lt.mpr (Rat.le_of_lt hpos)) ((lt_zero_iff_num d).mpr h)
        omega
      rw [hq, half, Rat.divInt_sub_divInt _ _ (by omega) (by decide),
        roundRat_divInt _ _ (by omega), Int.one_mul, ← hq, intOfRat, tdiv_eq_if _ _]
      simp only [show ¬ d.num < 0 by omega, ite_false]
      rw [roundDiv_sub_half hn]
    · simp only [hpos, ite_false]
      have hn : d.num < 0 := by
        have : d < 0 := by
          rcases Rat.le_iff_lt_or_eq.mp (Rat.not_lt.mp hpos) with h | h
          · exact h
          · exact absurd h h0
        exact (lt_zero_iff_num d).mp this
      rw [hq, half, Rat.divInt_add_divInt _ _ (by omega) (by decide),
        roundRat_divInt _ _ (by omega), Int.one_mul, ← hq, intOfRat, tdiv_eq_if _ _]
      simp only [hn, ite_true]
      rw [show d.num * 2 + d.den = -((-d.num) * 2 - d.den) by omega,
        roundDiv_neg _ (by omega), roundDiv_sub_half (by omega)]

/-! ## Products and quotients with rates -/

theorem mulRate_intCast (m k : Int) : mulRate m (k : Rat) = m * k := by
  unfold mulRate; rw [← Rat.intCast_mul, roundRat_intCast]

/-- `money * integer` is exact. -/
theorem mulInt_eq (m i : Int) : mulInt m i = m * i := mulRate_intCast m i

theorem mulRate_zero_left (r : Rat) : mulRate 0 r = 0 := by
  unfold mulRate; rw [show ((0 : Int) : Rat) = 0 from rfl, Rat.zero_mul, roundRat_zero]

/-- `money * (p / q)` is `roundDiv (m * p) q`. -/
theorem mulRate_div (m p q : Int) (hq : 0 < q) :
    mulRate m ((p : Rat) / (q : Rat)) = roundDiv (m * p) q := by
  unfold mulRate
  rw [Rat.div_def, ← Rat.mul_assoc, ← Rat.intCast_mul, ← Rat.div_def, roundRat_div _ _ hq]

/-- `money / integer` (positive divisor) is `roundDiv m i`. -/
theorem divInt_eq (m i : Int) (hi : 0 < i) : divInt m i = roundDiv m i := by
  unfold divInt divRate mulRate
  rw [← Rat.div_def, roundRat_div _ _ hi]

/-- `money * rate` is monotone in the amount for a nonnegative rate. -/
theorem mulRate_mono {m n : Int} {r : Rat} (hr : 0 ≤ r) (h : m ≤ n) : mulRate m r ≤ mulRate n r :=
  roundRat_mono (Rat.mul_le_mul_of_nonneg_right (Rat.intCast_le_intCast.mpr h) hr)

/-- `money * rate` is monotone in the rate for a nonnegative amount. -/
theorem mulRate_mono_rate {m : Int} {r s : Rat} (hm : 0 ≤ m) (h : r ≤ s) :
    mulRate m r ≤ mulRate m s :=
  roundRat_mono (Rat.mul_le_mul_of_nonneg_left h (Rat.intCast_nonneg.mpr hm))

theorem mulRate_nonneg {m : Int} {r : Rat} (hm : 0 ≤ m) (hr : 0 ≤ r) : 0 ≤ mulRate m r := by
  have := mulRate_mono hr hm
  rwa [mulRate_zero_left] at this

/-- For `0 ≤ r ≤ 1`, `money * r` does not exceed the amount. -/
theorem mulRate_le_self {m : Int} {r : Rat} (hm : 0 ≤ m) (hr : r ≤ 1) : mulRate m r ≤ m := by
  have := mulRate_mono_rate hm hr
  rwa [show (1 : Rat) = ((1 : Int) : Rat) from rfl, mulRate_intCast, Int.mul_one] at this

/-! ## Dollar rounding -/

theorem roundDollar_eq_roundDiv (m : Int) : roundDollar m = roundDiv m 100 * 100 := by
  unfold roundDollar
  rw [show (100 : Rat) = ((100 : Int) : Rat) from rfl, roundRat_div m 100 (by decide)]

/-- Integer form of `round of money` (ties away from zero), for `omega`. -/
theorem roundDollar_eq (m : Int) :
    roundDollar m = if m < 0 then -((-m + 50) / 100 * 100) else (m + 50) / 100 * 100 := by
  rw [roundDollar_eq_roundDiv]; unfold roundDiv; split <;> omega

theorem roundDollar_mono {m n : Int} (h : m ≤ n) : roundDollar m ≤ roundDollar n := by
  rw [roundDollar_eq, roundDollar_eq]; split <;> split <;> omega

/-- Whole-dollar amounts are fixed by `roundDollar`. -/
theorem roundDollar_mul_100 (k : Int) : roundDollar (100 * k) = 100 * k := by
  rw [roundDollar_eq]; split <;> omega

theorem roundDollar_emod (m : Int) : roundDollar m % 100 = 0 := by
  rw [roundDollar_eq]; split <;> omega

theorem roundDollar_idem (m : Int) : roundDollar (roundDollar m) = roundDollar m := by
  have h := roundDollar_mul_100 (roundDollar m / 100)
  rwa [Int.mul_ediv_cancel' (Int.dvd_of_emod_eq_zero (roundDollar_emod m))] at h

theorem roundDollar_neg (m : Int) : roundDollar (-m) = -roundDollar m := by
  rw [roundDollar_eq, roundDollar_eq]; split <;> split <;> omega

/-- `roundDollar` moves an amount by at most 50 cents. -/
theorem roundDollar_sub_le (m : Int) : roundDollar m - m ≤ 50 ∧ m - roundDollar m ≤ 50 := by
  rw [roundDollar_eq]; split <;> omega

theorem roundDollar_nonneg {m : Int} (hm : 0 ≤ m) : 0 ≤ roundDollar m := by
  rw [roundDollar_eq]; split <;> omega

theorem roundDollar_zero : roundDollar 0 = 0 := by
  have := roundDollar_mul_100 0
  simpa using this

/-! ## Stdlib truncation and directed dollar rounding -/

theorem truncate_eq (m : Int) : truncate m = Int.tdiv m 100 * 100 := by
  unfold truncate
  rw [tdiv_eq_if m 100]
  repeat' split
  all_goals (try rw [roundDollar_eq]) ; (try split) <;> omega

/-- `Money.round_by_default` is the floor to a whole dollar. -/
theorem roundByDefault_eq (m : Int) : roundByDefault m = m / 100 * 100 := by
  unfold roundByDefault
  split <;> rw [roundDollar_eq] <;> split <;> omega

/-- `Money.round_by_excess` is the ceiling to a whole dollar. -/
theorem roundByExcess_eq (m : Int) : roundByExcess m = -((-m) / 100 * 100) := by
  unfold roundByExcess
  split <;> rw [roundDollar_eq] <;> split <;> omega

/-! ## Direct File helpers -/

/-- `R.truncate_cents of (a / b)`: cents of `a / b` dollars, toward zero. -/
theorem truncateCents_div (a b : Int) (hb : 0 < b) :
    truncateCents ((a : Rat) / (b : Rat)) = Int.tdiv (a * 100) b := by
  unfold truncateCents
  rw [truncateRat_eq, show ((a : Rat) / (b : Rat)) * 100 = ((a * 100 : Int) : Rat) / (b : Rat) by
      rw [Rat.intCast_mul, Rat.div_def, Rat.div_def, Rat.mul_assoc, Rat.mul_comm (b : Rat)⁻¹,
        ← Rat.mul_assoc]; rfl,
    intOfRat_div _ _ hb, show (1 : Int) = ((1 : Int) : Int) from rfl, mulRate_intCast,
    Int.one_mul]

/-- `R.stepwise_multiply of m, num, den` for `den > 0`: drop the cents, divide
the dollars by `den` toward zero, multiply by `num`. -/
theorem stepwiseMultiply_eq (m num den : Int) (hd : 0 < den) :
    stepwiseMultiply m num den = Int.tdiv (Int.tdiv m 100) den * num * 100 := by
  unfold stepwiseMultiply divMoney
  dsimp only
  rw [truncate_eq]
  have e : ((Int.tdiv m 100 * 100 : Int) : Rat) / ((100 : Int) : Rat) / (den : Rat)
      = ((Int.tdiv m 100 : Int) : Rat) / (den : Rat) := by
    rw [Rat.intCast_mul, Rat.mul_div_cancel (by decide)]
  rw [e, truncateRat_eq, intOfRat_div _ _ hd, ← Rat.intCast_mul, mulRate_intCast]
  rw [Int.mul_comm 100]

theorem stepwiseMultiply_mono {m m' num den : Int} (hd : 0 < den) (hn : 0 ≤ num) (h : m ≤ m') :
    stepwiseMultiply m num den ≤ stepwiseMultiply m' num den := by
  rw [stepwiseMultiply_eq _ _ _ hd, stepwiseMultiply_eq _ _ _ hd]
  have := tdiv_mono hd (tdiv_mono (b := 100) (by decide) h)
  have := Int.mul_le_mul_of_nonneg_right this hn
  omega

/-! ## Round up to $1,000 -/

/-- For a nonnegative amount, `Money.round_to_decimal of (m + $499.99), -3` is
the ceiling to a multiple of $1,000. -/
theorem roundUpToThousand_eq_ceil {m : Int} (hm : 0 ≤ m) :
    roundUpToThousand m = (m + 99999) / 100000 * 100000 := by
  unfold roundUpToThousand roundToDecimal
  simp only [show ¬ ((-3 : Int) ≥ 2) by decide, show ¬ ((-3 : Int) = 1) by decide, ite_false,
    show (10 : Int) ^ (-(-3 : Int)).toNat = 1000 by decide]
  rw [Int.tdiv_eq_ediv_of_nonneg (by omega), roundDollar_eq]
  split <;> omega

theorem roundUpToThousand_mono {m n : Int} (hm : 0 ≤ m) (h : m ≤ n) :
    roundUpToThousand m ≤ roundUpToThousand n := by
  rw [roundUpToThousand_eq_ceil hm, roundUpToThousand_eq_ceil (by omega)]
  omega

/-! ## `min`, `max`, `positive` -/

theorem min_le_left (a b : Int) : min a b ≤ a := by unfold min; split <;> omega
theorem min_le_right (a b : Int) : min a b ≤ b := by unfold min; split <;> omega
theorem le_min {a b c : Int} (ha : c ≤ a) (hb : c ≤ b) : c ≤ min a b := by
  unfold min; split <;> omega
theorem min_eq_left {a b : Int} (h : a ≤ b) : min a b = a := by unfold min; split <;> omega
theorem min_eq_right {a b : Int} (h : b ≤ a) : min a b = b := by unfold min; split <;> omega
theorem min_comm (a b : Int) : min a b = min b a := by unfold min; split <;> split <;> omega
theorem min_mono {a a' b b' : Int} (ha : a ≤ a') (hb : b ≤ b') : min a b ≤ min a' b' := by
  unfold min; split <;> split <;> omega
/-- `Money.min` is core `Min.min` on `Int`. -/
theorem min_eq_min (a b : Int) : min a b = Min.min a b := by
  unfold min; rw [Int.min_def]; split <;> split <;> omega

theorem le_max_left (a b : Int) : a ≤ max a b := by unfold max; split <;> omega
theorem le_max_right (a b : Int) : b ≤ max a b := by unfold max; split <;> omega
theorem max_le {a b c : Int} (ha : a ≤ c) (hb : b ≤ c) : max a b ≤ c := by
  unfold max; split <;> omega
theorem max_eq_left {a b : Int} (h : b ≤ a) : max a b = a := by unfold max; split <;> omega
theorem max_eq_right {a b : Int} (h : a ≤ b) : max a b = b := by unfold max; split <;> omega
theorem max_comm (a b : Int) : max a b = max b a := by unfold max; split <;> split <;> omega
theorem max_mono {a a' b b' : Int} (ha : a ≤ a') (hb : b ≤ b') : max a b ≤ max a' b' := by
  unfold max; split <;> split <;> omega
/-- `Money.max` is core `Max.max` on `Int`. -/
theorem max_eq_max (a b : Int) : max a b = Max.max a b := by
  unfold max; rw [Int.max_def]; split <;> split <;> omega

/-- Integer form of `Money.positive`, for `omega`. -/
theorem positive_eq (m : Int) : positive m = if m < 0 then 0 else m := by
  unfold positive floor max; split <;> split <;> omega
theorem positive_nonneg (m : Int) : 0 ≤ positive m := by rw [positive_eq]; split <;> omega
theorem le_positive (m : Int) : m ≤ positive m := by rw [positive_eq]; split <;> omega
theorem positive_of_nonneg {m : Int} (h : 0 ≤ m) : positive m = m := by
  rw [positive_eq]; split <;> omega
theorem positive_of_nonpos {m : Int} (h : m ≤ 0) : positive m = 0 := by
  rw [positive_eq]; split <;> omega
theorem positive_mono {m n : Int} (h : m ≤ n) : positive m ≤ positive n := by
  rw [positive_eq, positive_eq]; split <;> split <;> omega

theorem inExcess_eq (m ref : Int) : inExcess m ref = positive (m - ref) := by
  rw [positive_eq]; unfold inExcess max; repeat' split
  all_goals omega
theorem inDefault_eq (m ref : Int) : inDefault m ref = positive (ref - m) := by
  rw [positive_eq]; unfold inDefault max; repeat' split
  all_goals omega

/-! ## `sum` -/

theorem foldl_add (l : List Int) (a : Int) : l.foldl (· + ·) a = a + sum l := by
  induction l generalizing a with
  | nil => simp [sum]
  | cons x xs ih =>
    simp only [sum, List.foldl_cons]
    rw [ih, ih (0 + x)]; omega

@[simp] theorem sum_nil : sum [] = 0 := by simp [sum]

@[simp] theorem sum_cons (x : Int) (l : List Int) : sum (x :: l) = x + sum l := by
  rw [sum, List.foldl_cons, foldl_add]; omega

theorem sum_append (l₁ l₂ : List Int) : sum (l₁ ++ l₂) = sum l₁ + sum l₂ := by
  induction l₁ with
  | nil => simp
  | cons x xs ih => simp only [List.cons_append, sum_cons, ih]; omega

theorem sum_nonneg {l : List Int} (h : ∀ x ∈ l, 0 ≤ x) : 0 ≤ sum l := by
  induction l with
  | nil => simp
  | cons x xs ih =>
    simp only [sum_cons]
    have := h x (List.mem_cons_self ..)
    have := ih (fun y hy => h y (List.mem_cons_of_mem _ hy))
    omega

/-- Pointwise `f ≤ g` on a list gives `sum (map f) ≤ sum (map g)`. -/
theorem sum_map_le {α : Type} {l : List α} {f g : α → Int} (h : ∀ x ∈ l, f x ≤ g x) :
    sum (l.map f) ≤ sum (l.map g) := by
  induction l with
  | nil => simp
  | cons x xs ih =>
    simp only [List.map_cons, sum_cons]
    have := h x (List.mem_cons_self ..)
    have := ih (fun y hy => h y (List.mem_cons_of_mem _ hy))
    omega

end Money
end UsTax

/-! ## Axiom audit (CLAUDE.md section 7): only `propext`, `Classical.choice`,
`Quot.sound` are allowed. -/

#audit_axioms UsTax.Money.roundRat_div
#audit_axioms UsTax.Money.roundRat_mono
#audit_axioms UsTax.Money.intOfRat_div
#audit_axioms UsTax.Money.truncateRat_eq
#audit_axioms UsTax.Money.mulRate_div
#audit_axioms UsTax.Money.mulRate_mono
#audit_axioms UsTax.Money.roundDollar_eq
#audit_axioms UsTax.Money.roundDollar_mono
#audit_axioms UsTax.Money.roundDollar_idem
#audit_axioms UsTax.Money.truncateCents_div
#audit_axioms UsTax.Money.stepwiseMultiply_eq
#audit_axioms UsTax.Money.roundUpToThousand_eq_ceil
#audit_axioms UsTax.Money.positive_mono
#audit_axioms UsTax.Money.sum_map_le
