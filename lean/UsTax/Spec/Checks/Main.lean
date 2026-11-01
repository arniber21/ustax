import UsTax.Proofs.Main

/-!
# Spec checks of the main theorems (CLAUDE.md section 4; issues #61, #62, #68)

For each statement of `lean/comparator.json` (`UsTax.Main.<stmt>`):

* `Main.<stmt>_sat`: the theorem instantiated on a concrete input with every hypothesis
  discharged, with the concrete values of the output computed by the kernel. It shows that the
  hypotheses are satisfiable and what the statement says on that input.
* `Main.<stmt>_bad_<what>`: at least two known-bad outputs on a concrete input, each rejected
  (`¬ Spec input badOutput`). Each is a plausible bug: a dropped floor, a missed midpoint, the
  wrong column, both refund and amount owed nonzero, and so on.

`make spec-checks` (`scripts/gen_spec_checks.py`) fails if a statement lacks either, and writes
the table `docs/spec-checks.md`. The concrete returns are `UsTax.Main.sampleReturn` (single,
$50,000 of wages, $5,000 withheld: line 15 $35,400, line 24 $4,019, refund $981) and
`UsTax.Main.highIncomeReturn` (single, $200,000 of wages: line 15 $185,400, line 16 $37,539).
-/

namespace UsTax.Checks.Main

open UsTax.Spec UsTax.TaxRates UsTax.Form1040 UsTax.Main

/-! ## (1) `tentativeTax_nonneg_monotone` -/

/-- Single: line 16 is $4,019 at $35,400 and $4,025 at $35,450, in order, and the property holds
for the single column. -/
theorem tentativeTax_nonneg_monotone_sat :
    NonnegMonotone (fun ti => tentativeTaxFor ti .single) ∧
    tentativeTaxFor 35_400_00 .single = 4_019_00 ∧ tentativeTaxFor 35_450_00 .single = 4_025_00 ∧
    tentativeTaxFor 35_400_00 .single ≤ tentativeTaxFor 35_450_00 .single :=
  ⟨tentativeTax_nonneg_monotone .single, by decide +kernel, by decide +kernel,
    (tentativeTax_nonneg_monotone .single).2 _ _ (by decide)⟩

/-- Rejected: a tax that drops to `$0` from $35,450 (a cliff) is not monotone. -/
theorem tentativeTax_nonneg_monotone_bad_cliff :
    ¬ NonnegMonotone (fun ti => if ti < 35_450_00 then tentativeTaxFor ti .single else 0) := by
  intro ⟨_, h⟩
  have h1 := h 35_400_00 35_450_00 (by decide)
  have : tentativeTaxFor 35_400_00 .single = 4_019_00 := by decide +kernel
  simp only [show (35_400_00 : Int) < 35_450_00 from by decide, ↓reduceIte,
    show ¬ ((35_450_00 : Int) < 35_450_00) from by decide, this] at h1
  omega

/-- Rejected: line 16 lowered by one cent everywhere is negative at taxable income `$0`. -/
theorem tentativeTax_nonneg_monotone_bad_negative :
    ¬ NonnegMonotone (fun ti => tentativeTaxFor ti .single - 1) := by
  intro ⟨h, _⟩
  have h0 := h 0
  have : tentativeTaxFor 0 .single = 0 := by decide +kernel
  simp only [this] at h0
  omega

/-! ## (2) `refund_balanceDue_consistent` -/

/-- The concrete return: tax $4,019, payments $5,000, refund $981, nothing owed. -/
theorem refund_balanceDue_consistent_sat :
    RefundOrBalanceDue 4_019_00 5_000_00 981_00 0 ∧
    (form1040 sampleReturn).overpayment = 981_00 ∧ (form1040 sampleReturn).balanceDue = 0 := by
  have h := refund_balanceDue_consistent sampleReturn
  obtain ⟨_, _, h3, h4, h5, h6⟩ := sampleReturn_lines
  rw [h3, h4, h5, h6] at h
  exact ⟨h, h5, h6⟩

