import UsTax.Types
import UsTax.Date

/-!
# Typed request (issue #51): the Lean image of `CalculateRequest`

`api/schema.json` `$defs/CalculateRequest` and its parts, field for field.
Names are the schema's property names in lower camel case
(`federal_withholding` is `federalWithholding`). Conventions:

* money is `Int` cents (never `Nat`, never a float), as in the verified core;
* an absent money box is `0`, an absent flag is `false` (`docs/api.md`,
  "Request"), so those fields are plain `Int` / `Bool` with those defaults;
* an absent optional section whose absence differs from its defaults is an
  `Option` (`filers.primary`, `adjustments.educator_expenses`, ...);
* enumerations are Lean inductives; `ApiEnum.name` is the wire spelling, which
  is the Catala constructor name unchanged;
* `api_version` and `tax_year` are checked, not stored (they are constants).

Which fields are money, and of which sign rule, is in the `moneyFields`
functions here; the range rules that use them are in `UsTax/Api/Spec.lean`.
`FilingStatus` is `UsTax.FilingStatus`.
-/

namespace UsTax.Api

open UsTax

/-- An enumeration with a wire spelling. -/
class ApiEnum (α : Type) where
  /-- Every constructor. -/
  all : List α
  /-- The wire spelling (a Catala constructor name, or `"2"` for a box 7 digit). -/
  name : α → String

/-- Whose form this is (`FilerRole`). `SecondaryFiler` requires a joint return. -/
inductive FilerRole where
  /-- Constructor `primaryFiler`. -/
  | primaryFiler
  /-- Constructor `secondaryFiler`. -/
  | secondaryFiler
  deriving DecidableEq, Repr, Inhabited

/-- Catala `Form_w2s.CombatPayElection`. -/
inductive CombatPayElection where
  /-- Constructor `noCombatPay`. -/
  | noCombatPay
  /-- Constructor `usePrimaryCombatPay`. -/
  | usePrimaryCombatPay
  /-- Constructor `useSpouseCombatPay`. -/
  | useSpouseCombatPay
  /-- Constructor `useBothCombatPay`. -/
  | useBothCombatPay
  /-- Constructor `usePrimaryNotSpouseCombatPay`. -/
  | usePrimaryNotSpouseCombatPay
  /-- Constructor `useSpouseNotPrimaryCombatPay`. -/
  | useSpouseNotPrimaryCombatPay
  deriving DecidableEq, Repr, Inhabited

/-- Who did something (`was_k12_educators`, `paid_with_former_spouse`). -/
inductive WhoDid where
  /-- Constructor `tpDid`. -/
  | tpDid
  /-- Constructor `spouseDid`. -/
  | spouseDid
  /-- Constructor `bothDid`. -/
  | bothDid
  /-- Constructor `neither`. -/
  | neither
  deriving DecidableEq, Repr, Inhabited

/-- One character of 1099-R box 7 (`Other` is every other character). -/
inductive CodeChar where
  /-- Constructor `c2`. -/
  | c2
  /-- Constructor `c4`. -/
  | c4
  /-- Constructor `c7`. -/
  | c7
  /-- Constructor `b`. -/
  | b
  /-- Constructor `g`. -/
  | g
  /-- Constructor `h`. -/
  | h
  /-- Constructor `other`. -/
  | other
  deriving DecidableEq, Repr, Inhabited

/-- W-2 box 12 code letters accepted by the schema (no `I`, `O`, `U`, `X`). -/
inductive Box12Code where
  /-- Constructor `a`. -/
  | a
  /-- Constructor `b`. -/
  | b
  /-- Constructor `c`. -/
  | c
  /-- Constructor `d`. -/
  | d
  /-- Constructor `e`. -/
  | e
  /-- Constructor `f`. -/
  | f
  /-- Constructor `g`. -/
  | g
  /-- Constructor `h`. -/
  | h
  /-- Constructor `j`. -/
  | j
  /-- Constructor `k`. -/
  | k
  /-- Constructor `l`. -/
  | l
  /-- Constructor `m`. -/
  | m
  /-- Constructor `n`. -/
  | n
  /-- Constructor `p`. -/
  | p
  /-- Constructor `q`. -/
  | q
  /-- Constructor `r`. -/
  | r
  /-- Constructor `s`. -/
  | s
  /-- Constructor `t`. -/
  | t
  /-- Constructor `v`. -/
  | v
  /-- Constructor `w`. -/
  | w
  /-- Constructor `y`. -/
  | y
  /-- Constructor `z`. -/
  | z
  /-- Constructor `aa`. -/
  | aa
  /-- Constructor `bb`. -/
  | bb
  /-- Constructor `dd`. -/
  | dd
  /-- Constructor `ee`. -/
  | ee
  /-- Constructor `ff`. -/
  | ff
  /-- Constructor `gg`. -/
  | gg
  /-- Constructor `hh`. -/
  | hh
  /-- Constructor `ii`. -/
  | ii
  deriving DecidableEq, Repr, Inhabited

instance : ApiEnum FilingStatus := ⟨FilingStatus.all, FilingStatus.catalaName⟩

instance : ApiEnum FilerRole where
  all := [.primaryFiler, .secondaryFiler]
  name | .primaryFiler => "PrimaryFiler" | .secondaryFiler => "SecondaryFiler"

instance : ApiEnum CombatPayElection where
  all := [.noCombatPay, .usePrimaryCombatPay, .useSpouseCombatPay, .useBothCombatPay,
    .usePrimaryNotSpouseCombatPay, .useSpouseNotPrimaryCombatPay]
  name
    | .noCombatPay => "NoCombatPay" | .usePrimaryCombatPay => "UsePrimaryCombatPay"
    | .useSpouseCombatPay => "UseSpouseCombatPay" | .useBothCombatPay => "UseBothCombatPay"
    | .usePrimaryNotSpouseCombatPay => "UsePrimaryNotSpouseCombatPay"
    | .useSpouseNotPrimaryCombatPay => "UseSpouseNotPrimaryCombatPay"

instance : ApiEnum WhoDid where
  all := [.tpDid, .spouseDid, .bothDid, .neither]
  name | .tpDid => "TpDid" | .spouseDid => "SpouseDid" | .bothDid => "BothDid" | .neither => "Neither"

instance : ApiEnum CodeChar where
  all := [.c2, .c4, .c7, .b, .g, .h, .other]
  name | .c2 => "2" | .c4 => "4" | .c7 => "7" | .b => "B" | .g => "G" | .h => "H"
       | .other => "Other"

instance : ApiEnum Box12Code where
  all := [.a, .b, .c, .d, .e, .f, .g, .h, .j, .k, .l, .m, .n, .p, .q, .r, .s, .t, .v, .w, .y,
    .z, .aa, .bb, .dd, .ee, .ff, .gg, .hh, .ii]
  name
    | .a => "A" | .b => "B" | .c => "C" | .d => "D" | .e => "E" | .f => "F" | .g => "G"
    | .h => "H" | .j => "J" | .k => "K" | .l => "L" | .m => "M" | .n => "N" | .p => "P"
    | .q => "Q" | .r => "R" | .s => "S" | .t => "T" | .v => "V" | .w => "W" | .y => "Y"
    | .z => "Z" | .aa => "AA" | .bb => "BB" | .dd => "DD" | .ee => "EE" | .ff => "FF"
    | .gg => "GG" | .hh => "HH" | .ii => "II"

/-- A date with no schema default; only ever a placeholder (`Inhabited` for the decoder). -/
instance : Inhabited Date := ⟨{ year := 1970, month := 1, day := 1 }⟩

/-- The `(name, amount)` entry of an optional `NonNegMoney` property, if present. -/
def optMoney (k : String) (o : Option Int) : List (String × Int) := o.toList.map (k, ·)

/-- `FilerTinSsnEmploymentValidity` (schema 1.2.0). -/
inductive FilerTinSsnEmploymentValidity where
  /-- Wire value `Neither`. -/
  | neither
  /-- Wire value `NotValid`. -/
  | notValid
  /-- Wire value `ValidOnlyWithDhsAuthorization`. -/
  | validOnlyWithDhsAuthorization
  deriving DecidableEq, Repr, Inhabited

instance : ApiEnum FilerTinSsnEmploymentValidity where
  all := [.neither, .notValid, .validOnlyWithDhsAuthorization]
  name
    | .neither => "Neither"
    | .notValid => "NotValid"
    | .validOnlyWithDhsAuthorization => "ValidOnlyWithDhsAuthorization"

/-- `EnrolledInMedicare` (schema 1.2.0). -/
inductive EnrolledInMedicare where
  /-- Wire value `MedicareAllYear`. -/
  | medicareAllYear
  /-- Wire value `MedicarePartOfYear`. -/
  | medicarePartOfYear
  /-- Wire value `MedicareNoneOfYear`. -/
  | medicareNoneOfYear
  deriving DecidableEq, Repr, Inhabited

instance : ApiEnum EnrolledInMedicare where
  all := [.medicareAllYear, .medicarePartOfYear, .medicareNoneOfYear]
  name
    | .medicareAllYear => "MedicareAllYear"
    | .medicarePartOfYear => "MedicarePartOfYear"
    | .medicareNoneOfYear => "MedicareNoneOfYear"

