import UsTax.Money
import UsTax.Params2024

/-!
# Educator expenses adjustment (Schedule 1 line 11) (issue #45)

Lean implementation of `catala/educator_adjustment.catala_en` (module
`Educator_adjustment`, scope `EducatorAdjustment`), written by hand from the Catala
source under strategy (c) of `docs/catala-to-lean.md`; the code that runs.
IRC 62(a)(2)(D), Rev. Proc. 2023-34 § 3.13.

| Catala (`Educator_adjustment`)  | Lean (`UsTax.EducatorAdjustment`)                 |
|---------------------------------|---------------------------------------------------|
| `enumeration K12EducatorOptions` | `K12EducatorOptions` (`tpDid`, `spouseDid`, `bothDid`, `neither`) |
| `scope EducatorAdjustment`      | `EducatorAdjustmentIn` → `EducatorAdjustmentOut` (`educatorAdjustment`) |

Money is `Int` cents.
-/

namespace UsTax.EducatorAdjustment

open Money

/-- Catala `K12EducatorOptions` (DF `/k12EducatorOptions`). -/
inductive K12EducatorOptions where
  /-- The taxpayer was an eligible educator. -/
  | tpDid
  /-- The spouse was. -/
  | spouseDid
  /-- Both were. -/
  | bothDid
  /-- Neither was. -/
  | neither
  deriving DecidableEq, Repr, Inhabited

namespace K12EducatorOptions

/-- Parse a Catala case name (`"TpDid"`) or a Direct File option (`"tpDid"`). -/
def ofString? : String → Option K12EducatorOptions
  | "TpDid" | "tpDid" => some tpDid
  | "SpouseDid" | "spouseDid" => some spouseDid
  | "BothDid" | "bothDid" => some bothDid
  | "Neither" | "neither" => some neither
  | _ => none

end K12EducatorOptions

/-- Inputs of `EducatorAdjustment`. -/
structure EducatorAdjustmentIn where
  /-- Catala input `was_k12_educators`. -/
  wasK12Educators : K12EducatorOptions := .neither
  /-- Catala input `primary_educator_expenses_writable`. -/
  primaryEducatorExpensesWritable : Int := 0
  /-- Catala input `secondary_educator_expenses_writable`. -/
  secondaryEducatorExpensesWritable : Int := 0
  /-- Catala input `is_mfj_dependent`. -/
  isMfjDependent : Bool := false

/-- Outputs of `EducatorAdjustment`. -/
structure EducatorAdjustmentOut where
  /-- Catala `tp_was_k12_educator`. -/
  tpWasK12Educator : Bool
  /-- Catala `spouse_was_k12_educator`. -/
  spouseWasK12Educator : Bool
  /-- Catala `primary_educator_expenses`. -/
  primaryEducatorExpenses : Int
  /-- Catala `secondary_educator_expenses`. -/
  secondaryEducatorExpenses : Int
  /-- Schedule 1 line 11. -/
  educatorExpensesAdjustment : Int
  /-- Catala `is_receiving_educator_expenses_adjustment`. -/
  isReceivingEducatorExpensesAdjustment : Bool

/-- Catala `scope EducatorAdjustment`. -/
def educatorAdjustment (i : EducatorAdjustmentIn) : EducatorAdjustmentOut :=
  let tp := i.wasK12Educators == .bothDid || i.wasK12Educators == .tpDid
  let spouse := i.wasK12Educators == .bothDid || i.wasK12Educators == .spouseDid
  let primary :=
    if tp then Money.min Params.educatorExpenseCapPerEducator i.primaryEducatorExpensesWritable else 0
  let secondary :=
    if spouse then Money.min Params.educatorExpenseCapPerEducator i.secondaryEducatorExpensesWritable
    else 0
  let adjustment := if i.isMfjDependent then 0 else roundDollar (primary + secondary)
  { tpWasK12Educator := tp
    spouseWasK12Educator := spouse
    primaryEducatorExpenses := primary
    secondaryEducatorExpenses := secondary
    educatorExpensesAdjustment := adjustment
    isReceivingEducatorExpensesAdjustment := decide (adjustment > 0) }

/-! ### Unit tests: every assertion of `catala/tests/test_educator_adjustment.catala_en` -/

/-- Catala helper scope `Base`. -/
private def base (o : K12EducatorOptions := .neither) (p s : Int := 0) (dep : Bool := false) :
    EducatorAdjustmentOut :=
  educatorAdjustment
    { wasK12Educators := o, primaryEducatorExpensesWritable := p,
      secondaryEducatorExpensesWritable := s, isMfjDependent := dep }

-- TestEducatorCases
#guard (base .tpDid 45_000).educatorExpensesAdjustment == 30_000
#guard (base .tpDid 17_500).educatorExpensesAdjustment == 17_500
#guard (base .bothDid 45_000 45_000).educatorExpensesAdjustment == 60_000
#guard (base .bothDid 1_200 25_000).educatorExpensesAdjustment == 26_200
#guard (base .tpDid 30_000).educatorExpensesAdjustment == 30_000
#guard (base .spouseDid 99_900 20_800).educatorExpensesAdjustment == 20_800

-- TestEducatorZero
#guard (base .neither 30_000 30_000).educatorExpensesAdjustment == 0
#guard (base .bothDid 30_000 30_000 (dep := true)).educatorExpensesAdjustment == 0
#guard !(base .neither 30_000 30_000).isReceivingEducatorExpensesAdjustment
#guard !(base .bothDid 30_000 30_000 (dep := true)).isReceivingEducatorExpensesAdjustment

-- TestEducatorRejectsBad
#guard (base .tpDid 45_000).educatorExpensesAdjustment != 45_000
#guard (base .tpDid 45_000).educatorExpensesAdjustment != 0
#guard (base .bothDid 45_000 45_000).educatorExpensesAdjustment != 90_000
#guard (base .bothDid 45_000 45_000).educatorExpensesAdjustment != 30_000

end UsTax.EducatorAdjustment
