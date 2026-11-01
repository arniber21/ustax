import { useState } from 'react';
import { ChevronRight } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Inline } from './Inline';
import { cn } from '@/lib/utils';
import { childrenOf, constraintsOf, resolve, schemaAnchor, typeLabel, type Schema } from './openapi';

const MAX_ENUM = 12;

function Chip({ children, mono = true }: { children: React.ReactNode; mono?: boolean }) {
  return (
    <span className={cn('inline-flex items-center rounded border bg-muted px-1.5 py-0.5 text-xs text-foreground', mono && 'font-mono')}>{children}</span>
  );
}

function EnumChips({ values }: { values: unknown[] }) {
  const shown = values.slice(0, MAX_ENUM);
  return (
    <span className="flex flex-wrap items-center gap-1" aria-label="Allowed values">
      {shown.map((v) => (
        <Chip key={String(v)}>{JSON.stringify(v)}</Chip>
      ))}
      {values.length > MAX_ENUM && <span className="text-xs text-muted-foreground">+{values.length - MAX_ENUM} more</span>}
    </span>
  );
}

/** One field: name, type, required/optional, then description, enum chips, constraints and default. Objects and arrays of objects expand lazily. */
export function SchemaNode({ name, schema, required, depth = 0 }: { name: string; schema: Schema; required: boolean; depth?: number }) {
  const [open, setOpen] = useState(false);
  const r = resolve(schema);
  const kids = childrenOf(schema);
  const t = typeLabel(schema);
  const cons = constraintsOf(schema);
  const enumValues = r.enum ?? (r.type === 'array' && r.items ? resolve(r.items).enum : undefined);
  const hasDefault = r.default !== undefined;

  return (
    <li className="py-2">
      <div className="flex flex-wrap items-baseline gap-x-2 gap-y-1">
        {kids ? (
          <button
            type="button"
            aria-expanded={open}
            onClick={() => setOpen(!open)}
            className="inline-flex cursor-pointer items-center gap-1 rounded-sm border-0 bg-transparent p-0 font-mono text-sm font-semibold text-foreground hover:text-primary focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring"
          >
            <ChevronRight aria-hidden="true" className={cn('size-4 shrink-0 text-muted-foreground transition-transform', open && 'rotate-90')} />
            {name}
          </button>
        ) : (
          <span className="font-mono text-sm font-semibold">{name}</span>
        )}
        <span className="text-xs text-muted-foreground">
          {t.ref ? (
            <a href={`#${schemaAnchor(t.ref)}`} className="font-mono">
              {t.ref}
            </a>
          ) : t.itemRef ? (
            <>
              array of{' '}
              <a href={`#${schemaAnchor(t.itemRef)}`} className="font-mono">
                {t.itemRef}
              </a>
            </>
          ) : null}
          {t.ref && ' · '}
          {!t.itemRef && <span className="font-mono">{t.type}</span>}
        </span>
        {required ? (
          <Badge variant="destructive" className="py-0">
            required
          </Badge>
        ) : (
          <span className="text-xs text-muted-foreground">optional</span>
        )}
      </div>
      {(r.description || enumValues || cons.length > 0 || hasDefault) && (
        <div className="mt-1 space-y-1.5 pl-0.5 text-sm text-muted-foreground">
          {r.description && (
            <p className="m-0">
              <Inline text={r.description} />
            </p>
          )}
          {enumValues && <EnumChips values={enumValues} />}
          {(cons.length > 0 || hasDefault) && (
            <span className="flex flex-wrap gap-1">
              {cons.map((c) => (
                <Chip key={c}>{c.length > 60 ? `${c.slice(0, 57)}...` : c}</Chip>
              ))}
              {hasDefault && <Chip>default {JSON.stringify(r.default)}</Chip>}
            </span>
          )}
        </div>
      )}
      {kids && open && (
        <div className="mt-2 ml-2 border-l pl-4">
          <SchemaProps schema={kids.schema} required={kids.required} depth={depth + 1} />
        </div>
      )}
    </li>
  );
}

/** The property list of an object schema. */
export function SchemaProps({ schema, required, depth = 0 }: { schema: Schema; required: string[]; depth?: number }) {
  const entries = Object.entries(schema.properties ?? {});
  if (entries.length === 0) return <p className="m-0 text-sm text-muted-foreground">No properties.</p>;
  return (
    <ul className="m-0 list-none divide-y p-0">
      {entries.map(([k, v]) => (
        <SchemaNode key={k} name={k} schema={v} required={required.includes(k)} depth={depth} />
      ))}
    </ul>
  );
}

/** A whole schema: header with the model name, then the tree (or the scalar summary for Money, enums, ...). */
export function SchemaTree({ schema, name }: { schema: Schema; name?: string }) {
  const r = resolve(schema);
  const t = typeLabel(schema);
  const modelName = name ?? t.ref;
  const cons = constraintsOf(schema);
  const kids = childrenOf(schema);
  const isArray = r.type === 'array';
  return (
    <div className="rounded-lg border">
      <div className="flex flex-wrap items-center gap-2 border-b bg-muted/50 px-4 py-2 text-sm">
        {modelName && <span className="font-mono font-semibold">{modelName}</span>}
        <span className="font-mono text-xs text-muted-foreground">{isArray ? t.type : (r.type ?? t.type)}</span>
        {r.additionalProperties === false && <span className="text-xs text-muted-foreground">no extra properties</span>}
      </div>
      <div className="px-4 py-1">
        {kids && !isArray ? (
          <>
            {r.description && (
              <p className="m-0 border-b py-2 text-sm text-muted-foreground">
                <Inline text={r.description} />
              </p>
            )}
            <SchemaProps schema={kids.schema} required={kids.required} />
          </>
        ) : (
          <div className="space-y-1.5 py-2 text-sm text-muted-foreground">
            {r.description && (
            <p className="m-0">
              <Inline text={r.description} />
            </p>
          )}
            {r.enum && <EnumChips values={r.enum} />}
            {cons.length > 0 && (
              <span className="flex flex-wrap gap-1">
                {cons.map((c) => (
                  <Chip key={c}>{c}</Chip>
                ))}
              </span>
            )}
            {kids && <SchemaProps schema={kids.schema} required={kids.required} />}
          </div>
        )}
      </div>
    </div>
  );
}
