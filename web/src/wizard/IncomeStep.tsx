import type { ReactNode } from 'react';
import { sumCents } from '../api';
import { Plus, Trash2 } from 'lucide-react';
import { Button, Callout, Select, Stat, StatGroup } from '../components';
import {
  BOX12_CODES,
  CODES_1099R,
  LIMITS,
  isJoint,
  newId,
  newInterest,
  newRetirement,
  newSsa,
  newUnemployment,
  newW2,
  useDraft,
  type Draft,
  type InterestDraft,
  type RetirementDraft,
  type UnemploymentDraft,
  type W2Draft,
} from '../draft';
import { MoneyField } from './fields';
import { useStepError } from './stepErrors';
import { Check, FormSection, More, Repeater, StepHeader, Where, WhoSelect } from './ui';

type ListKey = 'w2s' | 'interest' | 'unemployment' | 'retirement' | 'ssa';

/** Patch one item of a list inside the draft, by id. */
function patchItem<K extends ListKey>(key: K, id: string, patch: Partial<Draft[K][number]>) {
  return (d: Draft): Draft => ({
    ...d,
    [key]: (d[key] as { id: string }[]).map((x) => (x.id === id ? { ...x, ...patch } : x)),
  });
}
const removeItem = (key: ListKey, id: string) => (d: Draft): Draft => ({
  ...d,
  [key]: (d[key] as { id: string }[]).filter((x) => x.id !== id),
});

function Section({ title, form, children }: { title: string; form: string; children: ReactNode }) {
  return (
    <FormSection title={title} note={form} aria-label={title}>
      {children}
    </FormSection>
  );
}

/** Step 3: the money that came in, one form at a time. */
export function IncomeStep() {
  const { draft, update } = useDraft();
  const joint = isJoint(draft);

  const wages = sumCents(draft.w2s.map((w) => w.wages ?? 0));
  const withheld = sumCents([
    ...draft.w2s.map((w) => w.withholding ?? 0),
    ...draft.interest.map((i) => i.withheld ?? 0),
    ...draft.unemployment.map((u) => u.withheld ?? 0),
    ...draft.retirement.map((r) => r.withheld ?? 0),
  ]);
  const interest = sumCents(draft.interest.map((i) => i.interest ?? 0));

  return (
    <>
      <StepHeader
        eyebrow="Step 3 of 5"
        title="Income"
        intro="Add one entry for each tax form you received for 2024. Skip any you did not get. You can type cents; each box is rounded to the nearest dollar, as on the paper form."
      />

      <div className="mb-8">
      <StatGroup>
        <Stat label="W-2 wages entered" cents={wages} showCents />
        <Stat label="Interest entered" cents={interest} showCents />
        <Stat label="Federal tax withheld" cents={withheld} showCents note="By employers and other payers" />
      </StatGroup>
      </div>

      <Section title="Jobs (W-2)" form="Form W-2, “Wage and Tax Statement”. Your employer sends one for each job.">
        <Repeater
          noun="W-2"
          items={draft.w2s}
          max={LIMITS.maxItems}
          errorPath="w2s"
          empty="No W-2 yet. If you had a job in 2024, add it here."
          onAdd={() => update((d) => ({ ...d, w2s: [...d.w2s, newW2()] }))}
          onRemove={(id) => update(removeItem('w2s', id))}
          render={(w) => <W2Form w={w} joint={joint} />}
        />
      </Section>

      <Section title="Bank interest (1099-INT)" form="Form 1099-INT. Banks send one if you earned $10 or more in interest.">
        <Repeater
          noun="1099-INT"
          items={draft.interest}
          max={LIMITS.maxItems}
          errorPath="interest"
          empty="No interest yet. Savings accounts and CDs usually show up here."
          onAdd={() => update((d) => ({ ...d, interest: [...d.interest, newInterest()] }))}
          onRemove={(id) => update(removeItem('interest', id))}
          render={(i) => <InterestForm i={i} joint={joint} />}
        />
      </Section>

      <Section title="Unemployment (1099-G)" form="Form 1099-G. Your state sends it if you collected unemployment.">
        <Repeater
          noun="1099-G"
          items={draft.unemployment}
          max={LIMITS.maxItems}
          errorPath="unemployment"
          empty="Nothing here unless you collected unemployment in 2024."
          onAdd={() => update((d) => ({ ...d, unemployment: [...d.unemployment, newUnemployment()] }))}
          onRemove={(id) => update(removeItem('unemployment', id))}
          render={(u) => <UnemploymentForm u={u} joint={joint} />}
        />
      </Section>

      <Section title="Retirement withdrawals (1099-R)" form="Form 1099-R. Sent when you took money out of a pension, IRA or 401(k).">
        <Repeater
          noun="1099-R"
          items={draft.retirement}
          max={LIMITS.maxItems}
          errorPath="retirement"
          empty="Nothing here unless you took money out of a retirement account."
          onAdd={() => update((d) => ({ ...d, retirement: [...d.retirement, newRetirement()] }))}
          onRemove={(id) => update(removeItem('retirement', id))}
          render={(r) => <RetirementForm r={r} joint={joint} />}
        />
      </Section>

      <Section title="Social Security (SSA-1099)" form="Form SSA-1099. Sent in January if you got Social Security benefits.">
        <Repeater
          noun="SSA-1099"
          items={draft.ssa}
          max={LIMITS.maxSsaForms}
          errorPath="ssa"
          empty="Nothing here unless you got Social Security benefits in 2024."
          onAdd={() => update((d) => ({ ...d, ssa: [...d.ssa, newSsa()] }))}
          onRemove={(id) => update(removeItem('ssa', id))}
          render={(s) => (
            <MoneyField
              label="Box 5: net benefits"
              hint={
                <>
                  What you received minus anything you paid back. It can be negative if you repaid more than you got.{' '}
                  <Where>Box 5 is on the front of your SSA-1099, labeled “Net Benefits for 2024”.</Where>
                </>
              }
              path={`ssa.${s.id}.netBenefits`}
              nonNegative={false}
              value={s.netBenefits}
              onChange={(netBenefits) => update(patchItem('ssa', s.id, { netBenefits }))}
            />
          )}
        />
        {draft.filingStatus === 'MarriedFilingSeparately' && draft.ssa.length > 0 && (
          <Check
            label="My spouse and I lived apart for all of 2024"
            hint="This changes how much of your Social Security counts as income."
            checked={draft.livedApartAllYear}
            onChange={(livedApartAllYear) => update({ livedApartAllYear })}
          />
        )}
      </Section>

      <Callout tone="info" title="Other kinds of income">
        Only the forms above are supported. Self-employment, stock sales and other income are not, and entering them
        elsewhere would give a wrong result.
      </Callout>
    </>
  );
}

