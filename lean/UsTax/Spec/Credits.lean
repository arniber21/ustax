/-!
# Spec: nonrefundable credits never exceed the tax (issues #63, #66)

Main theorem 3 (`UsTax.Main.credits_within_liability` and
`UsTax.Main.totalTax_nonneg`, stated in `UsTax/Comparator/Challenge.lean`):
for every return, lines 18, 21 and 22 of Form 1040 satisfy
`CreditsWithinLiability`, and line 24 (total tax) is not negative.

Form 1040 line 22: "Subtract line 21 from line 18. If zero or less, enter
-0-". Line 21 is the total of the **nonrefundable** credits (child tax credit
and credit for other dependents, line 19, plus Schedule 3 line 8). Refundable
credits (EITC, additional child tax credit, net premium tax credit) are
payments on line 32, not here. Amounts in cents.

This file does not import the calculator.
-/

namespace UsTax.Spec

/-- Line 22 (`taxAfterCredits`) is line 18 (`taxBeforeCredits`) minus line 21
(`credits`), but not less than zero. So the credits actually used,
`taxBeforeCredits - taxAfterCredits`, never exceed the tax
(`CreditsWithinLiability.applied_le_tax`) nor the credits claimed
(`CreditsWithinLiability.applied_le_credits`). -/
def CreditsWithinLiability (taxBeforeCredits credits taxAfterCredits : Int) : Prop :=
  taxAfterCredits = max 0 (taxBeforeCredits - credits)

/-- The credits used never exceed the tax. -/
theorem CreditsWithinLiability.applied_le_tax {t c a : Int} (h : CreditsWithinLiability t c a) :
    t - a ≤ t := by
  unfold CreditsWithinLiability at h; omega

/-- The credits used never exceed the credits claimed. -/
theorem CreditsWithinLiability.applied_le_credits {t c a : Int}
    (h : CreditsWithinLiability t c a) : t - a ≤ c := by
  unfold CreditsWithinLiability at h; omega

/-- The tax after credits is never negative. -/
theorem CreditsWithinLiability.nonneg {t c a : Int} (h : CreditsWithinLiability t c a) :
    0 ≤ a := by
  unfold CreditsWithinLiability at h; omega

/-- Satisfiable: tax $4,019, credits $5,000, tax after credits $0 (only
$4,019 of the credits is used). -/
theorem creditsWithinLiability_example : CreditsWithinLiability 401_900 500_000 0 := by
  unfold CreditsWithinLiability; omega

/-- Rejected: the unused $981 of nonrefundable credit paid out as a negative
tax. -/
theorem not_creditsWithinLiability_negative : ¬ CreditsWithinLiability 401_900 500_000 (-98_100) := by
  unfold CreditsWithinLiability; omega

/-- Rejected: credits ignored. -/
theorem not_creditsWithinLiability_ignored : ¬ CreditsWithinLiability 401_900 200_000 401_900 := by
  unfold CreditsWithinLiability; omega

end UsTax.Spec
