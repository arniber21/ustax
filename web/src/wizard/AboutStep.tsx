import type { FilingStatus } from '../api';
import { Callout, Card } from '../components';
import { useDraft, type FlagsDraft } from '../draft';
import { Check, ChoiceCards, StepHeader, type CardOption } from './ui';

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
        eyebrow="Step 1 of 5"
        title="First, how will you be filing?"
        intro="This sets your standard deduction, which is the chunk of income that is not taxed. Not sure? Pick the closest one; you can change it any time."
      />
      <Card>
        <ChoiceCards
          legend="Your filing status"
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
      </Card>

      <Card>
        <h2>A few things about you</h2>
        <p className="muted">Tick anything that is true on December 31, 2024. Each one can raise your standard deduction.</p>
        <Check
          label="I am 65 or older"
          hint="You count as 65 if your 65th birthday is on or before January 1, 2025."
          checked={draft.primary.age65}
          onChange={(age65) => setPrimary({ age65 })}
        />
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
      </Card>
    </>
  );
}
