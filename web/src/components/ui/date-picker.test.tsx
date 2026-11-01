import { useState } from 'react';
import { describe, expect, it, vi } from 'vitest';
import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { DatePicker } from './date-picker';
import { Field } from '../Field';
import { fromLocalDate, parseIso, parseUs, toIso, toLocalDate, toLong, toUs } from '@/lib/isoDate';

// Radix popper measures with ResizeObserver, which jsdom lacks.
globalThis.ResizeObserver ??= class {
  observe() {}
  unobserve() {}
  disconnect() {}
};

function Harness({ initial = '', min, max, spy }: { initial?: string; min?: string; max?: string; spy?: (v: string) => void }) {
  const [v, setV] = useState(initial);
  return (
    <Field label="Date of birth">
      {(control) => (
        <DatePicker
          {...control}
          value={v}
          min={min}
          max={max ?? '2024-12-31'}
          calendarLabel="Choose date of birth"
          onChange={(x) => {
            setV(x);
            spy?.(x);
          }}
        />
      )}
    </Field>
  );
}

const input = () => screen.getByLabelText('Date of birth') as HTMLInputElement;
const openCalendar = () => userEvent.click(screen.getByRole('button', { name: /^Choose date of birth/ }));

describe('DatePicker', () => {
  it('shows an ISO value as MM/DD/YYYY and as a long date', () => {
    render(<Harness initial="1986-04-12" />);
    expect(input()).toHaveValue('04/12/1986');
    expect(screen.getByText('April 12, 1986')).toBeInTheDocument();
  });

  it('takes a typed US date and reports ISO', async () => {
    const spy = vi.fn();
    render(<Harness spy={spy} />);
    await userEvent.type(input(), '4/12/1986');
    expect(spy).toHaveBeenLastCalledWith('1986-04-12');
    expect(screen.getByText('April 12, 1986')).toBeInTheDocument();
    expect(input()).not.toHaveAttribute('aria-invalid');
  });

  it('selects from the calendar, closes it, and announces the choice', async () => {
    const spy = vi.fn();
    render(<Harness initial="1986-04-12" spy={spy} />);
    await openCalendar();
    const grid = screen.getByRole('grid');
    await userEvent.click(within(grid).getByRole('button', { name: /April 20th, 1986/ }));
    expect(spy).toHaveBeenLastCalledWith('1986-04-20');
    expect(input()).toHaveValue('04/20/1986');
    expect(screen.queryByRole('grid')).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Choose date of birth, selected April 20, 1986' })).toBeInTheDocument();
  });

  it('jumps by month and year dropdown without paging', async () => {
    const spy = vi.fn();
    render(<Harness spy={spy} />);
    await openCalendar();
    await userEvent.selectOptions(screen.getByRole('combobox', { name: /year/i }), '1975');
    await userEvent.selectOptions(screen.getByRole('combobox', { name: /month/i }), 'March');
    await userEvent.click(within(screen.getByRole('grid')).getByRole('button', { name: /March 9th, 1975/ }));
    expect(spy).toHaveBeenLastCalledWith('1975-03-09');
  });

  it('closes on Escape and keeps the value', async () => {
    render(<Harness initial="1986-04-12" />);
    await openCalendar();
    expect(screen.getByRole('grid')).toBeInTheDocument();
    await userEvent.keyboard('{Escape}');
    expect(screen.queryByRole('grid')).not.toBeInTheDocument();
    expect(input()).toHaveValue('04/12/1986');
  });

  it('opens the calendar from the keyboard', async () => {
    render(<Harness initial="1986-04-12" />);
    await userEvent.tab(); // input
    await userEvent.tab(); // calendar button
    expect(screen.getByRole('button', { name: /^Choose date of birth/ })).toHaveFocus();
    await userEvent.keyboard('{Enter}');
    expect(screen.getByRole('grid')).toBeInTheDocument();
  });

  it('flags text that is not a real date, and keeps it for validation', async () => {
    const spy = vi.fn();
    render(<Harness spy={spy} />);
    await userEvent.type(input(), '02/30/1986');
    await userEvent.tab();
    expect(spy).toHaveBeenLastCalledWith('02/30/1986');
    expect(screen.getByRole('alert')).toHaveTextContent(/MM\/DD\/YYYY/);
    expect(input()).toHaveAttribute('aria-invalid', 'true');
  });

  it('rejects dates outside min and max', async () => {
    const spy = vi.fn();
    render(<Harness spy={spy} min="1900-01-01" max="2024-12-31" />);
    await userEvent.type(input(), '01/01/2025');
    await userEvent.tab();
    expect(spy).toHaveBeenLastCalledWith('01/01/2025');
    expect(screen.getByRole('alert')).toHaveTextContent('Enter a date from 01/01/1900 to 12/31/2024.');
    await userEvent.clear(input());
    await userEvent.type(input(), '12/31/1899');
    expect(screen.getByRole('alert')).toBeInTheDocument();
    await userEvent.clear(input());
    await userEvent.type(input(), '12/31/2024');
    expect(spy).toHaveBeenLastCalledWith('2024-12-31');
    expect(screen.queryByRole('alert')).not.toBeInTheDocument();
  });

  it('disables calendar days after max', async () => {
    render(<Harness initial="2024-12-15" max="2024-12-20" />);
    await openCalendar();
    expect(within(screen.getByRole('grid')).getByRole('button', { name: /December 21st, 2024/ })).toBeDisabled();
    expect(within(screen.getByRole('grid')).getByRole('button', { name: /December 20th, 2024/ })).toBeEnabled();
  });

  it('clears the value when the text is erased', async () => {
    const spy = vi.fn();
    render(<Harness initial="1986-04-12" spy={spy} />);
    await userEvent.clear(input());
    expect(spy).toHaveBeenLastCalledWith('');
    expect(screen.queryByText('April 12, 1986')).not.toBeInTheDocument();
  });

  it('accepts typed ISO text too', async () => {
    const spy = vi.fn();
    render(<Harness spy={spy} />);
    await userEvent.type(input(), '1986-04-12');
    expect(spy).toHaveBeenLastCalledWith('1986-04-12');
  });
});