function Who({ role, joint, onChange }: { role: W2Draft['filer']; joint: boolean; onChange: (r: W2Draft['filer']) => void }) {
  return joint ? <WhoSelect value={role} onChange={onChange} /> : null;
}

function W2Form({ w, joint }: { w: W2Draft; joint: boolean }) {
  const { update } = useDraft();
  const set = (patch: Partial<W2Draft>) => update(patchItem('w2s', w.id, patch));
  const p = `w2.${w.id}`;
  const hasGov457 = w.box12.some((r) => r.code === 'G' || r.code === 'EE');
  return (
    <>
      <Who role={w.filer} joint={joint} onChange={(filer) => set({ filer })} />
      <MoneyField
        label="Box 1: wages, tips, other pay"
        hint={
          <>
            The main number. <Where>Box 1 is the first dollar box on your W-2, top left under your name and address.</Where>
          </>
        }
        path={`${p}.wages`}
        value={w.wages}
        onChange={(wages) => set({ wages })}
      />
      <MoneyField
        label="Box 2: federal income tax withheld"
        hint={
          <>
            Tax your employer already sent to the IRS for you.{' '}
            <Where>Box 2 sits right next to box 1. A bigger number here usually means a bigger refund.</Where>
          </>
        }
        path={`${p}.withholding`}
        value={w.withholding}
        onChange={(withholding) => set({ withholding })}
      />

      <More summary="More boxes: Social Security, Medicare, tips (optional)">
        <MoneyField label="Box 3: Social Security wages" path={`${p}.ssWages`} value={w.ssWages} onChange={(ssWages) => set({ ssWages })} />
        <MoneyField label="Box 4: Social Security tax withheld" path={`${p}.ssTax`} value={w.ssTax} onChange={(ssTax) => set({ ssTax })} />
        <MoneyField label="Box 5: Medicare wages" path={`${p}.medicareWages`} value={w.medicareWages} onChange={(medicareWages) => set({ medicareWages })} />
        <MoneyField label="Box 6: Medicare tax withheld" path={`${p}.medicareTax`} value={w.medicareTax} onChange={(medicareTax) => set({ medicareTax })} />
        <MoneyField label="Box 8: allocated tips" path={`${p}.allocatedTips`} value={w.allocatedTips} onChange={(allocatedTips) => set({ allocatedTips })} />
        <MoneyField label="Box 10: dependent care benefits" path={`${p}.dependentCare`} value={w.dependentCare} onChange={(dependentCare) => set({ dependentCare })} />
        <MoneyField label="Box 11: nonqualified plans" path={`${p}.nonQualified`} value={w.nonQualified} onChange={(nonQualified) => set({ nonQualified })} />
      </More>

      <fieldset className="m-0 grid min-w-0 gap-3 border-0 p-0">
        <legend className="mb-1 p-0 text-[0.9375rem] font-semibold">Box 12: codes</legend>
        <p className="m-0 max-w-prose text-sm text-muted-foreground">
          Retirement savings and benefits show up here as a letter plus an amount, like “D 5,000”.{' '}
          <Where>Box 12 is on the right side of the W-2, in lettered rows 12a to 12d. Add one entry per row.</Where>
        </p>
        {w.box12.map((r, i) => (
          <div className="grid items-end gap-3 rounded-md border bg-muted p-3 sm:grid-cols-[minmax(0,1fr)_11rem_auto]" key={r.id} role="group" aria-label={`Box 12 entry ${i + 1}`}>
            <Box12Code
              path={`${p}.box12.${r.id}.code`}
              value={r.code}
              onChange={(code) => set({ box12: w.box12.map((x) => (x.id === r.id ? { ...x, code } : x)) })}
            />
            <MoneyField
              label="Amount"
              path={`${p}.box12.${r.id}.amount`}
              value={r.amount}
              onChange={(amount) => set({ box12: w.box12.map((x) => (x.id === r.id ? { ...x, amount } : x)) })}
            />
            <Button variant="ghost" className="justify-self-start text-muted-foreground" aria-label={`Remove box 12 entry ${i + 1}`} onClick={() => set({ box12: w.box12.filter((x) => x.id !== r.id) })}>
              <Trash2 aria-hidden="true" />
              Remove
            </Button>
          </div>
        ))}
        <div>
          <Button variant="secondary" onClick={() => set({ box12: [...w.box12, { id: newId(), code: '', amount: null }] })}>
            <Plus aria-hidden="true" />
            Add a box 12 entry
          </Button>
        </div>
      </fieldset>
      {hasGov457 && (
        <Check
          label="My 457(b) plan is run by a government"
          hint="A state, city or school district rather than a private employer."
          checked={w.plan457bGovernmental}
          onChange={(plan457bGovernmental) => set({ plan457bGovernmental })}
        />
      )}

      <fieldset className="m-0 grid min-w-0 gap-3 border-0 p-0">
        <legend className="mb-1 p-0 text-[0.9375rem] font-semibold">Box 13: checkboxes</legend>
        <Check label="Statutory employee" checked={w.statutoryEmployee} onChange={(statutoryEmployee) => set({ statutoryEmployee })} />
        <Check label="Third-party sick pay" checked={w.thirdPartySickPay} onChange={(thirdPartySickPay) => set({ thirdPartySickPay })} />
      </fieldset>
    </>
  );
}

