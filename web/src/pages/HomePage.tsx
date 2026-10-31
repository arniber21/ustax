import { ButtonLink } from '../components';

/** Welcome: one promise, one button. */
export function HomePage() {
  return (
    <div className="container welcome">
      <div className="welcome__copy">
        <p className="eyebrow">Tax year 2024</p>
        <h1>
          Do your taxes in minutes. <em>See the math proven.</em>
        </h1>
        <p className="lead">
          Answer a few friendly questions and watch your refund (or what you owe) update as you go. No jargon you
          haven’t been told about first.
        </p>
        <div className="row">
          <ButtonLink size="lg" to="/start/about">
            Let’s start
          </ButtonLink>
          <ButtonLink size="lg" variant="ghost" to="/trust">
            How do I know it’s right?
          </ButtonLink>
        </div>
        <p className="muted small">About 10 minutes. Nothing is filed or sent anywhere.</p>
      </div>
      <div className="welcome__art" aria-hidden="true">
        <div className="receipt">
          <span className="receipt__label">Your refund</span>
          <span className="receipt__amount num">$981</span>
          <span className="receipt__proof">✓ proven</span>
        </div>
      </div>
    </div>
  );
}
