# Demo script: US Tax in 3 minutes

Audience: people who do not know what a theorem prover is. Technical add-on for judges at the end.

## Before you start (2 minutes, off stage)

```sh
export USTAX_NO_DEVBOX=1
make run                      # Lean server :8080, web app :5173
```

- Open <http://localhost:5173> in a clean window (or clear site data: answers are saved in the browser).
- Zoom the browser to 125 percent. Keep the Verification page in a second tab.
- Check `curl localhost:8080/health` answers. Run `make e2e` once beforehand if you want to be sure (about 20 seconds after the build).

Fallback if the live server is down: say so, then show the recorded path. `make web-dev` runs the web app on the saved API fixtures (`VITE_API_MOCK=1`, no server): the single filer with $50,000 wages gives a $981 refund there too. Or open `docs/screenshots/` (results, drawer, trust page). Do not pretend the mock is the live calculator.

## The 3 minutes

**0:00 Hook (15 s).** Home page. Say: "Tax software gives you a number and asks you to trust it. This one shows you why the number is right, down to the law and a machine-checked proof. It is a research project, nothing is filed."

**0:15 Enter a return (60 s).** Click Start your return.
1. Filing status: Married, filing together. Date of birth 04/12/1986 (type it, do not click the calendar). Say: "Plain-language questions, no tax jargon."
2. Your household: marital status Married. Next.
3. Dependents: Yes, add two children (born 03/01/2016 and 05/01/2019, relationship Son or daughter).
4. Income: Add a W-2. Wages 80,000, tax withheld 3,000.
5. Click Next through the remaining steps, then Calculate my return.

**1:15 Wow 1: the refund appears (20 s).** "Your refund: $1,365." Say: "Eighty thousand dollars of wages, three thousand already withheld, two kids. The child tax credit turns what would be an amount owed into a refund." Scroll to the Form 1040 table: line 11 AGI, line 15 taxable income, line 24 total tax, line 34 refund.

**1:35 Wow 2: How was this calculated? (50 s).** Next to line 15 click "How was this calculated?". The drawer opens. Walk down it:
- The law: the statute and IRS instructions with links.
- The rule: the Catala source for the line. Point at the label: "Readable rule, validated by differential testing against IRS Direct File. Not a proof." Say: "We say plainly what is tested and what is proved."
- What is proved: the Lean theorems for this line, with the Lean source on screen.
- How it is tested: the IRS test scenarios it agrees with.
Press Escape.

**2:25 Wow 3: it says no instead of guessing (20 s).** Go back, change filing status to Head of household and remove the children (or start a new return: head of household, no dependents). Calculate. The page says "This return can't be calculated yet" and lists why. Say: "When we cannot be sure, we say so and give no number."

**2:45 Close (15 s).** Open Verification. "Everything is on this page: what is proved, what is only tested, what you must trust, and what we do not cover." Scroll to the list of proved statements, then stop.

## 30-second technical add-on for judges

- **Comparator**: 9 main theorems (`lean/comparator.json`) are compared against a trusted statement file with `lake comparator`, replayed through the Lean kernel, axioms limited to `propext`, `Classical.choice`, `Quot.sound`. 31 more (`lean/comparator.extra.json`, `make comparator-extra`) cover each module versus the statute and the whole-return properties. The Tax Table result covers all 2,062 rows; at or above $100,000 it equals the Tax Computation Worksheet.
- **Forensics audit**: `make audit` scans for `sorry`, `native_decide`, extra axioms and vacuous theorems; 7,790 declarations, no high-severity finding (as of 2026-11-01).
- **Tested, not proved**: Catala rules versus the IRS Direct File engine on 157 scenarios, 5,360 fact checks agree. The link from Catala to Lean is tested, not proved, and the page says so.
- **Bugs found in the IRS reference implementation**: 33 logged in `docs/direct-file-bugs.md`. DF-BUG-8 is confirmed by running its engine: the 1099-R "percentage is zero" check strips the "0." characters, so `0.00` looks nonzero and a valid return is knocked out (4 of its own test returns). The rest are candidates, not yet confirmed. Found by Arnab Ghosh.
- **Real-stack end-to-end tests**: `make e2e`, Playwright against the Lean server, no mocks.