function Box12Code({ value, onChange, path }: { value: string; onChange: (c: string) => void; path: string }) {
  const error = useStepError(path);
  return (
    <Select
      label="Code"
      path={path}
      value={value}
      error={error}
      placeholder="Pick the letter"
      options={BOX12_CODES.map((c) => ({ value: c.code, label: `${c.code}: ${c.label}` }))}
      onChange={onChange}
    />
  );
}

function InterestForm({ i, joint }: { i: InterestDraft; joint: boolean }) {
  const { update } = useDraft();
  const set = (patch: Partial<InterestDraft>) => update(patchItem('interest', i.id, patch));
  const p = `interest.${i.id}`;
  return (
    <>
      <Who role={i.filer} joint={joint} onChange={(filer) => set({ filer })} />
      <MoneyField
        label="Box 1: interest income"
        hint={<>The interest you were paid. <Where>Box 1 is the first dollar box on the 1099-INT.</Where></>}
        path={`${p}.interest`}
        value={i.interest}
        onChange={(interest) => set({ interest })}
      />
      <MoneyField label="Box 4: federal income tax withheld" path={`${p}.withheld`} value={i.withheld} onChange={(withheld) => set({ withheld })} />
      <More summary="More boxes (optional)">
        <MoneyField label="Box 2: early withdrawal penalty" path={`${p}.earlyWithdrawalPenalty`} value={i.earlyWithdrawalPenalty} onChange={(earlyWithdrawalPenalty) => set({ earlyWithdrawalPenalty })} />
        <MoneyField label="Box 3: interest on U.S. savings bonds and Treasury obligations" path={`${p}.governmentBondInterest`} value={i.governmentBondInterest} onChange={(governmentBondInterest) => set({ governmentBondInterest })} />
        <MoneyField label="Box 6: foreign tax paid" path={`${p}.foreignTax`} value={i.foreignTax} onChange={(foreignTax) => set({ foreignTax })} />
        <MoneyField label="Box 8: tax-exempt interest" path={`${p}.taxExempt`} value={i.taxExempt} onChange={(taxExempt) => set({ taxExempt })} />
        <MoneyField label="Box 9: specified private activity bond interest" path={`${p}.privateActivityBond`} value={i.privateActivityBond} onChange={(privateActivityBond) => set({ privateActivityBond })} />
      </More>
    </>
  );
}

