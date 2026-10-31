/-!
# Exception groups: Conflict and NoValue (issue #40)

Catala defaults (`docs/catala-to-lean.md` section 3.4): a rule with an
`exception` sibling group raises `Conflict` when two or more exceptions apply
and `NoValue` when a variable has no applicable rule. The hand-written Lean
calculator (strategy (c)) uses one of two patterns for each exception group:

1. **Disjointness pattern (default).** Write the group as an `if` chain in
   priority order and prove the conditions pairwise disjoint (`Disjoint`,
   `handleExceptions_two_disjoint`). Then no `Conflict` is possible and the
   chain equals Catala's result. Nested single-exception chains (one exception
   per level) need no proof: they are an `if/else if` chain by construction.
2. **Combinator pattern.** Where the Catala source has real sibling
   exceptions whose conditions may overlap, use `handleExceptions`/
   `defaultRule`, which return `Except Error (Option α)` and reproduce
   `Conflict`. `errorOnEmpty` reproduces `NoValue`.

Positions (source locations) are dropped. Port of `docs/spike/lean/Spike/Runtime.lean`.
-/

namespace UsTax

/-- Run-time errors of Catala defaults that the Lean calculator can reproduce. -/
inductive Error where
  /-- two or more exceptions of one group apply -/
  | conflict
  /-- a variable has no applicable rule -/
  | noValue
  deriving DecidableEq, Repr

/-- Equality test on results, for `#guard` unit tests. -/
instance {α} [BEq α] : BEq (Except Error α) where
  beq
    | .ok a, .ok b => a == b
    | .error a, .error b => a == b
    | _, _ => false

