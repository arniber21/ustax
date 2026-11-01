import type { FilingStatus } from '../api';
import { Callout } from '../components';
import { useDraft, type FlagsDraft } from '../draft';
import { PersonDetails } from './PersonDetails';
import { Check, ChoiceCards, FormSection, StepHeader, type CardOption } from './ui';

export const FILING_STATUS_OPTIONS: readonly CardOption<FilingStatus>[] = [
  {
    value: 'Single',
    label: 'Single',
    desc: 'You were not married on December 31, 2024 (or you were legally divorced), and no other option fits.',
  },
  {
    value: 'MarriedFilingJointly',
    label: 'Married, filing together',
    desc: 'You were married on December 31, 2024, and you and your spouse put everything on one return. This is the most common choice for couples.',
  },
  {
    value: 'MarriedFilingSeparately',
    label: 'Married, filing separately',
    desc: 'You were married, but you and your spouse each file your own return.',
  },
  {
    value: 'HeadOfHousehold',
    label: 'Head of household',
    desc: 'You are unmarried and paid more than half the cost of keeping up a home for a child or relative who lived with you.',
  },
  {
    value: 'QualifyingSurvivingSpouse',
    label: 'Qualifying surviving spouse',
    desc: 'Your spouse died in 2022 or 2023, you have not remarried, and a child you support lives with you.',
  },
];

/** Step 1: how are you filing? Plus the few facts that change your standard deduction. */
export function AboutStep() {
  const { draft, update } = useDraft();
  const setPrimary = (patch: Partial<FlagsDraft>) => update((d) => ({ ...d, primary: { ...d.primary, ...patch } }));

  return (
    <>
      <StepHeader
        eyebrow="Step 1 of 7"
        title="About you"
        intro="Your filing status sets your standard deduction (the part of income that is not taxed) and your tax rates. You can change any answer later."
      />
      <FormSection title="Filing status">
        <ChoiceCards
          legend="Which one applies to you?"
          value={draft.filingStatus}
          options={FILING_STATUS_OPTIONS}
          onChange={(filingStatus) => update({ filingStatus })}
          errorPath="filingStatus"
        />
        {draft.filingStatus === 'QualifyingSurvivingSpouse' && (
          <Callout tone="info" title="Double-check this one">
            You can only use it for two years after your spouse’s death, and only with a dependent child. If that is not you,
            Single or Head of household is likely the right fit.
          </Callout>
        )}
      </FormSection>

      <FormSection title="You" note="A few facts about you on December 31, 2024. The credits you may qualify for depend on them.">
        <PersonDetails who="you" value={draft.primary} onChange={setPrimary} pathPrefix="primary" />
      </FormSection>

      <FormSection title="Age, sight and dependency" note="Select anything that was true on December 31, 2024. Each one can change your standard deduction.">
        {draft.primary.dob === '' && (
          <Check
            label="I am 65 or older"
            hint="You count as 65 if your 65th birthday is on or before January 1, 2025. Not needed if you gave your date of birth."
            checked={draft.primary.age65}
            onChange={(age65) => setPrimary({ age65 })}
          />
        )}
        <Check
          label="I am blind"
          hint="Legally blind in both eyes, with a statement from your eye doctor."
          checked={draft.primary.blind}
          onChange={(blind) => setPrimary({ blind })}
        />
        <Check
          label="Someone else can claim me as a dependent"
          hint="For example, a student whose parents still claim them. This lowers your standard deduction."
          checked={draft.primary.canBeClaimed}
          onChange={(canBeClaimed) => setPrimary({ canBeClaimed })}
        />
      </FormSection>
    </>
  );
}
