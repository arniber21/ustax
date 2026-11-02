/**
 * Everything /trust and the home-page verification panel say about verification, in ONE typed module.
 *
 * Sources, kept in step by `facts.test.ts` (which reads the repository files):
 *   - lean/comparator.json and lean/comparator.extra.json   the exact theorem lists (every name here must be
 *     in one of them, and every name in them must be here)
 *   - lean/UsTax/Comparator/Challenge.lean and Extra.lean   where each statement is written
 *   - docs/direct-file-bugs.md                              the bug counts
 *   - docs/spec-surface.md, docs/audit.md, docs/comparator.md, lean/README.md, README.md ("What you have to trust")
 *   - README.md                                             the test counts
 *
 * Rules for editing: never claim the Catala-to-Lean link is proved (it is tested); never state a count
 * without its date; say when a check is run by hand and not in CI.
 */

/** Date the counts below were last recorded (README.md). */
export const AS_OF = '2026-11-01';

export type ClaimStatus = 'proven' | 'tested';

/** One statement checked by `lake comparator`. */
export interface ProvedStatement {
  /** Fully qualified Lean name, exactly as in the comparator JSON. */
  name: string;
  /** What it says, in plain English. */
  says: string;
  /** For which inputs it holds (main list only). */
  holdsFor?: string;
}

export interface ProofSet {
  /** The config file Comparator reads (relative to the repository root). */
  config: string;
  /** Where the statements are written (the trusted file, `sorry` proofs by design). */
  statementsFile: string;
  /** Where they are proved. */
  proofsFile: string;
  /** The make target that runs it. */
  command: string;
  /** Whether CI runs it. */
  inCi: boolean;
  theorems: readonly ProvedStatement[];
}

/** The main theorems: lean/comparator.json, chosen by a human, reviewed in docs/spec-surface.md. */
export const MAIN: ProofSet = {
  config: 'lean/comparator.json',
  statementsFile: 'lean/UsTax/Comparator/Challenge.lean',
  proofsFile: 'lean/UsTax/Proofs/Main.lean',
  command: 'make comparator',
  inCi: true,
  theorems: [
    {
      name: 'UsTax.Main.line16_matches_tax_table',
      says: 'Form 1040 line 16 equals the amount printed in the 2024 Tax Table row that contains line 15, in the filer’s column.',
      holdsFor: 'Every return. The table covers taxable income below $100,000.',
    },
    {
      name: 'UsTax.Main.tentativeTax_matches_tax_table',
      says: 'The same for the tax function on its own, for every filing status and every income.',
      holdsFor: 'Below $100,000 (2,062 table rows that tile $0 to $100,000 with no gap).',
    },
    {
      name: 'UsTax.Main.line16_matches_worksheet',
      says: 'From $100,000 of taxable income, line 16 equals the 2024 Tax Computation Worksheet in the Form 1040 instructions.',
      holdsFor: 'Every return with line 15 from $100,000 to $1 trillion.',
    },
    {
      name: 'UsTax.Main.tentativeTax_matches_worksheet',
      says: 'The same for the tax function on its own, for every filing status.',
      holdsFor: 'Taxable income from $100,000 to $1 trillion.',
    },
    {
      name: 'UsTax.Main.tentativeTax_nonneg_monotone',
      says: 'Line 16 is never negative and never decreases as taxable income rises, with filing status fixed.',
      holdsFor: 'Every filing status, every income.',
    },
    {
      name: 'UsTax.Main.refund_balanceDue_consistent',
      says: 'Line 34 (refund) and line 37 (amount owed) are both nonnegative, at most one is nonzero, and refund minus owed equals payments minus tax.',
      holdsFor: 'Every return.',
    },
    {
      name: 'UsTax.Main.credits_within_liability',
      says: 'Line 22 equals max(0, line 18 − line 21): credits can reduce tax to zero but never below.',
      holdsFor: 'Every return.',
    },
    {
      name: 'UsTax.Main.totalTax_nonneg',
      says: 'Line 24 (total tax) is never negative.',
      holdsFor: 'Every return.',
    },
    {
      name: 'UsTax.Main.eitc_within_bounds',
      says: 'The earned income credit is between $0 and the maximum for the number of children, and is $0 once income reaches the completed phase-out.',
      holdsFor: 'Every input of the earned income credit table scope.',
    },
  ],
};

