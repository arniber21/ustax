import { useEffect, type ReactNode } from 'react';
import { useController, useForm, useFormContext } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { Form } from '@/components/ui/form';
import { useDraft } from '../draft';
import { draftSchema, type DraftFormValues } from './draftSchema';
import { formName } from './formName';

/**
 * react-hook-form over the wizard draft (shadcn/ui Form). The draft store stays the single source of
 * truth: the form's values follow it (`values`), fields still write through `useDraft().update`, and
 * `buildRequest` and `validateStep` are untouched. What the form adds is per-field state: a field is
 * "touched" once left, and from then on the zod schema (contract caps and enums) reports on it inline.
 */
export function DraftForm({ children }: { children: ReactNode }) {
  const { draft } = useDraft();
  const form = useForm<DraftFormValues>({
    values: draft as unknown as DraftFormValues,
    resolver: zodResolver(draftSchema),
    mode: 'onTouched',
    resetOptions: { keepTouched: true, keepErrors: true, keepDirty: true },
  });
  const { trigger } = form;
  // Values arrive from the store, not from RHF inputs, so re-check after each change.
  useEffect(() => {
    void trigger();
  }, [draft, trigger]);
  return <Form {...form}>{children}</Form>;
}

export interface BoundField {
  /** The zod message for this field, once it has been left at least once. */
  error?: string;
  /** Mark the field touched (call on blur). */
  onBlur?: () => void;
}

function useBound(name: string): BoundField {
  const { control } = useFormContext<DraftFormValues>();
  const { field, fieldState } = useController({ control, name: name as never });
  return { error: fieldState.isTouched ? fieldState.error?.message : undefined, onBlur: field.onBlur };
}

/** Renders `children` with the react-hook-form state of the field at draft `path` (if any form is around). */
export function WithBoundField({ path, children }: { path?: string; children: (b: BoundField) => ReactNode }) {
  const ctx = useFormContext();
  const { draft } = useOptionalDraft();
  const name = ctx && path && draft ? formName(path, draft) : null;
  if (!name) return <>{children({})}</>;
  return <Bound name={name}>{children}</Bound>;
}

function Bound({ name, children }: { name: string; children: (b: BoundField) => ReactNode }) {
  return <>{children(useBound(name))}</>;
}

/** `useDraft` that tolerates a missing provider (fields rendered on their own, e.g. in tests). */
function useOptionalDraft() {
  try {
    return useDraft();
  } catch {
    return { draft: null };
  }
}