/-- `HsaHdhpCoverageStatus` (schema 1.2.0). -/
inductive HsaHdhpCoverageStatus where
  /-- Wire value `HdhpAllYear`. -/
  | hdhpAllYear
  /-- Wire value `HdhpPartOfYear`. -/
  | hdhpPartOfYear
  /-- Wire value `HdhpNoneOfYear`. -/
  | hdhpNoneOfYear
  deriving DecidableEq, Repr, Inhabited

instance : ApiEnum HsaHdhpCoverageStatus where
  all := [.hdhpAllYear, .hdhpPartOfYear, .hdhpNoneOfYear]
  name
    | .hdhpAllYear => "HdhpAllYear"
    | .hdhpPartOfYear => "HdhpPartOfYear"
    | .hdhpNoneOfYear => "HdhpNoneOfYear"

/-- `TypeOfHdhp` (schema 1.2.0). -/
inductive TypeOfHdhp where
  /-- Wire value `SelfOnly`. -/
  | selfOnly
  /-- Wire value `Family`. -/
  | family
  /-- Wire value `BothSelfAndFamily`. -/
  | bothSelfAndFamily
  deriving DecidableEq, Repr, Inhabited

instance : ApiEnum TypeOfHdhp where
  all := [.selfOnly, .family, .bothSelfAndFamily]
  name
    | .selfOnly => "SelfOnly"
    | .family => "Family"
    | .bothSelfAndFamily => "BothSelfAndFamily"

/-- `HadOtherCoverageIneligibleForHsa` (schema 1.2.0). -/
inductive HadOtherCoverageIneligibleForHsa where
  /-- Wire value `OtherCoverageWholeYear`. -/
  | otherCoverageWholeYear
  /-- Wire value `OtherCoveragePartOfYear`. -/
  | otherCoveragePartOfYear
  /-- Wire value `OtherCoverageNoneOfYear`. -/
  | otherCoverageNoneOfYear
  deriving DecidableEq, Repr, Inhabited

instance : ApiEnum HadOtherCoverageIneligibleForHsa where
  all := [.otherCoverageWholeYear, .otherCoveragePartOfYear, .otherCoverageNoneOfYear]
  name
    | .otherCoverageWholeYear => "OtherCoverageWholeYear"
    | .otherCoveragePartOfYear => "OtherCoveragePartOfYear"
    | .otherCoverageNoneOfYear => "OtherCoverageNoneOfYear"

/-- `WritableChangeInMaritalStatusDuringTaxYear` (schema 1.2.0). -/
inductive WritableChangeInMaritalStatusDuringTaxYear where
  /-- Wire value `WasMarriedOrDivorcedThisYear`. -/
  | wasMarriedOrDivorcedThisYear
  /-- Wire value `WasNotMarriedNorDivorcedThisYear`. -/
  | wasNotMarriedNorDivorcedThisYear
  deriving DecidableEq, Repr, Inhabited

instance : ApiEnum WritableChangeInMaritalStatusDuringTaxYear where
  all := [.wasMarriedOrDivorcedThisYear, .wasNotMarriedNorDivorcedThisYear]
  name
    | .wasMarriedOrDivorcedThisYear => "WasMarriedOrDivorcedThisYear"
    | .wasNotMarriedNorDivorcedThisYear => "WasNotMarriedNorDivorcedThisYear"

/-- `MaritalStatus` (schema 1.2.0). -/
inductive MaritalStatus where
  /-- Wire value `NeverMarried`. -/
  | neverMarried
  /-- Wire value `Married`. -/
  | married
  /-- Wire value `Divorced`. -/
  | divorced
  /-- Wire value `Widowed`. -/
  | widowed
  deriving DecidableEq, Repr, Inhabited

instance : ApiEnum MaritalStatus where
  all := [.neverMarried, .married, .divorced, .widowed]
  name
    | .neverMarried => "NeverMarried"
    | .married => "Married"
    | .divorced => "Divorced"
    | .widowed => "Widowed"

/-- `YearOfSpouseDeath` (schema 1.2.0). -/
inductive YearOfSpouseDeath where
  /-- Wire value `DiedInTaxYear`. -/
  | diedInTaxYear
  /-- Wire value `DiedTaxYearMinusOne`. -/
  | diedTaxYearMinusOne
  /-- Wire value `DiedTaxYearMinusTwo`. -/
  | diedTaxYearMinusTwo
  /-- Wire value `DiedBeforeTaxYearMinusTwo`. -/
  | diedBeforeTaxYearMinusTwo
  deriving DecidableEq, Repr, Inhabited

instance : ApiEnum YearOfSpouseDeath where
  all := [.diedInTaxYear, .diedTaxYearMinusOne, .diedTaxYearMinusTwo, .diedBeforeTaxYearMinusTwo]
  name
    | .diedInTaxYear => "DiedInTaxYear"
    | .diedTaxYearMinusOne => "DiedTaxYearMinusOne"
    | .diedTaxYearMinusTwo => "DiedTaxYearMinusTwo"
    | .diedBeforeTaxYearMinusTwo => "DiedBeforeTaxYearMinusTwo"

/-- `SpouseLivedTogetherMonths` (schema 1.2.0). -/
inductive SpouseLivedTogetherMonths where
  /-- Wire value `LivedApartAllYear`. -/
  | livedApartAllYear
  /-- Wire value `LivedTogetherSixMonthsOrLess`. -/
  | livedTogetherSixMonthsOrLess
  /-- Wire value `LivedTogetherMoreThanSixMonths`. -/
  | livedTogetherMoreThanSixMonths
  deriving DecidableEq, Repr, Inhabited

instance : ApiEnum SpouseLivedTogetherMonths where
  all := [.livedApartAllYear, .livedTogetherSixMonthsOrLess, .livedTogetherMoreThanSixMonths]
  name
    | .livedApartAllYear => "LivedApartAllYear"
    | .livedTogetherSixMonthsOrLess => "LivedTogetherSixMonthsOrLess"
    | .livedTogetherMoreThanSixMonths => "LivedTogetherMoreThanSixMonths"

/-- `ResidenceState` (schema 1.2.0). -/
inductive ResidenceState where
  /-- Wire value `MoreThanOne`. -/
  | moreThanOne
  /-- Wire value `AK`. -/
  | ak
  /-- Wire value `AZ`. -/
  | az
  /-- Wire value `CA`. -/
  | ca
  /-- Wire value `CT`. -/
  | ct
  /-- Wire value `FL`. -/
  | fl
  /-- Wire value `ID`. -/
  | id
  /-- Wire value `IL`. -/
  | il
  /-- Wire value `KS`. -/
  | ks
  /-- Wire value `ME`. -/
  | me
  /-- Wire value `MD`. -/
  | md
  /-- Wire value `MA`. -/
  | ma
  /-- Wire value `NV`. -/
  | nv
  /-- Wire value `NH`. -/
  | nh
  /-- Wire value `NJ`. -/
  | nj
  /-- Wire value `NM`. -/
  | nm
  /-- Wire value `NY`. -/
  | ny
  /-- Wire value `NC`. -/
  | nc
  /-- Wire value `OR`. -/
  | or
  /-- Wire value `PA`. -/
  | pa
  /-- Wire value `SD`. -/
  | sd
  /-- Wire value `TN`. -/
  | tn
  /-- Wire value `TX`. -/
  | tx
  /-- Wire value `WA`. -/
  | wa
  /-- Wire value `WI`. -/
  | wi
  /-- Wire value `WY`. -/
  | wy
  /-- Wire value `NoneOfThese`. -/
  | noneOfThese
  deriving DecidableEq, Repr, Inhabited

instance : ApiEnum ResidenceState where
  all := [.moreThanOne, .ak, .az, .ca, .ct, .fl, .id, .il, .ks, .me, .md, .ma, .nv, .nh, .nj, .nm, .ny, .nc, .or, .pa, .sd, .tn, .tx, .wa, .wi, .wy, .noneOfThese]
  name
    | .moreThanOne => "MoreThanOne"
    | .ak => "AK"
    | .az => "AZ"
    | .ca => "CA"
    | .ct => "CT"
    | .fl => "FL"
    | .id => "ID"
    | .il => "IL"
    | .ks => "KS"
    | .me => "ME"
    | .md => "MD"
    | .ma => "MA"
    | .nv => "NV"
    | .nh => "NH"
    | .nj => "NJ"
    | .nm => "NM"
    | .ny => "NY"
    | .nc => "NC"
    | .or => "OR"
    | .pa => "PA"
    | .sd => "SD"
    | .tn => "TN"
    | .tx => "TX"
    | .wa => "WA"
    | .wi => "WI"
    | .wy => "WY"
    | .noneOfThese => "NoneOfThese"

/-- `WhichParentNotClaiming` (schema 1.2.0). -/
inductive WhichParentNotClaiming where
  /-- Wire value `IDid`. -/
  | iDid
  /-- Wire value `TheyDid`. -/
  | theyDid
  /-- Wire value `NobodyDid`. -/
  | nobodyDid
  deriving DecidableEq, Repr, Inhabited

instance : ApiEnum WhichParentNotClaiming where
  all := [.iDid, .theyDid, .nobodyDid]
  name
    | .iDid => "IDid"
    | .theyDid => "TheyDid"
    | .nobodyDid => "NobodyDid"