/-- Rejected: on that return, a refund of $981 and also $981 owed. -/
theorem refund_balanceDue_consistent_bad_both :
    ¬ RefundOrBalanceDue 4_019_00 5_000_00 981_00 981_00 := by
  unfold RefundOrBalanceDue; omega

/-- Rejected: on that return, the refund off by one cent. -/
theorem refund_balanceDue_consistent_bad_off_by_one :
    ¬ RefundOrBalanceDue 4_019_00 5_000_00 981_01 0 := by
  unfold RefundOrBalanceDue; omega

/-- Rejected: on that return, the refund reported as a negative amount owed. -/
theorem refund_balanceDue_consistent_bad_negative :
    ¬ RefundOrBalanceDue 4_019_00 5_000_00 0 (-981_00) := by
  unfold RefundOrBalanceDue; omega

/-! ## (3a) `credits_within_liability` -/

/-- The return with $5,000 of child tax credit: tax $4,019, credits $5,000, line 22 `$0`. -/
theorem credits_within_liability_sat :
    CreditsWithinLiability 4_019_00 5_000_00 0 ∧
    (form1040 { sampleReturn with totalCtcAndOdc := 5_000_00 }).taxLessNonRefundableCredits = 0 := by
  have h := credits_within_liability { sampleReturn with totalCtcAndOdc := 5_000_00 }
  have : (form1040 { sampleReturn with totalCtcAndOdc := 5_000_00 }).totalTentativeTax = 4_019_00 ∧
      (form1040 { sampleReturn with totalCtcAndOdc := 5_000_00 }).nonRefundableCredits = 5_000_00 := by
    decide +kernel
  have h22 : (form1040 { sampleReturn with totalCtcAndOdc := 5_000_00 }).taxLessNonRefundableCredits = 0 := by
    decide +kernel
  rw [this.1, this.2, h22] at h
  exact ⟨h, h22⟩

/-- Rejected: the unused $981 of nonrefundable credit paid out (line 22 −$981). -/
theorem credits_within_liability_bad_unfloored :
    ¬ CreditsWithinLiability 4_019_00 5_000_00 (-981_00) := by
  unfold CreditsWithinLiability; omega

/-- Rejected: the credits ignored (line 22 = line 18). -/
theorem credits_within_liability_bad_ignored :
    ¬ CreditsWithinLiability 4_019_00 5_000_00 4_019_00 := by
  unfold CreditsWithinLiability; omega

/-! ## (3b) `totalTax_nonneg` -/

/-- The concrete return: line 24 is $4,019, and the return with $5,000 of credits has line 24
`$0`; both nonnegative. -/
theorem totalTax_nonneg_sat :
    (form1040 sampleReturn).totalTax = 4_019_00 ∧ 0 ≤ (form1040 sampleReturn).totalTax ∧
    (form1040 { sampleReturn with totalCtcAndOdc := 5_000_00 }).totalTax = 0 ∧
    0 ≤ (form1040 { sampleReturn with totalCtcAndOdc := 5_000_00 }).totalTax :=
  ⟨sampleReturn_lines.2.2.1, totalTax_nonneg _, by decide +kernel, totalTax_nonneg _⟩

/-- Rejected: the unfloored line 24 of the $5,000-credit return, −$981. -/
theorem totalTax_nonneg_bad_unfloored : ¬ (0 ≤ (4_019_00 - 5_000_00 : Int)) := by decide

/-- Rejected: one cent below zero. -/
theorem totalTax_nonneg_bad_one_cent : ¬ (0 ≤ (-1 : Int)) := by decide

/-! ## (5a) `tentativeTax_matches_tax_table` -/

/-- Single, $35,400: line 16 is $4,019, the printed amount of row [$35,400, $35,450). -/
theorem tentativeTax_matches_tax_table_sat :
    MatchesTaxTable .single 35_400_00 4_019_00 ∧ tentativeTaxFor 35_400_00 .single = 4_019_00 := by
  have h := tentativeTax_matches_tax_table .single 35_400_00
  have hv : tentativeTaxFor 35_400_00 .single = 4_019_00 := by decide +kernel
  rw [hv] at h
  exact ⟨h, hv⟩

