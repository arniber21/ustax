# JSON API contract (issue #49)

Contract version: `api_version` 1, schema file `api/schema.json` (JSON Schema draft 2020-12,
`schema_version` 1.2.0), tax year 2024. Consumers: the Lean server (#51 validation, #52 endpoint),
the React frontend (#72 to #82). Plain HTTP; TLS is terminated by a proxy (`docs/lean-http-server.md`).

Files:

| File | Role |
|---|---|
| `api/schema.json` | The contract. Request, success, unsupported, error, health and version shapes in `$defs`. |
| `api/knockout-reasons.json` | Every `UnsupportedReason.code` with category and Direct File fact. Generated from the Catala enum (`make api-reasons`). |
| `api/line-catalog.json` | Key of each `lines` entry to Form 1040 line, label, Catala output, DF fact. |
| `api/examples/*.json` | Request and response pairs: one per filing status, refund, balance due, W-2 plus interest, a family with two children, earned income credit, knocked out. Every response is the output of the Catala `ApiCalculator` (`make api-examples`). |
| `docs/api-mapping.md` | The reference mapping from this contract to the Catala `Calculator` inputs (issue #38): field tables, decoding and encoding rules, the defaults. |
| `api/fixtures/manifest.json` | Mock-server table (method, path, request, status, response) for the frontend (#74): supported, unsupported and every error status. |
| `make api-check` | Validates all of the above against the schema (below). |

## Endpoints

| Method and path | Success | Failure |
|---|---|---|
| `POST /calculate` (`Content-Type: application/json`, body at most 256 KiB) | 200 `CalculateSuccess` | 422 `CalculateUnsupported`; 400, 413, 415, 500 `ErrorResponse` |
| `GET /health` | 200 `{"status":"ok"}` | |
| `GET /version` | 200 `VersionResponse` (`api_version`, `schema_version`, `tax_year`, `calculator_version` = git commit) | |
| anything else | | 404 `not_found`, or 405 `method_not_allowed` for a known path with the wrong method |

Every body is `application/json; charset=utf-8`. The server holds no state: the same request gives
the same answer.

## Money: integer cents

Every money value, in requests and responses, is a **JSON integer number of cents**
(`$50,000.00` is `5000000`). Reasons:

- Lossless and identical to the verified core: Catala `money` and Lean `Money` are integer cents
  (`catala/CONVENTIONS.md` section 4), so the server converts with no arithmetic and no rounding.
- No float ever appears on the wire. A decimal string (`"50000.00"`) would need a parser with
  rules for leading zeros, signs, exponents and one or two decimals; an integer needs none.
- JavaScript reads it exactly: the schema caps `|value| <= 10^13` cents ($100 billion), far below
  2^53, so `JSON.parse` and `number` are safe and no BigInt is needed. Sums over the 20-item list
  caps stay below 2^53.

Rules for the validator (#51): a money field is accepted only as an integer literal. `1.5`, `1e2`
and `100.0` are rejected with `not_integer` (JSON Schema's `integer` also admits `100.0`; the
server must be stricter), as are strings and values outside the range. Fields that cannot be
negative on the form use `NonNegMoney`; only `social_security.net_benefits` (SSA-1099 box 5 may be
negative) uses signed `Money`.

**Rounding** is entirely the calculator's, per CONVENTIONS section 4: the server never rounds an
input. Inputs may carry cents; Direct File rounds each box to whole dollars where its XML does
(`Round`, ties away from zero), and so does the verified code. As a consequence every output line
is a whole-dollar amount, a multiple of 100 cents. The frontend must display the returned integers
and must not recompute or re-round them. Tax Table lookups use the row midpoint
(`R.stepwise_multiply`), so for example taxable income $35,400 gives $4,019.

## Request: `POST /calculate`

The request holds the writable facts the Catala top-level scope reads (`ApiCalculator`, which calls
`Calculator`; `docs/api-mapping.md` has the field-by-field mapping), with box-oriented names. Required: `api_version` (1), `tax_year` (2024), `filing_status`. Everything
else is optional; an absent list is empty, an absent money box is $0, an absent flag is `false`
(CONVENTIONS section 3: inputs are complete, so absent means the value Direct File would use).

```json
{
  "api_version": 1,
  "tax_year": 2024,
  "filing_status": "Single",
  "w2s": [{ "filer": "PrimaryFiler", "wages": 5000000, "federal_withholding": 500000 }]
}
```

| Property | Type | Catala input |
|---|---|---|
| `filing_status` | `Single`, `MarriedFilingJointly`, `MarriedFilingSeparately`, `HeadOfHousehold`, `QualifyingSurvivingSpouse` | `filing_status` (`Types.FilingStatus`) |
| `filers.primary` / `filers.secondary` | `{is_blind, age65_or_older, can_be_claimed_as_dependent}` and, since 1.2.0, `date_of_birth`, `will_be_claimed`, citizenship answers, `is_student`, `tin`, `disability`, `hsa`, `cdcc` | `FilerAnswers` and `FilerExtra` of `Calculator` |
| `filing_details` | `treat_as_mfs`, `is_widowed_in_tax_year`, `mfj_deceased_spouse_reached_age65`, `mfs_spouse_65_or_older`, `mfs_spouse_provides_no_benefits`, `treat_filers_as_dependents`, `has_foreign_accounts_or_trusts`, `combat_pay_election`, `combat_pay_election_made` | the 1.0 flags are folded into the filers' facts (`docs/api-mapping.md`) |
| `filing_answers` (1.2.0) | marital status, spouse's death, living apart, residence state, MFS answers | `Calculator.FilersInput` |
| `dependents[]` (1.2.0) | `Dependent`: the Direct File per-person facts of a household member | `Calculator.HouseholdMember` |
| `credits`, `cdcc`, `premium_tax_credit`, `screening` (1.2.0) | the credit, child care, premium tax credit (with Forms 1095-A) and screening answers, named as in Catala | `credits`, `cdcc_answers`, `ptc_answers`, `screening` |
| `w2s[]` | `FormW2`: boxes 1 to 11, `box12` object keyed by code letter, box 13 flags | `w2s` (`Form_w2s.FormW2`) |
| `interest_reports[]` | `Form1099Int` | `interest_reports` (`Interest.InterestReport`) |
| `form_1099g[]` | `Form1099G` | `Unemployment.Form1099G` |
| `form_1099misc[]` | `Form1099Misc` | `Form1099_misc.Form1099Misc` |
| `form_1099r[]` | `Form1099R` | `Form1099_rs.Form1099R` |
| `social_security` | `{net_benefits: [Money], federal_tax_withheld: [NonNegMoney] (1.2.0), lived_apart_all_year}` | `Social_security` inputs |
| `adjustments` | `educator_expenses`, `student_loan_interest`, `hsa` (1.2.0: Form 8889 answers and distributions) | `Educator_adjustment`, `Student_loan_adjustment`, `Hsa` inputs |
| `estimated_payments` | `{paid_estimated_taxes_or_from_last_year, amount, paid_under_different_name, paid_with_former_spouse}` | `Estimated_payments` inputs |

The mapping from each API key to the exact Catala field (for example W-2 `wages` is
`writable_wages`, 1099-INT `federal_tax_withheld` is `writable_tax_withheld`) is in the
`description` of the matching `$defs` entry. Naming follows the form box, not the Direct File fact
path, so the UI and a paper form agree; the conversion function in #51 is the single place that
knows both.

### Validation policy (for #51)

- **Unknown properties are rejected** (`additionalProperties: false` everywhere) with HTTP 400
  `unknown_field`, never ignored: a typo must not silently drop income.
- `api_version` other than 1 gives `unsupported_api_version`; `tax_year` other than 2024 gives
  `unsupported_tax_year`.
- Beyond the schema: `SecondaryFiler` is allowed only for `MarriedFilingJointly`
  (`filer_not_allowed`); at most one `SecondaryFiler` and one `PrimaryFiler` filer object, and no
  `filers.secondary` unless joint; dates must exist (`invalid_date`); lists hold at most 20 items
  (`too_many_items`; `dependents` too); `social_security.federal_tax_withheld` is no longer than `net_benefits` (`range`); box 12 codes are the letters in the schema.
- Implemented in Lean (#51, `lean/UsTax/Api`, spec `Request.Valid`); `make api-conformance` cross-checks it against this schema. The Lean reader is stricter than ajv in three documented ways: integer-valued float literals (`100.0`, `1e2`) are `not_integer`, duplicate object keys are `invalid_json`, and `SecondaryFiler`/impossible dates are refused (the schema cannot express them). Shape problems (phase 1) are reported before range/size/role problems (phase 2); a body with both shows the shape problems first.
- Duplicate persons (`duplicate_person`) apply once the household section lands.
- The body cap is 256 KiB: the server catches the `readAll` failure and answers 413.

### Coverage of the writable facts

Since schema 1.2.0 (issue #38) the calculator behind the API is the whole-return Catala scope
`Calculator`: every section the contract accepts is read, none is "accepted but not used". The only
requests whose sections are not all read are the ones that are knocked out (422), which stop at the
reasons.

| Writable facts | Status |
|---|---|
| Filing status, W-2s, 1099-INT, foreign accounts, combat pay | In API, computed |
| Per-filer blind, 65 or older, can be claimed, date of birth, citizenship; MFS/widow/dependent answers | In API, computed |
| 1099-G, 1099-MISC (Alaska PFD), 1099-R, SSA-1099, educator and student loan adjustments, estimated payments | In API, computed |
| HSA (Form 8889 answers, distributions) | In API since 1.2.0 (`adjustments.hsa`, `filers.*.hsa`), computed |
| Household: qualifying children, qualifying relatives, dependents (`dependents[]`), earned income credit, child tax credit and credit for other dependents, child and dependent care credit (`cdcc`), Saver's credit, elderly or disabled credit (`credits`), premium tax credit with Forms 1095-A (`premium_tax_credit`) | In API since 1.2.0, computed |
| Screening questions (digital assets, foreign trusts, IRA contributions, state questions) | In API since 1.2.0 (`screening`); they only feed knockouts |
| Itemized deductions, Schedule C/D/E, capital gains, dividends | Not supported by Direct File; excluded permanently. Sending them is `unknown_field`; situations that need them are knockouts (`IncomeSourcesNotSupported`) |
| Name, address, SSN, bank account, dates of birth (except filers', dependents' and the 1099-R recipient's) | Excluded: no tax effect; the calculator takes no personal data beyond the dates of birth the age tests need |
| Process answers (`flowHasSeenDeductions`, too-late-to-file) | Part of `screening` where a knockout reads them; the rest is decided server side or by the frontend flow |

Defaults for what a request leaves out are in `api/schema.json` (`default`) and in `docs/api-mapping.md`.
A client that collects an answer should send it: a default is the ordinary-filer answer, not a guess
about the person.

## Response 200: `CalculateSuccess`

```json
{
  "api_version": 1, "tax_year": 2024, "supported": true, "reasons": [],
  "outcome": "balance_due",
  "lines": { "wages": 5000000, "agi": 5000000, "standard_or_itemized_deductions": 1460000,
             "taxable_income": 3540000, "total_tax": 401900, "total_payments": 0,
             "overpayment": 0, "balance_due": 401900, "...": "see api/examples/single-w2-50k.response.json" }
}
```

- `outcome` is `refund` (line 34 > 0), `balance_due` (line 37 > 0) or `even`; at most one of
  `overpayment` and `balance_due` is non-zero.
- `lines` has one integer-cents entry per scalar output of the Catala `Form1040` scope that the
  Lean mirror implements: `wages` (1a), `employer_income_subtotal` (1z), `interest_income` (2b),
  `total_income` (9), `adjustments_to_income` (10), `agi` (11), `standard_or_itemized_deductions`
  (12), `total_deductions` (14), `taxable_income` (15), `tentative_tax_from_taxable_income` (16),
  `total_tentative_tax` (18), `non_refundable_credits` (21), `tax_less_non_refundable_credits` (22),
  `total_tax` (24), `total_withholding` (25d), `total_other_payments_refundable_credits` (32),
  `total_payments` (33), `overpayment` (34), `balance_due` (37). `api/line-catalog.json` gives label,
  form line, Catala output and DF fact for each, for the line-by-line view (#77) and rule links.
- Extensibility: new lines (Schedule 1/2/3 and 8812 values, credits, `qualified_business_income_deduction`)
  are added as new keys. Clients ignore keys they do not know; `line-catalog.json` says how to label them.
  A future optional `details` object may carry the "how we got this number" breakdown.

### Warnings (schema 1.1.0, #52; 1.2.0)

`CalculateSuccess` may carry an optional `warnings` array: `{code, path, message}` per request part that
validated but did not affect the result. `path` is an RFC 6901 pointer such as `/filing_details/treat_as_mfs`.
It is omitted when empty, so a typical request gets exactly the body shown above. Codes: `section_not_used`
(1.1.0: a section whose module was not wired yet; none since 1.2.0, every section is read) and
`field_superseded` (1.2.0: a 1.0 `filing_details` flag that the calculator now derives from the filers' facts,
see `docs/api-mapping.md`). The frontend should show the warning next to the result.

## Response 422: `CalculateUnsupported`

At least one knockout fired, so no return is computed (CONVENTIONS section 6; Direct File's
`/flowIsKnockedOut`). Status is 422: the request is well formed but describes a situation outside
the supported subset. There is no `lines` property.

```json
{ "api_version": 1, "tax_year": 2024, "supported": false,
  "reasons": [{ "code": "FlowKnockoutHasBonds", "category": "interest", "message": "Flow Knockout Has Bonds" }] }
```

- `reasons` is non-empty and lists every knockout that fired, in the order of the Catala
  `KnockoutReason` enumeration (`fired_knockouts` of `KnockoutsIncome`, issue #36).
- `code` is the `KnockoutReason` constructor name. The valid codes, with category and DF fact, are
  in `api/knockout-reasons.json`; `make api-reasons` regenerates it from `catala/knockouts_income.catala_en`
  and `docs/knockout-inventory.md`, and `make api-check` fails if it is stale.
- `category` groups codes for the frontend copy screens (#80): `credits`, `estimated_payments`,
  `filers`, `health_coverage`, `household`, `hsa`, `income`, `interest`, `process`, `retirement`,
  `social_security`, `state`, `unemployment`, `w2`. The module-to-category map is in
  `api/scripts/gen-reasons.mjs`.
- `message` is English fallback text (the constructor name split into words). The frontend owns
  the user-facing copy and keys it by `code`; for an unknown `code` it shows its category text.

### How the calculator plugs in (issue #38)

The Catala scope `ApiCalculator` (`catala/api_calculator.catala_en`) is the reference for the response:
its outputs `supported`, `reasons`, `outcome` and `lines` are the response fields (`docs/api-mapping.md`
has the decode and encode rules). `supported = not unsupported`; when false, `reasons` is the list of
`CalculatorKnockout` constructors with their categories, and the response is 422 without `lines`.
`api/knockout-reasons.json` lists every code (the household, credit and premium tax credit reasons are
`Extra...` constructors of `KnockoutReason`); `make api-reasons` regenerates it together with the reason
to category function of the Catala side (`catala/api_reasons.catala_en`). Reasons are additive (a minor
version).

## Errors: `ErrorResponse`

```json
{ "api_version": 1,
  "error": { "code": "invalid_request", "message": "The request body is invalid.",
             "details": [{ "path": "/w2s/0/wages", "code": "range", "message": "must be >= 0" }] } }
```

| HTTP | `error.code` | When |
|---|---|---|
| 400 | `invalid_json` | body is not JSON |
| 400 | `invalid_request` | shape, type, enum, range, integer-ness, cross-field rules; `details` lists every problem (RFC 6901 `path`) |
| 400 | `unknown_field` | an unknown property (also listed in `details`) |
| 400 | `unsupported_api_version`, `unsupported_tax_year` | version or year not served |
| 404 / 405 | `not_found`, `method_not_allowed` | wrong path or method |
| 413 | `payload_too_large` | body over 262144 bytes |
| 415 | `unsupported_media_type` | `Content-Type` is not `application/json` |
| 500 | `internal_error` | server fault; no tax logic is exposed |

Unsupported (422) is deliberately a different shape from errors: it is an expected, user-facing
outcome, not a fault. A client switches on `status`, then on `supported` or `error.code`.

## Versioning

- `api_version` is the major version, sent in every request and response; the server rejects other values.
- Additive changes (new optional request property, new response `lines` key, new reason code, new
  error code) bump the minor part of `schema_version` and keep `api_version`. Clients must ignore
  unknown response keys and show a generic message for unknown reason codes.
- Changing or removing a property, making an optional property required, or changing a unit bumps
  `api_version` (and the major of `schema_version`); the server then serves both for a transition.
- Request validation is strict, response consumption is lenient (Postel in the direction that
  protects tax data).

## Checking the contract

```sh
make api-check     # cd api && npm ci --ignore-scripts && node scripts/check.mjs
make api-reasons   # regenerate api/knockout-reasons.json and catala/api_reasons.catala_en after the Catala enums change
make api-examples  # recompute every example/fixture response with the Catala ApiCalculator (needs clerk)
```

`api-check` (Node 18 or later; `ajv` 8.17.1 pinned in `api/package-lock.json`, installed under
`api/node_modules`, not committed) validates:

1. every response in `api/fixtures/manifest.json` against the schema type for its status (200,
   422, other, health, version), and every request that should be valid against `CalculateRequest`;
   requests of 400 fixtures must violate the schema, except those marked `semantic_error`;
2. arithmetic invariants of each success response (AGI, taxable income floor, refund versus
   balance due, `outcome`, no negative line);
3. that every reason `code` and `category` exists in `api/knockout-reasons.json`, that file is
   fresh against the Catala enum, and the schema's `Lines.required` equals `api/line-catalog.json`;
4. one example per filing status, and an example file for every status class (200, 400, 413, 422).

The numbers in the examples are the output of the Catala scope `ApiCalculator` (`make api-examples`
recomputes them) and agree with the hand-worked returns of `catala/tests/test_calculator.catala_en`
(Tax Table midpoints): Single $50,000 gives tax $4,019, joint $70,000 gives $4,435, the family of four
$1,635 after the $4,000 child tax credit, the head of household with one child a $3,604 refund
(earned income credit $1,448, additional child tax credit $156). The unsupported examples show the response shape; their
exact reason lists are confirmed by `make test-server` (`scripts/server_integration.mjs`). That test found that box 3 (`government_bond_interest`) does not fire `FlowKnockoutHasBonds` (only boxes 9 to 13 do, `catala/interest.catala_en`), so `knocked-out-bond-interest.request.json` now uses box 9 (`private_activity_bond_interest`).

## Examples (curl)

```sh
curl -s -X POST http://localhost:8080/calculate -H 'Content-Type: application/json' \
  --data @api/examples/single-w2-50k.request.json     # 200, balance_due 401900
curl -s -X POST http://localhost:8080/calculate -H 'Content-Type: application/json' \
  --data @api/examples/knocked-out-bond-interest.request.json   # 422, FlowKnockoutHasBonds
```

| Example | Result |
|---|---|
| `single-w2-50k` | AGI 5000000, standard deduction 1460000, taxable income 3540000, tax 401900, balance due 401900 |
| `refund-single-w2-50k` | $5,000 withheld: overpayment 98100 |
| `balance-due-single-w2-50k` | $3,000 withheld: balance due 101900 |
| `mfj-two-w2s` | Joint, two W-2s, tax 443500 |
| `mfs-w2-40k`, `hoh-w2-60k`, `qss-w2-80k` | One per remaining filing status; head of household and surviving spouse each have one child (`dependents[]`), since those statuses need a qualifying person |
| `family-mfj-two-kids` | Joint, $80,000 of wages, two children: child tax credit $4,000, tax 163500, refund 136500 |
| `eitc-hoh-one-child` | Head of household, $40,000 of wages, one child: tax 0, earned income credit $1,448 plus additional child tax credit $156 (line 32 160400), refund 360400 |
| `refund-below-standard-deduction` | $10,000 of wages, no children: tax 0, earned income credit $632 (line 32 63200), refund 113200 |
| `knocked-out-hoh-no-qualifying-person` | 422, `ExtraFilingStatusNotEligible` (head of household without a qualifying person) |
| `single-w2-and-interest` | W-2 plus 1099-INT, tax 413900 (oracle scenario `single-50k`) |
| `knocked-out-bond-interest` | 422, `FlowKnockoutHasBonds` |
