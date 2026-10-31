import { Badge, Callout, Card } from '../components';

interface Pillar {
  title: string;
  body: string;
  status: 'in-place' | 'coming';
}

/**
 * Stub for #82. Copy must stay within what CI actually checks; each pillar is
 * confirmed against the README trusted-surface section before that issue closes.
 */
const PILLARS: Pillar[] = [
  {
    title: 'The rules are written down as code',
    body: 'The tax rules are formalized in Catala, a language made for laws, so each line of the form traces to a rule.',
    status: 'in-place',
  },
  {
    title: 'Checked against the IRS’s own answers',
    body: 'We run hundreds of scenarios through both our math and the IRS Direct File reference and compare results.',
    status: 'in-place',
  },
  {
    title: 'Proofs, not just tests',
    body: 'Key properties of the calculator are proved in Lean, a proof assistant, so they hold for every input, not only the ones we tried.',
    status: 'coming',
  },
  {
    title: 'What we do not verify',
    body: 'An honest list of the edges: situations we don’t support, and parts of the system you still have to trust.',
    status: 'coming',
  },
];

export function TrustPage() {
  return (
    <div className="container narrow">
      <p className="eyebrow">Why you can trust this</p>
      <h1>Taxes you don’t have to take on faith.</h1>
      <p className="lead">
        Most tax software says “trust us.” We’d rather show our work, then prove it. Here’s how we know the number on
        your screen is right.
      </p>
      <Callout tone="info" title="Work in progress">
        This page is a first draft. Each claim will link to the exact proof or test that backs it.
      </Callout>
      <div className="stack">
        {PILLARS.map((p) => (
          <Card key={p.title} as="article">
            <Badge tone={p.status === 'in-place' ? 'good' : 'sun'}>{p.status === 'in-place' ? 'In place' : 'Being completed'}</Badge>
            <h2>{p.title}</h2>
            <p>{p.body}</p>
          </Card>
        ))}
      </div>
    </div>
  );
}