/-- `NightsWithTpVsOtherParent` (schema 1.2.0). -/
inductive NightsWithTpVsOtherParent where
  /-- Wire value `More`. -/
  | more
  /-- Wire value `Less`. -/
  | less
  /-- Wire value `Equal`. -/
  | equal
  deriving DecidableEq, Repr, Inhabited

instance : ApiEnum NightsWithTpVsOtherParent where
  all := [.more, .less, .equal]
  name
    | .more => "More"
    | .less => "Less"
    | .equal => "Equal"

/-- `ParentalSituation` (schema 1.2.0). -/
inductive ParentalSituation where
  /-- Wire value `DivorcedOrSeparated`. -/
  | divorcedOrSeparated
  /-- Wire value `LivedApartLastSixMonths`. -/
  | livedApartLastSixMonths
  /-- Wire value `Other`. -/
  | other
  deriving DecidableEq, Repr, Inhabited

instance : ApiEnum ParentalSituation where
  all := [.divorcedOrSeparated, .livedApartLastSixMonths, .other]
  name
    | .divorcedOrSeparated => "DivorcedOrSeparated"
    | .livedApartLastSixMonths => "LivedApartLastSixMonths"
    | .other => "Other"

/-- `Relationship` (schema 1.2.0). -/
inductive Relationship where
  /-- Wire value `BiologicalChild`. -/
  | biologicalChild
  /-- Wire value `AdoptedChild`. -/
  | adoptedChild
  /-- Wire value `StepChild`. -/
  | stepChild
  /-- Wire value `FosterChild`. -/
  | fosterChild
  /-- Wire value `GrandChildOrOtherDescendantOfChild`. -/
  | grandChildOrOtherDescendantOfChild
  /-- Wire value `ChildInLaw`. -/
  | childInLaw
  /-- Wire value `Sibling`. -/
  | sibling
  /-- Wire value `ChildOfSibling`. -/
  | childOfSibling
  /-- Wire value `HalfSibling`. -/
  | halfSibling
  /-- Wire value `ChildOfHalfSibling`. -/
  | childOfHalfSibling
  /-- Wire value `StepSibling`. -/
  | stepSibling
  /-- Wire value `ChildOfStepSibling`. -/
  | childOfStepSibling
  /-- Wire value `OtherDescendantOfSibling`. -/
  | otherDescendantOfSibling
  /-- Wire value `OtherDescendantOfHalfSibling`. -/
  | otherDescendantOfHalfSibling
  /-- Wire value `OtherDescendantOfStepSibling`. -/
  | otherDescendantOfStepSibling
  /-- Wire value `SiblingsSpouse`. -/
  | siblingsSpouse
  /-- Wire value `SiblingInLaw`. -/
  | siblingInLaw
  /-- Wire value `Parent`. -/
  | parent
  /-- Wire value `FosterParent`. -/
  | fosterParent
  /-- Wire value `SiblingOfParent`. -/
  | siblingOfParent
  /-- Wire value `GrandParent`. -/
  | grandParent
  /-- Wire value `OtherAncestorOfParent`. -/
  | otherAncestorOfParent
  /-- Wire value `StepParent`. -/
  | stepParent
  /-- Wire value `ParentInLaw`. -/
  | parentInLaw
  /-- Wire value `NoneOfTheAbove`. -/
  | noneOfTheAbove
  deriving DecidableEq, Repr, Inhabited

instance : ApiEnum Relationship where
  all := [.biologicalChild, .adoptedChild, .stepChild, .fosterChild, .grandChildOrOtherDescendantOfChild, .childInLaw, .sibling, .childOfSibling, .halfSibling, .childOfHalfSibling, .stepSibling, .childOfStepSibling, .otherDescendantOfSibling, .otherDescendantOfHalfSibling, .otherDescendantOfStepSibling, .siblingsSpouse, .siblingInLaw, .parent, .fosterParent, .siblingOfParent, .grandParent, .otherAncestorOfParent, .stepParent, .parentInLaw, .noneOfTheAbove]
  name
    | .biologicalChild => "BiologicalChild"
    | .adoptedChild => "AdoptedChild"
    | .stepChild => "StepChild"
    | .fosterChild => "FosterChild"
    | .grandChildOrOtherDescendantOfChild => "GrandChildOrOtherDescendantOfChild"
    | .childInLaw => "ChildInLaw"
    | .sibling => "Sibling"
    | .childOfSibling => "ChildOfSibling"
    | .halfSibling => "HalfSibling"
    | .childOfHalfSibling => "ChildOfHalfSibling"
    | .stepSibling => "StepSibling"
    | .childOfStepSibling => "ChildOfStepSibling"
    | .otherDescendantOfSibling => "OtherDescendantOfSibling"
    | .otherDescendantOfHalfSibling => "OtherDescendantOfHalfSibling"
    | .otherDescendantOfStepSibling => "OtherDescendantOfStepSibling"
    | .siblingsSpouse => "SiblingsSpouse"
    | .siblingInLaw => "SiblingInLaw"
    | .parent => "Parent"
    | .fosterParent => "FosterParent"
    | .siblingOfParent => "SiblingOfParent"
    | .grandParent => "GrandParent"
    | .otherAncestorOfParent => "OtherAncestorOfParent"
    | .stepParent => "StepParent"
    | .parentInLaw => "ParentInLaw"
    | .noneOfTheAbove => "NoneOfTheAbove"

/-- `ResidencyDuration` (schema 1.2.0). -/
inductive ResidencyDuration where
  /-- Wire value `AllYear`. -/
  | allYear
  /-- Wire value `SixToElevenMonths`. -/
  | sixToElevenMonths
  /-- Wire value `LessThanSixMonths`. -/
  | lessThanSixMonths
  deriving DecidableEq, Repr, Inhabited

instance : ApiEnum ResidencyDuration where
  all := [.allYear, .sixToElevenMonths, .lessThanSixMonths]
  name
    | .allYear => "AllYear"
    | .sixToElevenMonths => "SixToElevenMonths"
    | .lessThanSixMonths => "LessThanSixMonths"

/-- `TinType` (schema 1.2.0). -/
inductive TinType where
  /-- Wire value `Ssn`. -/
  | ssn
  /-- Wire value `Itin`. -/
  | itin
  /-- Wire value `Atin`. -/
  | atin
  /-- Wire value `NoTin`. -/
  | noTin
  deriving DecidableEq, Repr, Inhabited

instance : ApiEnum TinType where
  all := [.ssn, .itin, .atin, .noTin]
  name
    | .ssn => "Ssn"
    | .itin => "Itin"
    | .atin => "Atin"
    | .noTin => "NoTin"

/-- `DependentSsnEmploymentValidity` (schema 1.2.0). -/
inductive DependentSsnEmploymentValidity where
  /-- Wire value `Neither`. -/
  | neither
  /-- Wire value `NotValid`. -/
  | notValid
  /-- Wire value `ValidOnlyWithDhsAuthorizationInEffect`. -/
  | validOnlyWithDhsAuthorizationInEffect
  /-- Wire value `ValidOnlyWithDhsAuthorizationExpired`. -/
  | validOnlyWithDhsAuthorizationExpired
  deriving DecidableEq, Repr, Inhabited

instance : ApiEnum DependentSsnEmploymentValidity where
  all := [.neither, .notValid, .validOnlyWithDhsAuthorizationInEffect, .validOnlyWithDhsAuthorizationExpired]
  name
    | .neither => "Neither"
    | .notValid => "NotValid"
    | .validOnlyWithDhsAuthorizationInEffect => "ValidOnlyWithDhsAuthorizationInEffect"
    | .validOnlyWithDhsAuthorizationExpired => "ValidOnlyWithDhsAuthorizationExpired"

/-- `HsaDistributionCode` (schema 1.2.0). -/
inductive HsaDistributionCode where
  /-- Wire value `NormalDistribution`. -/
  | normalDistribution
  /-- Wire value `ExcessContributions`. -/
  | excessContributions
  /-- Wire value `Disability`. -/
  | disability
  /-- Wire value `DeathOtherThanCode6`. -/
  | deathOtherThanCode6
  /-- Wire value `ProhibitedTransaction`. -/
  | prohibitedTransaction
  /-- Wire value `DeathDistributionAfterYear`. -/
  | deathDistributionAfterYear
  deriving DecidableEq, Repr, Inhabited

instance : ApiEnum HsaDistributionCode where
  all := [.normalDistribution, .excessContributions, .disability, .deathOtherThanCode6, .prohibitedTransaction, .deathDistributionAfterYear]
  name
    | .normalDistribution => "NormalDistribution"
    | .excessContributions => "ExcessContributions"
    | .disability => "Disability"
    | .deathOtherThanCode6 => "DeathOtherThanCode6"
    | .prohibitedTransaction => "ProhibitedTransaction"
    | .deathDistributionAfterYear => "DeathDistributionAfterYear"

/-- `EitcReceivedImproperClaimsNotice` (schema 1.2.0). -/
inductive EitcReceivedImproperClaimsNotice where
  /-- Wire value `TwoYears`. -/
  | twoYears
  /-- Wire value `TenYears`. -/
  | tenYears
  /-- Wire value `ZeroYears`. -/
  | zeroYears
  /-- Wire value `NotAnswered`. -/
  | notAnswered
  deriving DecidableEq, Repr, Inhabited

