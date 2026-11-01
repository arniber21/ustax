import UsTax.Money
import UsTax.Lists
import UsTax.Types
import UsTax.Params2024.PtcHsa

/-!
# Health savings accounts: Form 8889 lines 1 to 16 and the Schedule 1 deduction (issue #47)

Lean implementation of `catala/hsa.catala_en` (module `Hsa`, scopes `HsaDistributionItem` and
`Hsa`), written by hand from the Catala source under strategy (c) of `docs/catala-to-lean.md`,
in the order of the Catala file; the code that runs. Law: 26 U.S.C. § 223
(`sources/statute/irc-223.html`), Rev. Proc. 2023-23 section 3.04, Form 8889 (2024) and its
instructions (`sources/forms-instructions/i8889--2024.pdf`).

| Catala (`Hsa`)                               | Lean (`UsTax.Hsa`)                                  |
|----------------------------------------------|-----------------------------------------------------|
| enums `MedicareEnrollment` ... `HsaDistributionCode` | the same names, cases in lower camel case   |
| structs `HsaFilerAnswers`, `HsaDistribution`, `Form8889` | the same names                          |
| `scope HsaDistributionItem`                  | `HsaDistributionItemOut` (`hsaDistributionItem`)    |
| `scope Hsa` inputs                           | `HsaIn`                                             |
| a variable `x` of `Hsa`                      | `def x (i : HsaIn)`; `x of role` is `x i role`      |
| `scope Hsa` (the outputs)                    | `HsaOut` (`hsa`)                                    |
| `R.round_dollar`, `Money.*`                  | `Money.roundDollar`, `Money.min`, `Money.positive`, `Lists.sumBy` |

Each variable of the scope is a definition of its own taking the scope inputs (and the filer role
where Catala says `depends on role`), so that the lemmas can name it; `hsa` collects the outputs.
Money is `Int` cents, conditions are `Bool`. DF-BUG(4) (the line 2 sum rounded once) and the
equal division of the family limit between spouses (IRC 223(b)(5)(B)(ii), DF-BUG(12) candidate)
are reproduced as in Catala (Lean follows Catala, not Direct File).
-/

namespace UsTax.Hsa

open Money

/-- Catala `MedicareEnrollment` (DF `/enrolledInMedicareOptions`). -/
inductive MedicareEnrollment where
  | medicareAllYear | medicarePartOfYear | medicareNoneOfYear
  deriving DecidableEq, Repr, Inhabited

/-- Catala `HdhpCoverageStatus` (DF `/hsaHdhpCoverageStatusOptions`). -/
inductive HdhpCoverageStatus where
  | hdhpAllYear | hdhpPartOfYear | hdhpNoneOfYear
  deriving DecidableEq, Repr, Inhabited

/-- Catala `TypeOfHdhp` (DF `/typeOfHdhpOptions`). -/
inductive TypeOfHdhp where
  | selfOnly | family | bothSelfAndFamily
  deriving DecidableEq, Repr, Inhabited

/-- Catala `OtherCoverageIneligible` (DF `/hadOtherCoverageIneligibleForHSAOptions`). -/
inductive OtherCoverageIneligible where
  | otherCoverageWholeYear | otherCoveragePartOfYear | otherCoverageNoneOfYear
  deriving DecidableEq, Repr, Inhabited

/-- Catala `MaritalStatusChange` (DF `/changeInMaritalStatusDuringTaxYearOptions`). -/
inductive MaritalStatusChange where
  | wasMarriedOrDivorcedThisYear | wasNotMarriedNorDivorcedThisYear
  deriving DecidableEq, Repr, Inhabited

/-- Catala `HsaDistributionCode`: Form 1099-SA box 3 (DF `/hsaDistributionCodeOptions`). -/
inductive HsaDistributionCode where
  | normalDistribution | excessContributions | disability | deathOtherThanCode6
  | prohibitedTransaction | deathDistributionAfterYear
  deriving DecidableEq, Repr, Inhabited

/-- Catala `HsaFilerAnswers`: the writable HSA answers DF keeps per filer (`/filers`). -/
structure HsaFilerAnswers where
  writablePrimaryFilerHasMadeContributionsToHsa : Bool
  writableSecondaryFilerHasMadeContributionsToHsa : Bool
  enrolledInMedicare : MedicareEnrollment
  hsaHdhpCoverageStatus : HdhpCoverageStatus
  typeOfHdhp : TypeOfHdhp
  hadOtherCoverageIneligibleForHsa : OtherCoverageIneligible
  writableMfsLine6Check : Bool
  writableChangeInMaritalStatusDuringTaxYear : MaritalStatusChange
  writableMaritalChangeAffectContributionLimitBool : Bool
  hasMadeQualifiedHsaFundingDistribution : Bool
  /-- Contributions made in the tax year. -/
  writableHsaNonemployerContributionsTaxYear : Int
  /-- Contributions for the tax year made by the unextended due date. -/
  writableHsaNonemployerContributionsTaxYearPlusOne : Int
  deriving Repr

/-- Catala `HsaDistribution`: one Form 1099-SA (DF `/hsaDistributions`). -/
structure HsaDistribution where
  filer : FilerRole
  writableDistributionsRolloverBool : Bool
  writableDistributionsRolloverAmount : Int
  /-- Box 1. -/
  writableGrossDistribution : Int
  hasWithdrawnExcessContributions : Bool
  writableWithdrawnExcessContributionsAmount : Int
  /-- Box 2. -/
  writableEarningsOnExcessContributions : Int
  /-- Box 3. -/
  hsaDistributionCode : HsaDistributionCode
  /-- Box 4. -/
  writableFmvOnDateOfDeath : Int
  writableQualifiedMedExpenses : Int
  deriving Repr

/-- Outputs of Catala `scope HsaDistributionItem`: the derived facts of one 1099-SA. -/
structure HsaDistributionItemOut where
  distributionsRolloverAmount : Int
  withdrawnExcessContributionsAmount : Int
  modifiedDistribution : Int
  filer : FilerRole
  grossDistribution : Int
  qualifiedMedExpenses : Int
  hasEarningsOnExcessContributions : Bool
  codeIsNotNormal : Bool
  hasFmvOnDateOfDeath : Bool
  hasUnqualifiedDistribution : Bool

/-- Catala `scope HsaDistributionItem`. -/
def hsaDistributionItem (d : HsaDistribution) : HsaDistributionItemOut :=
  let rollover := if d.writableDistributionsRolloverBool then d.writableDistributionsRolloverAmount else 0
  let withdrawn := if d.hasWithdrawnExcessContributions
    then d.writableWithdrawnExcessContributionsAmount else 0
  let modified := d.writableGrossDistribution - (rollover + withdrawn)
  { distributionsRolloverAmount := rollover, withdrawnExcessContributionsAmount := withdrawn
    modifiedDistribution := modified, filer := d.filer
    grossDistribution := d.writableGrossDistribution
    qualifiedMedExpenses := d.writableQualifiedMedExpenses
    hasEarningsOnExcessContributions := decide (d.writableEarningsOnExcessContributions > 0)
    codeIsNotNormal := decide (d.hsaDistributionCode ≠ .normalDistribution)
    hasFmvOnDateOfDeath := decide (d.writableFmvOnDateOfDeath > 0)
    hasUnqualifiedDistribution := decide (modified > d.writableQualifiedMedExpenses) }

/-- Catala `Form8889`: the lines of one Form 8889 (Parts I and II) that the module computes. -/
structure Form8889 where
  line1Family : Bool
  line1SelfOnly : Bool
  line2 : Int
  line3 : Int
  line5 : Int
  line6 : Int
  line7 : Int
  line8 : Int
  line9 : Int
  line11 : Int
  line12 : Int
  line13 : Int
  line14a : Int
  line14b : Int
  line14c : Int
  line15 : Int
  line16 : Int
  deriving Repr, DecidableEq