/-- `guard c a`: the exception value `a` when its condition `c` holds, else
absent (`Absent` in Catala's `Optional`). -/
def guard {α} (c : Prop) [Decidable c] (a : α) : Option α := if c then some a else none

/-- Catala `handle_exceptions`: none present is `none`, exactly one present is
that one, several present is `Conflict`. -/
def handleExceptions {α} (xs : List (Option α)) : Except Error (Option α) :=
  match xs.filterMap id with
  | [] => .ok none
  | [x] => .ok (some x)
  | _ => .error .conflict

/-- `<exceptions> | just :- cons`: the exceptions decide if any apply;
otherwise the base case if its justification holds; otherwise empty. -/
def defaultRule {α} (excepts : List (Option α)) (just : Bool) (cons : α) :
    Except Error (Option α) :=
  match handleExceptions excepts with
  | .ok (some x) => .ok (some x)
  | .ok none => .ok (if just then some cons else none)
  | .error e => .error e

/-- `ErrorOnEmpty`: no applicable rule is `NoValue`. -/
def errorOnEmpty {α} : Option α → Except Error α
  | some x => .ok x
  | none => .error .noValue

/-- Two conditions never hold together (the disjointness obligation of an
exception group). -/
def Disjoint {α} (p q : α → Prop) : Prop := ∀ x, ¬ (p x ∧ q x)

theorem handleExceptions_nil {α} : handleExceptions ([] : List (Option α)) = .ok none := rfl

theorem handleExceptions_single {α} (x : Option α) : handleExceptions [x] = .ok x := by
  cases x <;> rfl

/-- At most one exception present: never a `Conflict`. -/
theorem handleExceptions_ok_of_length_le_one {α} (xs : List (Option α))
    (h : (xs.filterMap id).length ≤ 1) : ∃ r, handleExceptions xs = .ok r := by
  unfold handleExceptions
  generalize xs.filterMap id = ys at h
  match ys, h with
  | [], _ => exact ⟨_, rfl⟩
  | [_], _ => exact ⟨_, rfl⟩

/-- Two or more exceptions present: `Conflict`. -/
theorem handleExceptions_conflict {α} (xs : List (Option α))
    (h : 2 ≤ (xs.filterMap id).length) : handleExceptions xs = .error .conflict := by
  unfold handleExceptions
  generalize xs.filterMap id = ys at h
  match ys, h with
  | _ :: _ :: _, _ => rfl

/-- The disjointness pattern for two exceptions: if the conditions exclude each
other the group never conflicts and equals the priority `if` chain. -/
theorem handleExceptions_two_disjoint {α} (p q : Prop) [Decidable p] [Decidable q]
    (a b : α) (h : ¬ (p ∧ q)) :
    handleExceptions [guard p a, guard q b] =
      .ok (if p then some a else if q then some b else none) := by
  by_cases hp : p <;> by_cases hq : q <;> simp_all [handleExceptions, guard]

/-- Disjointness pattern for three exceptions (pairwise). -/
theorem handleExceptions_three_disjoint {α} (p q r : Prop) [Decidable p] [Decidable q]
    [Decidable r] (a b c : α) (hpq : ¬ (p ∧ q)) (hpr : ¬ (p ∧ r)) (hqr : ¬ (q ∧ r)) :
    handleExceptions [guard p a, guard q b, guard r c] =
      .ok (if p then some a else if q then some b else if r then some c else none) := by
  by_cases hp : p <;> by_cases hq : q <;> by_cases hr : r <;>
    simp_all [handleExceptions, guard]

/-- A default rule whose exceptions are disjoint is the plain `if` chain. -/
theorem defaultRule_two_disjoint {α} (p q : Prop) [Decidable p] [Decidable q]
    (a b : α) (just : Bool) (c : α) (h : ¬ (p ∧ q)) :
    defaultRule [guard p a, guard q b] just c =
      .ok (if p then some a else if q then some b else if just then some c else none) := by
  by_cases hp : p <;> by_cases hq : q <;> simp_all [defaultRule, handleExceptions, guard]

/-- `errorOnEmpty` never fails on a present value. -/
theorem errorOnEmpty_some {α} (x : α) : errorOnEmpty (some x) = .ok x := rfl

/-! ### Worked example of the disjointness pattern

A toy group: a base value with two exceptions, "negative" and "at least 100".
The conditions are disjoint (`omega`), so the group cannot conflict. -/

/-- Exception condition: the input is negative. -/
def IsNegative (n : Int) : Prop := n < 0
/-- Exception condition: the input is at least 100. -/
def IsLarge (n : Int) : Prop := 100 ≤ n

instance (n : Int) : Decidable (IsNegative n) := inferInstanceAs (Decidable (n < 0))
instance (n : Int) : Decidable (IsLarge n) := inferInstanceAs (Decidable (100 ≤ n))

/-- The two toy conditions are disjoint. -/
theorem isNegative_isLarge_disjoint : Disjoint IsNegative IsLarge := by
  intro n; unfold IsNegative IsLarge; omega

/-- The group written with the combinator. -/
def toyGroup (n : Int) : Except Error (Option Int) :=
  defaultRule [guard (IsNegative n) 1, guard (IsLarge n) 2] true 0

/-- No `Conflict` for any input, by the disjointness lemma. -/
theorem toyGroup_eq (n : Int) :
    toyGroup n =
      .ok (if IsNegative n then some 1 else if IsLarge n then some 2 else some 0) := by
  have h : ¬ (IsNegative n ∧ IsLarge n) := isNegative_isLarge_disjoint n
  have := defaultRule_two_disjoint (IsNegative n) (IsLarge n) (1 : Int) 2 true 0 h
  unfold toyGroup; simpa using this

/-- Overlapping conditions do conflict: the combinator reports it. -/
example : handleExceptions [guard (0 ≤ (5 : Int)) 1, guard ((5 : Int) ≤ 10) 2] =
    .error .conflict := by
  rfl

#guard toyGroup (-3) == .ok (some 1)
#guard toyGroup 500 == .ok (some 2)
#guard toyGroup 50 == .ok (some 0)
#guard (handleExceptions [some 1, none, some 2] == .error .conflict)
#guard (handleExceptions [none, some 2, none] == .ok (some 2))
#guard (handleExceptions ([none, none] : List (Option Nat)) == .ok none)
#guard (errorOnEmpty (none : Option Nat) == .error .noValue)
#guard (defaultRule [none, none] false 7 == .ok (none : Option Nat))
#guard (defaultRule [none, some 3] true 7 == .ok (some 3))
#guard (defaultRule [none, none] true 7 == .ok (some 7))

end UsTax

#print axioms UsTax.toyGroup_eq
#print axioms UsTax.handleExceptions_three_disjoint
