// make openapi-check: validate api/openapi.json as OpenAPI 3.1 (offline: no external or http $refs are followed).
import SwaggerParser from '@apidevtools/swagger-parser';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const file = join(dirname(fileURLToPath(import.meta.url)), '..', 'openapi.json');
try {
  const d = await SwaggerParser.validate(file, { resolve: { external: false, http: false } });
  console.log(`openapi.json valid: OpenAPI ${d.openapi}, ${Object.keys(d.paths).length} paths, ${Object.keys(d.components.schemas).length} schemas`);
} catch (e) {
  console.error('openapi.json is not valid OpenAPI:', e.message);
  process.exit(1);
}
