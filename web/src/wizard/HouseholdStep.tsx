import { Globe2, Heart, House, ListChecks, UserRound } from 'lucide-react';
import { Callout } from '../components';
import { isJoint, useDraft, type Draft, type FlagsDraft } from '../draft';
import { SelectField } from './fields';
import { PersonDetails } from './PersonDetails';
import { Check, FormSection, StepHeader, YesNo } from './ui';

/** Step 2: marital details, where you lived, who paid for the home, and a few questions the IRS asks everyone. */
export function HouseholdStep() {
  const { draft, update } = useDraft();
  const joint = isJoint(draft);
  const separate = draft.filingStatus === 'MarriedFilingSeparately';
  const setSpouse = (patch: Partial<FlagsDraft>) => update((d) => ({ ...d, spouse: { ...d.spouse, ...patch } }));
  const unmarriedStatus = draft.filingStatus === 'Single' || draft.filingStatus === 'HeadOfHousehold' || draft.filingStatus === 'QualifyingSurvivingSpouse';
  const setScreening = (patch: Partial<Draft['screening']>) => update((d) => ({ ...d, screening: { ...d.screening, ...patch } }));

  return (
    <>
      <StepHeader
        eyebrow="Step 2 of 7"
        title="Your household"
        intro="Whether you were married, where you and your spouse lived, and who paid for your home. Children and other people you support come next."
      />

      <FormSection icon={Heart} title="Marital status" note="Your status on December 31, 2024.">
        <SelectField
          label="Which describes you?"
          hint="If you skip this, we use the filing status you picked."
          value={draft.maritalStatus}
          placeholder="Use my filing status"
          options={[
            { value: 'NeverMarried', label: 'Never married' },
            { value: 'Married', label: 'Married' },
            { value: 'Divorced', label: 'Divorced or legally separated' },
            { value: 'Widowed', label: 'Widowed' },
          ]}
          onChange={(maritalStatus) => update({ maritalStatus })}
          path="maritalStatus"
        />
        {draft.maritalStatus === 'Widowed' && (
          <SelectField
            label="When did your spouse die?"
            hint="It decides whether you can still use a joint return rate."
            value={draft.yearOfSpouseDeath}
            placeholder="Choose the year"
            options={[
              { value: 'DiedInTaxYear', label: 'In 2024' },
              { value: 'DiedTaxYearMinusOne', label: 'In 2023' },
              { value: 'DiedTaxYearMinusTwo', label: 'In 2022' },
              { value: 'DiedBeforeTaxYearMinusTwo', label: 'Before 2022' },
            ]}
            onChange={(yearOfSpouseDeath) => update({ yearOfSpouseDeath })}
            path="yearOfSpouseDeath"
          />
        )}
      </FormSection>

      {joint && (
        <FormSection icon={UserRound} title="Your spouse" note="Select anything that was true for your spouse on December 31, 2024.">
          <PersonDetails who="your spouse" value={draft.spouse} onChange={setSpouse} pathPrefix="spouse" />
          {draft.spouse.dob === '' && (
            <Check label="My spouse is 65 or older" checked={draft.spouse.age65} onChange={(age65) => setSpouse({ age65 })} />
          )}
          <Check label="My spouse is blind" checked={draft.spouse.blind} onChange={(blind) => setSpouse({ blind })} />
          <Check
            label="Someone else can claim my spouse as a dependent"
            checked={draft.spouse.canBeClaimed}
            onChange={(canBeClaimed) => setSpouse({ canBeClaimed })}
          />
          <YesNo
            legend="Did your spouse pass away in 2024?"
            hint="You can still file a joint return for the year of death."
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
        </FormSection>
      )}

      {separate && (
        <FormSection icon={UserRound} title="Your spouse" note="You file apart, so we only need to know how you lived.">
          <YesNo
            legend="Is your spouse 65 or older?"
            hint="Same rule: their 65th birthday is on or before January 1, 2025."
            value={draft.mfsSpouse65}
            onChange={(mfsSpouse65) => update({ mfsSpouse65 })}
          />
          <SelectField
            label="Did you live with your spouse in 2024?"
            hint="Living apart for the last six months can open credits that are otherwise closed to married people filing separately."
            value={draft.spouseLivedTogether}
            placeholder="Choose one"
            options={[
              { value: 'LivedTogetherMoreThanSixMonths', label: 'Yes, together for more than six months' },
              { value: 'LivedTogetherSixMonthsOrLess', label: 'Together for six months or less' },
              { value: 'LivedApartAllYear', label: 'No, we lived apart all year' },
            ]}
            onChange={(spouseLivedTogether) => update({ spouseLivedTogether })}
            path="spouseLivedTogether"
          />
        </FormSection>
      )}

      {unmarriedStatus && (
        <FormSection icon={House} title="Your home">
          <YesNo
            legend="Did you pay more than half of the cost of keeping up your home in 2024?"
            hint="Rent or mortgage interest, utilities, repairs, property tax, and food eaten at home. Head of household and the earned income credit look at this. It only counts if someone you support lived with you."
            value={draft.paidHomeUpkeep}
            onChange={(paidHomeUpkeep) => update({ paidHomeUpkeep })}
          />
        </FormSection>
      )}

      <FormSection icon={Globe2} title="Foreign accounts">
        <YesNo
          legend="Did you have a bank account, trust, or other financial account outside the U.S.?"
          hint="Having one doesn’t change your tax by itself. The IRS just asks."
          value={draft.foreignAccounts}
          onChange={(foreignAccounts) => update({ foreignAccounts })}
        />
        <YesNo
          legend="Did you create a foreign trust or receive money from one?"
          value={draft.screening.foreignTrustGrantor}
          onChange={(foreignTrustGrantor) => setScreening({ foreignTrustGrantor })}
        />
      </FormSection>

      <FormSection icon={ListChecks} title="Other questions the IRS asks" note="These do not change your tax here. They tell us whether your return needs a form we cannot do yet.">
        <YesNo
          legend="Did you receive digital assets, such as cryptocurrency, as a reward, payment or gift?"
          value={draft.screening.digitalReceived}
          onChange={(digitalReceived) => setScreening({ digitalReceived })}
        />
        <YesNo
          legend="Did you sell, trade or otherwise dispose of digital assets in 2024?"
          value={draft.screening.digitalDisposed}
          onChange={(digitalDisposed) => setScreening({ digitalDisposed })}
        />
        <YesNo
          legend="Did you put money into an IRA for 2024?"
          value={draft.screening.iraContributions}
          onChange={(iraContributions) => setScreening({ iraContributions })}
        />
        {(draft.screening.digitalReceived || draft.screening.digitalDisposed) && (
          <Callout tone="warn" title="We may not be able to finish your return">
            Digital asset activity needs forms we do not calculate yet. You can keep going, and the result page will say so
            if it stops us.
          </Callout>
        )}
      </FormSection>
    </>
  );
}
