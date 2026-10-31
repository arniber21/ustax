/-!
# Dates and ages (issue #40)

The subset of Catala's `Date` the spec uses (`Date.get_year/month/day`,
`date - 1 day`) and the age rules of `catala/filers.catala_en`:

* `age` = tax year minus year of birth (DF `/filers/*/age`);
* `ageDayBefore` = tax year minus year of the day before birth
  (DF `/filers/*/ageCalculatedDayBeforeDOB`);
* `age65OrOlder` uses `ageDayBefore >= 65` (IRC 63(f)(1); Pub. 501 p 3: "A
  person is considered to reach age 65 on the day before the person's 65th
  birthday");
* `completedYears` (age of a spouse at death).

All ages are the age on December 31 of the tax year. Year is `Int`; month and
day are `Nat` (calendar positions, not money).
-/

namespace UsTax

/-- A proleptic Gregorian calendar date. -/
structure Date where
  year : Int
  month : Nat
  day : Nat
  deriving DecidableEq, Repr

namespace Date

/-- Gregorian leap year. -/
def isLeap (y : Int) : Bool := y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)

/-- Days in month `m` (1 to 12) of year `y`; `0` for an invalid month. -/
def daysInMonth (y : Int) (m : Nat) : Nat :=
  match m with
  | 1 => 31 | 2 => if isLeap y then 29 else 28 | 3 => 31 | 4 => 30
  | 5 => 31 | 6 => 30 | 7 => 31 | 8 => 31 | 9 => 30 | 10 => 31
  | 11 => 30 | 12 => 31 | _ => 0

/-- A real calendar date. -/
def Valid (d : Date) : Prop :=
  1 ≤ d.month ∧ d.month ≤ 12 ∧ 1 ≤ d.day ∧ d.day ≤ daysInMonth d.year d.month

instance (d : Date) : Decidable d.Valid := inferInstanceAs (Decidable (_ ∧ _ ∧ _ ∧ _))

/-- Catala `date - 1 day`. -/
def dayBefore (d : Date) : Date :=
  if 1 < d.day then { d with day := d.day - 1 }
  else if 1 < d.month then
    { year := d.year, month := d.month - 1, day := daysInMonth d.year (d.month - 1) }
  else { year := d.year - 1, month := 12, day := 31 }

theorem daysInMonth_pos (y : Int) (m : Nat) (h1 : 1 ≤ m) (h2 : m ≤ 12) :
    1 ≤ daysInMonth y m := by
  have : m = 1 ∨ m = 2 ∨ m = 3 ∨ m = 4 ∨ m = 5 ∨ m = 6 ∨ m = 7 ∨ m = 8 ∨ m = 9 ∨
      m = 10 ∨ m = 11 ∨ m = 12 := by omega
  rcases this with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;>
    simp only [daysInMonth] <;> (try split) <;> omega

/-- The day before a real date is a real date. -/
theorem dayBefore_valid {d : Date} (h : d.Valid) : d.dayBefore.Valid := by
  obtain ⟨h1, h2, h3, h4⟩ := h
  unfold dayBefore Valid
  split
  · simp only; omega
  · split
    · have := daysInMonth_pos d.year (d.month - 1) (by omega) (by omega)
      simp only; omega
    · simp [daysInMonth]

/-- Only January 1 changes the year when going back one day. -/
theorem dayBefore_year {d : Date} (h : d.Valid) :
    d.dayBefore.year = if d.month = 1 ∧ d.day = 1 then d.year - 1 else d.year := by
  obtain ⟨h1, h2, h3, h4⟩ := h
  unfold dayBefore
  by_cases a : 1 < d.day
  · have : ¬ (d.month = 1 ∧ d.day = 1) := by omega
    simp [a, this]
  · by_cases b : 1 < d.month
    · have : ¬ (d.month = 1 ∧ d.day = 1) := by omega
      simp [a, b, this]
    · have : d.month = 1 ∧ d.day = 1 := by omega
      simp [this]

/-! ### Ages on December 31 of the tax year -/

/-- DF `/filers/*/age`: tax year minus year of birth. -/
def age (taxYear : Int) (dob : Date) : Int := taxYear - dob.year

/-- DF `/filers/*/ageCalculatedDayBeforeDOB`. -/
def ageDayBefore (taxYear : Int) (dob : Date) : Int := taxYear - dob.dayBefore.year

/-- Age of a person reached 65 by the end of `taxYear` (IRC 63(f)(1), Pub. 501). -/
def age65OrOlder (taxYear : Int) (dob : Date) : Bool := ageDayBefore taxYear dob ≥ 65

/-- Under 18 by the day-before rule (IRC 25B(c)(2)(C)). -/
def isUnder18 (taxYear : Int) (dob : Date) : Bool := ageDayBefore taxYear dob < 18