instance : ApiEnum EitcReceivedImproperClaimsNotice where
  all := [.twoYears, .tenYears, .zeroYears, .notAnswered]
  name
    | .twoYears => "TwoYears"
    | .tenYears => "TenYears"
    | .zeroYears => "ZeroYears"
    | .notAnswered => "NotAnswered"

/-- `FilerTin` (schema 1.2.0). -/
structure FilerTin where
  /-- Property `tin_is_ssn`. -/
  tinIsSsn : Bool := true
  /-- Property `ssn_employment_validity`. -/
  ssnEmploymentValidity : FilerTinSsnEmploymentValidity := .neither
  /-- Property `has_ssn_only_for_benefits`. -/
  hasSsnOnlyForBenefits : Option Bool := none
  deriving DecidableEq, Repr, Inhabited

/-- `DisabilityAnswers` (schema 1.2.0). -/
structure DisabilityAnswers where
  /-- Property `is_retired_on_perm_or_total_disability`. -/
  isRetiredOnPermOrTotalDisability : Option Bool := none
  /-- Property `employer_has_mandatory_retirement_age`. -/
  employerHasMandatoryRetirementAge : Option Bool := none
  /-- Property `has_met_employer_mandatory_retirement_age`. -/
  hasMetEmployerMandatoryRetirementAge : Option Bool := none
  /-- Property `are_payments_taxable_disability_income`. -/
  arePaymentsTaxableDisabilityIncome : Option Bool := none
  /-- Property `writable_total_taxable_disability_amount`. -/
  writableTotalTaxableDisabilityAmount : Option Int := none
  /-- Property `has_w2_wages`. -/
  hasW2Wages : Option Bool := none
  deriving DecidableEq, Repr, Inhabited

/-- `HsaFilerAnswers` (schema 1.2.0). -/
structure HsaFilerAnswers where
  /-- Property `writable_primary_filer_has_made_contributions_to_hsa`. -/
  writablePrimaryFilerHasMadeContributionsToHsa : Option Bool := none
  /-- Property `writable_secondary_filer_has_made_contributions_to_hsa`. -/
  writableSecondaryFilerHasMadeContributionsToHsa : Option Bool := none
  /-- Property `enrolled_in_medicare`. -/
  enrolledInMedicare : EnrolledInMedicare := .medicareNoneOfYear
  /-- Property `hsa_hdhp_coverage_status`. -/
  hsaHdhpCoverageStatus : HsaHdhpCoverageStatus := .hdhpAllYear
  /-- Property `type_of_hdhp`. -/
  typeOfHdhp : TypeOfHdhp := .selfOnly
  /-- Property `had_other_coverage_ineligible_for_hsa`. -/
  hadOtherCoverageIneligibleForHsa : HadOtherCoverageIneligibleForHsa := .otherCoverageNoneOfYear
  /-- Property `writable_mfs_line6_check`. -/
  writableMfsLine6Check : Option Bool := none
  /-- Property `writable_change_in_marital_status_during_tax_year`. -/
  writableChangeInMaritalStatusDuringTaxYear : WritableChangeInMaritalStatusDuringTaxYear := .wasNotMarriedNorDivorcedThisYear
  /-- Property `writable_marital_change_affect_contribution_limit_bool`. -/
  writableMaritalChangeAffectContributionLimitBool : Option Bool := none
  /-- Property `has_made_qualified_hsa_funding_distribution`. -/
  hasMadeQualifiedHsaFundingDistribution : Option Bool := none
  /-- Property `writable_hsa_nonemployer_contributions_tax_year`. -/
  writableHsaNonemployerContributionsTaxYear : Option Int := none
  /-- Property `writable_hsa_nonemployer_contributions_tax_year_plus_one`. -/
  writableHsaNonemployerContributionsTaxYearPlusOne : Option Int := none
  deriving DecidableEq, Repr, Inhabited

/-- `CdccFilerAnswers` (schema 1.2.0). -/
structure CdccFilerAnswers where
  /-- Property `elect_combat_pay_for_credit`. -/
  electCombatPayForCredit : Option Bool := none
  /-- Property `elect_combat_pay_for_benefits`. -/
  electCombatPayForBenefits : Option Bool := none
  /-- Property `dependent_care_plan_maximum`. -/
  dependentCarePlanMaximum : Option Int := none
  /-- Property `is_disabled`. -/
  isDisabled : Option Bool := none
  /-- Property `deemed_income_month_earnings`. -/
  deemedIncomeMonthEarnings : List Int := []
  /-- Property `has_dependent_care_expenses`. -/
  hasDependentCareExpenses : Option Bool := none
  /-- Property `expenses_paid_to_qualifying_provider`. -/
  expensesPaidToQualifyingProvider : Option Bool := none
  /-- Property `writable_qualifying_expense_amount`. -/
  writableQualifyingExpenseAmount : Option Int := none
  deriving DecidableEq, Repr, Inhabited

/-- `FilerFlags` (schema 1.2.0). -/
structure FilerFlags where
  /-- Property `is_blind`. -/
  isBlind : Bool := false
  /-- Property `age65_or_older`. -/
  age65OrOlder : Bool := false
  /-- Property `can_be_claimed_as_dependent`. -/
  canBeClaimedAsDependent : Bool := false
  /-- Property `date_of_birth`. -/
  dateOfBirth : Option Date := none
  /-- Property `will_be_claimed`. -/
  willBeClaimed : Bool := false
  /-- Property `potential_claimer_must_file`. -/
  potentialClaimerMustFile : Bool := false
  /-- Property `potential_claimer_did_file`. -/
  potentialClaimerDidFile : Bool := false
  /-- Property `is_us_citizen_full_year`. -/
  isUsCitizenFullYear : Bool := true
  /-- Property `citizen_at_end_of_tax_year`. -/
  citizenAtEndOfTaxYear : Bool := false
  /-- Property `noncitizen_resident_full_year`. -/
  noncitizenResidentFullYear : Bool := false
  /-- Property `is_national`. -/
  isNational : Bool := false
  /-- Property `is_student`. -/
  isStudent : Bool := false
  /-- Property `tin`. -/
  tin : Option FilerTin := none
  /-- Property `disability`. -/
  disability : Option DisabilityAnswers := none
  /-- Property `hsa`. -/
  hsa : Option HsaFilerAnswers := none
  /-- Property `cdcc`. -/
  cdcc : Option CdccFilerAnswers := none
  deriving DecidableEq, Repr, Inhabited

/-- `FilingDetails` (schema 1.2.0). -/
structure FilingDetails where
  /-- Property `treat_as_mfs`. -/
  treatAsMfs : Option Bool := none
  /-- Property `is_widowed_in_tax_year`. -/
  isWidowedInTaxYear : Option Bool := none
  /-- Property `mfj_deceased_spouse_reached_age65`. -/
  mfjDeceasedSpouseReachedAge65 : Option Bool := none
  /-- Property `mfs_spouse_65_or_older`. -/
  mfsSpouse65OrOlder : Bool := false
  /-- Property `mfs_spouse_provides_no_benefits`. -/
  mfsSpouseProvidesNoBenefits : Option Bool := none
  /-- Property `treat_filers_as_dependents`. -/
  treatFilersAsDependents : Option Bool := none
  /-- Property `has_foreign_accounts_or_trusts`. -/
  hasForeignAccountsOrTrusts : Bool := false
  /-- Property `combat_pay_election`. -/
  combatPayElection : CombatPayElection := .noCombatPay
  /-- Property `combat_pay_election_made`. -/
  combatPayElectionMade : Bool := false
  deriving DecidableEq, Repr, Inhabited

/-- `FilingAnswers` (schema 1.2.0). -/
structure FilingAnswers where
  /-- Property `marital_status`. -/
  maritalStatus : Option MaritalStatus := none
  /-- Property `year_of_spouse_death`. -/
  yearOfSpouseDeath : Option YearOfSpouseDeath := none
  /-- Property `secondary_filer_date_of_death`. -/
  secondaryFilerDateOfDeath : Date := { year := 2024, month := 12, day := 31 }
  /-- Property `primary_filer_potential_claimer_filed_only_for_refund`. -/
  primaryFilerPotentialClaimerFiledOnlyForRefund : Bool := false
  /-- Property `mfj_required_to_file`. -/
  mfjRequiredToFile : Bool := false
  /-- Property `mfj_dependents_filing_for_credits`. -/
  mfjDependentsFilingForCredits : Bool := false
  /-- Property `lived_together_all_year_with_spouse`. -/
  livedTogetherAllYearWithSpouse : Bool := true
  /-- Property `spouse_lived_together_months`. -/
  spouseLivedTogetherMonths : SpouseLivedTogetherMonths := .livedApartAllYear
  /-- Property `lived_apart_last_six_months`. -/
  livedApartLastSixMonths : Bool := false
  /-- Property `separation_agreement`. -/
  separationAgreement : Bool := false
  /-- Property `can_file_jointly_year_of_spouse_death`. -/
  canFileJointlyYearOfSpouseDeath : Bool := false
  /-- Property `in_registered_domestic_partnership`. -/
  inRegisteredDomesticPartnership : Bool := false
  /-- Property `residence_state`. -/
  residenceState : ResidenceState := .fl
  /-- Property `spouse_itemizes`. -/
  spouseItemizes : Bool := false
  /-- Property `mfs_living_spouse_filing_return`. -/
  mfsLivingSpouseFilingReturn : Bool := false
  /-- Property `mfs_deceased_spouse_filing_return`. -/
  mfsDeceasedSpouseFilingReturn : Bool := false
  /-- Property `mfs_spouse_has_gross_income`. -/
  mfsSpouseHasGrossIncome : Bool := false
  deriving DecidableEq, Repr, Inhabited

