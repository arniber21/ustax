/** The parts of api/provenance.json (schema: api/provenance.schema.json) the viewer reads. */
export interface Loc {
  file: string;
  line: number;
}
export interface Range {
  start: number;
  end: number;
}
export interface Heading extends Range {
  title: string;
  level?: number;
}
export interface Feed {
  instance?: string;
  file: string;
  scope?: string;
  variable: string;
  definition: Range;
  heading: Heading | null;
}
export interface Citation {
  id: string;
  kind: string;
  label: string;
  url: string;
  local?: { path: string; page?: number } | null;
  origin: 'catala' | 'curated';
  found_in: Loc[];
}
export interface Theorem {
  name: string;
  qualified: string;
  file: string;
  start: number;
  end: number;
  kind: string;
  in_comparator_set: boolean;
  statement: string;
  covers: string;
}
export interface DifftestEntry {
  mapping: string;
  mapping_file: string;
  catala_scope: string;
  catala_file: string;
  role: string;
  report_only: boolean;
}
export interface ProvLine {
  key: string;
  form: { form: string; line: string; label: string; pdf?: { path: string; page?: number; url: string } | null };
  description: string;
  direct_file_fact: { path: string; source?: Loc | null; matches_line_catalog?: boolean } | null;
  rule: {
    file: string;
    scope: string;
    variable: string;
    definition: Range & { comment_start?: number };
    heading: Heading | null;
    feeds: Feed[];
    depends_on?: { lines: { variable: string; api_key: string }[] };
  };
  citations: Citation[];
  proofs: { status: string; theorems: Theorem[] };
  lean: {
    file: string;
    definition: string;
    field: string;
    binding: { form: string } & Range;
    field_line?: number;
  };
  tests: { difftest: DifftestEntry[]; catala_unit_tests: { file: string }[] };
}
export interface FileEntry {
  path: string;
  kind: string;
  sha256: string;
  lines: number;
}
export interface Provenance {
  schema_version: string;
  tax_year: number;
  lines: Record<string, ProvLine>;
  files: FileEntry[];
}
