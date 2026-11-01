/** The wizard's steps, in order. Step pages are filled in by #76 to #78. */
export const WIZARD_STEPS = [
  { id: 'about', label: 'About you', blurb: 'Your name, filing status and a few basics.' },
  { id: 'household', label: 'Household', blurb: 'Who lives with you and who you support.' },
  { id: 'income', label: 'Income', blurb: 'Your W-2s, interest and other money in.' },
  { id: 'adjustments', label: 'Adjustments and payments', blurb: 'Deductions from income and tax you paid yourself.' },
  { id: 'review', label: 'Review', blurb: 'A last look before we show your result.' },
] as const;

export type WizardStepId = (typeof WIZARD_STEPS)[number]['id'];

export const stepIndex = (id: string | undefined): number => WIZARD_STEPS.findIndex((s) => s.id === id);
export const stepPath = (id: WizardStepId): string => `/start/${id}`;
