import { MoneyInput, type MoneyInputProps } from '../components';
import { useStepError } from './stepErrors';

/** `MoneyInput` that shows the step's validation message for `path` once the person tries to continue. */
export function MoneyField({ path, ...rest }: Omit<MoneyInputProps, 'error'> & { path?: string }) {
  const error = useStepError(path);
  return <MoneyInput {...rest} path={path} error={error} />;
}
