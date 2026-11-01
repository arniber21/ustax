import { Callout, Card } from '../components';
import { isJoint, useDraft, type FlagsDraft } from '../draft';
import { Check, StepHeader, YesNo } from './ui';

/** Step 2: spouse and household facts the calculator uses. */
export function HouseholdStep() {
  const { draft, update } = useDraft();
  const joint = isJoint(draft);
  const separate = draft.filingStatus === 'MarriedFilingSeparately';
  const setSpouse = (patch: Partial<FlagsDraft>) => update((d) => ({ ...d, spouse: { ...d.spouse, ...patch } }));
  const married = joint || separate;

  return (
    <>
      <StepHeader
        eyebrow="Step 2 of 5"
        title="Now, who’s in your household?"
        intro={married ? 'A few quick questions about your spouse.' : 'Just a couple of quick yes or no questions.'}
      />

      {joint && (
        <Card>
          <h2>Your spouse</h2>
          <p className="muted">Tick anything that is true for your spouse on December 31, 2024.</p>
          <Check label="My spouse is 65 or older" checked={draft.spouse.age65} onChange={(age65) => setSpouse({ age65 })} />
          <Check label="My spouse is blind" checked={draft.spouse.blind} onChange={(blind) => setSpouse({ blind })} />
          <Check
            label="Someone else can claim my spouse as a dependent"
            checked={draft.spouse.canBeClaimed}
            onChange={(canBeClaimed) => setSpouse({ canBeClaimed })}
          />
          <YesNo
            legend="Did your spouse pass away in 2024?"
            hint="We are sorry if so. You can still file a joint return for the year."
            value={draft.spouseDiedThisYear}
            onChange={(spouseDiedThisYear) => update({ spouseDiedThisYear })}
          />
          {draft.spouseDiedThisYear && (
            <YesNo
              legend="Would your spouse have turned 65 by the end of 2024?"
              value={draft.deceasedSpouseWas65}
              onChange={(deceasedSpouseWas65) => update({ deceasedSpouseWas65 })}
            />
          )}
        </Card>
      )}

      {separate && (
        <Card>
          <h2>Your spouse</h2>
          <YesNo
            legend="Is your spouse 65 or older?"
            hint="Same rule: their 65th birthday is on or before January 1, 2025."
            value={draft.mfsSpouse65}
            onChange={(mfsSpouse65) => update({ mfsSpouse65 })}
          />
        </Card>
      )}

      <Card>
        <h2>Kids and other dependents</h2>
        <YesNo
          legend="Do you support a child or another relative who lives with you?"
          hint="Anyone you could list as a dependent on your return."
          value={draft.hasDependents}
          onChange={(hasDependents) => update({ hasDependents })}
        />
        {draft.hasDependents && (
          <Callout tone="warn" title="Heads up: dependents aren’t in our math yet">
            We can’t work out the Child Tax Credit, the Earned Income Credit or dependent care credits yet, so your result
            won’t include them. They could lower your bill, so treat this number as a starting point.
          </Callout>
        )}
      </Card>

      <Card>
        <h2>One more</h2>
        <YesNo
          legend="Did you have a bank account, trust, or other financial account outside the U.S.?"
          hint="Having one doesn’t change your tax by itself. The IRS just asks."
          value={draft.foreignAccounts}
          onChange={(foreignAccounts) => update({ foreignAccounts })}
        />
      </Card>
    </>
  );
}
