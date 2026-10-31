// Form1040 on ALL non-knocked-out scenarios, with every plug-in slot filled from the oracle's own value
// for the fact a later module computes (e.g. /earnedIncomeCredit). Checks the chain wiring (lines 1a-37)
// everywhere; it does NOT test the later modules. Run: make difftest SCOPE=form_1040_plugged
import { pluggedInputs, outputs } from '../form_1040_inputs.mjs';

export default {
  name: 'form_1040_plugged',
  scope: 'Form1040',
  file: 'catala/form_1040.catala_en',
  appliesTo: () => true,
  inputs: pluggedInputs,
  outputs,
};