/-- Inputs of Catala `scope Hsa`. -/
structure HsaIn where
  isFilingStatusMfj : Bool
  isMarried : Bool
  isSingle : Bool
  primaryFilerAge55OrOlder : Bool
  secondaryFilerAge55OrOlder : Bool
  primaryFilerCanBeClaimed : Bool
  secondaryFilerCanBeClaimed : Bool
  /-- W-2 box 12 code W. -/
  primaryFilerTotalHsaContributionsFromW2s : Int
  secondaryFilerTotalHsaContributionsFromW2s : Int
  hasPrimaryFilerHsaContributionsFromW2s : Bool
  hasSecondaryFilerHsaContributionsFromW2s : Bool
  knockoutHasNoPaymentsOrCredits : Bool
  paidEstimatedTaxesOrFromLastYear : Bool
  taxExemptInterest : Int
  pensionsAndAnnuities : Int
  socialSecurityBenefits : Int
  primaryFiler : HsaFilerAnswers
  secondaryFiler : HsaFilerAnswers
  someFilerHadNonW2HsaActivity : Bool
  writablePrimaryFilerHadNonW2HsaActivity : Bool
  writableSecondaryFilerHadNonW2HsaActivity : Bool
  hasHsaMedicalSavingsAccountType : Bool
  writableHasHsaExcessContributionsPreviousYear : Bool
  writableHasHsaWithdrawnExcessContributionsYesNo : Bool
  someFilersMadeTestingPeriodContribution : Bool
  someFilersHaveTestingPeriodAdditionalIncome : Bool
  hsaDistributions : List HsaDistribution
  deriving Repr

section Variables

variable (i : HsaIn)

/-! ### Setup -/

/-- `is_primary of role`. -/
def isPrimary (role : FilerRole) : Bool := decide (role = .primaryFiler)
/-- `is_secondary of role`. -/
def isSecondary (role : FilerRole) : Bool := !isPrimary role
/-- `answers of role`. -/
def answers (role : FilerRole) : HsaFilerAnswers :=
  if isPrimary role then i.primaryFiler else i.secondaryFiler
/-- `age55_or_older of role`. -/
def age55OrOlder (role : FilerRole) : Bool :=
  if isPrimary role then i.primaryFilerAge55OrOlder else i.secondaryFilerAge55OrOlder
/-- `can_be_claimed of role`. -/
def canBeClaimed (role : FilerRole) : Bool :=
  if isPrimary role then i.primaryFilerCanBeClaimed else i.secondaryFilerCanBeClaimed
/-- `items`: each 1099-SA through `HsaDistributionItem`. -/
def items : List HsaDistributionItemOut := i.hsaDistributions.map hsaDistributionItem

/-! ### Who has HSA activity -/

/-- DF `/flowShowHsaYesNo`. -/
def flowShowHsaYesNo : Bool :=
  !i.hasPrimaryFilerHsaContributionsFromW2s ||
    (i.isFilingStatusMfj && !i.hasSecondaryFilerHsaContributionsFromW2s)
/-- DF `/someFilerHadNonEmployerHsaActivity`. -/
def someFilerHadNonEmployerHsaActivity : Bool :=
  flowShowHsaYesNo i && i.someFilerHadNonW2HsaActivity
/-- DF `/flowShowHsaPrimaryYesNo`. -/
def flowShowHsaPrimaryYesNo : Bool :=
  someFilerHadNonEmployerHsaActivity i && !i.hasPrimaryFilerHsaContributionsFromW2s
/-- DF `/primaryFilerHadNonW2HsaActivity`. -/
def primaryFilerHadNonW2HsaActivity : Bool :=
  flowShowHsaPrimaryYesNo i && i.writablePrimaryFilerHadNonW2HsaActivity
/-- DF `/flowShowHsaSecondaryYesNo`. -/
def flowShowHsaSecondaryYesNo : Bool :=
  i.isFilingStatusMfj && flowShowHsaYesNo i && someFilerHadNonEmployerHsaActivity i &&
    !i.hasSecondaryFilerHsaContributionsFromW2s
/-- DF `/secondaryFilerHadNonW2HsaActivity`. -/
def secondaryFilerHadNonW2HsaActivity : Bool :=
  flowShowHsaSecondaryYesNo i && i.writableSecondaryFilerHadNonW2HsaActivity
/-- DF `/filers/*/mayHaveHsaContributionsNotConsideringKos`. -/
def mayHaveHsaContributionsNotConsideringKos (role : FilerRole) : Bool :=
  (i.isFilingStatusMfj && isSecondary role &&
      (i.hasSecondaryFilerHsaContributionsFromW2s ||
        (secondaryFilerHadNonW2HsaActivity i && someFilerHadNonEmployerHsaActivity i))) ||
    (isPrimary role &&
      (i.hasPrimaryFilerHsaContributionsFromW2s ||
        (primaryFilerHadNonW2HsaActivity i && someFilerHadNonEmployerHsaActivity i)))
/-- DF `/someFilerHasSomeHsaActivityNotConsideringKos`. -/
def someFilerHasSomeHsaActivityNotConsideringKos : Bool :=
  mayHaveHsaContributionsNotConsideringKos i .primaryFiler ||
    mayHaveHsaContributionsNotConsideringKos i .secondaryFiler

/-! ### Medical savings account and excess contributions from earlier years -/

/-- DF `/hasHsaMedicalSavingsAccountTypeDerived`. -/
def hasHsaMedicalSavingsAccountTypeDerived : Bool :=
  someFilerHasSomeHsaActivityNotConsideringKos i && i.hasHsaMedicalSavingsAccountType
/-- DF `/flowToExcessContributionsPreviousYear`. -/
def flowToExcessContributionsPreviousYear : Bool :=
  someFilerHasSomeHsaActivityNotConsideringKos i && !i.hasHsaMedicalSavingsAccountType
/-- DF `/hasHsaExcessContributionsPreviousYear`. -/
def hasHsaExcessContributionsPreviousYear : Bool :=
  flowToExcessContributionsPreviousYear i && i.writableHasHsaExcessContributionsPreviousYear
/-- DF `/flowToHsaExcessContributions`. -/
def flowToHsaExcessContributions : Bool :=
  flowToExcessContributionsPreviousYear i && !i.writableHasHsaExcessContributionsPreviousYear
/-- DF `/hasHsaWithdrawnExcessContributionsYesNo`. -/
def hasHsaWithdrawnExcessContributionsYesNo : Bool :=
  flowToHsaExcessContributions i && i.writableHasHsaWithdrawnExcessContributionsYesNo
/-- DF `/flowKnockoutHsaExcessContributions`. -/
def koHsaExcessContributions : Bool :=
  hasHsaExcessContributionsPreviousYear i || hasHsaWithdrawnExcessContributionsYesNo i
/-- DF `/flowKnockoutHsaMedicalSavingsAccountType`. -/
def koHsaMedicalSavingsAccountType : Bool :=
  !flowToExcessContributionsPreviousYear i && !flowToHsaExcessContributions i &&
    hasHsaMedicalSavingsAccountTypeDerived i
/-- DF `/filers/*/mayHaveHsaContributions`. -/
def mayHaveHsaContributions (role : FilerRole) : Bool :=
  mayHaveHsaContributionsNotConsideringKos i role && !koHsaExcessContributions i &&
    !koHsaMedicalSavingsAccountType i

/-! ### Contributions made: who has a Part I -/

/-- DF `/filers/*/primaryFilerMayHaveOnlyNonW2Contributions`. -/
def primaryFilerMayHaveOnlyNonW2Contributions (role : FilerRole) : Bool :=
  mayHaveHsaContributions i role && !i.hasPrimaryFilerHsaContributionsFromW2s && isPrimary role
/-- DF `/filers/*/primaryFilerHasNonW2ContributionsInTy`. -/
def primaryFilerHasNonW2ContributionsInTy (role : FilerRole) : Bool :=
  primaryFilerMayHaveOnlyNonW2Contributions i role &&
    (answers i role).writablePrimaryFilerHasMadeContributionsToHsa
