import Spike.RateA
import Spike.RateC
open Catala

/-! Probe: the bridge lemma between the IR-shaped port (Rat division then
`integer of`) and plain `Int` division. Core-only (no Mathlib `field_simp`,
`linarith`). -/

theorem floor_div_const (a : Int) (c : Int) (hc : 0 < c) :
    ((a : Rat) / (c : Rat)).floor = a / c := by
  have hcR : (0 : Rat) < (c : Rat) := by
    have := (Rat.intCast_lt_intCast (a := 0) (b := c)).mpr hc
    simpa using this
  apply Int.le_antisymm
  · -- floor < a/c + 1
    have h1 : ((a : Rat) / c).floor < a / c + 1 := by
      rw [Rat.floor_lt_iff, Rat.div_lt_iff hcR, ← Rat.intCast_mul, Rat.intCast_lt_intCast]
      have := Int.lt_ediv_add_one_mul_self a hc
      omega
    omega
  · rw [Rat.le_floor_iff, ← Rat.not_lt, Rat.div_lt_iff hcR, ← Rat.intCast_mul,
      Rat.intCast_lt_intCast]
    have := Int.ediv_mul_le a (Int.ne_of_gt hc)
    omega

theorem intOfRat_div (a c : Int) (ha : 0 < a) (hc : 0 < c) :
    intOfRat ((a : Rat) / (c : Rat)) = a / c := by
  unfold intOfRat
  rw [← floor_div_const a c hc, Rat.floor_def]
  have : 0 ≤ ((a : Rat) / (c : Rat)).num := by
    rw [Rat.num_nonneg, ← Rat.not_lt]
    intro h
    have hcR : (0 : Rat) < (c : Rat) := by
      simpa using (Rat.intCast_lt_intCast (a := 0) (b := c)).mpr hc
    rw [Rat.div_lt_iff hcR] at h
    have : (a : Rat) < 0 := by simpa using h
    have := (Rat.intCast_lt_intCast (a := a) (b := 0)).mp (by simpa using this)
    omega
  rw [Int.tdiv_eq_ediv]
  simp [this]

theorem round_intCast (z : Int) : round (z : Rat) = z := by
  unfold round
  by_cases h : (z : Rat) < 0
  · simp only [h, ite_true]
    have hz : z < 0 := by
      have := (Rat.intCast_lt_intCast (a := z) (b := 0)).mp (by simpa using h)
      exact this
    rw [show -(z : Rat) = ((-z : Int) : Rat) by simp]
    simp only [Rat.num_intCast, Rat.den_intCast]
    omega
  · simp only [h, ite_false]
    simp only [Rat.num_intCast, Rat.den_intCast]
    omega

theorem ratLit {a b c d : Int} (hb : b ≠ 0) (hd : d ≠ 0) (h : a * d = c * b) :
    (a : Rat) / (b : Rat) = (c : Rat) / (d : Rat) := by
  rw [← Rat.divInt_eq_div, ← Rat.divInt_eq_div, Rat.divInt_eq_divInt_iff hb hd]
  exact h

def fsMap : RateA.FilingStatus → RateC.FilingStatus
  | .single => .single | .marriedFilingJointly => .mfj | .marriedFilingSeparately => .mfs
  | .headOfHousehold => .hoh | .qualifyingSurvivingSpouse => .qss

