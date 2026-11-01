import UsTax.TaxRates.Lemmas
import UsTax.Spec.TaxTable

/-!
# Lemmas for main theorem 5: line 16 equals the printed Tax Table

Method. `tentativeTaxFor` is monotone in taxable income
(`tentativeTaxFor_mono`). So if it equals the printed amount at the first cent
of a row (`atLeast`) and at the last cent (`butLessThan - $0.01`), it equals it
on every cent in between. The two endpoint checks for every row and every
filing status (2,062 rows x 5 statuses x 2 = 20,620 evaluations) are done by
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

/-- The rows chain from `a` to `b`: the first starts at `a`, each is nonempty,
each starts where the previous ended, and the last ends at `b`. -/
def chainOk : Int → List Row → Int → Bool
  | a, [], b => a == b
  | a, r :: rs, b => r.atLeast == a && decide (r.atLeast < r.butLessThan) &&
      chainOk r.butLessThan rs b

theorem chainOk_cover : ∀ (L : List Row) (a b x : Int), chainOk a L b = true → a ≤ x → x < b →
    ∃ r ∈ L, r.atLeast ≤ x ∧ x < r.butLessThan
  | [], a, b, x, h, h1, h2 => by
    simp only [chainOk, beq_iff_eq] at h; omega
  | r :: rs, a, b, x, h, h1, h2 => by
    simp only [chainOk, Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq] at h
    obtain ⟨⟨ha, hlt⟩, hrest⟩ := h
    by_cases hx : x < r.butLessThan
    · exact ⟨r, List.mem_cons_self .., by omega, hx⟩
    · obtain ⟨r', hr', h'⟩ := chainOk_cover rs r.butLessThan b x hrest (by omega) h2
      exact ⟨r', List.mem_cons_of_mem _ hr', h'⟩

/-- The printed rows tile $0 to $100,000 with no gap and no overlap. (The
earlier version of the data lacked the rows [$5, $15) and [$15, $25).) -/
theorem rows_chain : chainOk 0 rows 100_000 = true := by decide +kernel

/-- Every cent of taxable income in [$0, $100,000) is in some row, so the
Tax Table property (main theorem 5) constrains line 16 for all of them. -/
theorem rows_cover (ti : Int) (h0 : 0 ≤ ti) (h1 : ti < dollars 100_000) :
    ∃ r ∈ rows, InRow r ti := by
  have hc := chainOk_cover rows 0 100_000 (ti / 100) rows_chain (by omega)
    (by unfold dollars at h1; omega)
  obtain ⟨r, hr, a, b⟩ := hc
  exact ⟨r, hr, by unfold dollars; omega, by unfold dollars; omega⟩

end UsTax.Proofs