/-- DF `/flowSecondaryFilerHasNoHsaContributionsOnW2andMFJ`. -/
def flowSecondaryFilerHasNoHsaContributionsOnW2AndMfj : Bool :=
  mayHaveHsaContributions i .secondaryFiler && !i.hasSecondaryFilerHsaContributionsFromW2s &&
    i.isFilingStatusMfj
/-- DF `/filers/*/secondaryFilerMayHaveOnlyNonW2Contributions`. -/
def secondaryFilerMayHaveOnlyNonW2Contributions (role : FilerRole) : Bool :=
  flowSecondaryFilerHasNoHsaContributionsOnW2AndMfj i && isSecondary role
/-- DF `/filers/*/secondaryFilerHasNonW2ContributionsInTy`. -/
def secondaryFilerHasNonW2ContributionsInTy (role : FilerRole) : Bool :=
  secondaryFilerMayHaveOnlyNonW2Contributions i role &&
    (answers i role).writableSecondaryFilerHasMadeContributionsToHsa
/-- DF `/filers/*/flowSkipToHsaTestingPeriodContributionCheck`. -/
def flowSkipToHsaTestingPeriodContributionCheck (role : FilerRole) : Bool :=
  (primaryFilerMayHaveOnlyNonW2Contributions i role &&
      !primaryFilerHasNonW2ContributionsInTy i role) ||
    (secondaryFilerMayHaveOnlyNonW2Contributions i role &&
      !secondaryFilerHasNonW2ContributionsInTy i role)
/-- DF `/filers/*/primaryFilerHasMadeContributionsToHsa`. -/
def primaryFilerHasMadeContributionsToHsa (role : FilerRole) : Bool :=
  mayHaveHsaContributions i role && !flowSkipToHsaTestingPeriodContributionCheck i role &&
    (i.hasPrimaryFilerHsaContributionsFromW2s || primaryFilerHasNonW2ContributionsInTy i role)
/-- DF `/filers/*/secondaryFilerHasMadeContributionsToHsa`. -/
def secondaryFilerHasMadeContributionsToHsa (role : FilerRole) : Bool :=
  mayHaveHsaContributions i role && !flowSkipToHsaTestingPeriodContributionCheck i role &&
    (i.hasSecondaryFilerHsaContributionsFromW2s || secondaryFilerHasNonW2ContributionsInTy i role)
/-- DF `/filers/*/hasMadeContributionsToHsa`. -/
def hasMadeContributionsToHsa (role : FilerRole) : Bool :=
  (isPrimary role && primaryFilerHasMadeContributionsToHsa i role) ||
    (isSecondary role && secondaryFilerHasMadeContributionsToHsa i role)
/-- DF `/bothFilersHaveHsa`. -/
def bothFilersHaveHsa : Bool :=
  hasMadeContributionsToHsa i .primaryFiler && hasMadeContributionsToHsa i .secondaryFiler
/-- IRC 223(b)(6). DF `/flowKnockoutFilerIsDependentAndContributesToHsa`. -/
def koFilerIsDependentAndContributesToHsa : Bool :=
  (hasMadeContributionsToHsa i .primaryFiler && canBeClaimed i .primaryFiler) ||
    (hasMadeContributionsToHsa i .secondaryFiler && canBeClaimed i .secondaryFiler)

/-! ### IRC 223(b)(7): Medicare -/

/-- DF `/filers/*/enrolledInMedicarePartOfYearKnockout`. -/
def enrolledInMedicarePartOfYearKnockout (role : FilerRole) : Bool :=
  hasMadeContributionsToHsa i role && (answers i role).enrolledInMedicare == .medicarePartOfYear
/-- DF `/filers/*/enrolledInMedicareAllYearKnockout`. -/
def enrolledInMedicareAllYearKnockout (role : FilerRole) : Bool :=
  hasMadeContributionsToHsa i role && (answers i role).enrolledInMedicare == .medicareAllYear
/-- DF `/flowKnockoutHsaCoverageChanging`. -/
def koHsaCoverageChanging : Bool :=
  enrolledInMedicarePartOfYearKnockout i .primaryFiler ||
    enrolledInMedicarePartOfYearKnockout i .secondaryFiler
/-- DF `/flowKnockoutEnrolledInMedicareAllYear`. -/
def koEnrolledInMedicareAllYear : Bool :=
  enrolledInMedicareAllYearKnockout i .primaryFiler ||
    enrolledInMedicareAllYearKnockout i .secondaryFiler
/-- DF `/flowKnockoutHdhpCoverageStatusNotNeeded`. -/
def koHdhpCoverageStatusNotNeeded : Bool :=
  koHsaCoverageChanging i || koEnrolledInMedicareAllYear i

/-! ### IRC 223(c)(1): high deductible health plan coverage -/

/-- DF `/filers/*/hsaHdhpCoverageStatusDerived` is complete. -/
def hsaHdhpCoverageStatusAsked (role : FilerRole) : Bool :=
  hasMadeContributionsToHsa i role && !koHdhpCoverageStatusNotNeeded i
/-- DF `/filers/*/hasHdhpCoverageAllYear`. -/
def hasHdhpCoverageAllYear (role : FilerRole) : Bool :=
  hsaHdhpCoverageStatusAsked i role && (answers i role).hsaHdhpCoverageStatus == .hdhpAllYear
/-- DF `/filers/*/notEnrolledInHdhpKnockout`. -/
def notEnrolledInHdhpKnockout (role : FilerRole) : Bool :=
  hsaHdhpCoverageStatusAsked i role && (answers i role).hsaHdhpCoverageStatus == .hdhpNoneOfYear
/-- DF `/filers/*/hsaHdhpCoverageStatusKnockout`. -/
def hsaHdhpCoverageStatusKnockout (role : FilerRole) : Bool :=
  hsaHdhpCoverageStatusAsked i role && (answers i role).hsaHdhpCoverageStatus == .hdhpPartOfYear
/-- DF `/flowKnockoutNotEnrolledInHdhp`. -/
def koNotEnrolledInHdhp : Bool :=
  notEnrolledInHdhpKnockout i .primaryFiler || notEnrolledInHdhpKnockout i .secondaryFiler
/-- DF `/flowKnockoutHdhpCoverageNotAllYear`. -/
def koHdhpCoverageNotAllYear : Bool :=
  hsaHdhpCoverageStatusKnockout i .primaryFiler || hsaHdhpCoverageStatusKnockout i .secondaryFiler
/-- DF `/filers/*/flowShouldAskForHsaHdhpCoverageType`. -/
def flowShouldAskForHsaHdhpCoverageType (role : FilerRole) : Bool :=
  !koHsaCoverageChanging i && !koNotEnrolledInHdhp i && hasHdhpCoverageAllYear i role
/-- DF `/filers/*/typeOfHdhpKnockout`. -/
def typeOfHdhpKnockout (role : FilerRole) : Bool :=
  flowShouldAskForHsaHdhpCoverageType i role && (answers i role).typeOfHdhp == .bothSelfAndFamily
/-- DF `/filers/*/hasSelfOnlyHdhp`. -/
def hasSelfOnlyHdhp (role : FilerRole) : Bool :=
  flowShouldAskForHsaHdhpCoverageType i role && (answers i role).typeOfHdhp == .selfOnly
/-- DF `/filers/*/hasFamilyHdhp`. -/
def hasFamilyHdhp (role : FilerRole) : Bool :=
  flowShouldAskForHsaHdhpCoverageType i role && (answers i role).typeOfHdhp == .family
/-- DF `/flowKnockoutHsaSelfAndFamilyCoverage`. -/
def koHsaSelfAndFamilyCoverage : Bool :=
  typeOfHdhpKnockout i .primaryFiler || typeOfHdhpKnockout i .secondaryFiler
