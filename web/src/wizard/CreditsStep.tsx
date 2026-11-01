import { Link } from 'react-router';
import { Callout } from '../components';
import { isJoint, useDraft, type DependentDraft, type FlagsDraft, type HsaFilerDraft } from '../draft';
import { stepPath } from '../layout/steps';
import { MoneyField, SelectField } from './fields';
import { Check, ChoiceCards, FormSection, StepHeader, YesNo } from './ui';

function HsaPerson({
  who,
  path,
  value,
  onChange,
}: {
  who: 'you' | 'your spouse';
  path: 'primary' | 'spouse';
  value: FlagsDraft;
  onChange: (patch: Partial<HsaFilerDraft>) => void;
}) {
  const h = value.hsa;
  const you = who === 'you';
  return (
    <div className="grid gap-5">
      <YesNo
        legend={`Did ${who} put money into an HSA directly in 2024?`}
        hint="Deposits made yourself, not through an employer. Money from an employer is already on the W-2 (box 12, code W)."
        value={h.contributed}
        onChange={(contributed) => onChange({ contributed })}
      />
      {h.contributed && (
        <>
          <SelectField
            label={`${you ? 'Your' : 'Your spouse’s'} high-deductible health plan in 2024`}
            hint="Only a high-deductible plan lets you put money in an HSA. Your insurer's paperwork says if it is one."
            value={h.coverage}
            placeholder="Choose one"
            options={[
              { value: 'HdhpAllYear', label: 'Covered all year' },
              { value: 'HdhpPartOfYear', label: 'Covered part of the year' },
              { value: 'HdhpNoneOfYear', label: 'Not covered by one' },
            ]}
            onChange={(coverage) => onChange({ coverage })}
            path={`hsa.${path}.coverage`}
          />
          <SelectField
            label="Who did the plan cover?"
            value={h.type}
            placeholder="Choose one"
            options={[
              { value: 'SelfOnly', label: 'Just one person (self-only)' },
              { value: 'Family', label: 'More than one person (family)' },
              { value: 'BothSelfAndFamily', label: 'Both, at different times of the year' },
            ]}
            onChange={(type) => onChange({ type })}
            path={`hsa.${path}.type`}
          />
          <SelectField
            label="Medicare in 2024"
            hint="You cannot add to an HSA in months you are on Medicare."
            value={h.medicare}
            placeholder="Choose one"
            options={[
              { value: 'MedicareNoneOfYear', label: 'Not on Medicare' },
              { value: 'MedicarePartOfYear', label: 'On Medicare part of the year' },
              { value: 'MedicareAllYear', label: 'On Medicare all year' },
            ]}
            onChange={(medicare) => onChange({ medicare })}
            path={`hsa.${path}.medicare`}
          />
          <MoneyField
            label="Total you put in directly"
            hint="For tax year 2024, including deposits you made up to the filing deadline."
            path={`hsa.${path}.directContributions`}
            value={h.directContributions}
            onChange={(directContributions) => onChange({ directContributions })}
          />
        </>
      )}
    </div>
  );
}

function CareRow({ p, i, onChange }: { p: DependentDraft; i: number; onChange: (patch: Partial<DependentDraft>) => void }) {
  const label = p.name.trim() || `Person ${i + 1}`;
  const k = `dep.${p.id}`;
  return (
    <fieldset className="m-0 grid min-w-0 gap-5 rounded-lg border p-4 sm:p-5">
      <legend className="px-1 text-[0.9375rem] font-semibold">Care costs for {label}</legend>
      <MoneyField
        label={`What did you pay to care for ${label}?`}
        hint="Daycare, a babysitter, summer day camp (not overnight camp), or an adult care center, while you worked."
        path={`${k}.careExpenses`}
        value={p.careExpenses}
        onChange={(careExpenses) => onChange({ careExpenses })}
      />
      {(p.careExpenses ?? 0) > 0 && (
        <ChoiceCards
          legend="Who provided the care?"
          value={p.careProviderQualifies === null ? null : p.careProviderQualifies ? 'ok' : 'no'}
          options={[
            { value: 'ok', label: 'Someone else', desc: 'A daycare, a sitter, a relative who is not described below.' },
            {
              value: 'no',
              label: 'My spouse, their parent, someone I claim, or a child under 19',
              desc: 'Those payments do not count toward the credit.',
            },
          ]}
          onChange={(v) => onChange({ careProviderQualifies: v === 'ok' })}
          errorPath={`${k}.careProviderQualifies`}
        />
      )}
      <Check
        label={`${label} cannot care for themselves`}
        hint="They are physically or mentally unable, and lived with you more than half the year. This makes an older dependent count."
        checked={p.unableToSelfCare}
        onChange={(unableToSelfCare) => onChange({ unableToSelfCare })}
      />
    </fieldset>
  );
}