/-- Completed years from `start` to `finish` (the later date): year difference,
less one if `finish` falls before the anniversary of `start`. -/
def completedYears (start finish : Date) : Int :=
  (finish.year - start.year) -
    (if finish.month < start.month || (finish.month == start.month && finish.day < start.day)
     then 1 else 0)

/-- The day-before age exceeds the plain age only for January 1 births. -/
theorem ageDayBefore_eq {dob : Date} (h : dob.Valid) (t : Int) :
    ageDayBefore t dob = age t dob + (if dob.month = 1 ∧ dob.day = 1 then 1 else 0) := by
  unfold ageDayBefore age
  rw [dayBefore_year h]
  split <;> omega

/-- The 65 rule in terms of the birth date: born in `taxYear - 65` or earlier,
or on January 1 of `taxYear - 64`. -/
theorem age65OrOlder_iff {dob : Date} (h : dob.Valid) (t : Int) :
    age65OrOlder t dob = true ↔
      dob.year ≤ t - 65 ∨ (dob.year = t - 64 ∧ dob.month = 1 ∧ dob.day = 1) := by
  unfold age65OrOlder
  rw [decide_eq_true_iff, ageDayBefore_eq h]
  unfold age
  split <;> omega

/-- A January 2 birth (65 on Jan 2 of year `t + 1`) is not 65 at the end of year `t`. -/
theorem not_age65_jan2 (t : Int) : age65OrOlder t ⟨t - 64, 1, 2⟩ = false := by
  have h : (Date.mk (t - 64) 1 2).Valid := by simp [Valid, daysInMonth]
  have := age65OrOlder_iff h t
  cases hb : age65OrOlder t ⟨t - 64, 1, 2⟩
  · rfl
  · rw [hb] at this
    have h2 := this.mp rfl
    simp at h2

/-- A January 1 birth is 65 at the end of the year before the 65th birthday. -/
theorem age65_jan1 (t : Int) : age65OrOlder t ⟨t - 64, 1, 1⟩ = true := by
  have h : (Date.mk (t - 64) 1 1).Valid := by simp [Valid, daysInMonth]
  exact (age65OrOlder_iff h t).mpr (by right; simp)

/-! ### Unit tests (edge cases) -/

-- Pub. 501: born Jan 1, 1960 is 65 at the end of 2024; Jan 2, 1960 is not.
#guard age65OrOlder 2024 ⟨1960, 1, 1⟩
#guard !age65OrOlder 2024 ⟨1960, 1, 2⟩
#guard age65OrOlder 2024 ⟨1959, 12, 31⟩
#guard !age65OrOlder 2024 ⟨1960, 12, 31⟩
#guard age65OrOlder 2025 ⟨1960, 1, 2⟩
-- plain age on Jan 1 is one less than the day-before age
#guard age 2024 ⟨1960, 1, 1⟩ == 64
#guard ageDayBefore 2024 ⟨1960, 1, 1⟩ == 65
#guard ageDayBefore 2024 ⟨1960, 1, 2⟩ == 64
-- under 18 in 2024: born Jan 1, 2007 reaches 18 on Dec 31, 2024; Jan 2, 2007 does not
#guard !isUnder18 2024 ⟨2007, 1, 1⟩
#guard isUnder18 2024 ⟨2007, 1, 2⟩
-- leap days
#guard isLeap 2024 && !isLeap 1900 && isLeap 2000 && !isLeap 2023
#guard dayBefore ⟨2024, 3, 1⟩ == ⟨2024, 2, 29⟩
#guard dayBefore ⟨2023, 3, 1⟩ == ⟨2023, 2, 28⟩
#guard dayBefore ⟨1960, 2, 29⟩ == ⟨1960, 2, 28⟩
#guard dayBefore ⟨1960, 1, 1⟩ == ⟨1959, 12, 31⟩
#guard dayBefore ⟨2024, 1, 1⟩ == ⟨2023, 12, 31⟩
#guard dayBefore ⟨2024, 5, 1⟩ == ⟨2024, 4, 30⟩
#guard ageDayBefore 2024 ⟨1960, 2, 29⟩ == 64
-- completed years of a spouse who died during the year
#guard completedYears ⟨2000, 2, 29⟩ ⟨2001, 2, 28⟩ == 0
#guard completedYears ⟨2000, 2, 29⟩ ⟨2001, 3, 1⟩ == 1
#guard completedYears ⟨1960, 6, 15⟩ ⟨2024, 6, 15⟩ == 64
#guard completedYears ⟨1960, 6, 15⟩ ⟨2024, 6, 14⟩ == 63
#guard completedYears ⟨1960, 6, 15⟩ ⟨2024, 1, 31⟩ == 63

end Date
end UsTax

#print axioms UsTax.Date.age65OrOlder_iff
#print axioms UsTax.Date.dayBefore_valid
#print axioms UsTax.Date.not_age65_jan2