/-- DF `/filers/*/flowShouldAskHadCoverageIneligibleForHSAContributions`. -/
def flowShouldAskHadCoverageIneligibleForHsaContributions (role : FilerRole) : Bool :=
  flowShouldAskForHsaHdhpCoverageType i role && (hasSelfOnlyHdhp i role || hasFamilyHdhp i role)
/-- DF `/filers/*/causesOtherCoveragePartOfYearKnockOut`. -/
def causesOtherCoveragePartOfYearKnockOut (role : FilerRole) : Bool :=
  flowShouldAskHadCoverageIneligibleForHsaContributions i role &&
    (answers i role).hadOtherCoverageIneligibleForHsa == .otherCoveragePartOfYear
/-- DF `/filers/*/causesOtherCoverageWholeYearKnockOut`. -/
def causesOtherCoverageWholeYearKnockOut (role : FilerRole) : Bool :=
  flowShouldAskHadCoverageIneligibleForHsaContributions i role &&
    (answers i role).hadOtherCoverageIneligibleForHsa == .otherCoverageWholeYear
/-- DF `/flowKnockoutOtherCoveragePartOfYear`. -/
def koOtherCoveragePartOfYear : Bool :=
  causesOtherCoveragePartOfYearKnockOut i .primaryFiler ||
    causesOtherCoveragePartOfYearKnockOut i .secondaryFiler
/-- DF `/flowKnockoutOtherCoverageWholeYear`. -/
def koOtherCoverageWholeYear : Bool :=
  causesOtherCoverageWholeYearKnockOut i .primaryFiler ||
    causesOtherCoverageWholeYearKnockOut i .secondaryFiler
/-- DF `/flowKnockoutHsaCoverage`. -/
def koHsaCoverage : Bool :=
  koHsaCoverageChanging i || koHsaSelfAndFamilyCoverage i || koHdhpCoverageNotAllYear i ||
    koOtherCoveragePartOfYear i
/-- DF `/flowKnockoutContributionSummaryNoneAllowed`. -/
def koContributionSummaryNoneAllowed : Bool :=
  koEnrolledInMedicareAllYear i || koNotEnrolledInHdhp i || koOtherCoverageWholeYear i

/-! ### IRC 223(b)(5): married individuals -/

/-- DF `/hsaMarriedFilersHaveFamilyCoverage`. -/
def hsaMarriedFilersHaveFamilyCoverage : Bool :=
  flowShouldAskForHsaHdhpCoverageType i .primaryFiler &&
    flowShouldAskForHsaHdhpCoverageType i .secondaryFiler && i.isFilingStatusMfj &&
    (hasFamilyHdhp i .primaryFiler || hasFamilyHdhp i .secondaryFiler)
/-- DF `/filers/*/isCoveredByFamilyHdhp`. -/
def isCoveredByFamilyHdhp (role : FilerRole) : Bool :=
  hsaMarriedFilersHaveFamilyCoverage i || hasFamilyHdhp i role
/-- DF `/filers/*/isCoveredBySelfOnlyHdhp`. -/
def isCoveredBySelfOnlyHdhp (role : FilerRole) : Bool :=
  !isCoveredByFamilyHdhp i role && hasSelfOnlyHdhp i role
/-- DF `/filers/*/wasEligibleToMakeHsaContributionsAllYear`. -/
def wasEligibleToMakeHsaContributionsAllYear (role : FilerRole) : Bool :=
  hasHdhpCoverageAllYear i role && hasMadeContributionsToHsa i role &&
    (answers i role).enrolledInMedicare == .medicareNoneOfYear && !canBeClaimed i role
/-- DF `/flowKnockoutMFSLine6Check`. -/
def koMfsLine6Check : Bool :=
  i.isMarried && !i.isFilingStatusMfj && flowShouldAskForHsaHdhpCoverageType i .primaryFiler &&
    hasFamilyHdhp i .primaryFiler && i.primaryFiler.writableMfsLine6Check
/-- DF `/filers/*/causesMaritalChangeAffectsContributionLimitKnockout`. -/
def causesMaritalChangeAffectsContributionLimitKnockout (role : FilerRole) : Bool :=
  hasMadeContributionsToHsa i role && !i.isSingle &&
    (if flowShouldAskHadCoverageIneligibleForHsaContributions i role
     then (answers i role).hadOtherCoverageIneligibleForHsa == .otherCoverageNoneOfYear
     else true) &&
    (answers i role).writableChangeInMaritalStatusDuringTaxYear == .wasMarriedOrDivorcedThisYear &&
    (answers i role).writableMaritalChangeAffectContributionLimitBool
/-- DF `/flowKnockoutMaritalChangeAffectsContributionLimit`. -/
def koMaritalChangeAffectsContributionLimit : Bool :=
  causesMaritalChangeAffectsContributionLimitKnockout i .primaryFiler ||
    causesMaritalChangeAffectsContributionLimitKnockout i .secondaryFiler
/-- DF `/flowKnockoutMadeQualifiedHsaFundingDistribution`. -/
def koMadeQualifiedHsaFundingDistribution : Bool :=
  (hasMadeContributionsToHsa i .primaryFiler && i.primaryFiler.hasMadeQualifiedHsaFundingDistribution) ||
    (hasMadeContributionsToHsa i .secondaryFiler &&
      i.secondaryFiler.hasMadeQualifiedHsaFundingDistribution)

/-! ### IRC 223(b)(8): testing period -/

/-- DF `/filers/*/hasToShowTestingPeriodCheck`. -/
def hasToShowTestingPeriodCheck (role : FilerRole) : Bool :=
  ((isPrimary role || (isSecondary role && i.isFilingStatusMfj)) &&
      flowSkipToHsaTestingPeriodContributionCheck i role) ||
    ((isPrimary role || (isSecondary role && i.isFilingStatusMfj)) && flowShowHsaYesNo i &&
      someFilerHadNonEmployerHsaActivity i && !mayHaveHsaContributions i role)
/-- DF `/flowKnockoutHsaTestingPeriodAdditionalIncomeYes`. -/
def koHsaTestingPeriodAdditionalIncomeYes : Bool :=
  (hasToShowTestingPeriodCheck i .primaryFiler || hasToShowTestingPeriodCheck i .secondaryFiler) &&
    i.someFilersMadeTestingPeriodContribution && i.someFilersHaveTestingPeriodAdditionalIncome

/-! ### IRC 223(b): the limit (Form 8889 lines 2 to 13) -/

/-- Line 2. DF `/filers/*/hsaNonemployerContributionsTotal` (DF-BUG(4): rounded once). -/
def hsaNonemployerContributionsTotal (role : FilerRole) : Int :=
  if hasMadeContributionsToHsa i role then
    roundDollar ((answers i role).writableHsaNonemployerContributionsTaxYear +
      (answers i role).writableHsaNonemployerContributionsTaxYearPlusOne)
  else 0
/-- DF `/filers/*/hsaBaseContributionLimit`. -/
def hsaBaseContributionLimit (role : FilerRole) : Int :=
  if wasEligibleToMakeHsaContributionsAllYear i role && hasSelfOnlyHdhp i role &&
      !hsaMarriedFilersHaveFamilyCoverage i then Params.hsaLimitSelfOnly
  else if wasEligibleToMakeHsaContributionsAllYear i role && isCoveredByFamilyHdhp i role then
    Params.hsaLimitFamily
  else 0
/-- Line 3. DF `/filers/*/hsaInitialContributionLimit`. -/
def hsaInitialContributionLimit (role : FilerRole) : Int :=
  if hasMadeContributionsToHsa i role then
    roundDollar
      (if (wasEligibleToMakeHsaContributionsAllYear i role && age55OrOlder i role &&
            ((isCoveredByFamilyHdhp i role || isCoveredBySelfOnlyHdhp i role) && !i.isMarried)) ||
          (wasEligibleToMakeHsaContributionsAllYear i role && age55OrOlder i role &&
            isCoveredBySelfOnlyHdhp i role && i.isMarried)
       then hsaBaseContributionLimit i role + Params.hsaCatchUp55
       else hsaBaseContributionLimit i role)
  else 0
