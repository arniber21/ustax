// Mapping for catala/difftest_smoke.catala_en (scope SmokeWages): Form 1040 line 1a.
// Template for module issues: copy this file, change the names, add rows to `outputs`/`inputs`.
import { listFromCollection } from '../lib.mjs';

export default {
  name: 'smoke',
  scope: 'SmokeWages',
  file: 'catala/difftest_smoke.catala_en',

  /** Return true, or a string reason to skip a scenario as outside this module's scope. */
  appliesTo: () => true,

  /**
   * Catala input name -> function(facts) -> JSON value (see lib.mjs helpers).
   * Direct File: /formW2s/* /wages = writableWages if answered, else $0 (formW2s.xml:1142).
   */
  inputs: {
    w2_box1_wages: listFromCollection('/formW2s', 'writableWages', { type: 'money', missing: '0' }),
  },

  /** Oracle path <-> Catala output variable. type: money | int | bool | string. */
  outputs: [
    { oracle: '/wages', catala: 'line_1a', type: 'money' },
  ],
};
