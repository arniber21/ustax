// Mapping for catala/ctc_odc.catala_en (scope CtcOdcPersonTest, one person), issue #27.
// Run: make difftest-persons   (runs qualifying_child, qualifying_relative and ctc_odc_person against
// oracle/persons.csv)
//
// Like qualifying_relative.mjs, this reads oracle/persons.csv: one pseudo-scenario `<scenario>~<uuid>`
// per household member, with the person's answers and DF's per-person facts, including (added by
// issue #27 to oracle/generate_persons.mjs) /familyAndHousehold/*/ssnValidForEmployment, eligibleCtc
// and eligibleOdc. The person and dependent answers are mapped as in qualifying_child.mjs and
// qualifying_relative.mjs; ssnEmploymentValidity missing is Neither (see ctc_odc_household.mjs).
// ssnValidForEmployment is Incomplete in the oracle where the question was not asked, and is then
// not compared.
import { householdMember } from './ctc_odc_household.mjs';

const P = '/familyAndHousehold/*/';
const sbool = (f, p) => {
  const r = f.get(p);
  if (!r || r.completeness !== 'Complete') throw new Error(`oracle fact ${p} not Complete`);
  return r.value === 'true';
};
const b = (n, c) => ({ oracle: P + n, catala: c, type: 'bool' });

export default {
  name: 'ctc_odc_person',
  scope: 'CtcOdcPersonTest',
  file: 'catala/ctc_odc.catala_en',
  appliesTo: (f) => (f.has(P + 'eligibleCtc') ? true : 'needs per-person oracle: make difftest-persons'),
  inputs: {
    household_member: householdMember,
    minimum_filer_date_of_birth: (f) => f.get('/minimumFilerDateOfBirth').value,
    treat_filers_as_dependents: (f) => sbool(f, '/treatFilersAsDependents'),
    either_filer_us_citizen_or_national: (f) => sbool(f, '/eitherFilerUSCitizenOrNational'),
    treat_as_mfj: (f) => sbool(f, '/treatAsMFJ'),
  },
  outputs: [
    b('ssnValidForEmployment', 'ssn_valid_for_employment'),
    b('eligibleCtc', 'eligible_ctc'),
    b('eligibleOdc', 'eligible_odc'),
  ],
  knownDivergence: [],
};
