// Mapping for catala/dependents_benefit_split.catala_en (scope BenefitSplitTest, one person). Issue #18.
// Run: make difftest-persons   (qualifying_child, qualifying_relative, dependents_benefit_split vs oracle/persons.csv)
//
// Like qualifying_child.mjs, this reads oracle/persons.csv (oracle/generate_persons.mjs): one
// pseudo-scenario `<scenario>~<person uuid>` per household member, with that person's writable facts and
// the dependentsBenefitSplit.xml derived facts added for #18.
//
// Defaults for answers DF never asked (each is read by DF only behind an All/Any whose value is already
// decided by an answered fact, or the derived fact that reads it is not Complete and so not compared):
//   the boolean answers: false; whichParentNotClaiming: nobodyDid; nightsWithTpVsOtherParent: less;
//   parentalSituation: other. multipleSupportAgreement is not a DF fact (DF-BUG(18-a)): false.
// parentalSituation: five DF scenarios hold the value `writableLivedApartLastSixMonths`, which is not an
// option of /parentalSituationOptions (a stale option name in the scenario files). DF's engine compares
// the string, so NotEqual(.., other) is true for it; it is mapped to LivedApartLastSixMonths.
import { person } from './qualifying_child.mjs';

const P = '/familyAndHousehold/*/';
const val = (f, n) => f.get(P + n)?.value;
const bool = (f, n) => val(f, n) === 'true';
const sbool = (f, p) => {
  const r = f.get(p);
  if (!r || r.completeness !== 'Complete') throw new Error(`oracle fact ${p} not Complete`);
  return r.value === 'true';
};
const pick = (f, n, table, dflt) => {
  const v = val(f, n);
  if (v === undefined) return dflt;
  if (!(v in table)) throw new Error(`unknown ${n} value ${v}`);
  return table[v];
};

export function splitAnswers(f) {
  return {
    has_other_biological_or_adoptive_parent: bool(f, 'hasOtherBiologicalOrAdoptiveParent'),
    non_parental_some_parent_not_claiming: bool(f, 'nonParentalSomeParentNotClaiming'),
    which_parent_not_claiming: pick(f, 'whichParentNotClaiming',
      { iDid: 'IDid', theyDid: 'TheyDid', nobodyDid: 'NobodyDid' }, 'NobodyDid'),
    in_parents_custody: bool(f, 'inParentsCustody'),
    lived_with_tp_or_other_biological_or_adoptive_parent_more_than_six_months:
      bool(f, 'livedWithTpOrOtherBiologicalOrAdoptiveParentMoreThanSixMonths'),
    biological_or_adoptive_parents_living: bool(f, 'biologicalOrAdoptiveParentsLiving'),
    nights_with_tp_vs_other_parent: pick(f, 'nightsWithTpVsOtherParent',
      { more: 'More', less: 'Less', equal: 'Equal' }, 'Less'),
    tp_agi_higher_than_other_parent: bool(f, 'tpAgiHigherThanOtherParent'),
    parents_meet_reqs_rule_for_children_of_divorced_parents: bool(f, 'parentsMeetReqsRuleForChildrenOfDivorcedParents'),
    special_rule_child_used_by_custodial_parent_as_qp: bool(f, 'specialRuleChildUsedByCustodialParentAsQP'),
    special_rule_agi_test: bool(f, 'specialRuleAgiTest'),
    parental_situation: pick(f, 'parentalSituation', {
      divorcedOrSeparated: 'DivorcedOrSeparated', livedApartLastSixMonths: 'LivedApartLastSixMonths',
      writableLivedApartLastSixMonths: 'LivedApartLastSixMonths', other: 'Other',
    }, 'Other'),
    parental_support: bool(f, 'parentalSupport'),
    multiple_support_agreement: false,
  };
}

const b = (n, c) => ({ oracle: P + n, catala: c, type: 'bool' });

export default {
  name: 'dependents_benefit_split',
  scope: 'BenefitSplitTest',
  file: 'catala/dependents_benefit_split.catala_en',
  appliesTo: (f) => (f.has(P + 'eligibleForBenefitSplit') ? true : 'needs per-person oracle: make difftest-persons'),
  inputs: {
    member: (f) => ({ person: person(f), answers: splitAnswers(f) }),
    minimum_filer_date_of_birth: (f) => f.get('/minimumFilerDateOfBirth').value,
    treat_as_mfj: (f) => sbool(f, '/treatAsMFJ'),
  },
  outputs: [
    b('childMayQualifyForBenefitSplit', 'child_may_qualify_for_benefit_split'),
    b('tpIsParent', 'tp_is_parent'),
    b('tpIsNotParent', 'tp_is_not_parent'),
    b('parentalSomeParentNotClaiming', 'parental_some_parent_not_claiming'),
    b('primaryFilerNotClaiming', 'primary_filer_not_claiming'),
    b('bothFilersNotClaiming', 'both_filers_not_claiming'),
    b('otherParentNotClaiming', 'other_parent_not_claiming'),
    b('hadEqualNumberOfNightsWithParents', 'had_equal_number_of_nights_with_parents'),
    b('parentsAreDivorcedSeparatedOrLivingApart', 'parents_are_divorced_separated_or_living_apart'),
    b('tpIsCustodialParent', 'tp_is_custodial_parent'),
    b('eligibleForBenefitSplit', 'eligible_for_benefit_split'),
    b('reachedNonParentalBenefitSplit', 'reached_non_parental_benefit_split'),
    b('tpCanClaimSplitBenefitsHohEitcCdcc', 'tp_can_claim_split_benefits_hoh_eitc_cdcc'),
    b('disqualifiedDueToParentalCustody', 'disqualified_due_to_parental_custody'),
    b('contradictory8832TPIsCustodialParent', 'contradictory8832_tp_is_custodial_parent'),
    b('contradictory8832TPNotCustodialParent', 'contradictory8832_tp_not_custodial_parent'),
    b('contradictory8832Knockout', 'contradictory8832_knockout'),
    b('causesNoncustodialParentBenefitSplitKnockout', 'causes_noncustodial_parent_benefit_split_knockout'),
  ],
  // Places where we follow the law and DF does not (CONVENTIONS section 8, docs/direct-file-bugs.md).
  knownDivergence: [
    {
      bug: 'DF-BUG(18-a)', scenario: '(none in the oracle)', path: P + 'eligibleForBenefitSplit',
      note: 'a multiple support agreement (IRC 152(d)(3)) is in effect: IRC 152(e)(5) turns the split off; ' +
        'DF never asks and splits. No DF return has the input, so no oracle value changes.',
    },
  ],
};
