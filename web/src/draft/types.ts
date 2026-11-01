import type { Dependent, FilingStatus } from '../api';

/** Integer cents, or null while the field is empty. Never a float. */
export type Cents = number | null;

export type Role = 'PrimaryFiler' | 'SecondaryFiler';

/** Hard limits copied from api/schema.json (kept in one place so forms and validation agree). */
export const LIMITS = {
  maxItems: 20,
  maxSsaForms: 4,
  maxCodes1099R: 4,
  /** 20 dependents, like every other list in the contract. */
  maxDependents: 20,
  /** The tax year the contract supports; dates of birth cannot be later. */
  lastDayOfTaxYear: '2024-12-31',
  /** |value| <= 10^13 cents. */
  maxCents: 10_000_000_000_000,
} as const;

/** How a filer or dependent is a US citizen or resident. `citizen` is the contract default (nothing is sent). */
export type Citizenship = 'citizen' | 'resident' | 'national' | 'canadaMexico' | 'other';

/** What we ask about each filer (you, and your spouse on a joint return). */
export interface FlagsDraft {
  blind: boolean;
  /** Only used while `dob` is empty: the API replaces it with the date of birth when one is given. */
  age65: boolean;
  canBeClaimed: boolean;
  /** ISO date `YYYY-MM-DD`, or '' while empty. */
  dob: string;
  /** `citizen`, `resident` (noncitizen resident for the whole year) or `other`. */
  citizenship: Extract<Citizenship, 'citizen' | 'resident' | 'other'>;
  /** Has a Social Security number (the contract default is yes). */
  hasSsn: boolean;
  /** Full-time student (Saver's credit). */
  student: boolean;
  /** Retired on permanent and total disability (Schedule R). */
  retiredOnDisability: boolean;
  /** HSA answers for Form 8889, only used when `Draft.hsa.has` is true. */
  hsa: HsaFilerDraft;
}

export type HdhpCoverage = 'HdhpAllYear' | 'HdhpPartOfYear' | 'HdhpNoneOfYear';
export type HdhpType = 'SelfOnly' | 'Family' | 'BothSelfAndFamily';
export type MedicareStatus = 'MedicareAllYear' | 'MedicarePartOfYear' | 'MedicareNoneOfYear';

export interface HsaFilerDraft {
  /** Put money into an HSA outside the paycheck (or has one). */
  contributed: boolean;
  coverage: HdhpCoverage | '';
  type: HdhpType | '';
  medicare: MedicareStatus | '';
  /** Contributions made directly (not through an employer) for 2024. */
  directContributions: Cents;
}

export const newHsaFiler = (): HsaFilerDraft => ({ contributed: false, coverage: '', type: '', medicare: '', directContributions: null });

export type Relationship = NonNullable<Dependent['relationship']>;
export type ResidencyDuration = 'AllYear' | 'SixToElevenMonths' | 'LessThanSixMonths';
export type TinType = 'Ssn' | 'Itin' | 'Atin' | 'NoTin';

export interface DependentDraft {
  id: string;
  /** To tell people apart on screen. Never sent: the contract takes no names. */
  name: string;
  relationship: Relationship | '';
  dob: string;
  residency: ResidencyDuration;
  /** 6 to 11, only while `residency` is `SixToElevenMonths`. */
  months: number | null;
  tinType: TinType;
  citizenship: Citizenship;
  student: boolean;
  disabled: boolean;
  /** This person paid for over half of their own support. */
  ownSupport: boolean;
  /** You paid for over half of this person's support (qualifying relative test). */
  youSupport: boolean;
  /** Someone else could claim this person as a qualifying child. */
  claimableByOther: boolean;
  married: boolean;
  jointReturn: boolean;
  grossIncome: Cents;
  /** You choose to claim this person (the contract default is yes). */
  claim: boolean;
  /** Child and dependent care (Form 2441). */
  unableToSelfCare: boolean;
  careExpenses: Cents;
  /** Null until answered; only asked when `careExpenses` has an amount. */
  careProviderQualifies: boolean | null;
}

export interface Box12Row {
  id: string;
  /** Letter code from the schema (`W2Box12` keys), '' until picked. */
  code: string;
  amount: Cents;
}

