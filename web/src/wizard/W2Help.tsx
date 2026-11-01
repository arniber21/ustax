import { useState } from 'react';
import { ChevronDown, FileText } from 'lucide-react';
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from '../components/ui/collapsible';
import { cn } from '@/lib/utils';

/** A simplified Form W-2 with boxes 1, 2 and 12 highlighted. Schematic, not to scale. */
export function W2Diagram({ className }: { className?: string }) {
  const box = 'fill-background stroke-border';
  const hi = 'fill-primary/10 stroke-primary';
  const txt = 'fill-muted-foreground';
  const strong = 'fill-primary font-semibold';
  return (
    <svg viewBox="0 0 520 250" role="img" aria-labelledby="w2-diagram-title" className={cn('h-auto w-full', className)}>
      <title id="w2-diagram-title">
        Simplified Form W-2. Box 1 (wages) is the first box at the top right of the form. Box 2 (federal income tax
        withheld) is right beside it. Box 12 is a column of four lettered rows (12a to 12d) lower on the right.
      </title>
      <rect x="1" y="1" width="518" height="248" rx="6" className="fill-muted stroke-border" strokeWidth="1.5" />
      {/* left column: employee and employer */}
      <rect x="12" y="12" width="236" height="38" rx="3" className={box} />
      <text x="20" y="35" fontSize="11" className={txt}>a  Employee’s SSN</text>
      <rect x="12" y="56" width="236" height="78" rx="3" className={box} />
      <text x="20" y="76" fontSize="11" className={txt}>c  Employer’s name, address</text>
      <rect x="12" y="140" width="236" height="98" rx="3" className={box} />
      <text x="20" y="160" fontSize="11" className={txt}>e  Employee’s name, address</text>
      {/* right column: money boxes */}
      <rect x="256" y="12" width="124" height="38" rx="3" className={hi} strokeWidth="2" />
      <text x="263" y="27" fontSize="10.5" className={strong}>1  Wages, tips</text>
      <text x="372" y="44" fontSize="11" textAnchor="end" className={strong}>50,000.00</text>
      <rect x="386" y="12" width="122" height="38" rx="3" className={hi} strokeWidth="2" />
      <text x="393" y="27" fontSize="10.5" className={strong}>2  Federal tax</text>
      <text x="500" y="44" fontSize="11" textAnchor="end" className={strong}>5,000.00</text>
      <rect x="256" y="56" width="124" height="38" rx="3" className={box} />
      <text x="263" y="71" fontSize="10" className={txt}>3  SS wages</text>
      <rect x="386" y="56" width="122" height="38" rx="3" className={box} />
      <text x="393" y="71" fontSize="10" className={txt}>4  SS tax</text>
      <rect x="256" y="100" width="124" height="34" rx="3" className={box} />
      <text x="263" y="114" fontSize="10" className={txt}>5  Medicare wages</text>
      <rect x="386" y="100" width="122" height="34" rx="3" className={box} />
      <text x="393" y="114" fontSize="10" className={txt}>6  Medicare tax</text>
      <rect x="256" y="140" width="124" height="98" rx="3" className={box} />
      <text x="263" y="156" fontSize="10" className={txt}>10, 11, 13, 14 …</text>
      <rect x="386" y="140" width="122" height="98" rx="3" className={hi} strokeWidth="2" />
      <text x="393" y="156" fontSize="10.5" className={strong}>12  Codes</text>
      {['a', 'b', 'c', 'd'].map((r, i) => (
        <g key={r}>
          <line x1="392" x2="502" y1={168 + i * 18} y2={168 + i * 18} className="stroke-primary/30" />
          <text x="394" y={180 + i * 18} fontSize="10" className={txt}>
            12{r}{i === 0 ? '   D   5,000.00' : ''}
          </text>
        </g>
      ))}
    </svg>
  );
}

/** "Where do I find this on my W-2?": collapsed help with the diagram and the three boxes people ask about. */
export function W2Help() {
  const [open, setOpen] = useState(false);
  return (
    <Collapsible open={open} onOpenChange={setOpen} className="rounded-lg border bg-muted/40">
      <CollapsibleTrigger asChild>
        <button
          type="button"
          className="flex w-full cursor-pointer items-center gap-2.5 rounded-lg bg-transparent px-4 py-3 text-left text-sm font-medium text-foreground hover:bg-accent/60"
        >
          <FileText aria-hidden="true" className="size-4 text-primary" />
          Where do I find this on my W-2?
          <ChevronDown aria-hidden="true" className={cn('ml-auto size-4 text-muted-foreground transition-transform', open && 'rotate-180')} />
        </button>
      </CollapsibleTrigger>
      <CollapsibleContent className="grid gap-4 border-t px-4 py-4">
        <W2Diagram className="rounded-md bg-background" />
        <dl className="m-0 grid gap-3 text-sm sm:grid-cols-3">
          <div>
            <dt className="font-semibold">Box 1: wages</dt>
            <dd className="m-0 text-muted-foreground">Top row, first box on the right. Your taxable pay for the year.</dd>
          </div>
          <div>
            <dt className="font-semibold">Box 2: federal tax withheld</dt>
            <dd className="m-0 text-muted-foreground">Right next to box 1. Tax already sent to the IRS for you.</dd>
          </div>
          <div>
            <dt className="font-semibold">Box 12: codes</dt>
            <dd className="m-0 text-muted-foreground">Lower right, rows 12a to 12d: a letter and an amount, like “D 5,000.00”.</dd>
          </div>
        </dl>
      </CollapsibleContent>
    </Collapsible>
  );
}
