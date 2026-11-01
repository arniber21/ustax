import { isJoint, useDraft } from '../draft';
import { MoneyField } from './fields';
import { Check, FormSection, StepHeader, Where, YesNo } from './ui';

/** Step 4: deductions that come off your income before it is taxed, plus tax you already paid by hand. */
export function AdjustmentsStep() {
  const { draft, update } = useDraft();
  const joint = isJoint(draft);
  const ed = draft.educator;
  const sl = draft.studentLoan;
  const ep = draft.estimated;

  return (
    <>
      <StepHeader
        eyebrow="Step 5 of 7"
        title="Adjustments and payments"
        intro="Amounts that come off your income before it is taxed, and tax you paid to the IRS yourself. Answer No to anything that does not apply."
      />

      <FormSection title="Teacher expenses" note="Schedule 1, line 11">
        <YesNo
          legend="Did you work as a K-12 teacher, counselor, principal or aide, and buy classroom supplies yourself?"
          hint="Up to $300 of what you paid out of pocket comes off your income."
          value={ed.primary}
          onChange={(primary) => update({ educator: { ...ed, primary } })}
        />
        {ed.primary && (
          <MoneyField
            label="How much did you spend?"
            hint="Books, supplies, computer equipment, and similar things you were not reimbursed for."
            path="educator.primaryExpenses"
            value={ed.primaryExpenses}
            onChange={(primaryExpenses) => update({ educator: { ...ed, primaryExpenses } })}
          />
        )}
        {joint && (
          <>
            <YesNo
              legend="Is your spouse a K-12 educator who bought classroom supplies too?"
              value={ed.spouse}
              onChange={(spouse) => update({ educator: { ...ed, spouse } })}
            />
            {ed.spouse && (
              <MoneyField
                label="How much did your spouse spend?"
                path="educator.spouseExpenses"
                value={ed.spouseExpenses}
                onChange={(spouseExpenses) => update({ educator: { ...ed, spouseExpenses } })}
              />
            )}
          </>
        )}
      </FormSection>

      <FormSection title="Student loan interest" note="Schedule 1, line 21">
        <YesNo
          legend="Did you pay interest on a student loan in 2024?"
          hint="Your loan servicer sends Form 1098-E if you paid $600 or more."
          value={sl.hadPayments}
          onChange={(hadPayments) => update({ studentLoan: { ...sl, hadPayments } })}
        />
        {sl.hadPayments && (
          <>
            <Check
              label="The loan was for my own (or my spouse’s or dependent’s) college costs"
              hint="Loans from family members or for a business don’t count."
              checked={sl.loansQualify}
              onChange={(loansQualify) => update({ studentLoan: { ...sl, loansQualify } })}
            />
            <MoneyField
              label="Interest you paid"
              hint={
                <>
                  Add up all your loans. <Where>Box 1 of Form 1098-E, or your servicer’s website under “tax documents”.</Where>
                </>
              }
              path="studentLoan.interest"
              value={sl.interest}
              onChange={(interest) => update({ studentLoan: { ...sl, interest } })}
            />
          </>
        )}
      </FormSection>

      <FormSection title="Tax you paid on your own" note="Form 1040, line 26">
        <YesNo
          legend="Did you send the IRS any tax payments during 2024, or apply last year’s refund to this year?"
          hint="People who freelance or have other income sometimes pay four times a year (“estimated taxes”)."
          value={ep.paid}
          onChange={(paid) => update({ estimated: { ...ep, paid } })}
        />
        {ep.paid && (
          <>
            <MoneyField
              label="Total you paid"
              hint="Add up every payment, plus any refund you chose to apply to 2024."
              path="estimated.amount"
              value={ep.amount}
              onChange={(amount) => update({ estimated: { ...ep, amount } })}
            />
            <Check
              label="Some of it was paid under a different name or Social Security number"
              checked={ep.differentName}
              onChange={(differentName) => update({ estimated: { ...ep, differentName } })}
            />
          </>
        )}
      </FormSection>
    </>
  );
}