export interface W2Draft {
  id: string;
  filer: Role;
  wages: Cents; // box 1
  withholding: Cents; // box 2
  ssWages: Cents; // box 3
  ssTax: Cents; // box 4
  medicareWages: Cents; // box 5
  medicareTax: Cents; // box 6
  allocatedTips: Cents; // box 8
  dependentCare: Cents; // box 10
  nonQualified: Cents; // box 11
  box12: Box12Row[];
  statutoryEmployee: boolean; // box 13
  thirdPartySickPay: boolean; // box 13
  plan457bGovernmental: boolean; // 457(b) plan is a government plan
}

export interface InterestDraft {
  id: string;
  filer: Role;
  interest: Cents; // box 1
  earlyWithdrawalPenalty: Cents; // box 2
  governmentBondInterest: Cents; // box 3
  withheld: Cents; // box 4
  foreignTax: Cents; // box 6
  taxExempt: Cents; // box 8
  privateActivityBond: Cents; // box 9
}

export interface UnemploymentDraft {
  id: string;
  filer: Role;
  amount: Cents; // box 1
  withheld: Cents; // box 4
}

export interface RetirementDraft {
  id: string;
  filer: Role;
  codes: string[]; // box 7
  gross: Cents; // box 1
  taxable: Cents; // box 2a
  taxableBlank: boolean; // box 2a left empty by the payer
  withheld: Cents; // box 4
  iraSepSimple: boolean; // box 7 IRA/SEP/SIMPLE checkbox
  totalDistribution: boolean; // box 2b
}

export interface SsaDraft {
  id: string;
  /** Box 5, may be negative. */
  netBenefits: Cents;
  /** Box 6: federal income tax withheld. */
  withheld: Cents;
}

export interface Draft {
  /** Bumped when the stored shape changes; old drafts are dropped. */
  version: 1;
  filingStatus: FilingStatus | null;
  primary: FlagsDraft;
  spouse: FlagsDraft;
  spouseDiedThisYear: boolean;
  deceasedSpouseWas65: boolean;
  mfsSpouse65: boolean;
  foreignAccounts: boolean;
  /** The gate on the dependents step: nothing in `dependents` is sent while this is false. */
  hasDependents: boolean;
  dependents: DependentDraft[];
  /** `filing_answers`: '' means "not asked, the server derives it from the filing status". */
  maritalStatus: '' | 'NeverMarried' | 'Married' | 'Divorced' | 'Widowed';
  yearOfSpouseDeath: '' | 'DiedInTaxYear' | 'DiedTaxYearMinusOne' | 'DiedTaxYearMinusTwo' | 'DiedBeforeTaxYearMinusTwo';
  spouseLivedTogether: '' | 'LivedApartAllYear' | 'LivedTogetherSixMonthsOrLess' | 'LivedTogetherMoreThanSixMonths';
  /** Head of household: you paid over half the cost of keeping up the home. Sent on each dependent. */
  paidHomeUpkeep: boolean;
  /** `screening`: the yes answers only. */
  screening: { digitalReceived: boolean; digitalDisposed: boolean; iraContributions: boolean; foreignTrustGrantor: boolean };
  /** `credits`. */
  credits: { eitcImproperClaims: boolean; ctcImproperClaims: boolean; eitcQcOfAnother: boolean };
  /** `cdcc`: Form 2441. Per-person amounts live on each dependent. */
  cdcc: { paid: boolean; totalQualified: Cents };
  /** `adjustments.hsa`: per-filer answers live on `primary.hsa` and `spouse.hsa`. */
  hsa: { has: boolean };
  /** Explicit answers: null until the user confirms these unsupported situations. */
  healthScreening: { marketplace: boolean | null; hsaWithdrawals: boolean | null };
  w2s: W2Draft[];
  interest: InterestDraft[];
  unemployment: UnemploymentDraft[];
  retirement: RetirementDraft[];
  ssa: SsaDraft[];
  livedApartAllYear: boolean;
  educator: { primary: boolean; spouse: boolean; primaryExpenses: Cents; spouseExpenses: Cents };
  studentLoan: { hadPayments: boolean; loansQualify: boolean; interest: Cents };
  estimated: { paid: boolean; amount: Cents; differentName: boolean };
}

