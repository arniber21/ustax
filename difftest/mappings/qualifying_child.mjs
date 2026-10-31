// Mapping for catala/qualifying_child.catala_en (scope QualifyingChildTest, one person).
// Run: make difftest-persons   (= node difftest/run.mjs --scope qualifying_child --oracle oracle/persons.csv)
//
// oracle/facts.csv holds no per-person derived facts, so this mapping reads oracle/persons.csv
// (oracle/generate_persons.mjs): one pseudo-scenario `<scenario>~<person uuid>` per household
// member, with that person's writable and derived facts under /familyAndHousehold/*/<fact>.
// Against oracle/facts.csv (e.g. `make difftest SCOPE=all`) every scenario is listed as outside
// the module, because the per-person rows are absent.
//
// Defaults for facts DF never asked (each is read by DF only behind a gate that is false for
// that person, so a default cannot mask a mismatch on a checked output):
//   fullTimeStudent, permanentTotalDisability, ownSupport, the joint-return answers and the
//   qualifying-child-of-another answers: false.
const P = '/familyAndHousehold/*/';
const val = (f, n) => f.get(P + n)?.value;
const bool = (f, n) => val(f, n) === 'true';
const upper = (s) => s.charAt(0).toUpperCase() + s.slice(1);

// dependentsRelationship.xml /familyAndHousehold/*/relationship (lines 194-642): the category
// question selects which sub-question holds the relationship; `notRelated` is `noneOfTheAbove`.
function relationship(f) {
  const cat = val(f, 'relationshipCategory');
  const sub = {
    childOrDescendants: 'childRelationship', siblingOrDescendants: 'siblingRelationship',
    parentOrAncestors: 'parentalRelationship', inlaws: 'inlawRelationship',
  }[cat];
  if (cat === 'notRelated') return 'NoneOfTheAbove';
  if (!sub || !val(f, sub)) throw new Error(`no relationship answer (category ${cat})`);
  return upper(val(f, sub));
}

export function person(f) {
  return {
    relationship: relationship(f),
    date_of_birth: val(f, 'dateOfBirth'),
    full_time_student: bool(f, 'fullTimeStudent'),
    permanent_total_disability: bool(f, 'permanentTotalDisability'),
    residency_duration: upper(val(f, 'residencyDuration')),
    own_support: bool(f, 'ownSupport'),
    married: bool(f, 'married'),
    writable_joint_return: bool(f, 'writableJointReturn'),
    writable_required_to_file: bool(f, 'writableRequiredToFile'),
    writable_filing_only_for_refund: bool(f, 'writableFilingOnlyForRefund'),
    writable_could_be_qualifying_child_of_another: bool(f, 'writableCouldBeQualifyingChildOfAnother'),
    writable_potential_claimer_must_file: bool(f, 'writablePotentialClaimerMustFile'),
    writable_potential_claimer_did_file: bool(f, 'writablePotentialClaimerDidFile'),
    writable_potential_claimer_filed_only_for_refund: bool(f, 'writablePotentialClaimerFiledOnlyForRefund'),
  };
}

const b = (n, c) => ({ oracle: P + n, catala: c, type: 'bool' });

export default {
  name: 'qualifying_child',
  scope: 'QualifyingChildTest',
  file: 'catala/qualifying_child.catala_en',
  appliesTo: (f) => (f.has(P + 'qualifyingChild') ? true : 'needs per-person oracle: make difftest-persons'),
  inputs: {
    person,
    // filers.xml /minimumFilerDateOfBirth (output of Filers, #15), taken from the oracle.
    minimum_filer_date_of_birth: (f) => f.get('/minimumFilerDateOfBirth').value,
  },
  outputs: [
    { oracle: P + 'age', catala: 'age', type: 'int' },
    { oracle: P + 'ageAtFirstHalfOfYear', catala: 'age_at_first_half_of_year', type: 'int' },
    b('qcRelationshipTest', 'qc_relationship_test'),
    b('studentStatusMayAffectBenefits', 'student_status_may_affect_benefits'),
    b('isAStudentUnder24', 'is_a_student_under24'),
    b('disabilityStatusMayAffectBenefits', 'disability_status_may_affect_benefits'),
    b('ageTest', 'age_test'),
    b('residencyTest', 'residency_test'),
    b('qcSupportTest', 'qc_support_test'),
    b('jointReturn', 'joint_return'),
    b('requiredToFile', 'required_to_file'),
    b('filingOnlyForRefund', 'filing_only_for_refund'),
    b('jointReturnTest', 'joint_return_test'),
    b('qualifyingChild', 'qualifying_child'),
    b('qcOfAnotherButNot', 'qc_of_another_but_not'),
  ],
  // Places where we follow the law and DF does not (CONVENTIONS section 8, docs/direct-file-bugs.md).
  // The runner does not read this field yet; it documents the expected divergences.
  knownDivergence: [
    {
      bug: 'DF-BUG-3', scenario: 'qss_35K_1 dependent-signed~a39ea20d-687d-4bc7-b73c-9d413f32e708',
      path: 'ko_qualifying_child_tie_breaker (no DF fact)',
      note: 'QC of the filer and writableCouldBeQualifyingChildOfAnother=true with a claimer who must file: ' +
        'we knock out (IRC 152(c)(4) not computable); DF accepts the return. No compared path changes.',
    },
    {
      bug: 'DF-BUG-16-a', scenario: '(none in the oracle)', path: P + 'ageTest',
      note: 'disabled person under 18 born the same day as the oldest filer: we pass the age test (IRC 152(c)(3)(B)), DF fails it.',
    },
  ],
};
