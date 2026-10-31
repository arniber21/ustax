/-!
# Shared types (Catala module `Types`, `catala/types.catala_en`)

Only the types the Lean modules use so far. Constructor names are the Catala
enumeration cases in lower camel case, so a Catala JSON input value
(`"MarriedFilingJointly"`) maps to `.marriedFilingJointly`.
-/

namespace UsTax

/-- Catala `Types.FilerRole`: which of the (at most two) filers an item belongs to
(`catala/types.catala_en`, section "Filer role"). -/
inductive FilerRole where
  /-- The first filer. -/
  | primaryFiler
  /-- The spouse on a joint return. -/
  | secondaryFiler
  deriving DecidableEq, Repr, Inhabited

namespace FilerRole

/-- The Catala case name. -/
def catalaName : FilerRole → String
  | primaryFiler => "PrimaryFiler"
  | secondaryFiler => "SecondaryFiler"

/-- Parse a Catala case name. -/
def ofString? : String → Option FilerRole
  | "PrimaryFiler" => some primaryFiler
  | "SecondaryFiler" => some secondaryFiler
  | _ => none

end FilerRole

/-- Catala `Types.FilingStatus` (Direct File `/filingStatus`, IRC § 1 and § 2). -/
inductive FilingStatus where
  /-- Single (§ 1(c)). -/
  | single
  /-- Married filing jointly (§ 1(a)). -/
  | marriedFilingJointly
  /-- Married filing separately (§ 1(d)). -/
  | marriedFilingSeparately
  /-- Head of household (§ 1(b), § 2(b)). -/
  | headOfHousehold
  /-- Qualifying surviving spouse (§ 1(a), § 2(a)); taxed on the joint table. -/
  | qualifyingSurvivingSpouse
  deriving DecidableEq, Repr, Inhabited

namespace FilingStatus

/-- Every filing status, in the order of the Catala declaration. -/
def all : List FilingStatus :=
  [single, marriedFilingJointly, marriedFilingSeparately, headOfHousehold,
    qualifyingSurvivingSpouse]

/-- The Catala case name, as `clerk run` JSON inputs spell it. -/
def catalaName : FilingStatus → String
  | single => "Single"
  | marriedFilingJointly => "MarriedFilingJointly"
  | marriedFilingSeparately => "MarriedFilingSeparately"
  | headOfHousehold => "HeadOfHousehold"
  | qualifyingSurvivingSpouse => "QualifyingSurvivingSpouse"

/-- The Direct File `/filingStatus` option (`oracle/facts.csv`). Note
`qualifiedSurvivingSpouse`, not `qualifying...`. -/
def directFileName : FilingStatus → String
  | single => "single"
  | marriedFilingJointly => "marriedFilingJointly"
  | marriedFilingSeparately => "marriedFilingSeparately"
  | headOfHousehold => "headOfHousehold"
  | qualifyingSurvivingSpouse => "qualifiedSurvivingSpouse"

/-- Parse a Catala case name (`"Single"`) or a Direct File `/filingStatus`
option (`"single"`, `"qualifiedSurvivingSpouse"`, ...). -/
def ofString? (s : String) : Option FilingStatus :=
  all.find? fun fs => fs.catalaName == s || fs.directFileName == s

#guard all.all fun fs => ofString? fs.catalaName == some fs
#guard all.all fun fs => ofString? fs.directFileName == some fs
#guard ofString? "qualifiedSurvivingSpouse" == some qualifyingSurvivingSpouse
#guard ofString? "MFJ" == none

end FilingStatus
end UsTax