export const emptyFlags = (): FlagsDraft => ({
  blind: false, age65: false, canBeClaimed: false, dob: '', citizenship: 'citizen', hasSsn: true, student: false,
  retiredOnDisability: false, hsa: newHsaFiler(),
});
const flags = emptyFlags;

export const emptyDraft = (): Draft => ({
  version: 1,
  filingStatus: null,
  primary: flags(),
  spouse: flags(),
  spouseDiedThisYear: false,
  deceasedSpouseWas65: false,
  mfsSpouse65: false,
  foreignAccounts: false,
  hasDependents: false,
  dependents: [],
  maritalStatus: '',
  yearOfSpouseDeath: '',
  spouseLivedTogether: '',
  paidHomeUpkeep: false,
  screening: { digitalReceived: false, digitalDisposed: false, iraContributions: false, foreignTrustGrantor: false },
  credits: { eitcImproperClaims: false, ctcImproperClaims: false, eitcQcOfAnother: false },
  cdcc: { paid: false, totalQualified: null },
  hsa: { has: false },
  healthScreening: { marketplace: null, hsaWithdrawals: null },
  w2s: [],
  interest: [],
  unemployment: [],
  retirement: [],
  ssa: [],
  livedApartAllYear: false,
  educator: { primary: false, spouse: false, primaryExpenses: null, spouseExpenses: null },
  studentLoan: { hadPayments: false, loansQualify: false, interest: null },
  estimated: { paid: false, amount: null, differentName: false },
});

let counter = 0;
/** Local list-item id (not sent to the API). */
export const newId = (): string => `i${Date.now().toString(36)}${(counter++).toString(36)}`;

export const newW2 = (filer: Role = 'PrimaryFiler'): W2Draft => ({
  id: newId(), filer, wages: null, withholding: null, ssWages: null, ssTax: null, medicareWages: null,
  medicareTax: null, allocatedTips: null, dependentCare: null, nonQualified: null, box12: [],
  statutoryEmployee: false, thirdPartySickPay: false, plan457bGovernmental: false,
});
export const newInterest = (filer: Role = 'PrimaryFiler'): InterestDraft => ({
  id: newId(), filer, interest: null, earlyWithdrawalPenalty: null, governmentBondInterest: null,
  withheld: null, foreignTax: null, taxExempt: null, privateActivityBond: null,
});
export const newUnemployment = (filer: Role = 'PrimaryFiler'): UnemploymentDraft => ({
  id: newId(), filer, amount: null, withheld: null,
});
export const newRetirement = (filer: Role = 'PrimaryFiler'): RetirementDraft => ({
  id: newId(), filer, codes: [], gross: null, taxable: null, taxableBlank: false, withheld: null,
  iraSepSimple: false, totalDistribution: false,
});
export const newDependent = (): DependentDraft => ({
  id: newId(), name: '', relationship: '', dob: '', residency: 'AllYear', months: null, tinType: 'Ssn',
  citizenship: 'citizen', student: false, disabled: false, ownSupport: false, youSupport: false,
  claimableByOther: false, married: false, jointReturn: false, grossIncome: null, claim: true,
  unableToSelfCare: false, careExpenses: null, careProviderQualifies: null,
});
export const newSsa = (): SsaDraft => ({ id: newId(), netBenefits: null, withheld: null });

export const isJoint = (d: Pick<Draft, 'filingStatus'>): boolean => d.filingStatus === 'MarriedFilingJointly';