/-- Line 5 (line 4, Archer MSA, is `$0`). -/
def hsaContributionLimitLessMsaContributions (role : FilerRole) : Int :=
  if hasMadeContributionsToHsa i role then hsaInitialContributionLimit i role else 0
/-- DF `/filers/*/hasMetFamilyContributionLimitRule`. -/
def hasMetFamilyContributionLimitRule (role : FilerRole) : Bool :=
  hsaMarriedFilersHaveFamilyCoverage i && bothFilersHaveHsa i && hasHdhpCoverageAllYear i role
/-- IRC 223(b)(5)(B)(ii): equal division (DF-BUG(12) candidate). -/
def hsaAllocatedContributionLimit (role : FilerRole) : Int :=
  mulRate (hsaContributionLimitLessMsaContributions i role) (1 / 2)
/-- Line 6. -/
def hsaContributionLimitLessAddition (role : FilerRole) : Int :=
  if hasMadeContributionsToHsa i role then
    roundDollar (if hasMetFamilyContributionLimitRule i role then hsaAllocatedContributionLimit i role
      else hsaContributionLimitLessMsaContributions i role)
  else 0
/-- Line 7. -/
def additionToHsaContributionLimit (role : FilerRole) : Int :=
  if hasMadeContributionsToHsa i role then
    roundDollar (if wasEligibleToMakeHsaContributionsAllYear i role && age55OrOlder i role &&
        isCoveredByFamilyHdhp i role && i.isMarried then Params.hsaCatchUp55 else 0)
  else 0
/-- Line 9 (W-2 box 12 code W). -/
def hsaContributionsW2sTotal (role : FilerRole) : Int :=
  roundDollar (if i.isFilingStatusMfj && isSecondary role
    then i.secondaryFilerTotalHsaContributionsFromW2s
    else i.primaryFilerTotalHsaContributionsFromW2s)
/-- Line 10, always `$0` (`koMadeQualifiedHsaFundingDistribution`). -/
def hsaFundingDistributionsTotal (_role : FilerRole) : Int := 0
/-- Line 11. -/
def hsaEmployerContributionsAndFundingDistributionTotal (role : FilerRole) : Int :=
  roundDollar (hsaContributionsW2sTotal i role + hsaFundingDistributionsTotal role)
/-- DF `/filers/*/hsaContributionsTotal` (line 2 plus line 11). -/
def hsaContributionsTotal (role : FilerRole) : Int :=
  roundDollar (hsaEmployerContributionsAndFundingDistributionTotal i role +
    hsaNonemployerContributionsTotal i role)
/-- Line 8. -/
def hsaTotalContributionLimit (role : FilerRole) : Int :=
  if hasMadeContributionsToHsa i role then
    roundDollar (hsaContributionLimitLessAddition i role + additionToHsaContributionLimit i role)
  else 0
/-- Line 12. -/
def hsaContributionLimitLessLine11 (role : FilerRole) : Int :=
  if hasMadeContributionsToHsa i role then
    positive (hsaTotalContributionLimit i role -
      hsaEmployerContributionsAndFundingDistributionTotal i role)
  else 0
/-- Line 13: the smaller of line 2 and line 12. -/
def filerHsaTotalDeductibleAmount (role : FilerRole) : Int :=
  if hasMadeContributionsToHsa i role then
    Money.min (hsaNonemployerContributionsTotal i role) (hsaContributionLimitLessLine11 i role)
  else 0
/-- Schedule 1 line 13, Form 1040 line 10. -/
def hsaTotalDeductibleAmount : Int :=
  filerHsaTotalDeductibleAmount i .primaryFiler + filerHsaTotalDeductibleAmount i .secondaryFiler
/-- DF `/filers/*/hasExcessHsaContributions`. -/
def hasExcessHsaContributions (role : FilerRole) : Bool :=
  decide (hsaNonemployerContributionsTotal i role > filerHsaTotalDeductibleAmount i role)
/-- DF `/filers/*/hsaContributionLimitExceeded`. -/
def hsaContributionLimitExceeded (role : FilerRole) : Bool :=
  hasMadeContributionsToHsa i role &&
    decide (hsaContributionsTotal i role > hsaTotalContributionLimit i role)
/-- DF `/filers/*/hsaContributionLimitExceededAmount`. -/
def hsaContributionLimitExceededAmount (role : FilerRole) : Int :=
  hsaContributionsTotal i role - hsaTotalContributionLimit i role
/-- DF `/flowHsaContributionsOverLimitKnockout`. -/
def koHsaContributionsOverLimit : Bool :=
  hsaContributionLimitExceeded i .primaryFiler || hsaContributionLimitExceeded i .secondaryFiler

/-! ### Form 8889 Part II: distributions -/

/-- DF `/filers/*/hasHsaCanHaveDistribution`. -/
def hasHsaCanHaveDistribution (role : FilerRole) : Bool := mayHaveHsaContributions i role
/-- DF `/someFilerCanHaveDistribution`. -/
def someFilerCanHaveDistribution : Bool :=
  hasHsaCanHaveDistribution i .primaryFiler || hasHsaCanHaveDistribution i .secondaryFiler
/-- DF `/primaryFilerHsaDistributions`, `/secondaryFilerHsaDistributions`. -/
def filerItems (role : FilerRole) : List HsaDistributionItemOut :=
  (items i).filter fun x => hasHsaCanHaveDistribution i role && x.filer == role
/-- Line 14a. -/
def totalHsaDistributions (role : FilerRole) : Int :=
  if i.isFilingStatusMfj || isPrimary role then
    roundDollar (sumBy (·.grossDistribution) (filerItems i role))
  else 0
/-- DF `/filers/*/hsaRolloverTotal`. -/
def hsaRolloverTotal (role : FilerRole) : Int :=
  if i.isFilingStatusMfj || isPrimary role then
    roundDollar (sumBy (·.distributionsRolloverAmount) (filerItems i role))
  else 0
/-- DF `/filers/*/hsaTotalExcessContributionsWithdrawnInTime`. -/
def hsaTotalExcessContributionsWithdrawnInTime (role : FilerRole) : Int :=
  if i.isFilingStatusMfj || isPrimary role then
    roundDollar (sumBy (·.withdrawnExcessContributionsAmount) (filerItems i role))
  else 0
/-- Line 14b. -/
def hsaRolloversAndTimelyWithdrawals (role : FilerRole) : Int :=
  hsaTotalExcessContributionsWithdrawnInTime i role + hsaRolloverTotal i role
/-- DF `/filers/*/hsaNetDistributionAmount`. -/
def hsaNetDistributionAmount (role : FilerRole) : Int :=
  if totalHsaDistributions i role + hsaRolloversAndTimelyWithdrawals i role > 0 then
    positive (totalHsaDistributions i role - hsaRolloversAndTimelyWithdrawals i role)
  else 0
/-- Line 14c. -/
def hsaCalculatedDistributionAmount (role : FilerRole) : Int := hsaNetDistributionAmount i role
/-- Line 15. -/
def hsaQualifiedMedExpenses (role : FilerRole) : Int :=
  if i.isFilingStatusMfj || isPrimary role then
    roundDollar (sumBy (·.qualifiedMedExpenses) (filerItems i role))
  else 0
/-- Line 16, the constant `$0` (`koHsaUnqualifiedDistributions` guarantees it). -/
def hsaCalculatedTaxableHsaDistributionTotal (_role : FilerRole) : Int := 0
/-- DF `/filers/*/hasHsaDistributions`. -/
def hasHsaDistributions (role : FilerRole) : Bool :=
  hasHsaCanHaveDistribution i role && decide (totalHsaDistributions i role > 0)
