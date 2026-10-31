import type { FilingStatus } from '../api';

/** Integer cents, or null while the field is empty. Never a float. */
export type Cents = number | null;

export type Role = 'PrimaryFiler' | 'SecondaryFiler';

/** Hard limits copied from api/schema.json (kept in one place so forms and validation agree). */
export const LIMITS = {
  maxItems: 20,
  maxSsaForms: 4,
  maxCodes1099R: 4,
  /** |value| <= 10^13 cents. */
  maxCents: 10_000_000_000_000,
} as const;

export interface FlagsDraft {
  blind: boolean;
  age65: boolean;
  canBeClaimed: boolean;
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
  /** Not in the API yet: asked so we can warn that child-related credits are not included. */
  hasDependents: boolean;
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

const flags = (): FlagsDraft => ({ blind: false, age65: false, canBeClaimed: false });

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
  withheld: null, foreignTax: null, taxExempt: null,
});
export const newUnemployment = (filer: Role = 'PrimaryFiler'): UnemploymentDraft => ({
  id: newId(), filer, amount: null, withheld: null,
});
export const newRetirement = (filer: Role = 'PrimaryFiler'): RetirementDraft => ({
  id: newId(), filer, codes: [], gross: null, taxable: null, taxableBlank: false, withheld: null,
  iraSepSimple: false, totalDistribution: false,
});
export const newSsa = (): SsaDraft => ({ id: newId(), netBenefits: null });

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