/-- `BenefitSplitAnswers` (schema 1.2.0). -/
structure BenefitSplitAnswers where
  /-- Property `has_other_biological_or_adoptive_parent`. -/
  hasOtherBiologicalOrAdoptiveParent : Option Bool := none
  /-- Property `non_parental_some_parent_not_claiming`. -/
  nonParentalSomeParentNotClaiming : Option Bool := none
  /-- Property `which_parent_not_claiming`. -/
  whichParentNotClaiming : WhichParentNotClaiming := .nobodyDid
  /-- Property `in_parents_custody`. -/
  inParentsCustody : Option Bool := none
  /-- Property `lived_with_tp_or_other_biological_or_adoptive_parent_more_than_six_months`. -/
  livedWithTpOrOtherBiologicalOrAdoptiveParentMoreThanSixMonths : Option Bool := none
  /-- Property `biological_or_adoptive_parents_living`. -/
  biologicalOrAdoptiveParentsLiving : Option Bool := none
  /-- Property `nights_with_tp_vs_other_parent`. -/
  nightsWithTpVsOtherParent : NightsWithTpVsOtherParent := .less
  /-- Property `tp_agi_higher_than_other_parent`. -/
  tpAgiHigherThanOtherParent : Option Bool := none
  /-- Property `parents_meet_reqs_rule_for_children_of_divorced_parents`. -/
  parentsMeetReqsRuleForChildrenOfDivorcedParents : Option Bool := none
  /-- Property `special_rule_child_used_by_custodial_parent_as_qp`. -/
  specialRuleChildUsedByCustodialParentAsQp : Option Bool := none
  /-- Property `special_rule_agi_test`. -/
  specialRuleAgiTest : Option Bool := none
  /-- Property `parental_situation`. -/
  parentalSituation : ParentalSituation := .other
  /-- Property `parental_support`. -/
  parentalSupport : Option Bool := none
  /-- Property `multiple_support_agreement`. -/
  multipleSupportAgreement : Option Bool := none
  deriving DecidableEq, Repr, Inhabited

/-- `CdccMemberAnswers` (schema 1.2.0). -/
structure CdccMemberAnswers where
  /-- Property `unable_to_care_for_self`. -/
  unableToCareForSelf : Option Bool := none
  /-- Property `has_dependent_care_expenses`. -/
  hasDependentCareExpenses : Option Bool := none
  /-- Property `expenses_paid_to_qualifying_provider`. -/
  expensesPaidToQualifyingProvider : Option Bool := none
  /-- Property `writable_qualifying_expense_amount`. -/
  writableQualifyingExpenseAmount : Option Int := none
  deriving DecidableEq, Repr, Inhabited

/-- `Dependent` (schema 1.2.0). -/
structure Dependent where
  /-- Property `relationship`. -/
  relationship : Relationship
  /-- Property `date_of_birth`. -/
  dateOfBirth : Date
  /-- Property `full_time_student`. -/
  fullTimeStudent : Bool := false
  /-- Property `permanent_total_disability`. -/
  permanentTotalDisability : Bool := false
  /-- Property `residency_duration`. -/
  residencyDuration : ResidencyDuration := .allYear
  /-- Property `own_support`. -/
  ownSupport : Bool := false
  /-- Property `married`. -/
  married : Bool := false
  /-- Property `joint_return`. -/
  jointReturn : Bool := false
  /-- Property `required_to_file`. -/
  requiredToFile : Bool := false
  /-- Property `filing_only_for_refund`. -/
  filingOnlyForRefund : Bool := false
  /-- Property `could_be_qualifying_child_of_another`. -/
  couldBeQualifyingChildOfAnother : Bool := false
  /-- Property `potential_claimer_must_file`. -/
  potentialClaimerMustFile : Bool := false
  /-- Property `potential_claimer_did_file`. -/
  potentialClaimerDidFile : Bool := false
  /-- Property `potential_claimer_filed_only_for_refund`. -/
  potentialClaimerFiledOnlyForRefund : Bool := false
  /-- Property `gross_income`. -/
  grossIncome : Int := 0
  /-- Property `qr_support_test`. -/
  qrSupportTest : Bool := false
  /-- Property `tin_type`. -/
  tinType : TinType
  /-- Property `is_us_citizen_full_year`. -/
  isUsCitizenFullYear : Bool := true
  /-- Property `us_resident`. -/
  usResident : Bool := false
  /-- Property `us_national`. -/
  usNational : Bool := false
  /-- Property `canada_mexico_resident`. -/
  canadaMexicoResident : Bool := false
  /-- Property `tp_claims`. -/
  tpClaims : Bool := true
  /-- Property `deceased`. -/
  deceased : Bool := false
  /-- Property `custody`. -/
  custody : Option BenefitSplitAnswers := none
  /-- Property `tp_paid_most_of_home_upkeep`. -/
  tpPaidMostOfHomeUpkeep : Bool := false
  /-- Property `tp_paid_most_of_parent_home_upkeep`. -/
  tpPaidMostOfParentHomeUpkeep : Bool := false
  /-- Property `ssn_employment_validity`. -/
  ssnEmploymentValidity : DependentSsnEmploymentValidity := .neither
  /-- Property `ssn_only_for_federally_funded_benefit`. -/
  ssnOnlyForFederallyFundedBenefit : Bool := false
  /-- Property `months_lived_with_tp_in_us`. -/
  monthsLivedWithTpInUs : Int := 12
  /-- Property `cdcc`. -/
  cdcc : Option CdccMemberAnswers := none
  deriving DecidableEq, Repr, Inhabited

/-- `HsaDistribution` (schema 1.2.0). -/
structure HsaDistribution where
  /-- Property `filer`. -/
  filer : FilerRole
  /-- Property `writable_distributions_rollover_bool`. -/
  writableDistributionsRolloverBool : Bool
  /-- Property `writable_distributions_rollover_amount`. -/
  writableDistributionsRolloverAmount : Int
  /-- Property `writable_gross_distribution`. -/
  writableGrossDistribution : Int
  /-- Property `has_withdrawn_excess_contributions`. -/
  hasWithdrawnExcessContributions : Bool
  /-- Property `writable_withdrawn_excess_contributions_amount`. -/
  writableWithdrawnExcessContributionsAmount : Int
  /-- Property `writable_earnings_on_excess_contributions`. -/
  writableEarningsOnExcessContributions : Int
  /-- Property `hsa_distribution_code`. -/
  hsaDistributionCode : HsaDistributionCode
  /-- Property `writable_fmv_on_date_of_death`. -/
  writableFmvOnDateOfDeath : Int
  /-- Property `writable_qualified_med_expenses`. -/
  writableQualifiedMedExpenses : Int
  deriving DecidableEq, Repr, Inhabited

/-- `HsaInput` (schema 1.2.0). -/
structure HsaInput where
  /-- Property `some_filer_had_non_w2_hsa_activity`. -/
  someFilerHadNonW2HsaActivity : Option Bool := none
  /-- Property `writable_primary_filer_had_non_w2_hsa_activity`. -/
  writablePrimaryFilerHadNonW2HsaActivity : Option Bool := none
  /-- Property `writable_secondary_filer_had_non_w2_hsa_activity`. -/
  writableSecondaryFilerHadNonW2HsaActivity : Option Bool := none
  /-- Property `has_hsa_medical_savings_account_type`. -/
  hasHsaMedicalSavingsAccountType : Option Bool := none
  /-- Property `writable_has_hsa_excess_contributions_previous_year`. -/
  writableHasHsaExcessContributionsPreviousYear : Option Bool := none
  /-- Property `writable_has_hsa_withdrawn_excess_contributions_yes_no`. -/
  writableHasHsaWithdrawnExcessContributionsYesNo : Option Bool := none
  /-- Property `some_filers_made_testing_period_contribution`. -/
  someFilersMadeTestingPeriodContribution : Option Bool := none
  /-- Property `some_filers_have_testing_period_additional_income`. -/
  someFilersHaveTestingPeriodAdditionalIncome : Option Bool := none
  /-- Property `hsa_distributions`. -/
  hsaDistributions : List HsaDistribution := []
  deriving DecidableEq, Repr, Inhabited