/-- Rejected: the exact tax on $35,400 without the row midpoint, $4,016
($1,160 + 12% × $23,800). -/
theorem tentativeTax_matches_tax_table_bad_no_midpoint :
    ¬ MatchesTaxTable .single 35_400_00 4_016_00 := by
  intro h
  have key : ∃ r ∈ TaxTable.rows, (dollars r.atLeast ≤ 35_400_00 ∧ 35_400_00 < dollars r.butLessThan) ∧
      4_016_00 ≠ dollars (printedTax r .single) := by
    unfold dollars printedTax; decide +kernel
  obtain ⟨r, hr, hin, hne⟩ := key
  exact hne (h r hr hin)

/-- Rejected: the joint column ($3,787) for a single filer. -/
theorem tentativeTax_matches_tax_table_bad_wrong_column :
    ¬ MatchesTaxTable .single 35_400_00 3_787_00 := by
  intro h
  have key : ∃ r ∈ TaxTable.rows, (dollars r.atLeast ≤ 35_400_00 ∧ 35_400_00 < dollars r.butLessThan) ∧
      3_787_00 ≠ dollars (printedTax r .single) := by
    unfold dollars printedTax; decide +kernel
  obtain ⟨r, hr, hin, hne⟩ := key
  exact hne (h r hr hin)

/-! ## (5b) `line16_matches_tax_table` -/

/-- The concrete return: line 15 $35,400, line 16 $4,019, the printed amount. -/
theorem line16_matches_tax_table_sat :
    MatchesTaxTable .single 35_400_00 4_019_00 ∧ sampleReturn.filingStatus = .single := by
  have h := line16_matches_tax_table sampleReturn
  have hfs : sampleReturn.filingStatus = .single := by decide +kernel
  rw [sampleReturn_lines.1, sampleReturn_lines.2.1, hfs] at h
  exact ⟨h, hfs⟩

/-- Rejected: line 16 of the concrete return one dollar low ($4,018). -/
theorem line16_matches_tax_table_bad_one_dollar :
    ¬ MatchesTaxTable .single 35_400_00 4_018_00 := by
  intro h
  have key : ∃ r ∈ TaxTable.rows, (dollars r.atLeast ≤ 35_400_00 ∧ 35_400_00 < dollars r.butLessThan) ∧
      4_018_00 ≠ dollars (printedTax r .single) := by
    unfold dollars printedTax; decide +kernel
  obtain ⟨r, hr, hin, hne⟩ := key
  exact hne (h r hr hin)

/-- Rejected: the tax on line 11 ($50,000) instead of line 15, $6,059 (deduction skipped). -/
theorem line16_matches_tax_table_bad_no_deduction :
    ¬ MatchesTaxTable .single 35_400_00 6_059_00 := by
  intro h
  have key : ∃ r ∈ TaxTable.rows, (dollars r.atLeast ≤ 35_400_00 ∧ 35_400_00 < dollars r.butLessThan) ∧
      6_059_00 ≠ dollars (printedTax r .single) := by
    unfold dollars printedTax; decide +kernel
  obtain ⟨r, hr, hin, hne⟩ := key
  exact hne (h r hr hin)

/-! ## (5c) `tentativeTax_matches_worksheet` -/

/-- Single, $185,400 (both hypotheses discharged): $37,539. -/
theorem tentativeTax_matches_worksheet_sat :
    tentativeTaxFor 185_400_00 .single = worksheetTax .single 185_400_00 ∧
    worksheetTax .single 185_400_00 = 37_539_00 :=
  ⟨tentativeTax_matches_worksheet .single 185_400_00 (by decide) (by decide), by decide⟩

