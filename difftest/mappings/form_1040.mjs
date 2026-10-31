// Mapping for catala/form_1040.catala_en (scope Form1040), issue #14: Form 1040 lines 1a-37.
// STRICT subset: scenarios that use only W-2 + interest and no credits/adjustments/other income.
// A scenario is outside the subset when the oracle has a non-zero value for any fact that a later module
// computes (the plug-in slots); the reason string lists the module(s), so the skip list is the category list.
// Run: make difftest SCOPE=form_1040. See also form_1040_plugged (all scenarios) and
// form_1040_unplugged (report only).
import { unpluggedInputs, outputs, categoriesOf } from '../form_1040_inputs.mjs';

export default {
  name: 'form_1040',
  scope: 'Form1040',
  file: 'catala/form_1040.catala_en',
  appliesTo: (facts) => {
    const cats = categoriesOf(facts);
    return cats.length === 0 ? true : `needs ${cats.join(' + ')}`;
  },
  inputs: unpluggedInputs,
  outputs,
};
