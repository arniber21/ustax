import type { WizardStepId } from '../layout/steps';
import { LIMITS, RELATIONSHIPS, type Cents, type Draft } from './types';

/** Problems found in one step, keyed by field path (`w2.<id>.wages`, `filingStatus`, ...). Plain-language messages. */
export type StepErrors = Record<string, string>;

/** True for a real calendar date written `YYYY-MM-DD` (the contract pattern, plus a month and day that exist). */
export function isIsoDate(v: string): boolean {
  if (!/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/.test(v)) return false;
  const [y, m, d] = v.split('-').map(Number) as [number, number, number];
  const t = new Date(Date.UTC(y, m - 1, d));
  return t.getUTCFullYear() === y && t.getUTCMonth() === m - 1 && t.getUTCDate() === d;
}

const TOO_BIG = 'That number is too big. Check the digits and try again.';

/**
 * Per-step checks that mirror the contract (api/schema.json): required fields, caps, and the
 * cross-field rules the server enforces. Money text itself is parsed by `MoneyInput`, so by the time a
 * value is in the draft it is an integer number of cents. Empty means the step can continue.
 */
export function validateStep(d: Draft, step: WizardStepId): StepErrors {
  const e: StepErrors = {};
  const big = (path: string, v: Cents, signed = false) => {
    if (v !== null && (signed ? Math.abs(v) : v) > LIMITS.maxCents) e[path] = TOO_BIG;
  };
  const required = (path: string, v: Cents, msg: string, signed = false) => {
    if (v === null) e[path] = msg;
    else big(path, v, signed);
  };

  /** A date of birth: optional when `needed` is false. Not in the future of the tax year, not before 1900. */
  const dob = (path: string, v: string, who: string, needed: boolean) => {
    if (v === '') {
      if (needed) e[path] = `Enter ${who} date of birth.`;
      return;
    }
    if (!isIsoDate(v)) e[path] = `Enter ${who} date of birth as a real date.`;
    else if (v > LIMITS.lastDayOfTaxYear) e[path] = `${who[0]!.toUpperCase()}${who.slice(1)} date of birth cannot be after December 31, 2024.`;
    else if (v < '1900-01-01') e[path] = `Check ${who} date of birth: the year looks too early.`;
  };

  if (step === 'about') {
    if (d.filingStatus === null) e.filingStatus = 'Pick the option that fits you best. You can change it later.';
    dob('primary.dob', d.primary.dob, 'your', false);
  }

  if (step === 'household') {
    if (d.filingStatus === 'MarriedFilingJointly') dob('spouse.dob', d.spouse.dob, 'your spouse’s', false);
  }

  if (step === 'dependents' && d.hasDependents) {
    if (d.dependents.length === 0) e.dependents = 'Add each person you support, or answer No above.';
    if (d.dependents.length > LIMITS.maxDependents) e.dependents = `We can take up to ${LIMITS.maxDependents} people.`;
    for (const p of d.dependents) {
      const k = `dep.${p.id}`;
      if (p.relationship === '' || !RELATIONSHIPS.some((r) => r.value === p.relationship)) {
        e[`${k}.relationship`] = 'Pick how this person is related to you.';
      }
      dob(`${k}.dob`, p.dob, 'their', true);
      if (p.residency === 'SixToElevenMonths' && (p.months === null || p.months < 6 || p.months > 11)) {
        e[`${k}.months`] = 'Pick how many months, from 6 to 11.';
      }
      big(`${k}.grossIncome`, p.grossIncome);
    }
  }

  if (step === 'credits') {
    if (d.cdcc.paid) {
      big('cdcc.totalQualified', d.cdcc.totalQualified);
      if (d.hasDependents) {
        for (const p of d.dependents) {
          const k = `dep.${p.id}`;
          big(`${k}.careExpenses`, p.careExpenses);
          if ((p.careExpenses ?? 0) > 0 && p.careProviderQualifies === null) {
            e[`${k}.careProviderQualifies`] = 'Tell us whether the person who provided the care counts.';
          }
        }
      }
    }
    for (const f of [d.primary, ...(d.filingStatus === 'MarriedFilingJointly' ? [d.spouse] : [])]) {
      if (d.hsa.has && f.hsa.contributed) big(f === d.primary ? 'hsa.primary.directContributions' : 'hsa.spouse.directContributions', f.hsa.directContributions);
    }
  }

  if (step === 'income') {
    if (d.w2s.length > LIMITS.maxItems) e.w2s = `We can take up to ${LIMITS.maxItems} W-2s.`;
    if (d.interest.length > LIMITS.maxItems) e.interest = `We can take up to ${LIMITS.maxItems} 1099-INTs.`;
    if (d.unemployment.length > LIMITS.maxItems) e.unemployment = `We can take up to ${LIMITS.maxItems} 1099-Gs.`;
    if (d.retirement.length > LIMITS.maxItems) e.retirement = `We can take up to ${LIMITS.maxItems} 1099-Rs.`;
    if (d.ssa.length > LIMITS.maxSsaForms) e.ssa = `We can take up to ${LIMITS.maxSsaForms} Social Security statements.`;

    for (const w of d.w2s) {
      const p = `w2.${w.id}`;
      required(`${p}.wages`, w.wages, 'Box 1 is the heart of the W-2. Enter 0 if it is empty.');
      for (const [k, v] of [
        ['withholding', w.withholding], ['ssWages', w.ssWages], ['ssTax', w.ssTax], ['medicareWages', w.medicareWages],
        ['medicareTax', w.medicareTax], ['allocatedTips', w.allocatedTips], ['dependentCare', w.dependentCare],
        ['nonQualified', w.nonQualified],
      ] as const) big(`${p}.${k}`, v);
      for (const r of w.box12) {
        const rp = `${p}.box12.${r.id}`;
        if (r.code === '') e[`${rp}.code`] = 'Pick the letter printed in box 12.';
        required(`${rp}.amount`, r.amount, 'Enter the amount next to that letter.');
      }
    }
    for (const i of d.interest) {
      const p = `interest.${i.id}`;
      required(`${p}.interest`, i.interest, 'Box 1 is the interest you were paid. Enter 0 if it is empty.');
      for (const [k, v] of [
        ['earlyWithdrawalPenalty', i.earlyWithdrawalPenalty], ['governmentBondInterest', i.governmentBondInterest],
        ['withheld', i.withheld], ['foreignTax', i.foreignTax], ['taxExempt', i.taxExempt], ['privateActivityBond', i.privateActivityBond],
      ] as const) big(`${p}.${k}`, v);
    }
    for (const u of d.unemployment) {
      const p = `unemployment.${u.id}`;
      required(`${p}.amount`, u.amount, 'Box 1 is what you were paid in unemployment.');
      big(`${p}.withheld`, u.withheld);
    }
    for (const r of d.retirement) {
      const p = `retirement.${r.id}`;
      if (r.codes.length === 0) e[`${p}.codes`] = 'Pick the code (or codes) printed in box 7.';
      if (r.codes.length > LIMITS.maxCodes1099R) e[`${p}.codes`] = `Box 7 holds at most ${LIMITS.maxCodes1099R} codes.`;
      required(`${p}.gross`, r.gross, 'Box 1 is the total you took out.');
      if (!r.taxableBlank) required(`${p}.taxable`, r.taxable, 'Box 2a is the taxable part. Tick the box below if it is blank.');
      big(`${p}.withheld`, r.withheld);
    }
    for (const s of d.ssa) required(`ssa.${s.id}.netBenefits`, s.netBenefits, 'Box 5 is your net benefits for the year.', true);
  }

  if (step === 'adjustments') {
    const ed = d.educator;
    if (ed.primary) required('educator.primaryExpenses', ed.primaryExpenses, 'How much did you spend?');
    if (ed.spouse && d.filingStatus === 'MarriedFilingJointly') {
      required('educator.spouseExpenses', ed.spouseExpenses, 'How much did your spouse spend?');
    }
    if (d.studentLoan.hadPayments) required('studentLoan.interest', d.studentLoan.interest, 'Enter the interest from Form 1098-E.');
    if (d.estimated.paid) required('estimated.amount', d.estimated.amount, 'How much did you pay in total?');
  }

  return e;
}

/** Every step's problems; a step with none maps to an empty object. */
export function validateDraft(d: Draft): Record<WizardStepId, StepErrors> {
  return {
    about: validateStep(d, 'about'),
    household: validateStep(d, 'household'),
    dependents: validateStep(d, 'dependents'),
    income: validateStep(d, 'income'),
    adjustments: validateStep(d, 'adjustments'),
    credits: validateStep(d, 'credits'),
    review: validateStep(d, 'review'),
  };
}

/** True when no step has a problem and a request can be built. */
export const isDraftValid = (d: Draft): boolean =>
  Object.values(validateDraft(d)).every((s) => Object.keys(s).length === 0);