describe('ISO date helpers (time-zone safe)', () => {
  // `npm run test:tz` runs these under TZ=America/Los_Angeles and TZ=Asia/Tokyo.
  const edge = ['1999-12-31', '2000-01-01', '2024-12-31', '2024-01-01', '2024-02-29', '1986-04-12', '2024-03-10', '2024-11-03'];

  it.each(edge)('round-trips %s through the calendar Date and US text', (iso) => {
    const p = parseIso(iso)!;
    expect(toIso(fromLocalDate(toLocalDate(p)))).toBe(iso);
    expect(toIso(parseUs(toUs(p))!)).toBe(iso);
  });

  it('formats long dates', () => {
    expect(toLong(parseIso('2024-12-31')!)).toBe('December 31, 2024');
    expect(toLong(parseIso('2000-01-01')!)).toBe('January 1, 2000');
  });

  it('rejects non-dates', () => {
    expect(parseIso('2023-02-29')).toBeNull();
    expect(parseUs('13/01/2000')).toBeNull();
    expect(parseUs('1/1/00')).toBeNull();
  });

  it('typing a date near midnight gives the same ISO in this zone', async () => {
    const spy = vi.fn();
    render(<Harness spy={spy} />);
    await userEvent.type(input(), '12/31/2024');
    expect(spy).toHaveBeenLastCalledWith('2024-12-31');
    await userEvent.clear(input());
    await userEvent.type(input(), '01/01/2000');
    expect(spy).toHaveBeenLastCalledWith('2000-01-01');
  });

  it('picking from the calendar near New Year gives the same ISO in this zone', async () => {
    const spy = vi.fn();
    render(<Harness initial="2024-12-15" spy={spy} />);
    await openCalendar();
    await userEvent.click(within(screen.getByRole('grid')).getByRole('button', { name: /December 31st, 2024/ }));
    expect(spy).toHaveBeenLastCalledWith('2024-12-31');
  });
});
