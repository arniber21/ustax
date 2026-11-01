import { describe, expect, it, vi } from 'vitest';
import { useState } from 'react';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router';
import {
  Badge,
  Button,
  ButtonLink,
  Callout,
  Card,
  Field,
  MoneyInput,
  ProgressBar,
  Select,
  Stat,
  StatGroup,
  Stepper,
  ThemeToggle,
  Tooltip,
} from '.';
import type { Cents } from '../api';

describe('Button', () => {
  it('fires onClick and defaults to type=button', async () => {
    const onClick = vi.fn();
    render(<Button onClick={onClick}>Go</Button>);
    const b = screen.getByRole('button', { name: 'Go' });
    expect(b).toHaveAttribute('type', 'button');
    await userEvent.click(b);
    expect(onClick).toHaveBeenCalledOnce();
  });
  it('does not fire when disabled', async () => {
    const onClick = vi.fn();
    render(<Button disabled onClick={onClick}>Go</Button>);
    await userEvent.click(screen.getByRole('button'));
    expect(onClick).not.toHaveBeenCalled();
  });
  it('ButtonLink renders a link', () => {
    render(<MemoryRouter><ButtonLink to="/trust">Why</ButtonLink></MemoryRouter>);
    expect(screen.getByRole('link', { name: 'Why' })).toHaveAttribute('href', '/trust');
  });
});

describe('Field', () => {
  it('links label, hint and error to the control', () => {
    render(
      <Field label="Name" hint="As on your ID" error="Required">
        {(p) => <input {...p} />}
      </Field>,
    );
    const input = screen.getByLabelText('Name');
    expect(input).toHaveAccessibleDescription('As on your ID Required');
    expect(input).toBeInvalid();
    expect(screen.getByRole('alert')).toHaveTextContent('Required');
  });
});

function Money({ initial = null }: { initial?: Cents | null }) {
  const [v, setV] = useState<Cents | null>(initial);
  return (
    <>
      <MoneyInput label="Wages" value={v} onChange={setV} />
      <output data-testid="cents">{v === null ? 'null' : v}</output>
    </>
  );
}

describe('MoneyInput', () => {
  it('reports integer cents', async () => {
    render(<Money />);
    await userEvent.type(screen.getByLabelText('Wages'), '$1,234.5');
    expect(screen.getByTestId('cents')).toHaveTextContent('123450');
  });
  it('normalizes on blur', async () => {
    render(<Money />);
    const input = screen.getByLabelText('Wages');
    await userEvent.type(input, '50000');
    await userEvent.tab();
    expect(input).toHaveValue('50000.00');
    expect(screen.getByTestId('cents')).toHaveTextContent('5000000');
  });
  it('rejects extra decimals instead of rounding', async () => {
    render(<Money />);
    await userEvent.type(screen.getByLabelText('Wages'), '1.234');
    expect(screen.getByRole('alert')).toHaveTextContent(/two decimals/);
    expect(screen.getByTestId('cents')).toHaveTextContent('null');
  });
  it('rejects negatives by default', async () => {
    render(<Money />);
    await userEvent.type(screen.getByLabelText('Wages'), '-5');
    expect(screen.getByRole('alert')).toHaveTextContent(/negative/);
  });
  it('clearing the box gives null', async () => {
    render(<Money initial={100} />);
    await userEvent.clear(screen.getByLabelText('Wages'));
    expect(screen.getByTestId('cents')).toHaveTextContent('null');
  });
});

describe('Select', () => {
  it('shows a placeholder and reports the choice', async () => {
    const onChange = vi.fn();
    render(
      <Select
        label="Filing status"
        value=""
        onChange={onChange}
        options={[
          { value: 'Single', label: 'Single' },
          { value: 'HeadOfHousehold', label: 'Head of household' },
        ]}
      />,
    );
    expect(screen.getByRole('option', { name: 'Choose one' })).toBeDisabled();
    await userEvent.selectOptions(screen.getByLabelText('Filing status'), 'HeadOfHousehold');
    expect(onChange).toHaveBeenCalledWith('HeadOfHousehold');
  });
});

describe('Stepper / ProgressBar', () => {
  const steps = [
    { id: 'a', label: 'One' },
    { id: 'b', label: 'Two' },
    { id: 'c', label: 'Three' },
  ];
  it('links completed steps when given hrefFor', () => {
    render(<MemoryRouter><Stepper steps={steps} current={2} hrefFor={(id) => `/s/${id}`} /></MemoryRouter>);
    expect(screen.getByRole('link', { name: /One/ })).toHaveAttribute('href', '/s/a');
    expect(screen.queryByRole('link', { name: /Three/ })).toBeNull();
  });
  it('marks the current step and exposes progress', () => {
    render(<Stepper steps={steps} current={1} />);
    expect(screen.getByText('Two', { selector: '.stepper-label' }).closest('li')).toHaveAttribute('aria-current', 'step');
    expect(screen.getByText('One', { selector: '.stepper-label' }).closest('li')).not.toHaveAttribute('aria-current');
    expect(screen.getByRole('progressbar')).toHaveAttribute('aria-valuenow', '2');
    expect(screen.getByText(/Step 2 of 3/)).toBeInTheDocument();
  });
  it('ProgressBar has a name and value', () => {
    render(<ProgressBar value={1} max={4} label="Upload" />);
    expect(screen.getByRole('progressbar', { name: 'Upload' })).toHaveAttribute('aria-valuenow', '1');
  });
});

describe('Card, Callout, Badge', () => {
  it('render their content', () => {
    render(
      <>
        <Card>card body</Card>
        <Callout tone="warn" title="Heads up">careful</Callout>
        <Badge tone="good">Proven</Badge>
      </>,
    );
    expect(screen.getByText('card body')).toBeInTheDocument();
    expect(screen.getByRole('note')).toHaveTextContent('Heads up');
    expect(screen.getByText('Proven')).toBeInTheDocument();
  });
});

describe('Tooltip', () => {
  it('opens on focus and closes on Escape', async () => {
    render(<Tooltip content="A flat amount">Standard deduction</Tooltip>);
    const trigger = screen.getByRole('button', { name: 'Standard deduction' });
    expect(screen.getByRole('tooltip', { hidden: true })).not.toBeVisible();
    await userEvent.tab();
    expect(trigger).toHaveFocus();
    expect(screen.getByRole('tooltip')).toBeVisible();
    expect(trigger).toHaveAccessibleDescription('A flat amount');
    await userEvent.keyboard('{Escape}');
    expect(screen.getByRole('tooltip', { hidden: true })).not.toBeVisible();
  });
});

describe('Stat', () => {
  it('formats integer cents', () => {
    render(
      <StatGroup>
        <Stat label="Taxable income" cents={3540000} />
        <Stat label="Refund" cents={98100} showCents />
      </StatGroup>,
    );
    expect(screen.getByText('$35,400')).toBeInTheDocument();
    expect(screen.getByText('$981.00')).toBeInTheDocument();
  });
});

describe('ThemeToggle', () => {
  it('pins and persists the theme', async () => {
    document.documentElement.dataset.theme = 'light';
    render(<ThemeToggle />);
    await userEvent.click(screen.getByRole('button', { name: 'Switch to dark mode' }));
    expect(document.documentElement.dataset.theme).toBe('dark');
    expect(localStorage.getItem('ustax-theme')).toBe('dark');
    expect(screen.getByRole('button', { name: 'Switch to light mode' })).toBeInTheDocument();
  });
});