/** The additional statements: lean/comparator.extra.json. Module-versus-statute specs and whole-return properties. */
export const EXTRA: ProofSet = {
  config: 'lean/comparator.extra.json',
  statementsFile: 'lean/UsTax/Comparator/Extra.lean',
  proofsFile: 'lean/UsTax/Proofs/Extra.lean',
  command: 'make comparator-extra',
  inCi: false,
  theorems: [
    { name: 'UsTax.Extra.standardDeduction_eq_spec', says: 'Line 12 (standard deduction) is the amount in the statute (IRC 63(c)).' },
    { name: 'UsTax.Extra.additionalItems_range', says: 'The count of age and blindness items is between 0 and 4, and at most 2 without a spouse who counts.' },
    { name: 'UsTax.Extra.requiresScheduleB_eq_spec', says: 'Schedule B is required exactly as the instructions say.' },
    { name: 'UsTax.Extra.interestIncome_eq_spec', says: 'Line 2b (taxable interest) is the specified amount.' },
    { name: 'UsTax.Extra.wages_eq_spec', says: 'Line 1a is the total of W-2 box 1, each W-2 rounded to the dollar.' },
    { name: 'UsTax.Extra.formW2Withholding_eq_spec', says: 'Line 25a is the total of W-2 box 2, each W-2 rounded to the dollar.' },
    { name: 'UsTax.Extra.medicareKnockout_eq_spec', says: 'The Medicare knockout fires exactly when Form 8959 is needed.' },
    { name: 'UsTax.Extra.oasdiKnockout_eq_spec', says: 'The Social Security knockouts fire exactly when excess withholding is possible.' },
    { name: 'UsTax.Extra.line6b_eq_spec', says: 'Line 6b (taxable Social Security) is the amount in the statute (IRC 86).' },
    { name: 'UsTax.Extra.line6b_bounds', says: 'Line 6b is never negative and never more than 85% of line 6a.' },
    { name: 'UsTax.Extra.line6b_mono_otherIncome', says: 'More other income never lowers taxable Social Security.' },
    { name: 'UsTax.Extra.educatorAdjustment_eq_spec', says: 'The educator expense adjustment is the statutory amount (IRC 62(a)(2)(D)).' },
    { name: 'UsTax.Extra.educatorAdjustment_bounds', says: 'The educator adjustment is between $0 and $300 per educator, for nonnegative expenses.' },
    { name: 'UsTax.Extra.studentLoanAdjustment_eq_spec', says: 'The student loan interest adjustment is the statutory amount (IRC 221).' },
    { name: 'UsTax.Extra.studentLoanAdjustment_bounds', says: 'The student loan adjustment is between $0 and the lesser of the interest paid and $2,500.' },
    { name: 'UsTax.Extra.studentLoanAdjustment_zero_of_magi_ge_end', says: 'The student loan adjustment is $0 once income reaches the end of the phase-out.' },
    { name: 'UsTax.Extra.studentLoanAdjustment_antitone', says: 'More income never raises the student loan adjustment.' },
    { name: 'UsTax.Extra.estimatedPayments_eq_spec', says: 'Line 26 (estimated payments) is the payment in whole dollars, or $0.' },
    { name: 'UsTax.Extra.agi_eq', says: 'Line 11 (AGI) equals line 9 minus line 10.' },
    { name: 'UsTax.Extra.taxableIncome_eq', says: 'Line 15 (taxable income) equals max(0, line 11 − line 14).' },
    { name: 'UsTax.Extra.totalPayments_eq', says: 'Line 33 (total payments) equals lines 25d + 26 + 32, when line 26 is in whole dollars.' },
    { name: 'UsTax.Extra.totalPayments_eq_full', says: 'On the whole return, line 33 always equals lines 25d + 26 + 32.' },
    { name: 'UsTax.Extra.totalTax_mono_addW2', says: 'Adding a W-2 with nonnegative wages never lowers total tax (credits held fixed).' },
    { name: 'UsTax.Extra.calculator_refund_balanceDue_consistent', says: 'On the whole return, refund and amount owed are exclusive and consistent with payments minus tax.' },
    { name: 'UsTax.Extra.calculator_credits_within_liability', says: 'On the whole return, the nonrefundable credits used never exceed the tax they offset.' },
    { name: 'UsTax.Extra.calculator_totalTax_nonneg', says: 'On the whole return, total tax is never negative.' },
    { name: 'UsTax.Extra.calculator_credits_le_tax', says: 'The child care, elderly or disabled, and saver’s credits together never exceed the tax before credits.' },
    { name: 'UsTax.Extra.calculator_unsupported_iff', says: 'A return is marked unsupported exactly when at least one knockout reason fired.' },
    { name: 'UsTax.Extra.apiCalculator_supported_iff', says: 'The API answer says “not supported” exactly when its list of reasons is not empty.' },
    { name: 'UsTax.Extra.apiCalculator_outcome_refund_iff', says: 'The API answer’s outcome is “refund” exactly when line 34 is positive.' },
    { name: 'UsTax.Extra.calculateRequest_ne_fault', says: 'The pure calculator never returns its internal-inconsistency result on a valid request; HTTP/runtime failures are outside the theorem.' },
  ],
};

