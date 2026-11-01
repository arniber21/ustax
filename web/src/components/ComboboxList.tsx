import { Check } from 'lucide-react';
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from './ui/command';
import type { SelectOption } from './Select';
import { cn } from '@/lib/utils';

/** The searchable list inside `Combobox` (a lazy chunk: it carries cmdk). */
export default function ComboboxList<V extends string>({
  label,
  value,
  options,
  searchPlaceholder,
  onPick,
}: {
  label: string;
  value: V | '';
  options: readonly SelectOption<V>[];
  searchPlaceholder: string;
  onPick: (v: V) => void;
}) {
  return (
    <Command label={`Search ${label.toLowerCase()}`}>
      <CommandInput placeholder={searchPlaceholder} />
      <CommandList>
        <CommandEmpty>No match.</CommandEmpty>
        <CommandGroup>
          {options.map((o) => (
            <CommandItem key={o.value} value={`${o.value} ${o.label} ${o.desc ?? ''}`} onSelect={() => onPick(o.value)}>
              <Check aria-hidden="true" className={cn('size-4', o.value === value ? 'opacity-100' : 'opacity-0')} />
              <span className="grid">
                <span>{o.label}</span>
                {o.desc && <span className="text-xs text-muted-foreground">{o.desc}</span>}
              </span>
            </CommandItem>
          ))}
        </CommandGroup>
      </CommandList>
    </Command>
  );
}
