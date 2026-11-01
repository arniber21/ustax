import type { FlagsDraft } from '../draft';
import { ChoiceSelectField, DateField } from './fields';
import { Check } from './ui';

/**
 * Per-filer details the credits need: date of birth, citizenship, Social Security number, student and
 * disability. Used for you (About step) and for your spouse (Your household step).
 */
export function PersonDetails({
  who,
  value,
  onChange,
  pathPrefix,
}: {
  /** `you` or `your spouse`, for the labels. */
  who: 'you' | 'your spouse';
  value: FlagsDraft;
  onChange: (patch: Partial<FlagsDraft>) => void;
  pathPrefix: 'primary' | 'spouse';
}) {
  const you = who === 'you';
  const name = you ? 'I' : 'My spouse';
  return (
    <>
      <DateField
        label={`${you ? 'Your' : 'Your spouse’s'} date of birth`}
        hint={`Age decides the standard deduction and several credits. If you leave it empty, we assume ${you ? 'you are' : 'your spouse is'} under 65.`}
        value={value.dob}
        onChange={(dob) => onChange({ dob })}
        path={`${pathPrefix}.dob`}
      />
      <ChoiceSelectField
        label={`${you ? 'Your' : 'Your spouse’s'} citizenship`}
        hint="Most credits need a U.S. citizen or a resident alien."
        value={value.citizenship}
        options={[
          { value: 'citizen', label: `${name} was a U.S. citizen all of 2024`, desc: 'Born or naturalized in the U.S.' },
          { value: 'resident', label: `${name} was a resident alien all of 2024`, desc: 'Not a citizen, but a green card holder or met the substantial presence test.' },
          { value: 'other', label: 'Neither of those', desc: 'For example a nonresident alien. Several credits will not apply.' },
        ]}
        onChange={(citizenship) => onChange({ citizenship })}
        path={`${pathPrefix}.citizenship`}
      />
      <Check
        label={`${name} ${you ? 'have' : 'has'} a Social Security number`}
        hint="The earned income credit needs one for everyone on the return. An ITIN is not the same thing."
        checked={value.hasSsn}
        onChange={(hasSsn) => onChange({ hasSsn })}
      />
      <Check
        label={`${name} was a full-time student in 2024`}
        hint="It changes who can claim the saver’s credit."
        checked={value.student}
        onChange={(student) => onChange({ student })}
      />
      <Check
        label={`${name} retired on permanent and total disability`}
        hint="Stopped working because of a disability that a doctor says is permanent. It can open the credit for the elderly or disabled."
        checked={value.retiredOnDisability}
        onChange={(retiredOnDisability) => onChange({ retiredOnDisability })}
      />
    </>
  );
}
