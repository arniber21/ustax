// Form1040 on ALL non-knocked-out scenarios with every slot left at its $0 default. The mismatches are
// the work that later modules (#21-#35) must remove; this scope is REPORT ONLY (excluded from SCOPE=all,
// never sets the exit code). Run: make difftest SCOPE=form_1040_unplugged
import { unpluggedInputs, outputs } from '../form_1040_inputs.mjs';

export default {
  name: 'form_1040_unplugged',
  reportOnly: true,
  scope: 'Form1040',
  file: 'catala/form_1040.catala_en',
  appliesTo: () => true,
  inputs: unpluggedInputs,
  outputs,
};
