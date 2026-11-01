import UsTax.FilingStatus
import Plausible

/-!
# Property tests for the household and filing-status modules (plausible, issue #44)

Each statement was tested here before it was proved in `UsTax/Household/Lemmas.lean`
(CLAUDE.md section 5); the tests run on every build. As in `UsTax/Income/Props.lean` they
use `Testable.check`, so nothing is admitted. Structures are built from random `Bool`s and
small `Nat` codes (`pick` indexes an enumeration).
-/

namespace UsTax.Household.Props
open Plausible QualifyingChild DependentsBenefitSplit QualifyingRelative

/-- `#prop p`: run plausible on `p` with 300 random instances. -/
local macro "#prop " p:term : command =>
  `(command| #eval Testable.check $p { numInst := 300 })

/-- A random element of a nonempty list by code. -/
def pick {α} [Inhabited α] (l : List α) (n : Nat) : α := l[n % l.length]!

/-- A random person from codes; dates range over 1940 to 2024. -/
def person (r y m d : Nat) (b1 b2 b3 b4 b5 b6 : Bool) (res : Nat) : Person :=
  { relationship := (pick Relationship.all r).2
    dateOfBirth := ⟨1940 + (y % 85 : Nat), 1 + m % 12, 1 + d % 28⟩
    fullTimeStudent := b1, permanentTotalDisability := b2
    residencyDuration := pick [ResidencyDuration.allYear, .sixToElevenMonths, .lessThanSixMonths] res
    ownSupport := b3, married := b4, writableJointReturn := b5, writableRequiredToFile := b6
    writableFilingOnlyForRefund := b6, writableCouldBeQualifyingChildOfAnother := b1
    writablePotentialClaimerMustFile := b2, writablePotentialClaimerDidFile := b3
    writablePotentialClaimerFiledOnlyForRefund := b4 }

/-- A random eligibility input. -/
def elig (fs : Nat) (a b c d : Bool) (h q : Int) : FilingStatusMod.EligibilityIn :=
  { filingStatus := pick FilingStatus.all fs, maritalStatusAllowsFilingMarried := a
    eligibleForMfj := b, filerCouldQualifyForHoh := c, filerCouldQualifyForQss := d
    hohQualifyingPeopleCount := h, qssQualifyingPeopleCount := q }

-- QSS preempts HoH.
#prop (∀ fs : Nat, ∀ a b c d : Bool, ∀ h q : Int,
  let e := FilingStatusMod.eligibility (elig fs a b c d h q)
  !e.eligibleForQss || !e.eligibleForHoh)

-- A valid chosen status is not knocked out; the knockout is the negation of validity.
#prop (∀ fs : Nat, ∀ a b c d : Bool, ∀ h q : Int,
  let e := FilingStatusMod.eligibility (elig fs a b c d h q)
  !e.isFilingStatusValid || !e.koFilingStatusNotEligible)

-- The status count is between 0 and 5.
#prop (∀ fs : Nat, ∀ a b c d : Bool, ∀ h q : Int,
  let e := FilingStatusMod.eligibility (elig fs a b c d h q)
  decide (0 ≤ e.eligibleFilingStatusCount) && decide (e.eligibleFilingStatusCount ≤ 5))

/-- The recommended status is among the eligible ones. -/
def recOk (e : FilingStatusMod.EligibilityOut) (mfj : Bool) : Bool :=
  match e.recommendedFilingStatus with
  | .single => e.eligibleForSingle
  | .marriedFilingJointly => mfj
  | .marriedFilingSeparately => e.eligibleForMfs
  | .headOfHousehold => e.eligibleForHoh
  | .qualifyingSurvivingSpouse => e.eligibleForQss

-- The recommendation is eligible (Single only when the marital status does not allow marrying).
-- (MFJ eligibility implies the marital status allows marrying: without it plausible finds a
-- counterexample.)
#prop (∀ fs : Nat, ∀ a b c d : Bool, ∀ h q : Int,
  !(!b || a) || recOk (FilingStatusMod.eligibility (elig fs a b c d h q)) b)

-- A qualifying child passes the four tests.
#prop (∀ r y m d : Nat, ∀ b1 b2 b3 b4 b5 b6 : Bool, ∀ res y2 : Nat,
  let o := qualifyingChildTest { person := person r y m d b1 b2 b3 b4 b5 b6 res
                                 minimumFilerDateOfBirth := ⟨1940 + (y2 % 85 : Nat), 6, 15⟩ }
  !o.qualifyingChild || (o.ageTest && o.residencyTest && o.qcSupportTest && o.jointReturnTest))

-- A tie-breaker knockout needs a qualifying child.
#prop (∀ r y m d : Nat, ∀ b1 b2 b3 b4 b5 b6 : Bool, ∀ res : Nat,
  let o := qualifyingChildTest { person := person r y m d b1 b2 b3 b4 b5 b6 res
                                 minimumFilerDateOfBirth := ⟨1980, 6, 15⟩ }
  !o.koQualifyingChildTieBreaker || o.qualifyingChild)

-- The number of qualifying children is at most the household size.
#prop (∀ r y m d : Nat, ∀ b1 b2 b3 b4 b5 b6 : Bool, ∀ res : Nat, ∀ n : Nat,
  let ps := (List.range (n % 6)).map fun i => person (r + i) (y + i) m d b1 b2 b3 b4 b5 b6 (res + i)
  decide ((qualifyingChildren { persons := ps, minimumFilerDateOfBirth := ⟨1980, 6, 15⟩ }
    ).qualifyingChildCount ≤ ps.length))

end UsTax.Household.Props
