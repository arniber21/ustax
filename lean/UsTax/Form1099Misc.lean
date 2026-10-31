import UsTax.Money
import UsTax.Lists
import UsTax.Types

/-!
# Form 1099-MISC: Alaska Permanent Fund dividends (Schedule 1 line 8g) (issue #45)

Lean implementation of `catala/form1099_misc.catala_en` (module `Form1099_misc`, scope
`Form1099Miscs`), written by hand from the Catala source under strategy (c) of
`docs/catala-to-lean.md`; the code that runs.

| Catala (`Form1099_misc`)       | Lean (`UsTax.Form1099Misc`)                    |
|--------------------------------|------------------------------------------------|
| `structure Form1099Misc`       | `Form1099Misc`                                 |
| `scope Form1099Miscs`          | `Form1099MiscsIn` → `Form1099MiscsOut` (`form1099Miscs`) |

Money is `Int` cents. Box 3 and box 4 are each added with cents and rounded once.
-/

namespace UsTax.Form1099Misc

open Money

/-- One entry of DF `/form1099Miscs` (Catala `Form1099Misc`). Cents. -/
structure Form1099Misc where
  /-- Catala `filer`. -/
  filer : FilerRole := .primaryFiler
  /-- Catala `is_alaska_pfd`. -/
  isAlaskaPfd : Bool := true
  /-- Catala `writable_other_income` (box 3). -/
  writableOtherIncome : Int := 0
  /-- Catala `writable_federal_withholding` (box 4). -/
  writableFederalWithholding : Int := 0

/-- Inputs of `Form1099Miscs`. -/
structure Form1099MiscsIn where
  /-- Catala input `form_1099miscs`. -/
  form1099Miscs : List Form1099Misc

/-- Outputs of `Form1099Miscs`. -/
structure Form1099MiscsOut where
  /-- Schedule 1 line 8g. -/
  alaskaPfdIncome : Int
  /-- Catala `has_alaska_pfd_income`. -/
  hasAlaskaPfdIncome : Bool
  /-- Catala `has_1099_misc`. -/
  has1099Misc : Bool
  /-- The 1099-MISC term of line 25b. -/
  form1099MiscFederalIncomeTaxWithheld : Int
  /-- Catala `ko_non_pfd_1099_misc`. -/
  koNonPfd1099Misc : Bool
  /-- Every knockout of this scope. -/
  unsupported : Bool

/-- Catala `scope Form1099Miscs`. -/
def form1099Miscs (i : Form1099MiscsIn) : Form1099MiscsOut :=
  let alaskaPfdIncome :=
    roundDollar (sumBy (·.writableOtherIncome) (i.form1099Miscs.filter (·.isAlaskaPfd)))
  let koNonPfd := i.form1099Miscs.any fun f => !f.isAlaskaPfd
  { alaskaPfdIncome := alaskaPfdIncome
    hasAlaskaPfdIncome := decide (alaskaPfdIncome > 0)
    has1099Misc := decide (i.form1099Miscs.length > 0)
    form1099MiscFederalIncomeTaxWithheld :=
      roundDollar (sumBy (·.writableFederalWithholding) i.form1099Miscs)
    koNonPfd1099Misc := koNonPfd
    unsupported := koNonPfd }

/-! ### Unit tests: every assertion of `catala/tests/test_form1099_misc.catala_en` -/

/-- Catala helper `MkM`. -/
private def mkM (box3 box4 : Int) : Form1099Misc :=
  { writableOtherIncome := box3, writableFederalWithholding := box4 }

-- TestPfd1702
private def t1 := form1099Miscs { form1099Miscs := [mkM 170_200 0] }
#guard t1.alaskaPfdIncome == 170_200
#guard t1.hasAlaskaPfdIncome
#guard t1.has1099Misc
#guard t1.form1099MiscFederalIncomeTaxWithheld == 0
#guard !t1.unsupported
#guard t1.alaskaPfdIncome != 170_100
#guard t1.alaskaPfdIncome != 0

-- TestRoundedOnceAndWithholding
private def t2 := form1099Miscs { form1099Miscs := [mkM 100_040 1_040, mkM 100_040 1_040] }
#guard t2.alaskaPfdIncome == 200_100
#guard t2.alaskaPfdIncome != 200_000
#guard t2.form1099MiscFederalIncomeTaxWithheld == 2_100
#guard t2.form1099MiscFederalIncomeTaxWithheld != 2_000

-- TestNoForms
private def t3 := form1099Miscs { form1099Miscs := [] }
#guard t3.alaskaPfdIncome == 0
#guard !t3.hasAlaskaPfdIncome
#guard !t3.has1099Misc

-- TestNonPfdKnockedOut
private def t4 := form1099Miscs { form1099Miscs := [{ isAlaskaPfd := false, writableOtherIncome := 50_000 }] }
#guard t4.alaskaPfdIncome == 0
#guard t4.koNonPfd1099Misc
#guard t4.unsupported

end UsTax.Form1099Misc
