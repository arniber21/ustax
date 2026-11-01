import UsTax.Spec.TaxMonotone
import UsTax.Spec.RefundBalance
import UsTax.Spec.Credits
import UsTax.Spec.TaxTable
import UsTax.TaxRates.Lemmas
import UsTax.Proofs.Form1040
import UsTax.Proofs.TaxTable
import UsTax.Audit

/-!
# The main theorems, proved (solution module for `lake comparator`)

Same names and statements as `UsTax/Comparator/Challenge.lean`; each proof
refers to a lemma proved elsewhere:

| theorem | proof from |
|---|---|
| `tentativeTax_nonneg_monotone` | `TaxRates.tentativeTaxFor_nonneg`, `tentativeTaxFor_mono` (`TaxRates/Lemmas.lean`) |
| `refund_balanceDue_consistent` | `Proofs.overpayment_eq`, `balanceDue_eq` (`Proofs/Form1040.lean`) |
| `credits_within_liability` | `Proofs.taxLessNonRefundableCredits_eq` |
| `totalTax_nonneg` | `Proofs.totalTax_eq` and the above |
| `tentativeTax_matches_tax_table` | `Proofs.tentativeTaxFor_matchesTaxTable` (`Proofs/TaxTable.lean`) |
| `line16_matches_tax_table` | the same, line 16 being `tentativeTaxFor` of line 15 |

Below them: each theorem on a concrete return with every hypothesis
discharged (CLAUDE.md section 4). The rejected bad outputs are next to each
property in `UsTax/Spec/*.lean`.
-/

namespace UsTax.Main

open UsTax.Spec UsTax.TaxRates UsTax.Form1040

/-- (1) Line 16 is nonnegative and monotone in taxable income. -/
theorem tentativeTax_nonneg_monotone (fs : FilingStatus) :
    NonnegMonotone (fun ti => tentativeTaxFor ti fs) :=
  ⟨fun ti => tentativeTaxFor_nonneg ti fs, fun _ _ h => tentativeTaxFor_mono fs h⟩

/-- (2) Refund and amount owed are exclusive and consistent. -/
theorem refund_balanceDue_consistent (i : Form1040In) :
    RefundOrBalanceDue (form1040 i).totalTax (form1040 i).totalPayments
      (form1040 i).overpayment (form1040 i).balanceDue := by
  unfold RefundOrBalanceDue
  rw [Proofs.overpayment_eq, Proofs.balanceDue_eq]
  omega

/-- (3a) Nonrefundable credits never exceed the tax. -/
theorem credits_within_liability (i : Form1040In) :
    CreditsWithinLiability (form1040 i).totalTentativeTax (form1040 i).nonRefundableCredits
      (form1040 i).taxLessNonRefundableCredits :=
  Proofs.taxLessNonRefundableCredits_eq i

/-- (3b) Total tax is never negative. -/
theorem totalTax_nonneg (i : Form1040In) : 0 ≤ (form1040 i).totalTax := by
  rw [Proofs.totalTax_eq]
  exact (credits_within_liability i).nonneg

/-- (5a) Line 16 is the printed Tax Table amount. -/
theorem tentativeTax_matches_tax_table (fs : FilingStatus) (ti : Int) :
    MatchesTaxTable fs ti (tentativeTaxFor ti fs) :=
  Proofs.tentativeTaxFor_matchesTaxTable fs ti

/-- (5b) The same on every return: line 16 is `tentativeTaxFor` of line 15. -/
theorem line16_matches_tax_table (i : Form1040In) :
    MatchesTaxTable i.filingStatus (form1040 i).taxableIncome
      (form1040 i).tentativeTaxFromTaxableIncome :=
  tentativeTax_matches_tax_table i.filingStatus (form1040 i).taxableIncome

/-! ## The theorems on a concrete return

A single filer with one W-2: $50,000 wages, $5,000 withheld. Line 15 is
$35,400; the Tax Table row [$35,400, $35,450) prints $4,019 for single; line
24 is $4,019, line 33 $5,000, refund $981. Values are computed by the kernel.
-/