/-- `CreditAnswers` (schema 1.2.0). -/
structure CreditAnswers where
  /-- Property `eitc_qc_of_another`. -/
  eitcQcOfAnother : Option Bool := none
  /-- Property `eitc_qc_of_another_required_to_file`. -/
  eitcQcOfAnotherRequiredToFile : Option Bool := none
  /-- Property `eitc_qc_of_another_is_filing`. -/
  eitcQcOfAnotherIsFiling : Option Bool := none
  /-- Property `eitc_qc_of_another_is_filing_refund_only`. -/
  eitcQcOfAnotherIsFilingRefundOnly : Option Bool := none
  /-- Property `eitc_had_improper_claims`. -/
  eitcHadImproperClaims : Option Bool := none
  /-- Property `eitc_improper_claims_due_to_qc`. -/
  eitcImproperClaimsDueToQc : Option Bool := none
  /-- Property `eitc_improper_claim_taken_since_disallowal`. -/
  eitcImproperClaimTakenSinceDisallowal : Option Bool := none
  /-- Property `eitc_received_improper_claims_notice`. -/
  eitcReceivedImproperClaimsNotice : EitcReceivedImproperClaimsNotice := .notAnswered
  /-- Property `eitc_improper_claims_notice_expired`. -/
  eitcImproperClaimsNoticeExpired : Option Bool := none
  /-- Property `received_improper_claims`. -/
  receivedImproperClaims : Option Bool := none
  /-- Property `received_improper_claims_notice`. -/
  receivedImproperClaimsNotice : EitcReceivedImproperClaimsNotice := .notAnswered
  /-- Property `improper_claims_notice_expired`. -/
  improperClaimsNoticeExpired : Option Bool := none
  /-- Property `has_filed_ctc_odc_since_notice_expired`. -/
  hasFiledCtcOdcSinceNoticeExpired : Option Bool := none
  /-- Property `has_distributions_in_last_three_years`. -/
  hasDistributionsInLastThreeYears : Option Bool := none
  /-- Property `has_current_year_distributions`. -/
  hasCurrentYearDistributions : Option Bool := none
  /-- Property `has_self_reported_contributions`. -/
  hasSelfReportedContributions : Option Bool := none
  /-- Property `has_self_reported_non_taxable_payments`. -/
  hasSelfReportedNonTaxablePayments : Option Bool := none
  /-- Property `self_reported_non_taxable_payment_amount`. -/
  selfReportedNonTaxablePaymentAmount : Option Int := none
  deriving DecidableEq, Repr, Inhabited

/-- `CdccInput` (schema 1.2.0). -/
structure CdccInput where
  /-- Property `has_mfs_spouse_earned_income`. -/
  hasMfsSpouseEarnedIncome : Option Bool := none
  /-- Property `writable_mfs_spouse_earned_income`. -/
  writableMfsSpouseEarnedIncome : Option Int := none
  /-- Property `writable_total_qualified_dependent_care_expenses`. -/
  writableTotalQualifiedDependentCareExpenses : Option Int := none
  /-- Property `writable_carryover_amount`. -/
  writableCarryoverAmount : Option Int := none
  /-- Property `writable_forfeited_amount`. -/
  writableForfeitedAmount : Option Int := none
  /-- Property `has_credit_for_prior_year_expenses`. -/
  hasCreditForPriorYearExpenses : Option Bool := none
  /-- Property `claimed_credit_for_prior_year_expenses`. -/
  claimedCreditForPriorYearExpenses : Option Bool := none
  /-- Property `claimed_max_credit_for_prior_tax_year`. -/
  claimedMaxCreditForPriorTaxYear : Option Bool := none
  /-- Property `has_household_employee`. -/
  hasHouseholdEmployee : Option Bool := none
  /-- Property `benefits_from_sole_proprietorship_or_partnership`. -/
  benefitsFromSoleProprietorshipOrPartnership : Option Bool := none
  deriving DecidableEq, Repr, Inhabited

/-- `Form1095A` (schema 1.2.0). -/
structure Form1095A where
  /-- Property `writable_policy_start_date`. -/
  writablePolicyStartDate : Date
  /-- Property `writable_policy_end_date`. -/
  writablePolicyEndDate : Date
  /-- Property `writable_special_policy_modification_in_starting_month`. -/
  writableSpecialPolicyModificationInStartingMonth : Bool
  /-- Property `writable_has_policy_date_exception`. -/
  writableHasPolicyDateException : Bool
  /-- Property `has_coverage_months`. -/
  hasCoverageMonths : Bool
  /-- Property `coverage_months`. -/
  coverageMonths : List Int
  /-- Property `writable_premiums_or_slcsp_change`. -/
  writablePremiumsOrSlcspChange : Bool
  /-- Property `has_change_in_circumstance`. -/
  hasChangeInCircumstance : Bool
  /-- Property `writable_ptc_annual_premium`. -/
  writablePtcAnnualPremium : Int
  /-- Property `writable_slcsp_annual_premium`. -/
  writableSlcspAnnualPremium : Int
  /-- Property `writable_aptc_annual_amount`. -/
  writableAptcAnnualAmount : Int
  /-- Property `writable_ptc_monthly_premium`. -/
  writablePtcMonthlyPremium : List Int
  /-- Property `writable_ptc_monthly_slcsp_premium`. -/
  writablePtcMonthlySlcspPremium : List Int
  /-- Property `writable_ptc_monthly_aptc_premium`. -/
  writablePtcMonthlyAptcPremium : List Int
  deriving DecidableEq, Repr, Inhabited

/-- `PtcInput` (schema 1.2.0). -/
structure PtcInput where
  /-- Property `form1095_as`. -/
  form1095As : List Form1095A := []
  /-- Property `writable_has_ptc_qualifying_plan`. -/
  writableHasPtcQualifyingPlan : Option Bool := none
  /-- Property `writable_has_advanced_ptc`. -/
  writableHasAdvancedPtc : Option Bool := none
  /-- Property `dependent_tp_self_enrolled`. -/
  dependentTpSelfEnrolled : Option Bool := none
  /-- Property `dependent_tp_enrolled_someone_else`. -/
  dependentTpEnrolledSomeoneElse : Option Bool := none
  /-- Property `writable_dependent_tp_other_members_are_part_of_different_tax_family`. -/
  writableDependentTpOtherMembersArePartOfDifferentTaxFamily : Option Bool := none
  /-- Property `writable_has_mfs_exception`. -/
  writableHasMfsException : Option Bool := none
  /-- Property `writable_claiming_mfs_exception_for_fourth_straight_year`. -/
  writableClaimingMfsExceptionForFourthStraightYear : Option Bool := none
  /-- Property `writable_below100_threshold_and_not_eligible_for_medicaid_because_of_immigration_status`. -/
  writableBelow100ThresholdAndNotEligibleForMedicaidBecauseOfImmigrationStatus : Option Bool := none
  /-- Property `writable_has_employer_sponsored_plan`. -/
  writableHasEmployerSponsoredPlan : Option Bool := none
  /-- Property `writable_dependents_required_to_file`. -/
  writableDependentsRequiredToFile : Option Bool := none
  /-- Property `writable_self_reported_has_multiple1095_as`. -/
  writableSelfReportedHasMultiple1095As : Option Bool := none
  /-- Property `writable_is_additional_person_in_enrollment_family`. -/
  writableIsAdditionalPersonInEnrollmentFamily : Option Bool := none
  /-- Property `writable_is_additional_person_partof_different_tax_family`. -/
  writableIsAdditionalPersonPartofDifferentTaxFamily : Option Bool := none
  /-- Property `writable_is_enrolled_with_other_family`. -/
  writableIsEnrolledWithOtherFamily : Option Bool := none
  /-- Property `writable_has_immigration_status_not_eligible_for_marketplace`. -/
  writableHasImmigrationStatusNotEligibleForMarketplace : Option Bool := none
  /-- Property `writable_wants_to_use_alt_calculations`. -/
  writableWantsToUseAltCalculations : Option Bool := none
  deriving DecidableEq, Repr, Inhabited

/-- `ScreeningAnswers` (schema 1.2.0). -/
structure ScreeningAnswers where
  /-- Property `income_sources_supported`. -/
  incomeSourcesSupported : Bool := true
  /-- Property `received_digital_assets`. -/
  receivedDigitalAssets : Option Bool := none
  /-- Property `disposed_digital_assets`. -/
  disposedDigitalAssets : Option Bool := none
  /-- Property `has_foreign_accounts`. -/
  hasForeignAccounts : Option Bool := none
  /-- Property `is_foreign_trusts_grantor`. -/
  isForeignTrustsGrantor : Option Bool := none
  /-- Property `has_foreign_trusts_transactions`. -/
  hasForeignTrustsTransactions : Option Bool := none
  /-- Property `made_ira_contributions`. -/
  madeIraContributions : Option Bool := none
  /-- Property `w2_box15_income_from_different_state`. -/
  w2Box15IncomeFromDifferentState : Option Bool := none
  /-- Property `w2_has_box14_nyrrta_knockout_code`. -/
  w2HasBox14NyrrtaKnockoutCode : Option Bool := none
  /-- Property `w2_has_rrta_codes_in_box14`. -/
  w2HasRrtaCodesInBox14 : Option Bool := none
  /-- Property `lived_in_ny`. -/
  livedInNy : Option Bool := none
  /-- Property `w2_paid_yonkers_taxes`. -/
  w2PaidYonkersTaxes : Option Bool := none
  /-- Property `part_year_yonkers_resident`. -/
  partYearYonkersResident : Option Bool := none
  /-- Property `primary_filer_forms_another_state`. -/
  primaryFilerFormsAnotherState : Option Bool := none
  /-- Property `received_alaska_pfd`. -/
  receivedAlaskaPfd : Option Bool := none
  /-- Property `spouse_received_alaska_pfd`. -/
  spouseReceivedAlaskaPfd : Option Bool := none
  /-- Property `spouse_lives_in_other_or_multiple_states`. -/
  spouseLivesInOtherOrMultipleStates : Option Bool := none
  /-- Property `spouse_forms_another_state`. -/
  spouseFormsAnotherState : Option Bool := none
  /-- Property `is_after_tax_day_and_not_resubmitting`. -/
  isAfterTaxDayAndNotResubmitting : Option Bool := none
  /-- Property `is_after_resubmission_deadline`. -/
  isAfterResubmissionDeadline : Option Bool := none
  deriving DecidableEq, Repr, Inhabited