/** Proved and audited by `make audit`, but not in either Comparator list (docs/spec-surface.md, lean/README.md). */
export const OTHER_PROOFS: readonly { name: string; file: string; says: string }[] = [
  {
    name: 'UsTax.TaxRates.tentativeTaxFor_eq_taxSpec',
    file: 'lean/UsTax/TaxRates/Spec.lean',
    says: 'Line 16 equals the 2024 rate schedules as printed (up to $1 trillion).',
  },
  {
    name: 'UsTax.Api.parseRequest_sound',
    file: 'lean/UsTax/Api/Parse.lean',
    says: 'Every request the server accepts satisfies the written input specification.',
  },
];

/** The two checks, as the page words them. */
export const PROOF_CHECKS = {
  axioms: ['propext', 'Classical.choice', 'Quot.sound'],
  main: 'lake comparator replays the proofs through the Lean kernel and fails if a statement differs from the trusted statement file, or if a proof uses an axiom outside the allowed three.',
  note: 'Comparator needs Linux. CI runs it for the main list on every push. The additional list is run by hand with make comparator-extra, not in CI.',
} as const;

/** Differential-testing facts. Numbers from README.md, as of AS_OF. */
export const TESTED = {
  asOf: AS_OF,
  scenarios: { shipped: 161, runnable: 157, rejected: 4 },
  /** Catala whole-return calculator versus the Direct File engine. */
  calculator: { scenarios: 157, factChecks: 5360 },
  /** The same scope through the API request shape. */
  apiCalculator: { scenarios: 157, factChecks: 3105 },
  taxTable: { rows: 2062, checks: 16496 },
  rates: { incomesPerStatus: 2402, checks: 36030 },
  audit: { declarations: 7981, highSeverity: 0 },
  items: [
    'The Catala encoding of the law is compared with the IRS Direct File engine (its own compiled rules, run as an oracle). Direct File ships 161 test returns; its engine wrongly rejects 4 of them (DF-BUG-8), which leaves 157.',
    'On those 157 scenarios the calculator’s 5,360 fact checks agree between Catala and Direct File, and the API shape (3,105 checks) agrees too (re-run 2026-11-01).',
    'The Lean calculator is compared with Catala and Direct File the same way (make lean-difftest). This is how the Lean code is tied to the Catala rules: by testing, not by proof.',
    'Line 16 is compared with the Catala rate schedules on 2,402 incomes for each filing status (36,030 checks), and each of the 2,062 Tax Table rows is checked at its lowest dollar and highest cent in all four columns (16,496 checks).',
    'The proof audit (make audit, 2026-11-01) passed over 7,981 declarations with no sorry, no native_decide, no extra axiom and 0 high-severity findings.',
  ],
  caveat: 'Testing finds disagreements; it cannot rule them out. A scenario that Direct File does not contain is not tested.',
} as const;

/**
 * Tier 2, "Verified in Catala": NOT a proof. The rules are written in Catala (literate source that quotes the
 * statute; the Catala compiler checks types and default logic; unit tests in catala/tests) and are run against
 * the IRS Direct File engine as an oracle (difftest/mappings). `facts.test.ts` counts the files on disk and
 * checks each item's Catala file and mapping exist, and the numbers against README.md and lean/README.md.
 */
