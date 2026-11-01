/**
 * What the project can honestly claim, in one place, for the home page and /trust.
 * Sources: docs/spec-surface.md (theorems, comparator set), docs/audit.md (axiom audit),
 * lean/README.md (tests, trusted layers), lean/UsTax/Api/Bridge.lean (`unwiredSections`).
 * Keep every sentence within what those files say. Never claim the Catala-to-Lean link is proved.
 */

export type ClaimStatus = 'proven' | 'tested';

export interface Claim {
  /** Short statement of the fact. */
  title: string;
  /** One or two plain sentences on exactly what it covers. */
  detail: string;
  status: ClaimStatus;
  /** Lean theorem names (namespace `UsTax.Main` unless qualified), or the test that backs it. */
  evidence: string[];
}

/** The compact status list on the home page. */
export const STATUS_CLAIMS: Claim[] = [
  {
    title: 'Tax Table: proven equal to the printed IRS table',
    detail: 'All 2,062 rows, for every cent of taxable income below $100,000 and every filing status. From $100,000 up, proven equal to the Tax Computation Worksheet.',
    status: 'proven',
    evidence: ['line16_matches_tax_table', 'line16_matches_worksheet'],
  },
  {
    title: 'Refund or amount owed = payments − tax',
    detail: 'Exactly one of the two is nonzero, neither is negative, and the difference is payments minus total tax.',
    status: 'proven',
    evidence: ['refund_balanceDue_consistent'],
  },
  {
    title: 'Credits never exceed the tax they offset',
    detail: 'Tax after credits is max(0, tax − credits); total tax is never negative.',
    status: 'proven',
    evidence: ['credits_within_liability', 'totalTax_nonneg'],
  },
  {
    title: 'Checked against 157 IRS Direct File scenarios',
    detail: 'Differential testing against the Direct File engine and the Catala specification, not a proof.',
    status: 'tested',
    evidence: ['difftest/'],
  },
];

/** Main theorems, as listed in lean/comparator.json and docs/spec-surface.md. */
export const THEOREMS: { name: string; states: string; scope: string }[] = [
  {
    name: 'line16_matches_tax_table',
    states: 'Form 1040 line 16 equals the amount printed in the 2024 Tax Table row that contains line 15, in the filer’s column.',
    scope: 'Every return. The table covers taxable income below $100,000.',
  },
  {
    name: 'tentativeTax_matches_tax_table',
    states: 'The same for the tax function on its own, for every filing status and every income.',
    scope: 'Below $100,000 (2,062 rows, shown to tile $0 to $100,000 with no gap).',
  },
  {
    name: 'line16_matches_worksheet',
    states: 'From $100,000 of taxable income, line 16 equals the 2024 Tax Computation Worksheet in the Form 1040 instructions.',
    scope: 'Every return with line 15 from $100,000 to $1 trillion.',
  },
  {
    name: 'tentativeTax_matches_worksheet',
    states: 'The same for the tax function on its own, for every filing status.',
    scope: 'Taxable income from $100,000 to $1 trillion.',
  },
  {
    name: 'tentativeTax_nonneg_monotone',
    states: 'Tax on taxable income is never negative and never decreases when income rises.',
    scope: 'Every filing status, every income.',
  },
  {
    name: 'refund_balanceDue_consistent',
    states: 'Line 34 (refund) and line 37 (amount owed) are both nonnegative, at most one is nonzero, and refund − owed = payments − tax.',
    scope: 'Every return.',
  },
  {
    name: 'credits_within_liability',
    states: 'Line 22 equals max(0, line 18 − line 21): credits can reduce tax to zero but never below.',
    scope: 'Every return.',
  },
  {
    name: 'totalTax_nonneg',
    states: 'Line 24 (total tax) is never negative.',
    scope: 'Every return.',
  },
];

/** Proved outside the comparator set (lean/README.md). */
export const OTHER_PROOFS: { name: string; states: string }[] = [
  {
    name: 'TaxRates.tentativeTaxFor_eq_taxSpec',
    states: 'Line 16 equals the 2024 rate schedules as printed (up to $1 trillion).',
  },
  {
    name: 'Api.parseRequest_sound',
    states: 'Every request the server accepts satisfies the written input specification (Request.Valid).',
  },
];

export const TESTED: string[] = [
  'The Lean calculator is compared, line by line, with the Catala encoding of the law and with the IRS Direct File engine on its 161 test scenarios (157 that Direct File does not knock out).',
  'Line 16 is compared with the Catala rate schedules on 2,402 incomes for each filing status (36,030 checks).',
  'Each of the 2,062 Tax Table rows is checked at its lowest dollar and highest cent in all four columns (16,496 checks).',
  'The server’s request validator is compared with the JSON schema on every example, fixture and about 900 generated variants.',
];

export const TRUSTED: { what: string; why: string }[] = [
  {
    what: 'The theorem statements and the definitions they mention',
    why: 'A proof shows the statement holds; a person has to read the statement to know it is the right one (docs/spec-surface.md).',
  },
  {
    what: 'The Catala encoding of the law, and its link to the Lean code',
    why: 'The Lean calculator is written by hand from the Catala specification. They are linked by differential testing, not by proof.',
  },
  {
    what: 'The Tax Table data',
    why: 'The 2,062 rows were transcribed from the printed IRS table into a CSV. A wrong row would make the Tax Table theorem say something wrong.',
  },
  {
    what: 'The Lean kernel, compiler and runtime',
    why: 'The kernel checks the proofs. The server runs compiled Lean code, so the compiler, the C toolchain and the HTTP library are trusted too.',
  },
  {
    what: 'Three standard axioms',
    why: 'The proofs use only propext, Classical.choice and Quot.sound. The audit (make audit) and lake comparator reject sorry, native_decide and any other axiom.',
  },
  {
    what: 'This web page',
    why: 'The browser code that collects your answers, builds the request and formats the numbers is tested, not proved.',
  },
];

export const NOT_COVERED: string[] = [
  'Only 2024 federal income tax (Form 1040). No state tax, no filing.',
  'The result uses W-2 wages and withholding, bank interest (1099-INT), the standard deduction, and the age, blindness and dependent rules for it.',
  'Unemployment (1099-G), retirement (1099-R) and Social Security (SSA-1099) forms, teacher expenses, student loan interest and estimated payments are accepted but not yet counted. The result says so when it happens.',
  'Dependents and the credits that depend on them (child tax credit, earned income credit, child care) are not in the result.',
  'Proofs cover the properties above, not every line. Other lines are checked by testing. Above $1 trillion of taxable income the calculator is not specified.',
];