/-- Refinement: the IR-shaped port computes the readable Lean calculator. -/
theorem rateA_eq_rateC (fs : RateA.FilingStatus) (ti : Int) :
    RateA.tax fs ti = some (RateC.tax (fsMap fs) ti) := by
  have key : ∀ (c : Int), 0 < c → ∀ (a : Int), 0 < a →
      mulMonInt c (intOfRat ((a : Rat) / (c : Rat))) = c * (a / c) := by
    intro c hc a ha
    rw [intOfRat_div a c ha hc, mulMonInt, mulMonRat, ← Rat.intCast_mul, round_intCast]
  have k25 : ∀ a : Int, 2500 ≤ a → mulMonInt 2500 (intOfRat ((a : Rat) / ((2500 : Int) : Rat)))
      = a / 2500 * 2500 := fun a h => by rw [key 2500 (by decide) a (by omega), Int.mul_comm]
  have k50 : ∀ a : Int, 300000 ≤ a → mulMonInt 5000 (intOfRat ((a : Rat) / ((5000 : Int) : Rat)))
      = a / 5000 * 5000 := fun a h => by rw [key 5000 (by decide) a (by omega), Int.mul_comm]
  have r10 : (10 : Rat) / 100 = 1/10 := by
    simpa using ratLit (a := 10) (b := 100) (c := 1) (d := 10) (by decide) (by decide) (by decide)
  have r12 : (12 : Rat) / 100 = 3/25 := by
    simpa using ratLit (a := 12) (b := 100) (c := 3) (d := 25) (by decide) (by decide) (by decide)
  have r22 : (22 : Rat) / 100 = 11/50 := by
    simpa using ratLit (a := 22) (b := 100) (c := 11) (d := 50) (by decide) (by decide) (by decide)
  have r24 : (24 : Rat) / 100 = 6/25 := by
    simpa using ratLit (a := 24) (b := 100) (c := 6) (d := 25) (by decide) (by decide) (by decide)
  have r32 : (32 : Rat) / 100 = 8/25 := by
    simpa using ratLit (a := 32) (b := 100) (c := 8) (d := 25) (by decide) (by decide) (by decide)
  have r35 : (35 : Rat) / 100 = 7/20 := by
    simpa using ratLit (a := 35) (b := 100) (c := 7) (d := 20) (by decide) (by decide) (by decide)
  have r37 : (37 : Rat) / 100 = 37/100 := by
    simpa using ratLit (a := 37) (b := 100) (c := 37) (d := 100) (by decide) (by decide) (by decide)
  by_cases h1 : ti < 2500
  · cases fs <;>
    simp [RateA.tax, RateA.taxSchedule, RateC.tax, RateC.scheduleTax, RateC.tableKey,
      divMonMon, errorOnEmpty, bind, Except.bind, pure, Except.pure, h1, fsMap,
      RateC.schedule, RateC.schedule.mk, RateA.b, r10, r12, r22, r24, r32, r35, r37,
      Money.sum]
  have n0 : ¬ ti ≤ 0 := by omega
  have n5 : ¬ ti < 500 := by omega
  have n15 : ¬ ti < 1500 := by omega
  by_cases h2 : ti < 300000
  · have e := k25 ti (by omega)
    simp only [show ((2500 : Int) : Rat) = (2500 : Rat) by rfl] at e
    cases fs <;>
    simp [RateA.tax, RateA.taxSchedule, RateC.tax, RateC.scheduleTax, RateC.tableKey,
      divMonMon, errorOnEmpty, bind, Except.bind, pure, Except.pure, h1, h2, n0, n5, n15,
      fsMap, RateC.schedule, RateC.schedule.mk, RateA.b, r10, r12, r22, r24, r32, r35, r37,
      Money.sum, e]
  by_cases h3 : ti < 10000000
  · have e := k50 ti (by omega)
    simp only [show ((5000 : Int) : Rat) = (5000 : Rat) by rfl] at e
    cases fs <;>
    simp [RateA.tax, RateA.taxSchedule, RateC.tax, RateC.scheduleTax, RateC.tableKey,
      divMonMon, errorOnEmpty, bind, Except.bind, pure, Except.pure, h1, h2, h3, n0, n5, n15,
      fsMap, RateC.schedule, RateC.schedule.mk, RateA.b, r10, r12, r22, r24, r32, r35, r37,
      Money.sum, e]
  cases fs <;>
  simp [RateA.tax, RateA.taxSchedule, RateC.tax, RateC.scheduleTax, RateC.tableKey,
    divMonMon, errorOnEmpty, bind, Except.bind, pure, Except.pure, h1, h2, h3, n0, n5, n15,
    fsMap, RateC.schedule, RateC.schedule.mk, RateA.b, r10, r12, r22, r24, r32, r35, r37,
    Money.sum]

#print axioms rateA_eq_rateC