/** W-2 box 12 codes the schema accepts, with a plain-language meaning for the picker. */
export const BOX12_CODES: readonly { code: string; label: string }[] = [
  { code: 'A', label: 'Uncollected Social Security tax on tips' },
  { code: 'B', label: 'Uncollected Medicare tax on tips' },
  { code: 'C', label: 'Taxable cost of group-term life insurance over $50,000' },
  { code: 'D', label: '401(k) contributions' },
  { code: 'E', label: '403(b) contributions' },
  { code: 'F', label: 'SEP contributions' },
  { code: 'G', label: '457(b) contributions' },
  { code: 'H', label: '501(c)(18)(D) plan contributions' },
  { code: 'J', label: 'Nontaxable sick pay' },
  { code: 'K', label: '20% excise tax on excess golden parachute payments' },
  { code: 'L', label: 'Employee business expense reimbursements' },
  { code: 'M', label: 'Uncollected Social Security tax on group-term life insurance' },
  { code: 'N', label: 'Uncollected Medicare tax on group-term life insurance' },
  { code: 'P', label: 'Moving expense reimbursements (military)' },
  { code: 'Q', label: 'Nontaxable combat pay' },
  { code: 'R', label: 'Archer MSA employer contributions' },
  { code: 'S', label: 'SIMPLE retirement contributions' },
  { code: 'T', label: 'Adoption benefits' },
  { code: 'V', label: 'Income from exercising nonstatutory stock options' },
  { code: 'W', label: 'Employer contributions to your Health Savings Account' },
  { code: 'Y', label: '409A deferrals' },
  { code: 'Z', label: '409A income' },
  { code: 'AA', label: 'Roth 401(k) contributions' },
  { code: 'BB', label: 'Roth 403(b) contributions' },
  { code: 'DD', label: 'Cost of employer health coverage' },
  { code: 'EE', label: 'Roth 457(b) contributions' },
  { code: 'FF', label: 'Small employer health reimbursement arrangement' },
  { code: 'GG', label: 'Income from qualified equity grants' },
  { code: 'HH', label: 'Aggregate deferrals under section 83(i)' },
  { code: 'II', label: 'Medicaid waiver payments' },
];

/** Box 7 characters the schema accepts. Anything else is "Other". */
export const CODES_1099R: readonly { code: string; label: string }[] = [
  { code: '7', label: '7: Normal distribution (usually age 59½ or older)' },
  { code: '2', label: '2: Early distribution, an exception applies' },
  { code: '4', label: '4: Death benefit' },
  { code: 'B', label: 'B: Designated Roth account distribution' },
  { code: 'G', label: 'G: Direct rollover to another plan or IRA' },
  { code: 'H', label: 'H: Direct rollover of a Roth account' },
  { code: 'Other', label: 'Any other code (like 1, 3, 5, 8, D, L, P, Q, S, T)' },
];

/** `Dependent.relationship` values with plain-language labels, children first. */
export const RELATIONSHIPS: readonly { value: Relationship; label: string }[] = [
  { value: 'BiologicalChild', label: 'Son or daughter' },
  { value: 'AdoptedChild', label: 'Adopted child' },
  { value: 'StepChild', label: 'Stepchild' },
  { value: 'FosterChild', label: 'Foster child (placed with you by an agency or court)' },
  { value: 'GrandChildOrOtherDescendantOfChild', label: 'Grandchild or other descendant of your child' },
  { value: 'ChildInLaw', label: 'Son-in-law or daughter-in-law' },
  { value: 'Sibling', label: 'Brother or sister' },
  { value: 'HalfSibling', label: 'Half brother or half sister' },
  { value: 'StepSibling', label: 'Stepbrother or stepsister' },
  { value: 'ChildOfSibling', label: 'Niece or nephew' },
  { value: 'ChildOfHalfSibling', label: 'Child of your half sibling' },
  { value: 'ChildOfStepSibling', label: 'Child of your stepsibling' },
  { value: 'OtherDescendantOfSibling', label: 'Other descendant of your sibling' },
  { value: 'OtherDescendantOfHalfSibling', label: 'Other descendant of your half sibling' },
  { value: 'OtherDescendantOfStepSibling', label: 'Other descendant of your stepsibling' },
  { value: 'SiblingsSpouse', label: 'Sibling’s spouse' },
  { value: 'SiblingInLaw', label: 'Brother-in-law or sister-in-law' },
  { value: 'Parent', label: 'Parent' },
  { value: 'StepParent', label: 'Stepparent' },
  { value: 'FosterParent', label: 'Foster parent' },
  { value: 'ParentInLaw', label: 'Mother-in-law or father-in-law' },
  { value: 'GrandParent', label: 'Grandparent' },
  { value: 'OtherAncestorOfParent', label: 'Other ancestor of your parent' },
  { value: 'SiblingOfParent', label: 'Aunt or uncle' },
  { value: 'NoneOfTheAbove', label: 'None of these (another person you support)' },
];