function UnemploymentForm({ u, joint }: { u: UnemploymentDraft; joint: boolean }) {
  const { update } = useDraft();
  const set = (patch: Partial<UnemploymentDraft>) => update(patchItem('unemployment', u.id, patch));
  const p = `unemployment.${u.id}`;
  return (
    <>
      <Who role={u.filer} joint={joint} onChange={(filer) => set({ filer })} />
      <MoneyField
        label="Box 1: unemployment compensation"
        hint={<>What your state paid you. <Where>Box 1 on the 1099-G. Your state’s unemployment website also has a copy.</Where></>}
        path={`${p}.amount`}
        value={u.amount}
        onChange={(amount) => set({ amount })}
      />
      <MoneyField label="Box 4: federal income tax withheld" path={`${p}.withheld`} value={u.withheld} onChange={(withheld) => set({ withheld })} />
    </>
  );
}

function RetirementForm({ r, joint }: { r: RetirementDraft; joint: boolean }) {
  const { update } = useDraft();
  const set = (patch: Partial<RetirementDraft>) => update(patchItem('retirement', r.id, patch));
  const p = `retirement.${r.id}`;
  const codesError = useStepError(`${p}.codes`);
  const toggle = (code: string, on: boolean) => set({ codes: on ? [...r.codes, code] : r.codes.filter((c) => c !== code) });
  return (
    <>
      <Who role={r.filer} joint={joint} onChange={(filer) => set({ filer })} />
      <fieldset className="m-0 grid min-w-0 gap-3 border-0 p-0" data-path={`${p}.codes`} data-invalid={codesError ? true : undefined}>
        <legend className="mb-1 p-0 text-[0.9375rem] font-semibold">Box 7: distribution code</legend>
        <p className="m-0 max-w-prose text-sm text-muted-foreground">
          One to four codes tell the IRS why you took the money out. <Where>Box 7 is in the middle of the 1099-R, usually a number or a letter.</Where>
        </p>
        {CODES_1099R.map((c) => (
          <Check
            key={c.code}
            label={c.label}
            checked={r.codes.includes(c.code)}
            onChange={(on) => toggle(c.code, on)}
          />
        ))}
        {codesError && (
          <p className="field-error m-0 text-sm font-semibold text-destructive" role="alert" data-error>
            {codesError}
          </p>
        )}
      </fieldset>
      <MoneyField label="Box 1: gross distribution" hint="Everything you took out, before any tax." path={`${p}.gross`} value={r.gross} onChange={(gross) => set({ gross })} />
      {!r.taxableBlank && (
        <MoneyField label="Box 2a: taxable amount" hint="The part that counts as income." path={`${p}.taxable`} value={r.taxable} onChange={(taxable) => set({ taxable })} />
      )}
      <Check label="Box 2a is blank on my form" checked={r.taxableBlank} onChange={(taxableBlank) => set({ taxableBlank })} />
      <Check label="Box 2b: total distribution is checked" checked={r.totalDistribution} onChange={(totalDistribution) => set({ totalDistribution })} />
      <Check label="Box 7: IRA/SEP/SIMPLE is checked" checked={r.iraSepSimple} onChange={(iraSepSimple) => set({ iraSepSimple })} />
      <MoneyField label="Box 4: federal income tax withheld" path={`${p}.withheld`} value={r.withheld} onChange={(withheld) => set({ withheld })} />
    </>
  );
}
