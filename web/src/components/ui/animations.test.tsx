import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Sheet, SheetContent, SheetTitle, SheetDescription, SheetTrigger } from './sheet';
import { Popover, PopoverContent, PopoverTrigger } from './popover';
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from './accordion';

const css = readFileSync('src/index.css', 'utf8');

function TestSheet() {
  return (
    <Sheet>
      <SheetTrigger>open</SheetTrigger>
      <SheetContent>
        <SheetTitle>t</SheetTitle>
        <SheetDescription>d</SheetDescription>
      </SheetContent>
    </Sheet>
  );
}

globalThis.ResizeObserver ??= class {
  observe() {}
  unobserve() {}
  disconnect() {}
};

describe('shadcn default animations', () => {
  it('imports tw-animate-css', () => {
    expect(css).toMatch(/@import 'tw-animate-css';/);
  });

  it('keeps a single global reduced-motion rule with a near-zero (not none) duration so Radix presence finishes', () => {
    expect(css.match(/prefers-reduced-motion: reduce/g)).toHaveLength(1);
    expect(css).toMatch(/animation-duration: 0\.001ms !important/);
  });

  it('sheet content and overlay carry the open/close animation classes', async () => {
    render(<TestSheet />);
    await userEvent.click(screen.getByText('open'));
    const dialog = screen.getByRole('dialog');
    expect(dialog.className).toContain('data-open:animate-in');
    expect(dialog.className).toContain('data-closed:animate-out');
    expect(dialog.className).toContain('slide-in-from-right');
    expect(document.querySelector('[data-slot=sheet-overlay]')?.className).toContain('data-open:fade-in-0');
  });

  it('sheet closes with Escape', async () => {
    render(<TestSheet />);
    await userEvent.click(screen.getByText('open'));
    await userEvent.keyboard('{Escape}');
    expect(screen.queryByRole('dialog')).toBeNull();
  });

  it('popover content carries zoom/fade classes', async () => {
    render(
      <Popover>
        <PopoverTrigger>go</PopoverTrigger>
        <PopoverContent>hello</PopoverContent>
      </Popover>,
    );
    await userEvent.click(screen.getByText('go'));
    const el = document.querySelector('[data-slot=popover-content]');
    expect(el?.className).toContain('data-[state=open]:zoom-in-95');
    expect(el?.className).toContain('data-[state=closed]:animate-out');
  });

  it('accordion content uses accordion-down/up', () => {
    render(
      <Accordion type="single" collapsible defaultValue="a">
        <AccordionItem value="a">
          <AccordionTrigger>q</AccordionTrigger>
          <AccordionContent>answer</AccordionContent>
        </AccordionItem>
      </Accordion>,
    );
    const el = document.querySelector('[data-slot=accordion-content]');
    expect(el?.className).toContain('animate-accordion-down');
    expect(el?.className).toContain('animate-accordion-up');
  });
});