/-- DF `/flowKnockoutEarningsOnExcessContributions`. -/
def koEarningsOnExcessContributions : Bool :=
  someFilerCanHaveDistribution i && (items i).any (·.hasEarningsOnExcessContributions)
/-- DF `/flowKnockoutHsaDistributionCode`. -/
def koHsaDistributionCode : Bool :=
  someFilerCanHaveDistribution i && (items i).any (·.codeIsNotNormal)
/-- DF `/flowKnockoutHsaUnqualifiedDistributions`. -/
def koHsaUnqualifiedDistributions : Bool :=
  someFilerCanHaveDistribution i && (items i).any (·.hasUnqualifiedDistribution)
/-- DF `/flowKnockoutHsaDistributionFMV`. -/
def koHsaDistributionFmv : Bool :=
  someFilerCanHaveDistribution i && (items i).any (·.hasFmvOnDateOfDeath)
/-- DF `/hsaDistributions/secondaryFilerUsedWithoutMFJ`. -/
def koHsaDistributionsSecondaryFilerUsedWithoutMfj : Bool :=
  someFilerCanHaveDistribution i && !i.isFilingStatusMfj &&
    (items i).any (fun x => x.filer == .secondaryFiler)
/-- DF `/hsaDistributions/*/hasDistributionsWithoutHsaActivity`. -/
def koHasHsaDistributionsWithoutActivity : Bool :=
  someFilerCanHaveDistribution i && !koHsaDistributionsSecondaryFilerUsedWithoutMfj i &&
    (items i).any (fun x => !hasHsaCanHaveDistribution i x.filer)
/-- DF `/knockoutNoPaymentsHsaDistribution`. -/
def koNoPaymentsHsaDistribution : Bool :=
  !i.paidEstimatedTaxesOrFromLastYear && i.knockoutHasNoPaymentsOrCredits &&
    i.taxExemptInterest == 0 && i.pensionsAndAnnuities == 0 && i.socialSecurityBenefits == 0 &&
    (hasHsaDistributions i .primaryFiler || hasHsaDistributions i .secondaryFiler)

/-! ### Who files Form 8889, and the lines of each form -/

/-- DF `/numberOfFilersRequiredToFileForm8889`. -/
def numberOfFilersRequiredToFileForm8889 : Int :=
  (if hasMadeContributionsToHsa i .primaryFiler || hasHsaDistributions i .primaryFiler then 1
   else 0) +
  (if hasMadeContributionsToHsa i .secondaryFiler || hasHsaDistributions i .secondaryFiler then 1
   else 0)
/-- DF `/requiresForm8889`. -/
def requiresForm8889 : Bool := decide (numberOfFilersRequiredToFileForm8889 i > 0)

/-- The lines of the form of `role`. -/
def form8889 (role : FilerRole) : Form8889 :=
  { line1Family := hasMadeContributionsToHsa i role && isCoveredByFamilyHdhp i role
    line1SelfOnly := hasMadeContributionsToHsa i role && isCoveredBySelfOnlyHdhp i role
    line2 := hsaNonemployerContributionsTotal i role
    line3 := hsaInitialContributionLimit i role
    line5 := hsaContributionLimitLessMsaContributions i role
    line6 := hsaContributionLimitLessAddition i role
    line7 := additionToHsaContributionLimit i role
    line8 := hsaTotalContributionLimit i role
    line9 := hsaContributionsW2sTotal i role
    line11 := hsaEmployerContributionsAndFundingDistributionTotal i role
    line12 := hsaContributionLimitLessLine11 i role
    line13 := filerHsaTotalDeductibleAmount i role
    line14a := totalHsaDistributions i role
    line14b := hsaRolloversAndTimelyWithdrawals i role
    line14c := hsaCalculatedDistributionAmount i role
    line15 := hsaQualifiedMedExpenses i role
    line16 := hsaCalculatedTaxableHsaDistributionTotal role }

/-- `unsupported`: the 19 `flow.xml` knockouts and the two block-submission validations. -/
def unsupported : Bool :=
  koNoPaymentsHsaDistribution i || koHsaMedicalSavingsAccountType i || koHsaDistributionCode i ||
    koOtherCoveragePartOfYear i || koOtherCoverageWholeYear i ||
    koEarningsOnExcessContributions i || koHsaTestingPeriodAdditionalIncomeYes i ||
    koHsaUnqualifiedDistributions i || koHsaDistributionFmv i ||
    koMaritalChangeAffectsContributionLimit i || koMfsLine6Check i ||
    koHsaContributionsOverLimit i || koHsaExcessContributions i ||
    koContributionSummaryNoneAllowed i || koHdhpCoverageStatusNotNeeded i ||
    koNotEnrolledInHdhp i || koMadeQualifiedHsaFundingDistribution i || koHsaCoverage i ||
    koFilerIsDependentAndContributesToHsa i || koHasHsaDistributionsWithoutActivity i ||
    koHsaDistributionsSecondaryFilerUsedWithoutMfj i

end Variables

/-- The outputs of Catala `scope Hsa`. Outputs that depend on the filer role are functions. -/
structure HsaOut where
  hasMadeContributionsToHsa : FilerRole → Bool
  hsaNonemployerContributionsTotal : FilerRole → Int
  hsaEmployerContributionsAndFundingDistributionTotal : FilerRole → Int
  hsaContributionsTotal : FilerRole → Int
  hsaInitialContributionLimit : FilerRole → Int
  hsaContributionLimitLessMsaContributions : FilerRole → Int
  hsaContributionLimitLessAddition : FilerRole → Int
  additionToHsaContributionLimit : FilerRole → Int
  hsaTotalContributionLimit : FilerRole → Int
  hsaContributionLimitLessLine11 : FilerRole → Int
  filerHsaTotalDeductibleAmount : FilerRole → Int
  hsaTotalDeductibleAmount : Int
  hasExcessHsaContributions : FilerRole → Bool
  hsaContributionLimitExceededAmount : FilerRole → Int
  totalHsaDistributions : FilerRole → Int
  hsaRolloversAndTimelyWithdrawals : FilerRole → Int
  hsaCalculatedDistributionAmount : FilerRole → Int
  hsaQualifiedMedExpenses : FilerRole → Int
  hsaCalculatedTaxableHsaDistributionTotal : FilerRole → Int
  hasHsaDistributions : FilerRole → Bool
  numberOfFilersRequiredToFileForm8889 : Int
  requiresForm8889 : Bool
  form8889 : FilerRole → Form8889
  koFilerIsDependentAndContributesToHsa : Bool
  koHsaExcessContributions : Bool
  koHsaMedicalSavingsAccountType : Bool
  koMfsLine6Check : Bool
  koEarningsOnExcessContributions : Bool
  koHsaDistributionCode : Bool
  koHsaUnqualifiedDistributions : Bool
  koHsaDistributionFmv : Bool
  koHsaContributionsOverLimit : Bool
  koOtherCoveragePartOfYear : Bool
  koOtherCoverageWholeYear : Bool
  koMaritalChangeAffectsContributionLimit : Bool
  koMadeQualifiedHsaFundingDistribution : Bool
  koHsaTestingPeriodAdditionalIncomeYes : Bool
  koNoPaymentsHsaDistribution : Bool
  koNotEnrolledInHdhp : Bool
  koEnrolledInMedicareAllYear : Bool
  koHsaCoverageChanging : Bool
  koHsaSelfAndFamilyCoverage : Bool
  koHdhpCoverageNotAllYear : Bool
  koHsaCoverage : Bool
  koContributionSummaryNoneAllowed : Bool
  koHdhpCoverageStatusNotNeeded : Bool
  koHasHsaDistributionsWithoutActivity : Bool
  koHsaDistributionsSecondaryFilerUsedWithoutMfj : Bool
  unsupported : Bool

