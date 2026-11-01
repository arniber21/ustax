import { z } from 'zod';
import type { FilingStatus } from '../api';
import { BOX12_CODES, CODES_1099R, LIMITS, RELATIONSHIPS } from '../draft';

/**
 * zod schema for the wizard draft: the contract's (api/schema.json) hard constraints, checked as
 * soon as a field is left rather than only when Next is pressed. It covers what the contract
 * enforces on values (money caps, enums, list lengths); "required" and cross-field rules stay in
 * `draft/validate.ts`, which also drives the error summary. Messages match validate.ts word for word.
 * `forms.test.ts` fails if a constant here drifts from api/schema.json.
 */

export const TOO_BIG = 'That number is too big. Check the digits and try again.';

export const FILING_STATUSES = [
  'Single',
  'MarriedFilingJointly',
  'MarriedFilingSeparately',
  'HeadOfHousehold',
  'QualifyingSurvivingSpouse',
] as const satisfies readonly FilingStatus[];

/** `NonNegMoney` (and signed `Money` with `signed`), in integer cents; null while the box is empty. */
export const moneySchema = (signed = false) =>
  z
    .number()
    .int()
    .refine((v) => (signed ? Math.abs(v) : v) <= LIMITS.maxCents, TOO_BIG)
    .refine((v) => signed || v >= 0, 'This can’t be negative.')
    .nullable();

const money = moneySchema();
const role = z.enum(['PrimaryFiler', 'SecondaryFiler']);
const enumOrEmpty = <T extends string>(values: readonly [T, ...T[]]) => z.union([z.literal(''), z.enum(values)]);
const codes = <T extends { code: string }>(xs: readonly T[]) => xs.map((x) => x.code) as [string, ...string[]];

const hsaFiler = z.looseObject({
  coverage: enumOrEmpty(['HdhpAllYear', 'HdhpPartOfYear', 'HdhpNoneOfYear']),
  type: enumOrEmpty(['SelfOnly', 'Family', 'BothSelfAndFamily']),
  medicare: enumOrEmpty(['MedicareAllYear', 'MedicarePartOfYear', 'MedicareNoneOfYear']),
  directContributions: money,
});

const filer = z.looseObject({
  citizenship: z.enum(['citizen', 'resident', 'other']),
  hsa: hsaFiler,
});

const dependent = z.looseObject({
  relationship: enumOrEmpty(RELATIONSHIPS.map((r) => r.value) as [string, ...string[]]),
  residency: z.enum(['AllYear', 'SixToElevenMonths', 'LessThanSixMonths']),
  months: z.number().int().min(6).max(11).nullable(),
  tinType: z.enum(['Ssn', 'Itin', 'Atin', 'NoTin']),
  citizenship: z.enum(['citizen', 'resident', 'national', 'canadaMexico', 'other']),
  grossIncome: money,
  careExpenses: money,
});

const w2 = z.looseObject({
  filer: role,
  wages: money,
  withholding: money,
  ssWages: money,
  ssTax: money,
  medicareWages: money,
  medicareTax: money,
  allocatedTips: money,
  dependentCare: money,
  nonQualified: money,
  box12: z.array(z.looseObject({ code: z.union([z.literal(''), z.enum(codes(BOX12_CODES))]), amount: money })),
});

const interest = z.looseObject({
  filer: role,
  interest: money,
  earlyWithdrawalPenalty: money,
  governmentBondInterest: money,
  withheld: money,
  foreignTax: money,
  taxExempt: money,
  privateActivityBond: money,
});

const retirement = z.looseObject({
  filer: role,
  codes: z.array(z.enum(codes(CODES_1099R))).max(LIMITS.maxCodes1099R, `Box 7 holds at most ${LIMITS.maxCodes1099R} codes.`),
  gross: money,
  taxable: money,
  withheld: money,
});

const list = <T extends z.ZodType>(item: T, max: number, noun: string) => z.array(item).max(max, `We can take up to ${max} ${noun}.`);

export const draftSchema = z.looseObject({
  version: z.literal(1),
  filingStatus: z.enum(FILING_STATUSES).nullable(),
  primary: filer,
  spouse: filer,
  maritalStatus: enumOrEmpty(['NeverMarried', 'Married', 'Divorced', 'Widowed']),
  yearOfSpouseDeath: enumOrEmpty(['DiedInTaxYear', 'DiedTaxYearMinusOne', 'DiedTaxYearMinusTwo', 'DiedBeforeTaxYearMinusTwo']),
  spouseLivedTogether: enumOrEmpty(['LivedApartAllYear', 'LivedTogetherSixMonthsOrLess', 'LivedTogetherMoreThanSixMonths']),
  dependents: list(dependent, LIMITS.maxDependents, 'people'),
  cdcc: z.looseObject({ totalQualified: money }),
  w2s: list(w2, LIMITS.maxItems, 'W-2s'),
  interest: list(interest, LIMITS.maxItems, '1099-INTs'),
  unemployment: list(z.looseObject({ filer: role, amount: money, withheld: money }), LIMITS.maxItems, '1099-Gs'),
  retirement: list(retirement, LIMITS.maxItems, '1099-Rs'),
  ssa: list(z.looseObject({ netBenefits: moneySchema(true) }), LIMITS.maxSsaForms, 'Social Security statements'),
  educator: z.looseObject({ primaryExpenses: money, spouseExpenses: money }),
  studentLoan: z.looseObject({ interest: money }),
  estimated: z.looseObject({ amount: money }),
});

export type DraftFormValues = z.input<typeof draftSchema>;