/-- Rejected: $37,538.50 rounded down. -/
theorem tentativeTax_matches_worksheet_bad_round_down :
    ¬ ((37_538_00 : Int) = worksheetTax .single 185_400_00) := by decide

/-- Rejected: the Section B (joint) row for a single filer ($30,894). -/
theorem tentativeTax_matches_worksheet_bad_wrong_section :
    ¬ ((30_894_00 : Int) = worksheetTax .single 185_400_00) := by decide

/-! ## (5d) `line16_matches_worksheet` -/

/-- The $200,000 return: line 15 $185,400 (both hypotheses discharged), line 16 $37,539. -/
theorem line16_matches_worksheet_sat :
    (form1040 highIncomeReturn).tentativeTaxFromTaxableIncome = worksheetTax .single 185_400_00 ∧
    (form1040 highIncomeReturn).tentativeTaxFromTaxableIncome = 37_539_00 := by
  have h := line16_matches_worksheet highIncomeReturn
    (by rw [highIncomeReturn_lines.1]; decide) (by rw [highIncomeReturn_lines.1]; decide)
  rw [highIncomeReturn_lines.1, highIncomeReturn_lines.2.2] at h
  exact ⟨h, highIncomeReturn_lines.2.1⟩

/-- Rejected: 24% of line 15 with nothing subtracted ($44,496). -/
theorem line16_matches_worksheet_bad_no_subtraction :
    ¬ ((44_496_00 : Int) = worksheetTax .single 185_400_00) := by decide

/-- Rejected: the worksheet on line 11 ($200,000) instead of line 15 ($41,043). -/
theorem line16_matches_worksheet_bad_no_deduction :
    ¬ ((41_043_00 : Int) = worksheetTax .single 185_400_00) := by decide

/-! ## (4) `eitc_within_bounds` -/

/-- Single, one child, $15,000: the credit is the maximum, $4,213; at the completed phase-out,
$49,084, it is `$0`. -/
theorem eitc_within_bounds_sat :
    EitcWithinBounds (Eitc.caseOf ⟨15_000_00, 15_000_00, false, 1⟩) 4_213_00 ∧
    EitcWithinBounds (Eitc.caseOf ⟨49_084_00, 49_084_00, false, 1⟩) 0 := by
  have h1 := eitc_within_bounds ⟨15_000_00, 15_000_00, false, 1⟩
  have h2 := eitc_within_bounds ⟨49_084_00, 49_084_00, false, 1⟩
  rw [eitc_example_max] at h1
  rw [eitc_example_phased_out] at h2
  exact ⟨h1, h2⟩

/-- Rejected: one dollar above the one-child maximum. -/
theorem eitc_within_bounds_bad_above_max :
    ¬ EitcWithinBounds (Eitc.caseOf ⟨15_000_00, 15_000_00, false, 1⟩) 4_214_00 := by
  have hc : Eitc.caseOf ⟨15_000_00, 15_000_00, false, 1⟩ = ⟨1, false, 15_000_00, 15_000_00⟩ := rfl
  rw [hc]; exact not_eitcWithinBounds_above_max

/-- Rejected: $1 of credit at the completed phase-out. -/
theorem eitc_within_bounds_bad_after_phaseout :
    ¬ EitcWithinBounds (Eitc.caseOf ⟨49_084_00, 49_084_00, false, 1⟩) 100 := by
  have hc : Eitc.caseOf ⟨49_084_00, 49_084_00, false, 1⟩ = ⟨1, false, 49_084_00, 49_084_00⟩ := rfl
  rw [hc]; unfold EitcWithinBounds; simp only [eitcMaxCredit, eitcCompletedPhaseout]; omega

/-- Rejected: a negative credit (the combat-pay variant without a zero case, DF-BUG-17). -/
theorem eitc_within_bounds_bad_negative :
    ¬ EitcWithinBounds (Eitc.caseOf ⟨15_000_00, 15_000_00, false, 1⟩) (-100) := by
  intro h; exact absurd h.1 (by decide)

end UsTax.Checks.Main