/-- `NonNegMoney` properties of `DisabilityAnswers`. -/
def DisabilityAnswers.moneyFields (s : DisabilityAnswers) : List (String × Int) :=
  optMoney "writable_total_taxable_disability_amount" s.writableTotalTaxableDisabilityAmount

/-- `NonNegMoney` properties of `HsaFilerAnswers`. -/
def HsaFilerAnswers.moneyFields (s : HsaFilerAnswers) : List (String × Int) :=
  optMoney "writable_hsa_nonemployer_contributions_tax_year" s.writableHsaNonemployerContributionsTaxYear ++
  optMoney "writable_hsa_nonemployer_contributions_tax_year_plus_one" s.writableHsaNonemployerContributionsTaxYearPlusOne

/-- `NonNegMoney` properties of `CdccFilerAnswers`. -/
def CdccFilerAnswers.moneyFields (s : CdccFilerAnswers) : List (String × Int) :=
  optMoney "dependent_care_plan_maximum" s.dependentCarePlanMaximum ++
  optMoney "writable_qualifying_expense_amount" s.writableQualifyingExpenseAmount

/-- `NonNegMoney` properties of `CdccMemberAnswers`. -/
def CdccMemberAnswers.moneyFields (s : CdccMemberAnswers) : List (String × Int) :=
  optMoney "writable_qualifying_expense_amount" s.writableQualifyingExpenseAmount

/-- `NonNegMoney` properties of `Dependent`. -/
def Dependent.moneyFields (s : Dependent) : List (String × Int) :=
  [("gross_income", s.grossIncome)]

/-- `NonNegMoney` properties of `HsaDistribution`. -/
def HsaDistribution.moneyFields (s : HsaDistribution) : List (String × Int) :=
  [("writable_distributions_rollover_amount", s.writableDistributionsRolloverAmount), ("writable_gross_distribution", s.writableGrossDistribution), ("writable_withdrawn_excess_contributions_amount", s.writableWithdrawnExcessContributionsAmount), ("writable_earnings_on_excess_contributions", s.writableEarningsOnExcessContributions), ("writable_fmv_on_date_of_death", s.writableFmvOnDateOfDeath), ("writable_qualified_med_expenses", s.writableQualifiedMedExpenses)]

/-- `NonNegMoney` properties of `CreditAnswers`. -/
def CreditAnswers.moneyFields (s : CreditAnswers) : List (String × Int) :=
  optMoney "self_reported_non_taxable_payment_amount" s.selfReportedNonTaxablePaymentAmount

/-- `NonNegMoney` properties of `CdccInput`. -/
def CdccInput.moneyFields (s : CdccInput) : List (String × Int) :=
  optMoney "writable_mfs_spouse_earned_income" s.writableMfsSpouseEarnedIncome ++
  optMoney "writable_total_qualified_dependent_care_expenses" s.writableTotalQualifiedDependentCareExpenses ++
  optMoney "writable_carryover_amount" s.writableCarryoverAmount ++
  optMoney "writable_forfeited_amount" s.writableForfeitedAmount

/-- `NonNegMoney` properties of `Form1095A`. -/
def Form1095A.moneyFields (s : Form1095A) : List (String × Int) :=
  [("writable_ptc_annual_premium", s.writablePtcAnnualPremium), ("writable_slcsp_annual_premium", s.writableSlcspAnnualPremium), ("writable_aptc_annual_amount", s.writableAptcAnnualAmount)]


/-- `filers`: each side is absent or a flags object. -/
structure Filers where
  /-- Property `primary`. -/
  primary : Option FilerFlags := none
  /-- Property `secondary`. -/
  secondary : Option FilerFlags := none
  deriving DecidableEq, Repr, Inhabited

/-- W-2 box 12: the codes present, in the order given (JSON keys are unique). -/
structure Box12 where
  /-- Property `entries`. -/
  entries : List (Box12Code × Int) := []
  deriving DecidableEq, Repr, Inhabited

/-- One Form W-2. -/
structure FormW2 where
  /-- Property `filer`. -/
  filer : FilerRole
  /-- Property `wages`. -/
  wages : Int
  /-- Property `federal_withholding`. -/
  federalWithholding : Int := 0
  /-- Property `oasdi_wages`. -/
  oasdiWages : Int := 0
  /-- Property `oasdi_withholding`. -/
  oasdiWithholding : Int := 0
  /-- Property `medicare_wages`. -/
  medicareWages : Int := 0
  /-- Property `medicare_withholding`. -/
  medicareWithholding : Int := 0
  /-- Property `allocated_tips`. -/
  allocatedTips : Int := 0
  /-- Property `dependent_care_benefits`. -/
  dependentCareBenefits : Int := 0
  /-- Property `non_qualified_plans`. -/
  nonQualifiedPlans : Int := 0
  /-- Property `box12`. -/
  box12 : Box12 := {}
  /-- Property `statutory_employee`. -/
  statutoryEmployee : Bool := false
  /-- Property `third_party_sick_pay`. -/
  thirdPartySickPay : Bool := false
  /-- Property `plan457b_is_governmental`. -/
  plan457bIsGovernmental : Bool := false
  deriving DecidableEq, Repr, Inhabited

/-- One Form 1099-INT. -/
structure Form1099Int where
  /-- Property `filer`. -/
  filer : FilerRole
  /-- Property `has1099`. -/
  has1099 : Bool
  /-- Property `no1099_amount`. -/
  no1099Amount : Int := 0
  /-- Property `interest_income`. -/
  interestIncome : Int := 0
  /-- Property `early_withdrawal_penalty`. -/
  earlyWithdrawalPenalty : Int := 0
  /-- Property `government_bond_interest`. -/
  governmentBondInterest : Int := 0
  /-- Property `federal_tax_withheld`. -/
  federalTaxWithheld : Int := 0
  /-- Property `foreign_tax_paid`. -/
  foreignTaxPaid : Int := 0
  /-- Property `tax_exempt_interest`. -/
  taxExemptInterest : Int := 0
  /-- Property `private_activity_bond_interest`. -/
  privateActivityBondInterest : Int := 0
  /-- Property `market_discount`. -/
  marketDiscount : Int := 0
  /-- Property `bond_premium`. -/
  bondPremium : Int := 0
  /-- Property `bond_premium_treasury`. -/
  bondPremiumTreasury : Int := 0
  /-- Property `bond_premium_tax_exempt`. -/
  bondPremiumTaxExempt : Int := 0
  /-- Property `state_is_different`. -/
  stateIsDifferent : Bool := false
  /-- Property `state_tax_withheld`. -/
  stateTaxWithheld : Int := 0
  /-- Property `facta_filing_required`. -/
  factaFilingRequired : Bool := false
  deriving DecidableEq, Repr, Inhabited

/-- One Form 1099-G. -/
structure Form1099G where
  /-- Property `filer`. -/
  filer : FilerRole
  /-- Property `unemployment_compensation`. -/
  unemploymentCompensation : Int
  /-- Property `repaid_this_year_for_this_year`. -/
  repaidThisYearForThisYear : Int := 0
  /-- Property `repaid_this_year_for_earlier_year`. -/
  repaidThisYearForEarlierYear : Int := 0
  /-- Property `federal_tax_withheld`. -/
  federalTaxWithheld : Int := 0
  /-- Property `state_is_different`. -/
  stateIsDifferent : Bool := false
  deriving DecidableEq, Repr, Inhabited

/-- One Form 1099-MISC. -/
structure Form1099Misc where
  /-- Property `filer`. -/
  filer : FilerRole
  /-- Property `is_alaska_pfd`. -/
  isAlaskaPfd : Bool
  /-- Property `other_income`. -/
  otherIncome : Int
  /-- Property `federal_withholding`. -/
  federalWithholding : Int := 0
  deriving DecidableEq, Repr, Inhabited