/** Step 6: child and dependent care, health savings accounts, and the yes/no questions behind the credits. */
export function CreditsStep() {
  const { draft, update } = useDraft();
  const joint = isJoint(draft);
  const people = draft.hasDependents ? draft.dependents : [];
  const hasBenefits = draft.w2s.some((w) => (w.dependentCare ?? 0) > 0);
  const setDep = (id: string, patch: Partial<DependentDraft>) =>
    update((d) => ({ ...d, dependents: d.dependents.map((p) => (p.id === id ? { ...p, ...patch } : p)) }));
  const setHsa = (who: 'primary' | 'spouse') => (patch: Partial<HsaFilerDraft>) =>
    update((d) => ({ ...d, [who]: { ...d[who], hsa: { ...d[who].hsa, ...patch } } }));

  return (
    <>
      <StepHeader
        eyebrow="Step 6 of 7"
        title="Credits and care costs"
        intro="What you paid for child and dependent care, health savings accounts, and a few questions that decide which credits you can take. Answer No to anything that does not apply."
      />

      <FormSection title="Child and dependent care" note="Form 2441. The credit is a share of what you paid, up to a limit.">
        <YesNo
          legend="Did you pay someone to care for a child under 13, or for a dependent who cannot care for themselves, so you could work or look for work?"
          hint="If you are married, this must also be true for your spouse (or they were a full-time student or disabled)."
          value={draft.cdcc.paid}
          onChange={(paid) => update((d) => ({ ...d, cdcc: { ...d.cdcc, paid } }))}
        />
        {draft.cdcc.paid && people.length === 0 && (
          <Callout tone="info" title="Add the person first">
            Care costs belong to the person you cared for. Add them on the <Link to={stepPath('dependents')}>Dependents step</Link>, then
            come back.
          </Callout>
        )}
        {draft.cdcc.paid && people.map((p, i) => <CareRow key={p.id} p={p} i={i} onChange={(patch) => setDep(p.id, patch)} />)}
        {draft.cdcc.paid && hasBenefits && (
          <MoneyField
            label="Total care costs for the year, for Form 2441, line 16"
            hint="Your W-2 shows employer dependent care benefits in box 10, so the form asks for the full amount you paid, including what that benefit covered."
            path="cdcc.totalQualified"
            value={draft.cdcc.totalQualified}
            onChange={(totalQualified) => update((d) => ({ ...d, cdcc: { ...d.cdcc, totalQualified } }))}
          />
        )}
      </FormSection>

      <FormSection title="Health savings account (HSA)" note="Form 8889">
        <YesNo
          legend="Did you or your spouse have HSA activity that is not on a W-2?"
          hint="Money you put in yourself, or money you took out. Your employer’s deposits are already on the W-2."
          value={draft.hsa.has}
          onChange={(has) => update((d) => ({ ...d, hsa: { ...d.hsa, has } }))}
        />
        {draft.hsa.has && (
          <>
            <HsaPerson who="you" path="primary" value={draft.primary} onChange={setHsa('primary')} />
            {joint && <HsaPerson who="your spouse" path="spouse" value={draft.spouse} onChange={setHsa('spouse')} />}
            <Callout tone="warn" title="Withdrawals are not collected yet">
              We do not ask about HSA withdrawals (Form 1099-SA), rollovers or extra deposits. If you had any, this part of
              your return is incomplete.
            </Callout>
          </>
        )}
      </FormSection>

      <FormSection
        title="Earned income and child tax credits"
        note="The credits themselves come from your income and the people you listed. These questions only rule you out."
      >
        <Check
          label="The IRS has disallowed my earned income credit in an earlier year"
          hint="If so, you may have to file Form 8862 to claim it again."
          checked={draft.credits.eitcImproperClaims}
          onChange={(eitcImproperClaims) => update((d) => ({ ...d, credits: { ...d.credits, eitcImproperClaims } }))}
        />
        <Check
          label="The IRS has disallowed my child tax credit in an earlier year"
          checked={draft.credits.ctcImproperClaims}
          onChange={(ctcImproperClaims) => update((d) => ({ ...d, credits: { ...d.credits, ctcImproperClaims } }))}
        />
        <Check
          label="I could be someone else’s qualifying child"
          hint="For example, a young adult who lives with a parent who supports them."
          checked={draft.credits.eitcQcOfAnother}
          onChange={(eitcQcOfAnother) => update((d) => ({ ...d, credits: { ...d.credits, eitcQcOfAnother } }))}
        />
      </FormSection>

      <Callout tone="warn" title="Marketplace health insurance (Form 1095-A) is not supported yet">
        If you or your family had a plan from the Health Insurance Marketplace, your premium tax credit is not in this result,
        and you may owe back some of what was paid for you, or be owed more. Do not rely on this result if you got a Form 1095-A.
      </Callout>
    </>
  );
}
