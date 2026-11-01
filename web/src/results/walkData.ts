import { formatCents, type FilingStatus, type Lines } from '../api';

/** One row of the walk through Form 1040. `key` is the API `lines` key (api/line-catalog.json). */
export interface WalkLine {
  key: string;
  /** Printed on the form, e.g. "Line 11". */
  line: string;
  /** Plain English. */
  label: string;
  /** "How did we get this?" text, for the lines people ask about. */
  explain?: (ctx: ExplainContext) => string;
}

export interface WalkGroup {
  id: string;
  title: string;
  blurb: string;
  lines: WalkLine[];
}

export interface ExplainContext {
  lines: Lines;
  filingStatus?: FilingStatus;
}

const $ = (c: number) => formatCents(c, { showCents: false });

const STATUS_WORDS: Record<FilingStatus, string> = {
  Single: 'single',
  MarriedFilingJointly: 'married filing jointly',
  MarriedFilingSeparately: 'married filing separately',
  HeadOfHousehold: 'head of household',
  QualifyingSurvivingSpouse: 'qualifying surviving spouse',
};

/** The order and wording of the walk. Every catalog key appears exactly once (see lineWalk.test.ts). */
export const WALK: WalkGroup[] = [
  {
    id: 'income',
    title: 'Income',
    blurb: 'Everything that counts as income this year.',
    lines: [
      { key: 'wages', line: '1a', label: 'Wages (W-2 box 1)' },
      { key: 'employer_income_subtotal', line: '1z', label: 'Total wages and other employee income' },
      { key: 'interest_income', line: '2b', label: 'Taxable interest' },
      {
        key: 'total_income',
        line: '9',
        label: 'Total income',
        explain: ({ lines }) =>
          `We added your job pay (${$(lines.employer_income_subtotal)}) and bank interest (${$(lines.interest_income)}). That makes ${$(lines.total_income)}.`,
      },
    ],
  },
  {
    id: 'adjustments',
    title: 'Adjustments',
    blurb: 'A few costs the IRS lets you take off the top.',
    lines: [
      { key: 'adjustments_to_income', line: '10', label: 'Adjustments to income' },
      {
        key: 'agi',
        line: '11',
        label: 'Adjusted gross income (AGI)',
        explain: ({ lines }) =>
          `AGI is your total income (${$(lines.total_income)}) minus your adjustments (${$(lines.adjustments_to_income)}), which leaves ${$(lines.agi)}. Many other tax rules look at this number, so it comes up a lot.`,
      },
    ],
  },
  {
    id: 'deductions',
    title: 'Deductions',
    blurb: 'An amount the IRS lets you skip paying tax on.',
    lines: [
      {
        key: 'standard_or_itemized_deductions',
        line: '12',
        label: 'Standard deduction',
        explain: ({ lines, filingStatus }) =>
          `Everyone gets a flat deduction so they don’t have to list every expense. ${
            filingStatus ? `For someone filing as ${STATUS_WORDS[filingStatus]} in 2024 it is ` : 'For your filing status in 2024 it is '
          }${$(lines.standard_or_itemized_deductions)}.`,
      },
      { key: 'total_deductions', line: '14', label: 'Total deductions' },
      {
        key: 'taxable_income',
        line: '15',
        label: 'Taxable income',
        explain: ({ lines }) =>
          `Your AGI (${$(lines.agi)}) minus your deductions (${$(lines.total_deductions)}) leaves ${$(lines.taxable_income)}. This is the only part of your income that actually gets taxed.${
            lines.taxable_income === 0 ? ' Your deductions covered all of it, so there is no income tax.' : ''
          }`,
      },
    ],
  },
  {
    id: 'tax',
    title: 'Tax',
    blurb: 'What the tax rules say that income costs.',
    lines: [
      {
        key: 'tentative_tax_from_taxable_income',
        line: '16',
        label: 'Tax on taxable income',
        explain: ({ lines }) =>
          `We looked up ${$(lines.taxable_income)} in the IRS’s 2024 tax tables for your filing status. The rate climbs in steps, so the first slice of income is taxed lightly and only the top slice at the highest rate. The result is ${$(lines.tentative_tax_from_taxable_income)}.`,
      },
      { key: 'total_tentative_tax', line: '18', label: 'Tax before credits (lines 16 and 17)' },
    ],
  },
  {
    id: 'credits',
    title: 'Credits',
    blurb: 'Credits take money straight off your tax bill.',
    lines: [
      { key: 'non_refundable_credits', line: '21', label: 'Nonrefundable credits' },
      { key: 'tax_less_non_refundable_credits', line: '22', label: 'Tax after credits' },
      {
        key: 'total_tax',
        line: '24',
        label: 'Total tax',
        explain: ({ lines }) =>
          `Tax before credits (${$(lines.total_tentative_tax)}) minus credits (${$(lines.non_refundable_credits)}) gives ${$(lines.total_tax)}. That is what you owe the IRS for the year, before counting anything you already paid.`,
      },
    ],
  },
  {
    id: 'payments',
    title: 'Payments',
    blurb: 'Money sent to the IRS on your behalf during the year.',
    lines: [
      { key: 'total_withholding', line: '25d', label: 'Federal income tax withheld' },
      { key: 'total_other_payments_refundable_credits', line: '32', label: 'Other payments and refundable credits' },
      { key: 'total_payments', line: '33', label: 'Total payments' },
    ],
  },
  {
    id: 'result',
    title: 'Refund or amount owed',
    blurb: 'Paid in versus tax owed.',
    lines: [
      { key: 'overpayment', line: '34', label: 'Overpayment (refund)' },
      { key: 'balance_due', line: '37', label: 'Amount you owe' },
    ],
  },
];
