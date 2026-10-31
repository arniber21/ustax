// Mapping for catala/form1099_rs.catala_en (scope Form1099Rs), issue #22: Form 1040 lines 5a and 5b.
// Compares /pensionsAndAnnuities (5a) and /taxablePensionsAndAnnuitiesDisplay (5b; oracle rows that are
// Incomplete = "blank" are reported as unchecked). Line 25b is in form1099_rs_withholding.mjs.
//
// Input encoding (see the Form1099R structure):
//  - box 7 text: upper-cased, trimmed; '2' '4' '7' 'B' 'G' 'H' map to their constructors, every other
//    character to OtherCode.
//  - box 8 / 9a percentage text: nonzero = it has a character other than '0' and '.' (the DF test,
//    meant as written in form1099Rs.xml, not the number-parsed "0" the oracle engine reads).
//  - unanswered optional boxes are $0 / false, as in Direct File.
//
// knownDivergence: none from DF-BUG(1) (no oracle scenario uses a code outside the supported set).
// DF-BUG(7, proposed) (box 8 "0.00" read as nonzero by the oracle engine) makes four scenarios
// knocked out in the oracle; the runner skips knocked-out scenarios, so they are listed here and
// checked by hand in the PR: 1099r-box-2b-total-distribution, ats-2-1099r, ats-2-1099r-blank-taxable,
// ats-2-1099r-nonzero-taxable. In those, our `ko_knockout_for_form1099_r_box8_percentage` is false.
import { collectionIds, toCatalaJson, parseOracleValue } from '../lib.mjs';

const val = (f, p) => {
  const r = f.get(p);
  return r && r.completeness !== 'Incomplete' && r.value !== '' ? r.value : undefined;
};
const money = (f, p) => toCatalaJson('money', parseOracleValue('money', val(f, p) ?? '0'));
const bool = (f, p) => val(f, p) === 'true';
const nonzeroText = (f, p) => { const v = val(f, p); return v !== undefined && /[^0.]/.test(v); };
const CHAR = { 2: 'Code2', 4: 'Code4', 7: 'Code7', B: 'CodeB', G: 'CodeG', H: 'CodeH' };
const primaryId = (f) => collectionIds(f, '/filers').find((id) => val(f, `/filers/#${id}/isPrimaryFiler`) === 'true');

export const knownDivergence = [];

export function formsInput(facts) {
  return collectionIds(facts, '/form1099Rs').map((id) => {
    const p = (n) => `/form1099Rs/#${id}/${n}`;
    const filerId = val(facts, p('filer'));
    const code = (val(facts, p('writableDistributionCode')) ?? '').trim().toUpperCase();
    return {
      filer: filerId === primaryId(facts) ? 'PrimaryFiler' : 'SecondaryFiler',
      distribution_code: [...code].map((c) => CHAR[c] ?? 'OtherCode'),
      writable_gross_distribution: money(facts, p('writableGrossDistribution')),
      writable_taxable_amount: money(facts, p('writableTaxableAmount')),
      taxable_amount_blank: val(facts, p('writableTaxableAmount')) === undefined
        && !bool(facts, p('writableTaxableAmountNotDetermined')),
      taxable_amount_not_determined: bool(facts, p('writableTaxableAmountNotDetermined')),
      total_distribution: bool(facts, p('writableTotalDistribution')),
      writable_capital_gain: money(facts, p('writableCapitalGain')),
      writable_federal_withholding: money(facts, p('writableFederalWithholding')),
      writable_net_appreciation: money(facts, p('writableNetAppreciation')),
      ira_sep_simple: bool(facts, p('iraSepSimple')),
      writable_other_dollar: money(facts, p('writableOtherDollar')),
      other_percentage_nonzero: nonzeroText(facts, p('writableOtherPercentage')),
      percentage_total_distribution_nonzero: nonzeroText(facts, p('writablePercentageTotalDistribution')),
      writable_amount_allocable_to_irr: money(facts, p('writableAmountAllocableToIRR')),
      facta_filing_requirement: bool(facts, p('factaFilingRequirement')),
      writable_state_tax_withheld: money(facts, p('writableStateTaxWithheld')),
      payer_state_is_different: val(facts, p('writablePayerState')) === 'differentState',
      has_death_benefit_payment_date: val(facts, p('writableDateOfPayment')) !== undefined,
      writable_is_indirect_rollover: bool(facts, p('writableIsIndirectRollover')),
      writable_is_distribution_from_military_retirement_plan: bool(facts, p('writableIsDistributionFromMilitaryRetirementPlan')),
      writable_qualified_disaster_distribution: bool(facts, p('writableQualifiedDisasterDistribution')),
      writeable_public_safety_officer: bool(facts, p('writeablePublicSafetyOfficer')),
      writeable_public_safety_officer_premiums: bool(facts, p('writeablePublicSafetyOfficerPremiums')),
      recipient_date_of_birth: val(facts, `/filers/#${filerId}/dateOfBirth`) ?? '1990-06-15',
    };
  });
}

export default {
  name: 'form1099_rs',
  scope: 'Form1099Rs',
  file: 'catala/form1099_rs.catala_en',
  appliesTo: () => true,
  knownDivergence,
  inputs: { forms: formsInput },
  outputs: [
    { oracle: '/pensionsAndAnnuities', catala: 'line_5a', type: 'money' },
    { oracle: '/taxablePensionsAndAnnuitiesDisplay', catala: 'line_5b', type: 'money' },
  ],
};