export const CATALA = {
  asOf: AS_OF,
  /** catala/*.catala_en */
  moduleFiles: 37,
  /** catala/tests/*.catala_en */
  testFiles: 42,
  /** difftest/mappings/*.mjs (one per module or scope compared with Direct File) */
  mappings: 37,
  /** docs/direct-file-bugs.md entries (same as BUGS.total; checked in facts.test.ts). */
  discrepancies: 33,
  legend:
    'Proved = a Lean theorem holds for every input. Verified = the Catala rules agree with IRS Direct File on every scenario we have; not a proof.',
  checks: [
    'Literate Catala source that quotes the statute and the IRS instructions it encodes',
    'Type- and default-logic-checked by the Catala compiler (Catala 1.3.0)',
    'Unit tests next to the rules (catala/tests)',
    'Differential tests against the IRS Direct File engine, fact by fact',
  ],
  items: [
    {
      title: 'Whole return (Form 1040 and every module)',
      file: 'catala/calculator.catala_en',
      scope: 'Calculator',
      mapping: 'calculator',
      result: `${TESTED.calculator.scenarios}/${TESTED.calculator.scenarios} scenarios, ${TESTED.calculator.factChecks.toLocaleString('en-US')} fact checks agree`,
      line: 'total_tax',
    },
    {
      title: 'The same, through the API request shape',
      file: 'catala/api_calculator.catala_en',
      scope: 'ApiCalculator',
      mapping: 'api_calculator',
      result: `${TESTED.apiCalculator.scenarios}/${TESTED.apiCalculator.scenarios} scenarios, ${TESTED.apiCalculator.factChecks.toLocaleString('en-US')} fact checks agree`,
      line: 'overpayment',
    },
    {
      title: 'Form 1040 lines 1a to 37',
      file: 'catala/form_1040.catala_en',
      scope: 'Form1040',
      mapping: 'form_1040',
      result: 'Agrees on every Direct File scenario it applies to',
      line: 'taxable_income',
    },
    {
      title: 'Tax rates (line 16)',
      file: 'catala/tax_rates.catala_en',
      scope: 'TentativeTax',
      mapping: 'tax_rates',
      result: `${TESTED.rates.checks.toLocaleString('en-US')} checks against the rate schedules; the Lean side is also proved`,
      line: 'tentative_tax_from_taxable_income',
    },
    {
      title: 'Standard deduction (line 12)',
      file: 'catala/standard_deduction.catala_en',
      scope: 'StandardDeduction',
      mapping: 'standard_deduction',
      result: 'Agrees on every Direct File scenario it applies to',
      line: 'standard_or_itemized_deductions',
    },
    {
      title: 'Earned income credit',
      file: 'catala/eitc.catala_en',
      scope: 'EitcFromFilers',
      mapping: 'eitc',
      result: 'Agrees on every Direct File scenario it applies to',
    },
    {
      title: 'Child tax credit and credit for other dependents',
      file: 'catala/ctc_odc.catala_en',
      scope: 'CtcOdc',
      mapping: 'ctc_odc',
      result: 'Agrees on every Direct File scenario it applies to',
    },
    {
      title: 'Filing status, qualifying child and relative',
      file: 'catala/filing_status.catala_en',
      scope: 'FilingStatusReturn',
      mapping: 'filing_status',
      result: 'Agrees on every Direct File scenario it applies to',
    },
    {
      title: 'Taxable Social Security (line 6b)',
      file: 'catala/social_security.catala_en',
      scope: 'SocialSecurity',
      mapping: 'social_security',
      result: 'Agrees on every Direct File scenario it applies to; the Lean side is also proved',
    },
  ],
  caveat:
    'Where Direct File and the statute differ we follow the statute and log the difference (33 entries in docs/direct-file-bugs.md). Testing finds disagreements; it cannot rule them out.',
} as const;

/** What a reader has to take on trust. README.md, "What you have to trust". */
export const TRUSTED: readonly { what: string; why: string }[] = [
  { what: 'The Lean kernel, compiler and runtime', why: 'The kernel checks the proofs. The server runs compiled Lean code (Lean 4.35.0), so the compiler and runtime are trusted too.' },
  { what: 'The web server layer', why: 'Std.Http from Lean core, and our socket glue in lean/ServerMain.lean. Tested, not proved.' },
  { what: 'Our JSON reader', why: 'lean/UsTax/Api/Json.lean. Tested, not proved. (That an accepted request meets the written input specification is proved; that the reader parses JSON correctly is not.)' },
  {
    what: 'The spec files a human must review',
    why: 'The properties in lean/UsTax/Spec/, the statements in lean/UsTax/Comparator/Challenge.lean and Extra.lean, and the Tax Table data transcribed from the printed IRS table. A theorem means only what its statement says. The review of the statements is listed in docs/spec-surface.md and was accepted by the owner without a detailed review.',
  },
  { what: 'Three standard axioms', why: 'propext, Classical.choice and Quot.sound. make audit and Comparator reject sorry, native_decide and any other axiom.' },
  { what: 'The Catala toolchain (tests only)', why: 'Catala 1.3.0 runs the readable rules in the differential tests. It is not part of the running calculator.' },
  { what: 'The Direct File oracle bundle (tests only)', why: 'The prebuilt Scala.js bundle of the IRS Direct File engine (oracle/README.md). The tests are only as good as this reference, and it has bugs (below).' },
  { what: 'Caddy (optional)', why: 'Only if you use the optional HTTPS front (docs/tls.md). Not needed to run the calculator.' },
  { what: 'This web app', why: 'It collects your answers, builds the request and formats the numbers. It is tested (unit and end-to-end tests), not verified.' },
];

