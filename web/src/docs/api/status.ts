/** Badge variant for an HTTP status: 2xx green, 4xx amber, 5xx red. */
export function statusVariant(code: number | string): 'success' | 'warning' | 'destructive' | 'secondary' {
  const n = Number(code);
  if (n >= 200 && n < 300) return 'success';
  if (n >= 400 && n < 500) return 'warning';
  if (n >= 500) return 'destructive';
  return 'secondary';
}

/** GET blue, POST green: the same convention as Swagger UI and Redoc, in the site's own colours. */
export const METHOD_CLASS: Record<string, string> = {
  GET: 'border-primary/30 bg-primary/10 text-primary',
  POST: 'border-success/30 bg-success-soft text-success',
};
