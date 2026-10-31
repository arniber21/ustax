import UsTax.Money

/-!
# List helpers for money (issue #40)

Catala's `Money.sum of (map each x among l to f x)`, `filter`, and counting.
Money is `Int` cents (see `UsTax/Money.lean`), so lists of money are `List Int`.
The lemmas are the ones later proofs need: sums are nonnegative for nonnegative
entries, monotone pointwise, monotone under sublists/filters.
-/

namespace UsTax.Money

/-- `Money.sum of (map each x among l to f x)`. -/
def sumBy {α} (f : α → Int) (l : List α) : Int := sum (l.map f)

/-- How many elements satisfy `p`. -/
def countBy {α} (p : α → Bool) (l : List α) : Nat := (l.filter p).length

theorem foldl_add_eq (a : Int) (l : List Int) : l.foldl (· + ·) a = a + sum l := by
  induction l generalizing a with
  | nil => simp [sum]
  | cons x xs ih =>
    have h1 : (x :: xs).foldl (· + ·) a = xs.foldl (· + ·) (a + x) := rfl
    have h2 := ih (a + x)
    have h3 := ih x
    have h4 : sum (x :: xs) = xs.foldl (· + ·) (0 + x) := rfl
    have h5 : 0 + x = x := by omega
    rw [h1, h2, h4, h5, h3]; omega

theorem sum_nil : sum [] = 0 := rfl

theorem sum_cons (a : Int) (l : List Int) : sum (a :: l) = a + sum l := by
  have := foldl_add_eq a l
  have h4 : sum (a :: l) = l.foldl (· + ·) (0 + a) := rfl
  rw [h4]
  have h5 : 0 + a = a := by omega
  rw [h5, this]

theorem sum_append (l₁ l₂ : List Int) : sum (l₁ ++ l₂) = sum l₁ + sum l₂ := by
  induction l₁ with
  | nil => simp [sum_nil]
  | cons x xs ih => rw [List.cons_append, sum_cons, sum_cons, ih]; omega

/-- A sum of nonnegative entries is nonnegative. -/
theorem sum_nonneg {l : List Int} (h : ∀ x ∈ l, 0 ≤ x) : 0 ≤ sum l := by
  induction l with
  | nil => simp [sum_nil]
  | cons x xs ih =>
    rw [sum_cons]
    have := h x (by simp)
    have := ih (fun y hy => h y (by simp [hy]))
    omega

/-- A sublist of nonnegative entries has a smaller sum. -/
theorem sum_le_of_sublist {l₁ l₂ : List Int} (hs : l₁.Sublist l₂) (h : ∀ x ∈ l₂, 0 ≤ x) :
    sum l₁ ≤ sum l₂ := by
  induction hs with
  | slnil => simp [sum_nil]
  | cons a _ ih =>
    rw [sum_cons]
    have := h a (by simp)
    have := ih (fun y hy => h y (by simp [hy]))
    omega
  | cons_cons a _ ih =>
    rw [sum_cons, sum_cons]
    have := ih (fun y hy => h y (by simp [hy]))
    omega

theorem sumBy_nil {α} (f : α → Int) : sumBy f [] = 0 := rfl

theorem sumBy_cons {α} (f : α → Int) (a : α) (l : List α) :
    sumBy f (a :: l) = f a + sumBy f l := by
  unfold sumBy; rw [List.map_cons, sum_cons]

theorem sumBy_append {α} (f : α → Int) (l₁ l₂ : List α) :
    sumBy f (l₁ ++ l₂) = sumBy f l₁ + sumBy f l₂ := by
  unfold sumBy; rw [List.map_append, sum_append]

theorem sumBy_nonneg {α} {f : α → Int} {l : List α} (h : ∀ x ∈ l, 0 ≤ f x) :
    0 ≤ sumBy f l := by
  induction l with
  | nil => simp [sumBy_nil]
  | cons x xs ih =>
    rw [sumBy_cons]
    have := h x (by simp)
    have := ih (fun y hy => h y (by simp [hy]))
    omega

/-- Monotone in the summand function. -/
theorem sumBy_mono {α} {f g : α → Int} {l : List α} (h : ∀ x ∈ l, f x ≤ g x) :
    sumBy f l ≤ sumBy g l := by
  induction l with
  | nil => simp [sumBy_nil]
  | cons x xs ih =>
    rw [sumBy_cons, sumBy_cons]
    have := h x (by simp)
    have := ih (fun y hy => h y (by simp [hy]))
    omega

theorem sumBy_add {α} (f g : α → Int) (l : List α) :
    sumBy (fun x => f x + g x) l = sumBy f l + sumBy g l := by
  induction l with
  | nil => simp [sumBy_nil]
  | cons x xs ih => rw [sumBy_cons, sumBy_cons, sumBy_cons, ih]; omega

theorem sumBy_filter_nonneg {α} {f : α → Int} (p : α → Bool) {l : List α}
    (h : ∀ x ∈ l, 0 ≤ f x) : 0 ≤ sumBy f (l.filter p) :=
  sumBy_nonneg (fun y hy => h y (List.mem_filter.mp hy).1)

/-- Filtering nonnegative summands cannot increase the sum. -/
theorem sumBy_filter_le {α} {f : α → Int} (p : α → Bool) {l : List α}
    (h : ∀ x ∈ l, 0 ≤ f x) : sumBy f (l.filter p) ≤ sumBy f l := by
  induction l with
  | nil => simp [sumBy_nil]
  | cons x xs ih =>
    have hx := h x (by simp)
    have hxs := ih (fun y hy => h y (by simp [hy]))
    have hn := sumBy_filter_nonneg (f := f) p (l := xs) (fun y hy => h y (by simp [hy]))
    rw [List.filter_cons]
    cases hp : p x <;> simp [sumBy_cons] <;> omega

/-- A filter and its complement partition the sum. -/
theorem sumBy_filter_add_not {α} (f : α → Int) (p : α → Bool) (l : List α) :
    sumBy f (l.filter p) + sumBy f (l.filter (fun x => !p x)) = sumBy f l := by
  induction l with
  | nil => simp [sumBy_nil]
  | cons x xs ih =>
    rw [sumBy_cons]
    cases hp : p x <;> simp [hp, sumBy_cons] <;> omega

theorem countBy_le_length {α} (p : α → Bool) (l : List α) : countBy p l ≤ l.length :=
  List.length_filter_le p l

#guard sum [] == 0
#guard sum [100, -250, 5] == -145
#guard sumBy (fun (x : Int) => x * 2) [1, 2, 3] == 12
#guard countBy (fun (x : Int) => decide (x > 0)) [1, -2, 3, 0] == 2
#guard sumBy id ([5, -3, 7].filter (fun x : Int => decide (x > 0))) == 12

end UsTax.Money

#print axioms UsTax.Money.sumBy_filter_le
#print axioms UsTax.Money.sum_le_of_sublist
#print axioms UsTax.Money.sumBy_filter_add_not