/** What US Tax does not cover. */
export const NOT_COVERED: readonly string[] = [
  'Tax year 2024 only, federal income tax only (Form 1040). No state tax, no other years, no filing.',
  'The standard deduction only. Itemized deductions are not calculated.',
  'Some situations are knocked out: the calculator says “cannot do yet” and lists the reasons instead of guessing (for example private activity bond interest, or head of household with no qualifying person). The full list is api/knockout-reasons.json and docs/knockout-inventory.md.',
  'Proofs cover the properties listed on this page, not every line of the return. The other lines are checked by testing. Above $1 trillion of taxable income the calculator is not specified.',
  'The link from the Catala rules to the Lean code, and from both to Direct File, is tested, not proved.',
];

/** The Direct File bug log: docs/direct-file-bugs.md. Counts are checked against that file. */
export const BUGS = {
  file: 'docs/direct-file-bugs.md',
  total: 33,
  confirmed: 2,
  fixed: 2,
  candidates: 29,
  credit: 'Arnab Ghosh, ustax formal verification project',
  highlights: [
    {
      id: 'DF-BUG-8',
      status: 'confirmed',
      text: 'Direct File’s check “box 8 percentage is zero” on Form 1099-R strips the characters “0.” from the text, so 0.00 loses its dots and looks nonzero. The knockout fires wrongly on 4 of its own test returns. Reproduced by running the Direct File engine.',
    },
    {
      id: 'DF-BUG-5',
      status: 'confirmed (engine)',
      text: 'Direct File converts exact amounts to dollars through a 32-bit floating-point number. The statute and our code use exact arithmetic.',
    },
    {
      id: 'DF-BUG-1',
      status: 'fixed in our code',
      text: 'Direct File strips characters from the 1099-R distribution code before checking it: codes such as 7D and 7M are accepted as 7, and code 1 is stripped to nothing and knocked out.',
    },
  ],
  caveat:
    'Only DF-BUG-8 and DF-BUG-5 were reproduced by running the Direct File engine. The other entries are candidates: read in the XML and the law, not yet confirmed with the IRS. Where Direct File and the statute differ, we follow the statute.',
} as const;

/** The compact list on the home page. Built from the facts above so the two pages cannot disagree. */
export interface Claim {
  title: string;
  detail: string;
  status: ClaimStatus;
}

export const STATUS_CLAIMS: readonly Claim[] = [
  {
    title: `${MAIN.theorems.length} main statements proved and checked by Comparator`,
    detail: 'The tax equals the printed 2024 IRS Tax Table below $100,000 and the Tax Computation Worksheet from $100,000 through $1 trillion; refund and amount owed are consistent; credits never exceed the tax; total tax is never negative; the earned income credit stays within its bounds.',
    status: 'proven',
  },
  {
    title: `${EXTRA.theorems.length} more statements proved, covering the whole return`,
    detail: 'Each module equals its statute-style spec, and the whole-return refund, credit and knockout properties hold. Run by make comparator-extra, not yet in CI.',
    status: 'proven',
  },
  {
    title: `${CATALA.moduleFiles} Catala rule files verified against the IRS engine`,
    detail: `The law is written in Catala and run against IRS Direct File: on all ${TESTED.calculator.scenarios} scenarios, ${TESTED.calculator.factChecks.toLocaleString('en-US')} fact checks agree (as of ${AS_OF}). Differences are logged and we follow the statute. Testing, not a proof.`,
    status: 'tested',
  },
];

/** What the calculator includes today, and what it does not (home page). */
export const SCOPE_INCLUDED: readonly string[] = [
  'W-2 wages and federal tax withheld, bank interest, and 1099-G, 1099-R, 1099-MISC and Social Security income',
  'Standard deduction, including age 65+, blindness and dependent rules',
  'Dependents, child tax credit, earned income credit and child care credit',
  'All five filing statuses',
];

export const SCOPE_NOT_INCLUDED: readonly string[] = [
  'Itemized deductions, self-employment, investments, state tax',
  'Anything on the knockout list: you are told what, and no number is guessed',
  'Tax years other than 2024',
];
