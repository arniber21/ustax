import { Callout, Field } from '../components';
import { Input } from '../components/ui/input';
import {
  LIMITS,
  RELATIONSHIPS,
  newDependent,
  useDraft,
  type Citizenship,
  type DependentDraft,
  type ResidencyDuration,
  type TinType,
} from '../draft';
import { DateField, MoneyField, SelectField } from './fields';
import { Check, FormSection, More, Repeater, StepHeader, YesNo } from './ui';

const TIN_OPTIONS: { value: TinType; label: string }[] = [
  { value: 'Ssn', label: 'Social Security number (SSN)' },
  { value: 'Itin', label: 'Individual taxpayer ID (ITIN)' },
  { value: 'Atin', label: 'Adoption taxpayer ID (ATIN)' },
  { value: 'NoTin', label: 'No taxpayer ID yet' },
];

const CITIZENSHIP_OPTIONS: { value: Citizenship; label: string }[] = [
  { value: 'citizen', label: 'U.S. citizen all of 2024' },
  { value: 'resident', label: 'Resident alien (not a citizen)' },
  { value: 'national', label: 'U.S. national' },
  { value: 'canadaMexico', label: 'Lives in Canada or Mexico' },
  { value: 'other', label: 'None of these' },
];

const RESIDENCY_OPTIONS: { value: ResidencyDuration; label: string }[] = [
  { value: 'AllYear', label: 'All year (12 months)' },
  { value: 'SixToElevenMonths', label: '6 to 11 months' },
  { value: 'LessThanSixMonths', label: 'Less than 6 months' },
];

const MONTH_OPTIONS = ['6', '7', '8', '9', '10', '11'].map((m) => ({ value: m, label: `${m} months` }));

