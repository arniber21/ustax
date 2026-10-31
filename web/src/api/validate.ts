import Ajv2020 from 'ajv/dist/2020.js';
import type { ValidateFunction } from 'ajv/dist/2020.js';
import schema from '../../../api/schema.json';

// Same strictness as `make api-check` (api/scripts/check.mjs).
const ajv = new Ajv2020({ strict: true, allErrors: true });
ajv.addSchema(schema);

function compileDef(name: string): ValidateFunction {
  const v = ajv.getSchema(`${schema.$id}#/$defs/${name}`);
  if (!v) throw new Error(`api/schema.json has no $defs/${name}`);
  return v;
}

export type ContractType =
  | 'CalculateRequest'
  | 'CalculateSuccess'
  | 'CalculateUnsupported'
  | 'ErrorResponse'
  | 'HealthResponse'
  | 'VersionResponse';

const validators = new Map<ContractType, ValidateFunction>();

/** Returns a list of human-readable problems, empty when `doc` conforms to the contract type. */
export function contractProblems(type: ContractType, doc: unknown): string[] {
  let v = validators.get(type);
  if (!v) {
    v = compileDef(type);
    validators.set(type, v);
  }
  if (v(doc)) return [];
  return (v.errors ?? []).map((e) => `${e.instancePath || '/'} ${e.message ?? 'invalid'}`);
}
