// Mapping for catala/educator_adjustment.catala_en (scope EducatorAdjustment): Schedule 1 line 11.
// Run: make difftest SCOPE=educator_adjustment
//
// The oracle has no /isMFJDependent row, so is_mfj_dependent is fed as false (a scenario that is an
// MFJ dependent would show as a failure of /educatorExpensesAdjustment). Missing writable expenses
// default to $0, as DF does for an unanswered optional Dollar (the amount is ignored unless the
// educator flag is set anyway).
import { scalar } from '../lib.mjs';

const OPTIONS = { tpDid: 'TpDid', spouseDid: 'SpouseDid', bothDid: 'BothDid', neither: 'Neither' };

export default {
  name: 'educator_adjustment',
  scope: 'EducatorAdjustment',
  file: 'catala/educator_adjustment.catala_en',
  appliesTo: () => true,
  inputs: {
    was_k12_educators: (f) => OPTIONS[f.get('/wasK12Educators')?.value ?? 'neither'],
    primary_educator_expenses_writable: scalar('/primaryEducatorExpensesWritable', { type: 'money', missing: '0' }),
    secondary_educator_expenses_writable: scalar('/secondaryEducatorExpensesWritable', { type: 'money', missing: '0' }),
    is_mfj_dependent: () => false,
  },
  outputs: [{ oracle: '/educatorExpensesAdjustment', catala: 'educator_expenses_adjustment', type: 'money' }],
};
