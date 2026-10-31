// Mapping for catala/hoh_qss_persons.catala_en (scope HohQssPersonTest, one person). Issue #19.
// Run: make difftest-persons   (all per-person modules vs oracle/persons.csv)
//
// Like qualifying_child.mjs, this reads oracle/persons.csv (oracle/generate_persons.mjs): one
// pseudo-scenario `<scenario>~<person uuid>` per household member, with that person's writable facts,
// the derived facts added for #19 and the filers.xml / filingStatus.xml facts /eligibleForMFJ,
// /filerCouldQualifyForHoh and /filerCouldQualifyForQss (DF's own values, as /minimumFilerDateOfBirth
// is for qualifying_child).
//
// Defaults for answers DF never asked: tpPaidMostOfHomeUpkeep and tpPaidMostOfParentHomeUpkeep, false.
// DF asks them only behind flowAddPersonKeepingUpHome / flowAddPersonKeepingUpParentsHome; when the
// question is not asked, every branch that reads the answer is false or Incomplete in DF (so not
// compared). The dependent, qualifying child and benefit-split answers are mapped as in
// qualifying_relative.mjs and dependents_benefit_split.mjs.
import { person } from './qualifying_child.mjs';
import { answers } from './qualifying_relative.mjs';
import { splitAnswers } from './dependents_benefit_split.mjs';

const P = '/familyAndHousehold/*/';
const val = (f, n) => f.get(P + n)?.value;
const bool = (f, n) => val(f, n) === 'true';
const sbool = (f, p) => {
  const r = f.get(p);
  if (!r || r.completeness !== 'Complete') throw new Error(`oracle fact ${p} not Complete`);
  return r.value === 'true';
};

const b = (n, c) => ({ oracle: P + n, catala: c, type: 'bool' });

export default {
  name: 'hoh_qss_persons',
  scope: 'HohQssPersonTest',
  file: 'catala/hoh_qss_persons.catala_en',
  appliesTo: (f) => (f.has(P + 'hohQualifyingPerson') ? true : 'needs per-person oracle: make difftest-persons'),
  inputs: {
    member: (f) => ({
      dependent: { person: person(f), answers: answers(f), split: splitAnswers(f) },
      upkeep: {
        tp_paid_most_of_home_upkeep: bool(f, 'tpPaidMostOfHomeUpkeep'),
        tp_paid_most_of_parent_home_upkeep: bool(f, 'tpPaidMostOfParentHomeUpkeep'),
      },
    }),
    minimum_filer_date_of_birth: (f) => f.get('/minimumFilerDateOfBirth').value,
    treat_filers_as_dependents: (f) => sbool(f, '/treatFilersAsDependents'),
    either_filer_us_citizen_or_national: (f) => sbool(f, '/eitherFilerUSCitizenOrNational'),
    treat_as_mfj: (f) => sbool(f, '/treatAsMFJ'),
    eligible_for_mfj: (f) => sbool(f, '/eligibleForMFJ'),
    filer_could_qualify_for_hoh: (f) => sbool(f, '/filerCouldQualifyForHoh'),
    filer_could_qualify_for_qss: (f) => sbool(f, '/filerCouldQualifyForQss'),
  },
  outputs: [
    b('marriedHohRelationshipTest', 'married_hoh_relationship_test'),
    b('isBiologicalAdoptedFosterOrStepchild', 'is_biological_adopted_foster_or_stepchild'),
    b('qssPersonResidencyTest', 'qss_person_residency_test'),
    b('flowAddPersonKeepingUpHome', 'flow_add_person_keeping_up_home'),
    b('flowAddPersonKeepingUpParentsHome', 'flow_add_person_keeping_up_parents_home'),
    b('hohQualifyingPerson', 'hoh_qualifying_person'),
    b('personQualifiesTPforHoH', 'person_qualifies_tp_for_hoh'),
    b('qssQualifyingPerson', 'qss_qualifying_person'),
    b('personQualifiesTPforQss', 'person_qualifies_tp_for_qss'),
  ],
  // Places where we follow the law and DF does not (CONVENTIONS section 8, docs/direct-file-bugs.md).
  knownDivergence: [
    {
      bug: 'DF-BUG(19-a)', scenario: 'mfj-50k-ctc-odc~9d45c664-8966-42e0-a179-4883b593f939', path: P + 'hohQualifyingPerson',
      note: 'married filer (eligibleForMFJ) and a 2-year-old son with tinType none, so not an eligible dependent: ' +
        'IRC 7703(b)(1) needs a child the filer is entitled to claim under 151 (151(e): TIN), so this child ' +
        'cannot make the filer "considered unmarried": we say false, DF true. No tax effect here: the filer ' +
        'files jointly and /filerCouldQualifyForHoh is false (personQualifiesTPforHoH agrees, false).',
    },
    {
      bug: 'DF-BUG(19-b)', scenario: '(none in the oracle)', path: P + 'hohQualifyingPerson',
      note: 'an eligible dependent the filer does not claim (tpClaims false): DF requires isClaimedIfClaimable for ' +
        'HoH and QSS; IRC 2(a)(1)(B), 2(b)(1) need only entitlement. We say true, DF false. Also qssQualifyingPerson.',
    },
    {
      bug: 'DF-BUG(19-c)', scenario: '(none in the oracle)', path: P + 'hohQualifyingPerson',
      note: 'married qualifying child with no TIN, or on the custodial side of a benefit split: IRC ' +
        '2(b)(1)(A)(i)(II) excludes a married child only for 152(b)(2)/(b)(3). We say true, DF false.',
    },
    {
      bug: 'DF-BUG(19-d)', scenario: '(none in the oracle)', path: P + 'hohQualifyingPerson',
      note: 'qualifying relative (not the filer\'s qualifying child) on the filer\'s side of a benefit split: IRC ' +
        '2(b)(1)(A)(ii) needs a dependent the filer may claim. We say false, DF true.',
    },
  ],
};
