import * as React from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { DayPicker } from 'react-day-picker';
import { cn } from '@/lib/utils';
import { buttonVariants } from './button';

/** shadcn/ui Calendar: react-day-picker styled with the app's Tailwind tokens. */
export function Calendar({ className, classNames, showOutsideDays = true, ...props }: React.ComponentProps<typeof DayPicker>) {
  const navBtn = cn(buttonVariants({ variant: 'ghost', size: 'icon' }), 'size-8 p-0');
  return (
    <DayPicker
      showOutsideDays={showOutsideDays}
      className={cn('p-3', className)}
      classNames={{
        root: 'w-fit',
        months: 'relative flex flex-col gap-4',
        month: 'flex flex-col gap-3',
        month_caption: 'flex h-8 items-center justify-center px-8 text-sm font-medium',
        caption_label: 'text-sm font-medium',
        dropdowns: 'flex items-center justify-center gap-1.5 text-sm font-medium',
        dropdown_root:
          'relative inline-flex items-center rounded-md border border-input bg-background px-2 py-1 has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-ring',
        dropdown: 'absolute inset-0 cursor-pointer opacity-0',
        nav: 'absolute inset-x-0 top-0 flex items-center justify-between',
        button_previous: navBtn,
        button_next: navBtn,
        month_grid: 'w-full border-collapse',
        weekdays: 'flex',
        weekday: 'w-9 text-[0.8rem] font-normal text-muted-foreground',
        week: 'mt-1 flex w-full',
        day: 'relative size-9 p-0 text-center text-sm',
        day_button: cn(buttonVariants({ variant: 'ghost' }), 'size-9 p-0 font-normal'),
        selected: '[&>button]:bg-primary [&>button]:text-primary-foreground [&>button:hover]:bg-primary-hover',
        today: '[&>button]:border [&>button]:border-primary',
        outside: 'text-muted-foreground opacity-60',
        disabled: 'text-muted-foreground opacity-40',
        hidden: 'invisible',
        ...classNames,
      }}
      components={{
        Chevron: ({ orientation, className: c }) =>
          orientation === 'left' ? (
            <ChevronLeft className={cn('size-4', c)} />
          ) : orientation === 'right' ? (
            <ChevronRight className={cn('size-4', c)} />
          ) : (
            <span aria-hidden className={cn('pl-1 text-xs', c)}>
              ▾
            </span>
          ),
      }}
      {...props}
    />
  );
}
