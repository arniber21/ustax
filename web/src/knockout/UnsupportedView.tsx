import { useState } from 'react';
import type { ReasonCategory, UnsupportedReason } from '../api';
import { Button, ButtonLink, Callout, Card } from '../components';
import { categoryCopy, friendlyReason, type FriendlyReason } from './reasonCopy';
import '../results/results.css';

/** Things we do handle, so nobody leaves wondering. */
const SUPPORTED = [
  'Jobs paid on a W-2',
  'Bank interest (1099-INT)',
  'The standard deduction',
  'Single, married, head of household and more',
  'The child tax credit',
];

interface Group {
  category: ReasonCategory;
  reasons: FriendlyReason[];
}

/** Group reasons by category, keeping the order in which categories first appear and dropping repeats. */
export function groupReasons(reasons: readonly UnsupportedReason[]): Group[] {
  const groups = new Map<ReasonCategory, Group>();
  for (const r of reasons) {
    const g = groups.get(r.category) ?? { category: r.category, reasons: [] };
    if (!g.reasons.some((x) => x.code === r.code)) g.reasons.push(friendlyReason(r.code, r.category));
    groups.set(r.category, g);
  }
  return [...groups.values()];
}

/** Plain-text version of the list, for a preparer or a note to self. Contains no personal numbers. */
export function summaryText(groups: Group[]): string {
  const lines = ['Sumsure could not prepare my 2024 federal return because:'];
  for (const g of groups) {
    lines.push('', categoryCopy(g.category).title);
    for (const r of g.reasons) lines.push(`- ${r.what}`);
  }
  return lines.join('\n');
}

/** The friendly "not yet" screen: what we spotted, what it means, what to do instead. Never a dead end. */
export function UnsupportedView({ reasons }: { reasons: readonly UnsupportedReason[] }) {
  const groups = groupReasons(reasons);
  const [copied, setCopied] = useState<'idle' | 'yes' | 'no'>('idle');
  const copy = async () => {
    try {
      await navigator.clipboard.writeText(summaryText(groups));
      setCopied('yes');
    } catch {
      setCopied('no');
    }
  };

  return (
    <div className="container narrow knockout">
      <p className="eyebrow">Not yet</p>
      <h1>This one’s beyond what we can do right now.</h1>
      <p className="lead">
        Your situation includes {reasons.length === 1 ? 'something' : 'a few things'} Sumsure doesn’t handle yet. We’d
        rather tell you now than guess and hand you a wrong number. This isn’t a mistake on your part.
      </p>

      <h2 className="knockout__h">What we spotted</h2>
      {groups.map((g) => {
        const cc = categoryCopy(g.category);
        return (
          <Card key={g.category} className="knockout__group" aria-labelledby={`ko-${g.category}`}>
            <h3 id={`ko-${g.category}`}>{cc.title}</h3>
            <ul className="reasons">
              {g.reasons.map((r) => (
                <li key={r.code}>{r.what}</li>
              ))}
            </ul>
            <dl className="knockout__help">
              <div>
                <dt>What this means</dt>
                <dd>{cc.means}</dd>
              </div>
              <div>
                <dt>What to do instead</dt>
                <dd>{cc.todo}</dd>
              </div>
            </dl>
          </Card>
        );
      })}

      <Callout tone="good" title="You still have good, free options">
        <p>
          <strong>IRS Free File:</strong> if your income was about $84,000 or less for 2024, name-brand tax software is free
          through the IRS. You start at irs.gov/freefile, so you know it’s the free version.
        </p>
        <p>
          <strong>Free File Fillable Forms:</strong> electronic IRS forms for any income. You do the math yourself, which
          is the same as paper but faster to send.
        </p>
        <p>
          <strong>Free help from a person:</strong> IRS-certified volunteers (the VITA and TCE programs) prepare returns
          for free for many people. Search “VITA locator” on irs.gov.
        </p>
        <p className="muted">
          We don’t make any outside calls from this page, so those names are plain text. Limits change yearly; irs.gov has
          the current ones.
        </p>
      </Callout>

      <Callout tone="info" title="Your answers stay with you">
        Nothing you entered has been sent anywhere except to our own calculator. Come back to change an answer, and we’ll
        check again.
      </Callout>

      <Card>
        <h2>What we can do</h2>
        <ul className="ticks">
          {SUPPORTED.map((s) => (
            <li key={s}>{s}</li>
          ))}
        </ul>
      </Card>

      <div className="row">
        <ButtonLink to="/start/about">← Change my answers</ButtonLink>
        <Button variant="secondary" onClick={copy}>
          Copy this list for a preparer
        </Button>
        <ButtonLink variant="ghost" to="/trust">
          How Sumsure works
        </ButtonLink>
        <ButtonLink variant="ghost" to="/">
          Home
        </ButtonLink>
      </div>
      <p role="status" className="muted">
        {copied === 'yes' && 'Copied. Paste it anywhere.'}
        {copied === 'no' && 'Your browser blocked copying. You can select the text above instead.'}
      </p>
    </div>
  );
}
