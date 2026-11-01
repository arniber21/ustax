// Unit tests for the runner's pure logic (no Catala needed): `node --test difftest/selftest.mjs`.
import test from 'node:test';
import assert from 'node:assert/strict';
import { parseCsv, parseMoney, showValue, parseCatalaResult, compareOutputs, isKnockedOut, listFromCollection } from './lib.mjs';

test('csv quoting', () => {
  assert.deepEqual(parseCsv('a,"b ""q"", c",d\n1,,3\n'), [['a', 'b "q", c', 'd'], ['1', '', '3']]);
});

test('money parsing and printing', () => {
  assert.equal(parseMoney('39674.00'), 3967400n);
  assert.equal(parseMoney('$1,234.5'), 123450n);
  assert.equal(parseMoney('-$5.00'), -500n);
  assert.equal(showValue('money', -505n), '-5.05');
  assert.throws(() => parseMoney('1.234'));
});

test('catala result block', () => {
  const t = '[WARNING] x\n┌─[RESULT]─ S ─\n│ line_1a = $39,674.00\n│ ok = true\n└─\n';
  assert.deepEqual([...parseCatalaResult(t)], [['line_1a', '$39,674.00'], ['ok', 'true']]);
});

const mapping = { outputs: [{ oracle: '/wages', catala: 'line_1a', type: 'money' }] };
const facts = (value, completeness = 'Complete') => new Map([['/wages', { value, completeness }]]);

test('compare: pass, fail (spec rejects bad output), unchecked, error', () => {
  const cat = (v) => new Map([['line_1a', v]]);
  assert.equal(compareOutputs(mapping, facts('10.00'), cat('$10.00'))[0].status, 'pass');
  assert.equal(compareOutputs(mapping, facts('10.00'), cat('$10.01'))[0].status, 'fail');
  assert.equal(compareOutputs(mapping, facts('', 'Incomplete'), cat('$0.00'))[0].status, 'unchecked');
  assert.equal(compareOutputs(mapping, facts('0.00', 'Placeholder'), cat('$0.00'))[0].status, 'unchecked');
  assert.equal(compareOutputs(mapping, facts('10.00'), new Map())[0].status, 'error');
});

test('knockout policy: only Complete true is knocked out; Placeholder false is not', () => {
  assert.equal(isKnockedOut(new Map([['/flowIsKnockedOut', { value: 'true', completeness: 'Complete' }]])), true);
  assert.equal(isKnockedOut(new Map([['/flowIsKnockedOut', { value: 'false', completeness: 'Placeholder' }]])), false);
});

test('listFromCollection fills missing items with default', () => {
  const f = new Map([
    ['/c', { value: 'a;b', completeness: 'Complete' }],
    ['/c/#a/x', { value: '5.00', completeness: 'Complete' }],
  ]);
  assert.deepEqual(listFromCollection('/c', 'x', { missing: '0' })(f), [5, 0]);
  assert.deepEqual(listFromCollection('/c', 'x')(f), [5]);
});