/** Step 3: the people you support, one card each. Names stay on this device; the contract takes none. */
export function DependentsStep() {
  const { draft, update } = useDraft();
  const set = (id: string, patch: Partial<DependentDraft>) =>
    update((d) => ({ ...d, dependents: d.dependents.map((p) => (p.id === id ? { ...p, ...patch } : p)) }));

  return (
    <>
      <StepHeader
        eyebrow="Step 3 of 7"
        title="Dependents"
        intro="A dependent is a child or another relative you support. Claiming one can lower your tax through the child tax credit, the earned income credit and more."
      />

      <FormSection title="Who you support">
        <YesNo
          legend="Do you have children or other people you support?"
          hint="Include a child who lived with you more than half the year, and any relative whose living costs you mostly paid."
          value={draft.hasDependents}
          onChange={(hasDependents) =>
            update((d) => ({
              ...d,
              hasDependents,
              dependents: hasDependents && d.dependents.length === 0 ? [newDependent()] : d.dependents,
            }))
          }
        />
      </FormSection>

      {draft.hasDependents && (
        <FormSection
          title="The people you support"
          note="Add everyone, even if you are not sure you can claim them. The calculator makes that call from your answers."
        >
          <Repeater
            noun="Person"
            addLabel="Add a person"
            addAnotherLabel="Add another person"
            items={draft.dependents}
            max={LIMITS.maxDependents}
            empty="Nobody added yet."
            errorPath="dependents"
            onAdd={() => update((d) => ({ ...d, dependents: [...d.dependents, newDependent()] }))}
            onRemove={(id) => update((d) => ({ ...d, dependents: d.dependents.filter((p) => p.id !== id) }))}
            render={(p, i) => (
              <>
                <Field
                  label="First name (optional)"
                  hint="Only so you can tell people apart here. Names are never sent to the calculator."
                >
                  {(control) => (
                    <Input {...control} className="max-w-sm" value={p.name} autoComplete="off" onChange={(e) => set(p.id, { name: e.target.value })} />
                  )}
                </Field>
                <SelectField
                  label="How are they related to you?"
                  value={p.relationship}
                  placeholder="Choose one"
                  options={RELATIONSHIPS}
                  onChange={(relationship) => set(p.id, { relationship })}
                  path={`dep.${p.id}.relationship`}
                />
                <DateField
                  label="Date of birth"
                  hint="Age matters: for example, the child tax credit is for children under 17 at the end of 2024."
                  value={p.dob}
                  onChange={(dob) => set(p.id, { dob })}
                  path={`dep.${p.id}.dob`}
                />
                <SelectField
                  label="How long did they live with you in 2024?"
                  hint="Count time away at school, in the hospital, or on a short trip as living with you."
                  value={p.residency}
                  options={RESIDENCY_OPTIONS}
                  onChange={(residency) => set(p.id, { residency, months: residency === 'SixToElevenMonths' ? (p.months ?? 6) : null })}
                  path={`dep.${p.id}.residency`}
                />
                {p.residency === 'SixToElevenMonths' && (
                  <SelectField
                    label="How many months?"
                    value={p.months === null ? '' : String(p.months)}
                    placeholder="Choose the months"
                    options={MONTH_OPTIONS}
                    onChange={(m) => set(p.id, { months: Number(m) })}
                    path={`dep.${p.id}.months`}
                  />
                )}
                <SelectField
                  label="Their taxpayer ID"
                  hint="The earned income credit and child tax credit need the child to have a Social Security number."
                  value={p.tinType}
                  options={TIN_OPTIONS}
                  onChange={(tinType) => set(p.id, { tinType })}
                />
                <SelectField
                  label="Citizenship"
                  value={p.citizenship}
                  options={CITIZENSHIP_OPTIONS}
                  onChange={(citizenship) => set(p.id, { citizenship })}
                />
                <fieldset className="m-0 grid min-w-0 gap-4 border-0 p-0">
                  <legend className="mb-3 p-0 text-[0.9375rem] font-semibold">About {p.name.trim() || `person ${i + 1}`}</legend>
                  <Check label="Was a full-time student in 2024" checked={p.student} onChange={(student) => set(p.id, { student })} />
                  <Check
                    label="Is permanently and totally disabled"
                    hint="A doctor says they cannot do substantial work, and it will last a long time or end in death."
                    checked={p.disabled}
                    onChange={(disabled) => set(p.id, { disabled })}
                  />
                  <Check
                    label="I will claim this person on my return"
                    hint="Uncheck it if someone else, such as the other parent, will claim them."
                    checked={p.claim}
                    onChange={(claim) => set(p.id, { claim })}
                  />
                </fieldset>
                <fieldset className="m-0 grid min-w-0 gap-4 border-0 p-0">
                  <legend className="mb-3 p-0 text-[0.9375rem] font-semibold">Who paid for their support?</legend>
                  <Check
                    label="They paid for more than half of their own support"
                    hint="Food, housing, clothing, school and medical care, paid from their own money."
                    checked={p.ownSupport}
                    onChange={(ownSupport) => set(p.id, { ownSupport })}
                  />
                  <Check
                    label="I paid for more than half of their support"
                    hint="This matters most for a relative who is not your child."
                    checked={p.youSupport}
                    onChange={(youSupport) => set(p.id, { youSupport })}
                  />
                  <Check
                    label="Someone else could claim them as their child"
                    hint="For example, the other parent, or a relative they also lived with."
                    checked={p.claimableByOther}
                    onChange={(claimableByOther) => set(p.id, { claimableByOther })}
                  />
                </fieldset>
                <More summary="More about this person (married, own income)">
                  <Check label="They are married" checked={p.married} onChange={(married) => set(p.id, { married, jointReturn: married ? p.jointReturn : false })} />
                  {p.married && (
                    <Check
                      label="They file a joint return, other than to get a refund"
                      checked={p.jointReturn}
                      onChange={(jointReturn) => set(p.id, { jointReturn })}
                    />
                  )}
                  <MoneyField
                    label="Their own income in 2024"
                    hint="Wages and other taxable income. Leave empty if none."
                    path={`dep.${p.id}.grossIncome`}
                    value={p.grossIncome}
                    onChange={(grossIncome) => set(p.id, { grossIncome })}
                  />
                </More>
              </>
            )}
          />
        </FormSection>
      )}

      <Callout tone="info" title="What happens to these answers">
        They go to the calculator with the rest of your return. If it cannot use a section yet, the result page lists it, and
        no number is made up for it.
      </Callout>
    </>
  );
}
