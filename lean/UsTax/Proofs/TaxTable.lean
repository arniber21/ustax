import UsTax.TaxRates.Lemmas
import UsTax.Spec.TaxTable

/-!
# Lemmas for main theorem 5: line 16 equals the printed Tax Table

Method. `tentativeTaxFor` is monotone in taxable income
(`tentativeTaxFor_mono`). So if it equals the printed amount at the first cent
of a row (`atLeast`) and at the last cent (`butLessThan - $0.01`), it equals it
on every cent in between. The two endpoint checks for every row and every
filing status (2,060 rows x 5 statuses x 2 = 20,600 evaluations) are done by
the **kernel** (`decide +kernel`, no `native_decide`), one theorem per data
chunk `rows0` ... `rows20`, about 3 s each.

This replaces the compiled `#guard`s of `UsTax/TaxRates/TaxTable.lean` by a
proof, and covers every cent, not only the two endpoints.
-/

namespace UsTax.Proofs

open UsTax.Spec UsTax.TaxRates UsTax.TaxRates.TaxTable

/-- The code agrees with row `r` at both ends of the row, for every filing
status. -/
def rowEndsOk (r : Row) : Bool := FilingStatus.all.all fun fs =>
  tentativeTaxFor (dollars r.atLeast) fs == dollars (printedTax r fs) &&
  tentativeTaxFor (dollars r.butLessThan - 1) fs == dollars (printedTax r fs)

theorem rows0_ok : rows0.all rowEndsOk = true := by decide +kernel
theorem rows1_ok : rows1.all rowEndsOk = true := by decide +kernel
theorem rows2_ok : rows2.all rowEndsOk = true := by decide +kernel
theorem rows3_ok : rows3.all rowEndsOk = true := by decide +kernel
theorem rows4_ok : rows4.all rowEndsOk = true := by decide +kernel
theorem rows5_ok : rows5.all rowEndsOk = true := by decide +kernel
theorem rows6_ok : rows6.all rowEndsOk = true := by decide +kernel
theorem rows7_ok : rows7.all rowEndsOk = true := by decide +kernel
theorem rows8_ok : rows8.all rowEndsOk = true := by decide +kernel
theorem rows9_ok : rows9.all rowEndsOk = true := by decide +kernel
theorem rows10_ok : rows10.all rowEndsOk = true := by decide +kernel
theorem rows11_ok : rows11.all rowEndsOk = true := by decide +kernel
theorem rows12_ok : rows12.all rowEndsOk = true := by decide +kernel
theorem rows13_ok : rows13.all rowEndsOk = true := by decide +kernel
theorem rows14_ok : rows14.all rowEndsOk = true := by decide +kernel
theorem rows15_ok : rows15.all rowEndsOk = true := by decide +kernel
theorem rows16_ok : rows16.all rowEndsOk = true := by decide +kernel
theorem rows17_ok : rows17.all rowEndsOk = true := by decide +kernel
theorem rows18_ok : rows18.all rowEndsOk = true := by decide +kernel
theorem rows19_ok : rows19.all rowEndsOk = true := by decide +kernel
theorem rows20_ok : rows20.all rowEndsOk = true := by decide +kernel

/-- Every row of the table passes the endpoint check. -/
theorem rows_ok : rows.all rowEndsOk = true := by
  simp only [rows, List.all_append, rows0_ok, rows1_ok, rows2_ok, rows3_ok, rows4_ok, rows5_ok,
    rows6_ok, rows7_ok, rows8_ok, rows9_ok, rows10_ok, rows11_ok, rows12_ok, rows13_ok,
    rows14_ok, rows15_ok, rows16_ok, rows17_ok, rows18_ok, rows19_ok, rows20_ok, Bool.and_self]

/-- `tentativeTaxFor` meets the printed Tax Table for every filing status and
every taxable income. -/
theorem tentativeTaxFor_matchesTaxTable (fs : FilingStatus) (ti : Int) :
    MatchesTaxTable fs ti (tentativeTaxFor ti fs) := by
  intro r hr ⟨hlo, hhi⟩
  have hok := List.all_eq_true.mp rows_ok r hr
  simp only [rowEndsOk, List.all_eq_true, Bool.and_eq_true, beq_iff_eq] at hok
  have hfs : fs ∈ FilingStatus.all := by cases fs <;> decide
  obtain ⟨h1, h2⟩ := hok fs hfs
  have m1 := tentativeTaxFor_mono fs hlo
  have m2 := tentativeTaxFor_mono fs (show ti ≤ dollars r.butLessThan - 1 by omega)
  omega

/-- The data has no row for [$5, $25): the CSV it is generated from skips the
printed rows [$5, $15) and [$15, $25). Every other pair of neighbouring rows
abuts, and the last row ends at $100,000. (A fact about the data, recorded
for the reviewer; see `docs/spec-surface.md`.) -/
theorem rows_layout :
    (rows.take 2).map (fun r => (r.atLeast, r.butLessThan)) = [(0, 5), (25, 50)] ∧
    ((rows.drop 1).zip (rows.drop 2)).all (fun (a, b) => a.butLessThan == b.atLeast) = true ∧
    (rows.getLast?.map (·.butLessThan)) = some 100_000 := by
  decide +kernel

end UsTax.Proofs