/-- The concrete return. -/
def sampleReturn : Form1040In :=
  run [{ writableWages := 50_000_00, writableFederalWithholding := 5_000_00 }]

/-- Its lines 15, 16, 24, 33, 34, 37. -/
theorem sampleReturn_lines :
    (form1040 sampleReturn).taxableIncome = 35_400_00 ∧
    (form1040 sampleReturn).tentativeTaxFromTaxableIncome = 4_019_00 ∧
    (form1040 sampleReturn).totalTax = 4_019_00 ∧
    (form1040 sampleReturn).totalPayments = 5_000_00 ∧
    (form1040 sampleReturn).overpayment = 981_00 ∧
    (form1040 sampleReturn).balanceDue = 0 := by
  decide +kernel

/-- (1) on the concrete incomes $35,400 and $35,450 (hypothesis `a ≤ b`
discharged). -/
example : tentativeTaxFor 35_400_00 .single ≤ tentativeTaxFor 35_450_00 .single :=
  (tentativeTax_nonneg_monotone .single).2 _ _ (by decide)

/-- (2) on the concrete return: refund $981 = payments $5,000 − tax $4,019. -/
example : RefundOrBalanceDue 4_019_00 5_000_00 981_00 0 := by
  have h := refund_balanceDue_consistent sampleReturn
  obtain ⟨_, _, h3, h4, h5, h6⟩ := sampleReturn_lines
  rwa [h3, h4, h5, h6] at h

/-- (3) on a return whose $5,000 of nonrefundable credits exceed the $4,019
tax: line 22 is `$0`, not −$981. -/
example : (form1040 { sampleReturn with totalCtcAndOdc := 5_000_00 }).taxLessNonRefundableCredits = 0 := by
  have h := credits_within_liability { sampleReturn with totalCtcAndOdc := 5_000_00 }
  have : (form1040 { sampleReturn with totalCtcAndOdc := 5_000_00 }).totalTentativeTax = 4_019_00 ∧
      (form1040 { sampleReturn with totalCtcAndOdc := 5_000_00 }).nonRefundableCredits = 5_000_00 := by
    decide +kernel
  unfold CreditsWithinLiability at h
  omega

/-- (5) on the concrete return: line 15 lies in a printed row (the hypotheses
`r ∈ rows` and `InRow r ti` are satisfiable), and line 16 is that row's single
column, $4,019. -/
example : ∃ r ∈ TaxTable.rows, InRow r (form1040 sampleReturn).taxableIncome ∧
    (form1040 sampleReturn).tentativeTaxFromTaxableIncome = dollars (printedTax r .single) := by
  have hrow : ∃ r ∈ TaxTable.rows, InRow r 35_400_00 := by
    unfold InRow dollars; decide +kernel
  obtain ⟨r, hr, hin⟩ := hrow
  rw [sampleReturn_lines.1] at *
  refine ⟨r, hr, hin, ?_⟩
  have := line16_matches_tax_table sampleReturn r hr
  rw [sampleReturn_lines.1] at this
  exact this hin

end UsTax.Main

#audit_axioms UsTax.Main.tentativeTax_nonneg_monotone
#audit_axioms UsTax.Main.refund_balanceDue_consistent
#audit_axioms UsTax.Main.credits_within_liability
#audit_axioms UsTax.Main.totalTax_nonneg
#audit_axioms UsTax.Main.tentativeTax_matches_tax_table
#audit_axioms UsTax.Main.line16_matches_tax_table
#spec_surface UsTax.Main.tentativeTax_nonneg_monotone
#spec_surface UsTax.Main.refund_balanceDue_consistent
#spec_surface UsTax.Main.credits_within_liability
#spec_surface UsTax.Main.totalTax_nonneg
#spec_surface UsTax.Main.tentativeTax_matches_tax_table
#spec_surface UsTax.Main.line16_matches_tax_table
