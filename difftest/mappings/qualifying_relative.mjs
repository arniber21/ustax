// Mapping for catala/qualifying_relative.catala_en (scope DependentTest, one person). Issue #17.
// Run: make difftest-persons   (runs qualifying_child and qualifying_relative against oracle/persons.csv)
//
// Like qualifying_child.mjs, this reads oracle/persons.csv (oracle/generate_persons.mjs): one
// pseudo-scenario `<scenario>~<person uuid>` per household member.
//
// Inputs DF did not ask (each is read by DF only behind a gate that is false for that person, or the
// derived fact that reads it is not Complete and so not compared):
//   grossIncomeTest missing: treated as "no" (gross income at the limit, the test fails);
//   writableQrSupportTest, tpClaims, writableUsResident, writableUsNational,
//   writableCanadaMexicoResident missing: false.
// grossIncomeTest is a yes/no Writable in DF; the Catala input is the amount. "yes" (less than the
// limit) becomes $0, "no" becomes $5,050 (Params_2024.qualifying_relative_gross_income_limit).
// The benefit-split facts (dependentsBenefitSplit.xml, issue #18) and the filers.xml facts are DF's
// own derived values from the oracle, as /minimumFilerDateOfBirth is for qualifying_child.
import { person } from './qualifying_child.mjs';

const P = '/familyAndHousehold/*/';
const val = (f, n) => f.get(P + n)?.value;
const bool = (f, n) => val(f, n) === 'true';
const sbool = (f, p) => {
  const r = f.get(p);
  if (!r || r.completeness !== 'Complete') throw new Error(`oracle fact ${p} not Complete`);
  return r.value === 'true';
};
const TIN = { ssn: 'Ssn', itin: 'Itin', atin: 'Atin', none: 'NoTin' };

export function answers(f) {
  const tin = val(f, 'tinType');
  if (!(tin in TIN)) throw new Error(`unknown tinType ${tin}`);
  return {
    gross_income: val(f, 'grossIncomeTest') === 'true' ? 0 : 5050,
    writable_qr_support_test: bool(f, 'writableQrSupportTest'),
    tin_type: TIN[tin],
    is_us_citizen_full_year: bool(f, 'isUsCitizenFullYear'),
    writable_us_resident: bool(f, 'writableUsResident'),
    writable_us_national: bool(f, 'writableUsNational'),
    writable_canada_mexico_resident: bool(f, 'writableCanadaMexicoResident'),
    tp_claims: bool(f, 'tpClaims'),
    tp_can_claim_split_benefits_hoh_eitc_cdcc: sbool(f, P + 'tpCanClaimSplitBenefitsHohEitcCdcc'),
    disqualified_due_to_parental_custody: sbool(f, P + 'disqualifiedDueToParentalCustody'),
  };
}

const b = (n, c) => ({ oracle: P + n, catala: c, type: 'bool' });

export default {
  name: 'qualifying_relative',
  scope: 'DependentTest',
  file: 'catala/qualifying_relative.catala_en',
  appliesTo: (f) => (f.has(P + 'eligibleDependent') ? true : 'needs per-person oracle: make difftest-persons'),
  inputs: {
    member: (f) => ({ person: person(f), answers: answers(f) }),
    minimum_filer_date_of_birth: (f) => f.get('/minimumFilerDateOfBirth').value,
    treat_filers_as_dependents: (f) => sbool(f, '/treatFilersAsDependents'),
    either_filer_us_citizen_or_national: (f) => sbool(f, '/eitherFilerUSCitizenOrNational'),
  },
  outputs: [
    b('qualifyingChild', 'qualifying_child'),
    b('askAboutQCOfAnother', 'ask_about_qc_of_another'),
    b('isQualifyingChildOfAnother', 'is_qualifying_child_of_another'),
    b('notQualifyingChildTest', 'not_qualifying_child_test'),
    b('qrRelationshipTest', 'qr_relationship_test'),
    b('memberOfHouseholdTest', 'member_of_household_test'),
    b('relationshipMemberOfHouseholdTest', 'relationship_member_of_household_test'),
    b('grossIncomeTest', 'gross_income_test'),
    b('qrSupportTest', 'qr_support_test'),
    b('qualifyingRelativeMinusNotQcTest', 'qualifying_relative_minus_not_qc_test'),
    b('qualifyingRelative', 'qualifying_relative'),
    b('usResident', 'us_resident'),
    b('usNational', 'us_national'),
    b('canadaMexicoResident', 'canada_mexico_resident'),
    b('childIsAdopted', 'child_is_adopted'),
    b('adoptedChildException', 'adopted_child_exception'),
    b('citizenOrUsResidentTest', 'citizen_or_us_resident_test'),
    b('citizenOrResidentTest', 'citizen_or_resident_test'),
    b('qcOrQr', 'qc_or_qr'),
    b('eligibleDependentMinusFilerInformation', 'eligible_dependent_minus_filer_information'),
    b('eligibleDependent', 'eligible_dependent'),
    b('isClaimedDependent', 'is_claimed_dependent'),
    b('isClaimedIfClaimable', 'is_claimed_if_claimable'),
  ],
  // Places where we follow the law and DF does not (CONVENTIONS section 8, docs/direct-file-bugs.md).
  knownDivergence: [
    ...['hoh-cdcc-combat-pay', 'hoh-cdcc-multiple-careproviders'].map((s) => ({
      bug: 'DF-BUG(15)', scenario: `${s}~e626fc63-667a-4639-ac65-1e68ce9d0d2e`, path: P + 'qualifyingRelative',
      note: "the filer's own qualifying child (4-year-old) also answers the qualifying relative questions; " +
        'IRC 152(d)(1)(D) "not a qualifying child of such taxpayer": we say false, DF true. qcOrQr and ' +
        'eligibleDependent agree.',
    })),
    {
      bug: 'DF-BUG(16)', scenario: '(none in the oracle)', path: P + 'notQualifyingChildTest',
      note: 'a person who can be the qualifying child of another taxpayer but fails DF\'s gate ' +
        '(askAboutQCOfAnother: not younger than this filer, or fails the gross income test): ' +
        'we use the answer, DF ignores it.',
    },
  ],
};