/-- One Form 1099-R. -/
structure Form1099R where
  /-- Property `filer`. -/
  filer : FilerRole
  /-- Property `distribution_code`. -/
  distributionCode : List CodeChar
  /-- Property `gross_distribution`. -/
  grossDistribution : Int
  /-- Property `taxable_amount`. -/
  taxableAmount : Int
  /-- Property `taxable_amount_blank`. -/
  taxableAmountBlank : Bool := false
  /-- Property `taxable_amount_not_determined`. -/
  taxableAmountNotDetermined : Bool := false
  /-- Property `total_distribution`. -/
  totalDistribution : Bool := false
  /-- Property `capital_gain`. -/
  capitalGain : Int := 0
  /-- Property `federal_withholding`. -/
  federalWithholding : Int := 0
  /-- Property `net_appreciation`. -/
  netAppreciation : Int := 0
  /-- Property `ira_sep_simple`. -/
  iraSepSimple : Bool := false
  /-- Property `other_dollar`. -/
  otherDollar : Int := 0
  /-- Property `other_percentage_nonzero`. -/
  otherPercentageNonzero : Bool := false
  /-- Property `percentage_total_distribution_nonzero`. -/
  percentageTotalDistributionNonzero : Bool := false
  /-- Property `amount_allocable_to_irr`. -/
  amountAllocableToIrr : Int := 0
  /-- Property `facta_filing_requirement`. -/
  factaFilingRequirement : Bool := false
  /-- Property `state_tax_withheld`. -/
  stateTaxWithheld : Int := 0
  /-- Property `payer_state_is_different`. -/
  payerStateIsDifferent : Bool := false
  /-- Property `has_death_benefit_payment_date`. -/
  hasDeathBenefitPaymentDate : Bool := false
  /-- Property `is_indirect_rollover`. -/
  isIndirectRollover : Bool := false
  /-- Property `is_distribution_from_military_retirement_plan`. -/
  isDistributionFromMilitaryRetirementPlan : Bool := false
  /-- Property `qualified_disaster_distribution`. -/
  qualifiedDisasterDistribution : Bool := false
  /-- Property `public_safety_officer`. -/
  publicSafetyOfficer : Bool := false
  /-- Property `public_safety_officer_premiums`. -/
  publicSafetyOfficerPremiums : Bool := false
  /-- Property `recipient_date_of_birth`. -/
  recipientDateOfBirth : Option Date := none
  deriving DecidableEq, Repr, Inhabited

/-- `social_security`: `netBenefits` (box 5 of each SSA-1099) may be negative. -/
structure SocialSecurity where
  /-- Property `net_benefits`. -/
  netBenefits : List Int
  /-- Property `lived_apart_all_year`. -/
  livedApartAllYear : Bool := false
  /-- Property `federal_tax_withheld` (box 6 of each SSA-1099, `NonNegMoney`). -/
  federalTaxWithheld : List Int := []
  deriving DecidableEq, Repr, Inhabited

/-- `adjustments.educator_expenses`. -/
structure EducatorExpenses where
  /-- Property `was_k12_educators`. -/
  wasK12Educators : WhoDid
  /-- Property `primary_expenses`. -/
  primaryExpenses : Int := 0
  /-- Property `secondary_expenses`. -/
  secondaryExpenses : Int := 0
  deriving DecidableEq, Repr, Inhabited

/-- `adjustments.student_loan_interest`. -/
structure StudentLoanInterest where
  /-- Property `had_payments`. -/
  hadPayments : Bool
  /-- Property `loans_qualify`. -/
  loansQualify : Bool := false
  /-- Property `interest_amount`. -/
  interestAmount : Int := 0
  deriving DecidableEq, Repr, Inhabited

/-- `adjustments`. -/
structure Adjustments where
  /-- Property `educator_expenses`. -/
  educatorExpenses : Option EducatorExpenses := none
  /-- Property `student_loan_interest`. -/
  studentLoanInterest : Option StudentLoanInterest := none
  /-- Property `hsa`. -/
  hsa : Option HsaInput := none
  deriving DecidableEq, Repr, Inhabited

/-- `estimated_payments`. -/
structure EstimatedPayments where
  /-- Property `paid_estimated_taxes_or_from_last_year`. -/
  paidEstimatedTaxesOrFromLastYear : Bool
  /-- Property `amount`. -/
  amount : Int := 0
  /-- Property `paid_under_different_name`. -/
  paidUnderDifferentName : Bool := false
  /-- Property `paid_with_former_spouse`. -/
  paidWithFormerSpouse : Option WhoDid := none
  deriving DecidableEq, Repr, Inhabited

/-- The validated-shape request body (`POST /calculate`). A value of this type
has the right shape and types; whether its numbers, list sizes and cross-field
rules hold is `Request.Valid` (`UsTax/Api/Spec.lean`). Absent list = empty. -/
structure Request where
  /-- Property `filing_status`. -/
  filingStatus : FilingStatus
  /-- Property `filers`. -/
  filers : Filers := {}
  /-- Property `filing_details`. -/
  filingDetails : FilingDetails := {}
  /-- Property `w2s`. -/
  w2s : List FormW2 := []
  /-- Property `interest_reports`. -/
  interestReports : List Form1099Int := []
  /-- Property `form1099g`. -/
  form1099g : List Form1099G := []
  /-- Property `form1099misc`. -/
  form1099misc : List Form1099Misc := []
  /-- Property `form1099r`. -/
  form1099r : List Form1099R := []
  /-- Property `social_security`. -/
  socialSecurity : Option SocialSecurity := none
  /-- Property `adjustments`. -/
  adjustments : Adjustments := {}
  /-- Property `estimated_payments`. -/
  estimatedPayments : Option EstimatedPayments := none
  /-- Property `filing_answers`. -/
  filingAnswers : Option FilingAnswers := none
  /-- Property `dependents`. -/
  dependents : List Dependent := []
  /-- Property `credits`. -/
  credits : Option CreditAnswers := none
  /-- Property `cdcc`. -/
  cdcc : Option CdccInput := none
  /-- Property `premium_tax_credit`. -/
  premiumTaxCredit : Option PtcInput := none
  /-- Property `screening`. -/
  screening : Option ScreeningAnswers := none
  deriving DecidableEq, Repr, Inhabited

/-! ### Money fields

Each record lists its money amounts with the schema property name (the last
segment of the error path). Every `NonNegMoney` box is here, so the range rule
in `Spec.lean` covers it; `socialSecurity.netBenefits` is the only signed one. -/

/-- Box 12 amounts, keyed by code letter. -/
def Box12.moneyFields (b : Box12) : List (String × Int) :=
  b.entries.map fun (code, n) => (ApiEnum.name code, n)

/-- `NonNegMoney` properties of a W-2 (box 12 is separate). -/
def FormW2.moneyFields (w : FormW2) : List (String × Int) :=
  [("wages", w.wages), ("federal_withholding", w.federalWithholding),
   ("oasdi_wages", w.oasdiWages), ("oasdi_withholding", w.oasdiWithholding),
   ("medicare_wages", w.medicareWages), ("medicare_withholding", w.medicareWithholding),
   ("allocated_tips", w.allocatedTips), ("dependent_care_benefits", w.dependentCareBenefits),
   ("non_qualified_plans", w.nonQualifiedPlans)]

/-- `NonNegMoney` properties of a 1099-INT. -/
def Form1099Int.moneyFields (f : Form1099Int) : List (String × Int) :=
  [("no_1099_amount", f.no1099Amount), ("interest_income", f.interestIncome),
   ("early_withdrawal_penalty", f.earlyWithdrawalPenalty),
   ("government_bond_interest", f.governmentBondInterest),
   ("federal_tax_withheld", f.federalTaxWithheld), ("foreign_tax_paid", f.foreignTaxPaid),
   ("tax_exempt_interest", f.taxExemptInterest),
   ("private_activity_bond_interest", f.privateActivityBondInterest),
   ("market_discount", f.marketDiscount), ("bond_premium", f.bondPremium),
   ("bond_premium_treasury", f.bondPremiumTreasury),
   ("bond_premium_tax_exempt", f.bondPremiumTaxExempt),
   ("state_tax_withheld", f.stateTaxWithheld)]

/-- `NonNegMoney` properties of a 1099-G. -/
def Form1099G.moneyFields (f : Form1099G) : List (String × Int) :=
  [("unemployment_compensation", f.unemploymentCompensation),
   ("repaid_this_year_for_this_year", f.repaidThisYearForThisYear),
   ("repaid_this_year_for_earlier_year", f.repaidThisYearForEarlierYear),
   ("federal_tax_withheld", f.federalTaxWithheld)]

/-- `NonNegMoney` properties of a 1099-MISC. -/
def Form1099Misc.moneyFields (f : Form1099Misc) : List (String × Int) :=
  [("other_income", f.otherIncome), ("federal_withholding", f.federalWithholding)]

/-- `NonNegMoney` properties of a 1099-R. -/
def Form1099R.moneyFields (f : Form1099R) : List (String × Int) :=
  [("gross_distribution", f.grossDistribution), ("taxable_amount", f.taxableAmount),
   ("capital_gain", f.capitalGain), ("federal_withholding", f.federalWithholding),
   ("net_appreciation", f.netAppreciation), ("other_dollar", f.otherDollar),
   ("amount_allocable_to_irr", f.amountAllocableToIrr),
   ("state_tax_withheld", f.stateTaxWithheld)]

/-- `NonNegMoney` properties of the educator expenses. -/
def EducatorExpenses.moneyFields (e : EducatorExpenses) : List (String × Int) :=
  [("primary_expenses", e.primaryExpenses), ("secondary_expenses", e.secondaryExpenses)]

/-- `NonNegMoney` properties of the student loan interest. -/
def StudentLoanInterest.moneyFields (s : StudentLoanInterest) : List (String × Int) :=
  [("interest_amount", s.interestAmount)]

/-- `NonNegMoney` properties of the estimated payments. -/
def EstimatedPayments.moneyFields (e : EstimatedPayments) : List (String × Int) :=
  [("amount", e.amount)]

end UsTax.Api