/-- Catala `scope Hsa`: the outputs. -/
def hsa (i : HsaIn) : HsaOut :=
  { hasMadeContributionsToHsa := hasMadeContributionsToHsa i
    hsaNonemployerContributionsTotal := hsaNonemployerContributionsTotal i
    hsaEmployerContributionsAndFundingDistributionTotal :=
      hsaEmployerContributionsAndFundingDistributionTotal i
    hsaContributionsTotal := hsaContributionsTotal i
    hsaInitialContributionLimit := hsaInitialContributionLimit i
    hsaContributionLimitLessMsaContributions := hsaContributionLimitLessMsaContributions i
    hsaContributionLimitLessAddition := hsaContributionLimitLessAddition i
    additionToHsaContributionLimit := additionToHsaContributionLimit i
    hsaTotalContributionLimit := hsaTotalContributionLimit i
    hsaContributionLimitLessLine11 := hsaContributionLimitLessLine11 i
    filerHsaTotalDeductibleAmount := filerHsaTotalDeductibleAmount i
    hsaTotalDeductibleAmount := hsaTotalDeductibleAmount i
    hasExcessHsaContributions := hasExcessHsaContributions i
    hsaContributionLimitExceededAmount := hsaContributionLimitExceededAmount i
    totalHsaDistributions := totalHsaDistributions i
    hsaRolloversAndTimelyWithdrawals := hsaRolloversAndTimelyWithdrawals i
    hsaCalculatedDistributionAmount := hsaCalculatedDistributionAmount i
    hsaQualifiedMedExpenses := hsaQualifiedMedExpenses i
    hsaCalculatedTaxableHsaDistributionTotal := hsaCalculatedTaxableHsaDistributionTotal
    hasHsaDistributions := hasHsaDistributions i
    numberOfFilersRequiredToFileForm8889 := numberOfFilersRequiredToFileForm8889 i
    requiresForm8889 := requiresForm8889 i
    form8889 := form8889 i
    koFilerIsDependentAndContributesToHsa := koFilerIsDependentAndContributesToHsa i
    koHsaExcessContributions := koHsaExcessContributions i
    koHsaMedicalSavingsAccountType := koHsaMedicalSavingsAccountType i
    koMfsLine6Check := koMfsLine6Check i
    koEarningsOnExcessContributions := koEarningsOnExcessContributions i
    koHsaDistributionCode := koHsaDistributionCode i
    koHsaUnqualifiedDistributions := koHsaUnqualifiedDistributions i
    koHsaDistributionFmv := koHsaDistributionFmv i
    koHsaContributionsOverLimit := koHsaContributionsOverLimit i
    koOtherCoveragePartOfYear := koOtherCoveragePartOfYear i
    koOtherCoverageWholeYear := koOtherCoverageWholeYear i
    koMaritalChangeAffectsContributionLimit := koMaritalChangeAffectsContributionLimit i
    koMadeQualifiedHsaFundingDistribution := koMadeQualifiedHsaFundingDistribution i
    koHsaTestingPeriodAdditionalIncomeYes := koHsaTestingPeriodAdditionalIncomeYes i
    koNoPaymentsHsaDistribution := koNoPaymentsHsaDistribution i
    koNotEnrolledInHdhp := koNotEnrolledInHdhp i
    koEnrolledInMedicareAllYear := koEnrolledInMedicareAllYear i
    koHsaCoverageChanging := koHsaCoverageChanging i
    koHsaSelfAndFamilyCoverage := koHsaSelfAndFamilyCoverage i
    koHdhpCoverageNotAllYear := koHdhpCoverageNotAllYear i
    koHsaCoverage := koHsaCoverage i
    koContributionSummaryNoneAllowed := koContributionSummaryNoneAllowed i
    koHdhpCoverageStatusNotNeeded := koHdhpCoverageStatusNotNeeded i
    koHasHsaDistributionsWithoutActivity := koHasHsaDistributionsWithoutActivity i
    koHsaDistributionsSecondaryFilerUsedWithoutMfj := koHsaDistributionsSecondaryFilerUsedWithoutMfj i
    unsupported := unsupported i }

/-! ### Unit tests: every assertion of `catala/tests/test_hsa.catala_en`

`Case` is the Catala test helper: a single filer aged 40 with a self-only HDHP for the whole
year, no Medicare, no other coverage, no W-2 HSA contributions and `$0` of own contributions;
the spouse has the same defaults. Its contexts are the fields of `Case` below. -/

/-- The contexts of the Catala test helper `Case`, with its defaults. -/
structure Case where
  isMfj : Bool := false
  isMarried : Bool := false
  pAge55 : Bool := false
  sAge55 : Bool := false
  pClaimed : Bool := false
  pW2 : Int := 0
  sW2 : Int := 0
  pMade : Bool := true
  sMade : Bool := true
  pTy : Int := 0
  pTy1 : Int := 0
  sTy : Int := 0
  sTy1 : Int := 0
  pType : TypeOfHdhp := .selfOnly
  sType : TypeOfHdhp := .selfOnly
  pMedicare : MedicareEnrollment := .medicareNoneOfYear
  hasMsa : Bool := false
  nonW2Activity : Bool := true
  pActivity : Bool := true
  sActivity : Bool := true
  dists : List HsaDistribution := []

/-- One filer's answers in `Case`. -/
def Case.answersOf (pMade sMade : Bool) (medicare : MedicareEnrollment) (type : TypeOfHdhp)
    (ty ty1 : Int) : HsaFilerAnswers :=
  { writablePrimaryFilerHasMadeContributionsToHsa := pMade
    writableSecondaryFilerHasMadeContributionsToHsa := sMade
    enrolledInMedicare := medicare, hsaHdhpCoverageStatus := .hdhpAllYear, typeOfHdhp := type
    hadOtherCoverageIneligibleForHsa := .otherCoverageNoneOfYear
    writableMfsLine6Check := false
    writableChangeInMaritalStatusDuringTaxYear := .wasNotMarriedNorDivorcedThisYear
    writableMaritalChangeAffectContributionLimitBool := false
    hasMadeQualifiedHsaFundingDistribution := false
    writableHsaNonemployerContributionsTaxYear := ty
    writableHsaNonemployerContributionsTaxYearPlusOne := ty1 }

/-- The `Hsa` inputs `Case` builds. -/
def Case.input (c : Case) : HsaIn :=
  { isFilingStatusMfj := c.isMfj, isMarried := c.isMarried, isSingle := !c.isMarried
    primaryFilerAge55OrOlder := c.pAge55, secondaryFilerAge55OrOlder := c.sAge55
    primaryFilerCanBeClaimed := c.pClaimed, secondaryFilerCanBeClaimed := false
    primaryFilerTotalHsaContributionsFromW2s := c.pW2
    secondaryFilerTotalHsaContributionsFromW2s := c.sW2
    hasPrimaryFilerHsaContributionsFromW2s := decide (c.pW2 > 0)
    hasSecondaryFilerHsaContributionsFromW2s := decide (c.sW2 > 0)
    knockoutHasNoPaymentsOrCredits := false, paidEstimatedTaxesOrFromLastYear := false
    taxExemptInterest := 0, pensionsAndAnnuities := 0, socialSecurityBenefits := 0
    primaryFiler := Case.answersOf c.pMade false c.pMedicare c.pType c.pTy c.pTy1
    secondaryFiler := Case.answersOf false c.sMade .medicareNoneOfYear c.sType c.sTy c.sTy1
    someFilerHadNonW2HsaActivity := c.nonW2Activity
    writablePrimaryFilerHadNonW2HsaActivity := c.pActivity
    writableSecondaryFilerHadNonW2HsaActivity := c.sActivity
    hasHsaMedicalSavingsAccountType := c.hasMsa
    writableHasHsaExcessContributionsPreviousYear := false
    writableHasHsaWithdrawnExcessContributionsYesNo := false
    someFilersMadeTestingPeriodContribution := false
    someFilersHaveTestingPeriodAdditionalIncome := false
    hsaDistributions := c.dists }

/-- `Case` run through `hsa`. -/
def Case.run (c : Case) : HsaOut := hsa c.input
/-- The primary filer's form. -/
def Case.pForm (c : Case) : Form8889 := c.run.form8889 .primaryFiler
/-- The secondary filer's form. -/
def Case.sForm (c : Case) : Form8889 := c.run.form8889 .secondaryFiler
/-- The Catala `Case` output `ko_medicare`. -/
def Case.koMedicare (c : Case) : Bool := c.run.koHsaCoverageChanging || c.run.koEnrolledInMedicareAllYear

/-- A 1099-SA of the primary filer with `gross` and `expenses` and nothing else. -/
def normalDistribution (gross expenses : Int) : HsaDistribution :=
  { filer := .primaryFiler, writableDistributionsRolloverBool := false
    writableDistributionsRolloverAmount := 0, writableGrossDistribution := gross
    hasWithdrawnExcessContributions := false, writableWithdrawnExcessContributionsAmount := 0
    writableEarningsOnExcessContributions := 0, hsaDistributionCode := .normalDistribution
    writableFmvOnDateOfDeath := 0, writableQualifiedMedExpenses := expenses }

-- TestSelfOnly4000
private def t1 : Case := { pTy := 400_000 }
#guard t1.run.hsaTotalDeductibleAmount == 400_000
#guard t1.pForm.line1SelfOnly
#guard !t1.pForm.line1Family
#guard t1.pForm.line2 == 400_000
#guard t1.pForm.line3 == 415_000
#guard t1.pForm.line5 == 415_000
#guard t1.pForm.line6 == 415_000
#guard t1.pForm.line7 == 0
#guard t1.pForm.line8 == 415_000
#guard t1.pForm.line9 == 0
#guard t1.pForm.line11 == 0
#guard t1.pForm.line12 == 415_000
#guard t1.pForm.line13 == 400_000
#guard t1.pForm.line16 == 0
#guard !(t1.run.hasExcessHsaContributions .primaryFiler)
#guard !t1.run.koHsaContributionsOverLimit
#guard !t1.run.unsupported
#guard t1.sForm.line13 == 0
#guard !(t1.run.hsaTotalDeductibleAmount == 415_000)
#guard !(t1.run.hsaTotalDeductibleAmount == 399_900)
-- TestContributionsMadeNextYear
private def t2 : Case := { pTy := 300_000, pTy1 := 100_000 }
#guard t2.run.hsaTotalDeductibleAmount == 400_000
#guard t2.pForm.line2 == 400_000
-- TestSelfOnly5000
private def t3 : Case := { pTy := 500_000 }
#guard t3.run.hsaTotalDeductibleAmount == 415_000
#guard t3.pForm.line13 == 415_000
#guard t3.run.hasExcessHsaContributions .primaryFiler
#guard t3.run.hsaContributionLimitExceededAmount .primaryFiler == 85_000
#guard t3.run.koHsaContributionsOverLimit
#guard t3.run.unsupported
#guard !(t3.run.hsaTotalDeductibleAmount == 500_000)
-- TestAge55SelfOnly
private def t4 : Case := { pAge55 := true, pTy := 515_000 }
#guard t4.pForm.line3 == 515_000
#guard t4.pForm.line7 == 0
#guard t4.pForm.line8 == 515_000
#guard t4.run.hsaTotalDeductibleAmount == 515_000
#guard !t4.run.unsupported
-- TestFamily
private def t5 : Case := { pType := .family, pTy := 830_000 }
#guard t5.pForm.line1Family
#guard t5.pForm.line3 == 830_000
#guard t5.pForm.line8 == 830_000
#guard t5.run.hsaTotalDeductibleAmount == 830_000
#guard !t5.run.unsupported
-- TestEmployerAndPersonal
private def t6 : Case := { pW2 := 300_000, pTy := 400_000 }
#guard t6.pForm.line9 == 300_000
#guard t6.pForm.line11 == 300_000
#guard t6.pForm.line12 == 115_000
#guard t6.pForm.line13 == 115_000
#guard t6.run.hsaTotalDeductibleAmount == 115_000
#guard t6.run.hasExcessHsaContributions .primaryFiler
#guard t6.run.hsaContributionLimitExceededAmount .primaryFiler == 285_000
#guard t6.run.koHsaContributionsOverLimit
-- TestEmployerOnly
private def t7 : Case := { pW2 := 300_000, nonW2Activity := false }
#guard t7.run.hsaTotalDeductibleAmount == 0
#guard t7.pForm.line9 == 300_000
#guard t7.pForm.line12 == 115_000
#guard !t7.run.unsupported
-- TestMfjSeparateHsasFamily
private def t8 : Case := {
  isMfj := true, isMarried := true, pAge55 := true, sAge55 := true,
  pType := .family, sType := .family, pTy := 500_000, sTy := 500_000 }
#guard t8.pForm.line5 == 830_000
#guard t8.pForm.line6 == 415_000
#guard t8.pForm.line7 == 100_000
#guard t8.pForm.line8 == 515_000
#guard t8.sForm.line6 == 415_000
#guard t8.sForm.line8 == 515_000
#guard t8.run.hsaTotalDeductibleAmount == 1_000_000
#guard !t8.run.unsupported
-- TestMfjEqualDivision (DF-BUG(7) candidate: equal division, IRC 223(b)(5)(B)(ii))
private def t9 : Case := {
  isMfj := true, isMarried := true, pType := .family, sType := .family,
  pTy := 600_000, sTy := 100_000 }
#guard t9.pForm.line6 == 415_000
#guard t9.pForm.line13 == 415_000
#guard t9.sForm.line13 == 100_000
#guard t9.run.hsaTotalDeductibleAmount == 515_000
#guard t9.run.hasExcessHsaContributions .primaryFiler
#guard t9.run.koHsaContributionsOverLimit
#guard t9.run.unsupported
-- TestMfjOneHsa
private def t10 : Case := {
  isMfj := true, isMarried := true, pType := .family, pTy := 830_000,
  sMade := false, sActivity := false }
#guard t10.pForm.line6 == 830_000
#guard t10.run.hsaTotalDeductibleAmount == 830_000
#guard t10.sForm.line13 == 0
#guard !t10.run.unsupported
-- TestKnockouts
private def ka : Case := { pTy := 100_000, pMedicare := .medicareAllYear }
#guard ka.koMedicare
#guard ka.run.unsupported
private def kb : Case := { pTy := 100_000, pClaimed := true }
#guard kb.run.koFilerIsDependentAndContributesToHsa
#guard kb.run.unsupported
private def kd : Case := { pTy := 100_000, hasMsa := true }
#guard kd.run.koHsaMedicalSavingsAccountType
#guard kd.run.unsupported
private def ke : Case := { pTy := 100_000 }
#guard !ke.koMedicare
#guard !ke.run.koFilerIsDependentAndContributesToHsa
#guard !ke.run.koHsaMedicalSavingsAccountType
#guard !ke.run.unsupported
-- TestNoActivity
private def t11 : Case := { nonW2Activity := false }
#guard t11.run.hsaTotalDeductibleAmount == 0
#guard t11.pForm.line3 == 0
#guard !t11.run.unsupported
-- TestDistributions
private def da : Case := {
  pTy := 69_000, pTy1 := 8_000, pW2 := 26_000,
  dists := [normalDistribution 90_000 90_000] }
#guard da.run.hsaTotalDeductibleAmount == 77_000
#guard da.pForm.line14a == 90_000
#guard da.pForm.line14b == 0
#guard da.pForm.line14c == 90_000
#guard da.pForm.line15 == 90_000
#guard da.pForm.line16 == 0
#guard !da.run.koHsaUnqualifiedDistributions
#guard !da.run.unsupported
private def db : Case := { pTy := 69_000, dists := [normalDistribution 100_000 90_000] }
#guard db.run.koHsaUnqualifiedDistributions
#guard db.run.unsupported

end UsTax.Hsa
