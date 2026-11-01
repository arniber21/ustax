# API request to Calculator mapping (issue #38, schema 1.2.0)

One reference mapping between the JSON API (`api/schema.json`, `docs/api.md`) and the whole-return
Catala scope `Calculator` (`catala/calculator.catala_en`). The mapping is the Catala scope
`ApiCalculator` (`catala/api_calculator.catala_en`): the Lean calculator port (#48) and the server
(#52) implement exactly this, and `make difftest SCOPE=api_calculator` checks it against the 157
oracle scenarios that are not knocked out.

```
POST /calculate body ──decode──▶ ApiRequest ──ApiCalculator──▶ supported, reasons, outcome, lines ──encode──▶ response
  (cents, sparse)      (JSON)    (dollars, complete)   │
                                                       └─ calls Calculator with the mapped inputs
```

Only two steps are outside Catala, and both are mechanical JSON work:

- **Decode** (request to `ApiRequest`): fill every absent property with its schema `default`, divide
  money by 100, apply the renames below. Test implementation: `scripts/api_decode.mjs`, driven by
  `api/schema.json`.
- **Encode** (outputs to response): multiply `lines` by 100, spell `outcome` and each reason's
  `category` in the wire form, render each reason `code`. Test implementation: `scripts/api_catala.mjs`.

Both scripts are test code and untrusted; the Lean server has its own implementation of the same
rules, and `make difftest SCOPE=api_calculator` is the check that the rules (together with the Catala
mapping) lose nothing.

## Units: cents on the wire, dollars in Catala

The API carries every money value as an integer number of cents. Catala `money` is a decimal number of
dollars with cent precision. The conversion is exact and sits at the JSON boundary only:

| Direction | Rule |
|---|---|
| request to `ApiRequest` | every `Money` / `NonNegMoney` value `v` (cents) becomes `v / 100` dollars, for example `5000000` becomes `$50,000.00` |
| `ApiCalculator` to response | every `lines` value in dollars becomes `dollars * 100` cents |

`Calculator` rounds every box and line to whole dollars the way Direct File does (CONVENTIONS section
4), so every `lines` value is a whole number of dollars (a multiple of 100 cents); requests may carry
cents, which the calculator rounds as the form instructions say. The Lean port works in cents natively
and needs no conversion.

## Decoding

1. **Defaults.** Every absent property takes its schema `default`; with no `default`: `false` for a
   boolean, `0` for a money or integer, `[]` for a list, the first constructor for an enum without a
   `default`, and the default object for an absent object. `api/schema.json` is the single list of
   defaults. The ones that matter for tax: a filer is a US citizen for the full year, has an SSN
   (`tin.tin_is_ssn`), screening `income_sources_supported` is true, a dependent is claimed
   (`tp_claims`), is a US citizen with an SSN, lived with the filer all year (`residency_duration`
   `AllYear`, `months_lived_with_tp_in_us` 12), and the spouses lived together all year
   (`lived_together_all_year_with_spouse`) unless `social_security.lived_apart_all_year`.
2. **Optional dates.** `filers.*.date_of_birth` and `form_1099r[].recipient_date_of_birth` have no
   default. The decoder sets `date_of_birth_given` (resp. `recipient_date_of_birth_given`) to whether
   the request had the property and fills a placeholder date. `ApiCalculator` then takes the date if
   given, else for a filer 1950-06-15 if `age65_or_older` and 1985-06-15 if not, and for the
   1099-R recipient 1980-01-01 (age 44).
3. **Unspecified enums.** `filing_answers.marital_status` and `year_of_spouse_death` default to the
   Catala constructor `Unspecified`, which `ApiCalculator` resolves from the filing status
   (`MaritalOf`): Single and HeadOfHousehold are NeverMarried, MarriedFilingJointly and
   MarriedFilingSeparately are Married, QualifyingSurvivingSpouse is Widowed whose spouse died in
   2023 (`DiedTaxYearMinusOne`). The legacy `filing_details.is_widowed_in_tax_year` gives Widowed and
   `DiedInTaxYear`. Otherwise `year_of_spouse_death` defaults to `DiedBeforeTaxYearMinusTwo`.
4. **Renames.** `w2s[].box12` keys `A` to `II` become `code_a` to `code_ii`; `form_1099r[].distribution_code`
   items `2 4 7 B G H Other` become `Code2 Code4 Code7 CodeB CodeG CodeH OtherCode`; every other
   property keeps its name (the form tables below give the API name to Calculator field).
5. **Padding.** `social_security.federal_tax_withheld` (box 6) is padded with `0` to the length of
   `net_benefits`; a longer list is a validation error (`invalid_request`).
6. `api_version` and `tax_year` are checked by the server (400 `unsupported_api_version`,
   `unsupported_tax_year`) and are not part of `ApiRequest`.

## Encoding

| `ApiCalculator` output | Response |
|---|---|
| `supported` | `supported`. `false`: HTTP 422 `CalculateUnsupported` (no `lines`, no `outcome`); `true`: HTTP 200 `CalculateSuccess` |
| `lines` (19 fields, dollars) | `lines`, each `* 100` |
| `outcome` | `Refund` is `refund`, `BalanceDue` is `balance_due`, `Even` is `even` (`Even` is the contract's "zero": the form shows neither a refund nor an amount owed) |
| `reasons[]` | `{code, category, message}`: `code` is the name of the `KnockoutReason` constructor, taken from inside the `IncomeOrHsa` or `Household` wrapper (both hold a `KnockoutReason`); `category` is the snake_case of the `ApiReasonCategory` constructor (`HealthCoverage` is `health_coverage`, `W2` is `w2`); `message` is the English fallback of `api/knockout-reasons.json` |

`reasons` lists every knockout that fired, in the order of the `Calculator` knockout table (the income,
HSA and process reasons first, then the household, credit and premium tax credit reasons). `ApiReasonCategory`
and the reason-to-category function (`ApiReasonCategoryOf`) are generated by `make api-reasons` into
`catala/api_reasons.catala_en` from `api/knockout-reasons.json`'s source, so the category of every
code has one definition.

## Mapping, section by section

"Calc" is the `Calculator` input named in the right column. A row marked **derived** is an input
`Calculator` computes itself (a request field for it is folded into the facts it derives from).

### Return level

| API | `ApiRequest` | `Calculator` input |
|---|---|---|
| `filing_status` | `filing_status` | `filing_status` |
| `filers.primary`, `filers.secondary` | `filers.primary`, `.secondary` (`ApiFiler`) | `filers.primary_filer`, `.secondary_filer` (`FilerAnswers`), `primary_extra`, `secondary_extra` (`FilerExtra`); see the filer table |
| `filing_answers.*` | `filing_answers` (`ApiFilingAnswers`) | `filers` (`FilersInput`), see the filing answers table |
| `dependents[]` | `dependents` | `household` (list of `HouseholdMember`) |
| `w2s[]`, `interest_reports[]`, `form_1099g[]`, `form_1099misc[]`, `form_1099r[]` | same names | `income.w2s`, `.interest_reports`, `.form_1099gs`, `.form_1099miscs`, `.form_1099rs` |
| `filing_details.combat_pay_election` | `filing_details.combat_pay_election` | `income.combat_pay_election` |
| `filing_details.combat_pay_election_made` or `combat_pay_election` not `NoCombatPay` | | `income.combat_pay_election_made` |
| `social_security.net_benefits`, `.federal_tax_withheld` | `social_security.*` | `income.ssa_net_benefits`, `income.ssa_federal_tax_withheld` |
| `adjustments.educator_expenses.*` | `adjustments.educator_expenses` | `adjustments.was_k12_educators`, `.primary_educator_expenses_writable`, `.secondary_educator_expenses_writable` |
| `adjustments.student_loan_interest.*` | `adjustments.student_loan_interest` | `adjustments.had_student_loan_interest_payments`, `.student_loans_qualify`, `.student_loan_interest_amount` |
| `adjustments.hsa` | `adjustments.hsa` (`Calculator.HsaInput`, same names) | `adjustments.hsa` |
| `estimated_payments.*` | `estimated_payments` | `payments` (`paid_estimated_taxes_or_from_last_year`, `estimated_tax_payment_writable` is `amount`, `..._under_different_name` is `paid_under_different_name`, `paid_estimated_taxes_with_former_spouse` is `paid_with_former_spouse`) |
| `credits` | `credits` (`Calculator.CreditAnswers`, same names) | `credits` |
| `cdcc` | `cdcc` (`Calculator.CdccInput`, same names) | `cdcc_answers` |
| `premium_tax_credit` | `premium_tax_credit` (`Calculator.PtcInput`, same names; its `form1095_as` is the list of Forms 1095-A) | `ptc_answers` |
| `screening` | `screening` (`ApiScreening`: `Calculator.ScreeningAnswers` without `member_vitals`) | `screening` (with `has_foreign_accounts` or-ed with `filing_details.has_foreign_accounts_or_trusts`; `member_vitals` derived from `dependents[]`: `date_of_birth`, `deceased`, `tin_type` NoTin) |

### Filers

`filers.primary` / `filers.secondary` (`FilerFlags`). `filers.secondary` is allowed only for
`MarriedFilingJointly` (the server rejects it otherwise, `filer_not_allowed`).

| API property | Calculator target |
|---|---|
| `is_blind` | `FilerAnswers.is_blind` |
| `age65_or_older` | used only when `date_of_birth` is absent (above) |
| `date_of_birth` | `FilerAnswers.date_of_birth` |
| `can_be_claimed_as_dependent` | `FilerAnswers.can_be_claimed` (or `filing_details.treat_filers_as_dependents`) |
| `will_be_claimed`, `potential_claimer_must_file`, `potential_claimer_did_file` | `FilerAnswers.will_be_claimed`, `.potential_claimer_must_file` (both or-ed with `treat_filers_as_dependents`), `.potential_claimer_did_file` |
| `is_us_citizen_full_year`, `citizen_at_end_of_tax_year`, `noncitizen_resident_full_year`, `is_national` | `FilerAnswers.is_us_citizen_full_year`, `.writable_citizen_at_end_of_tax_year`, `.writable_is_noncitizen_resident_full_year`, `.writable_is_national` |
| `is_student` | `FilerExtra.is_student` |
| `tin` | `FilerExtra.tin` (`tin_is_ssn`, `ssn_employment_validity`, `has_ssn_only_for_benefits`) |
| `disability` | `FilerExtra.disability` (Schedule R answers; `has_w2_wages` is **derived** from the W-2s, the request value is ignored) |
| `hsa` | `FilerExtra.hsa` (Form 8889 per-filer answers, `Hsa.HsaFilerAnswers`, same names) |
| `cdcc` | `FilerExtra.cdcc` (Form 2441 per-filer answers, `CdccFilerAnswers`, same names) |

### Filing answers (`filing_answers`)

| API property | `FilersInput` field |
|---|---|
| `marital_status`, `year_of_spouse_death` | `marital_status`, `year_of_spouse_death` (defaults above) |
| `secondary_filer_date_of_death` | `secondary_filer_date_of_death` (default 2024-12-31) |
| `primary_filer_potential_claimer_filed_only_for_refund` | `primary_filer_potential_claimer_filed_only_for_refund` |
| `mfj_required_to_file`, `mfj_dependents_filing_for_credits` | same names |
| `lived_together_all_year_with_spouse` | `lived_together_all_year_with_spouse` (false if `social_security.lived_apart_all_year`) |
| `spouse_lived_together_months` | `spouse_lived_together_months` (`LivedApartAllYear` if `social_security.lived_apart_all_year`) |
| `lived_apart_last_six_months`, `separation_agreement` | `writable_lived_apart_last_six_months`, `writable_separation_agreement` |
| `can_file_jointly_year_of_spouse_death` | `can_file_jointly_year_of_spouse_death` (true for `QualifyingSurvivingSpouse`) |
| `in_registered_domestic_partnership` | `in_registered_domestic_partnership` |
| `residence_state` | `filer_residence_and_income_state` (default `FL`, a supported state) |
| `spouse_itemizes`, `mfs_living_spouse_filing_return`, `mfs_deceased_spouse_filing_return` | same names |
| `mfs_spouse_has_gross_income` | `mfs_spouse_has_gross_income` (or-ed with the legacy `filing_details.mfs_spouse_provides_no_benefits`) |
| `filing_details.mfs_spouse_65_or_older` | `mfs_spouse_65_or_older` |

### Legacy `filing_details` fields (schema 1.0 and 1.1)

Schema 1.0 took the standard deduction's answers as inputs. `Calculator` derives them from the filers'
facts, so these requests keep their meaning but the fields are folded in. A server SHOULD answer a
request that sets a superseded field with the warning `field_superseded` at its path (a `Warning`,
HTTP 200 stays).

| Field | Now |
|---|---|
| `treat_as_mfs` | **derived** (`filing_status = MarriedFilingSeparately`); ignored |
| `is_widowed_in_tax_year` | `marital_status` Widowed and `year_of_spouse_death` `DiedInTaxYear` when those are not given |
| `mfj_deceased_spouse_reached_age65` | the secondary filer counts as 65 or older when no `date_of_birth` is given |
| `mfs_spouse_provides_no_benefits` | counts as `mfs_spouse_has_gross_income` |
| `treat_filers_as_dependents` | both filers can be claimed, will be claimed and the claimer must file |
| `has_foreign_accounts_or_trusts` | or-ed into `screening.has_foreign_accounts` |
| `social_security.lived_apart_all_year` | the spouses did not live together at any time (see the filing answers) |

### Forms

Boxes are named as on the form. Every property not listed under a form has the same name in the
Calculator structure. Money properties are cents on the wire; `filer` is `PrimaryFiler` or
`SecondaryFiler`.

#### `w2s[]` (`FormW2` to `Form_w2s.FormW2`)

| API property | `Calculator` field |
|---|---|
| `filer` | `filer` |
| `wages` | `writable_wages` |
| `federal_withholding` | `writable_federal_withholding` |
| `oasdi_wages` | `writable_oasdi_wages` |
| `oasdi_withholding` | `writable_oasdi_withholding` |
| `medicare_wages` | `writable_medicare_wages` |
| `medicare_withholding` | `writable_medicare_withholding` |
| `allocated_tips` | `writable_allocated_tips` |
| `dependent_care_benefits` | `writable_dependent_care_benefits` |
| `non_qualified_plans` | `writable_non_qualified_plans` |
| `box12.A` | `uncollected_oasdi_tax_on_tips` |
| `box12.B` | `uncollected_medicare_tax_on_tips` |
| `box12.C` | `taxable_life_insurance_over_50k` |
| `box12.D` | `deferrals_401k` |
| `box12.E` | `deferrals_403b` |
| `box12.F` | `sarsep_deferrals` |
| `box12.G` | `deferrals_457b` |
| `box12.H` | `deferrals_501c18` |
| `box12.J` | `nontaxable_sick_pay` |
| `box12.K` | `golden_parachute_excise_tax` |
| `box12.L` | `expense_reimbursements` |
| `box12.M` | `uncollected_oasdi_tax_on_life_insurance_over_50k` |
| `box12.N` | `uncollected_medicare_tax_on_life_insurance_over_50k` |
| `box12.P` | `armed_forces_moving_expenses` |
| `box12.Q` | `writable_combat_pay` |
| `box12.R` | `archer_msa_contributions` |
| `box12.S` | `simple_contributions` |
| `box12.T` | `adoption_benefits` |
| `box12.V` | `nso_income` |
| `box12.W` | `employer_hsa_contributions` |
| `box12.Y` | `deferrals_409a` |
| `box12.Z` | `nqdc_deferrals` |
| `box12.AA` | `roth401k_contributions` |
| `box12.BB` | `roth403b_contributions` |
| `box12.DD` | `health_coverage_cost` |
| `box12.EE` | `roth457b_contributions` |
| `box12.FF` | `qsehra_benefits` |
| `box12.GG` | `income_83i` |
| `box12.HH` | `deferrals_83i` |
| `box12.II` | `non_taxable_medicaid_waiver_payments` |
| `plan_457b_is_governmental` | `plan_457b_is_governmental` |
| `statutory_employee` | `statutory_employee` |
| `third_party_sick_pay` | `third_party_sick_pay` |

#### `interest_reports[]` (`Form1099Int` to `Interest.InterestReport`)

| API property | `Calculator` field |
|---|---|
| `filer` | `filer` |
| `has_1099` | `has_1099` |
| `no_1099_amount` | `no_1099_amount` |
| `interest_income` | `writable_1099_amount` |
| `early_withdrawal_penalty` | `writable_early_withdrawl_penalty_amount` |
| `government_bond_interest` | `writable_interest_on_government_bonds` |
| `federal_tax_withheld` | `writable_tax_withheld` |
| `foreign_tax_paid` | `writable_foreign_tax_paid` |
| `tax_exempt_interest` | `writable_tax_exempt_interest` |
| `private_activity_bond_interest` | `writable_specified_private_activity_bond_interest` |
| `market_discount` | `writable_market_discount` |
| `bond_premium` | `writable_bond_premium` |
| `bond_premium_treasury` | `writable_bond_premium_on_treasury_obligations` |
| `bond_premium_tax_exempt` | `writable_bond_premium_on_tax_exempt_bond` |
| `state_is_different` | `state_is_different_state` |
| `state_tax_withheld` | `writable_state_tax_withheld` |
| `facta_filing_required` | `facta_filing_required` |

#### `form_1099g[]` (`Form1099G` to `Unemployment.Form1099G`)

| API property | `Calculator` field |
|---|---|
| `filer` | `filer` |
| `unemployment_compensation` | `amount` |
| `repaid_this_year_for_this_year` | `writable_amount_paid_back_for_benefits_in_tax_year` |
| `repaid_this_year_for_earlier_year` | `writable_amount_paid_back_for_benefits_before_tax_year` |
| `federal_tax_withheld` | `writable_federal_tax_withheld` |
| `state_is_different` | `state_is_different_state` |

#### `form_1099misc[]` (`Form1099Misc` to `Form1099_misc.Form1099Misc`)

| API property | `Calculator` field |
|---|---|
| `filer` | `filer` |
| `is_alaska_pfd` | `is_alaska_pfd` |
| `other_income` | `writable_other_income` |
| `federal_withholding` | `writable_federal_withholding` |

#### `form_1099r[]` (`Form1099R` to `Form1099_rs.Form1099R`; `distribution_code` items `2 4 7 B G H Other` are `Code2 Code4 Code7 CodeB CodeG CodeH OtherCode`)

| API property | `Calculator` field |
|---|---|
| `filer` | `filer` |
| `distribution_code` | `distribution_code` |
| `gross_distribution` | `writable_gross_distribution` |
| `taxable_amount` | `writable_taxable_amount` |
| `taxable_amount_blank` | `taxable_amount_blank` |
| `taxable_amount_not_determined` | `taxable_amount_not_determined` |
| `total_distribution` | `total_distribution` |
| `capital_gain` | `writable_capital_gain` |
| `federal_withholding` | `writable_federal_withholding` |
| `net_appreciation` | `writable_net_appreciation` |
| `ira_sep_simple` | `ira_sep_simple` |
| `other_dollar` | `writable_other_dollar` |
| `other_percentage_nonzero` | `other_percentage_nonzero` |
| `percentage_total_distribution_nonzero` | `percentage_total_distribution_nonzero` |
| `amount_allocable_to_irr` | `writable_amount_allocable_to_irr` |
| `facta_filing_requirement` | `facta_filing_requirement` |
| `state_tax_withheld` | `writable_state_tax_withheld` |
| `payer_state_is_different` | `payer_state_is_different` |
| `has_death_benefit_payment_date` | `has_death_benefit_payment_date` |
| `is_indirect_rollover` | `writable_is_indirect_rollover` |
| `is_distribution_from_military_retirement_plan` | `writable_is_distribution_from_military_retirement_plan` |
| `qualified_disaster_distribution` | `writable_qualified_disaster_distribution` |
| `public_safety_officer` | `writeable_public_safety_officer` |
| `public_safety_officer_premiums` | `writeable_public_safety_officer_premiums` |
| `recipient_date_of_birth` | `recipient_date_of_birth` |

#### `dependents[]` (`Dependent` to `Calculator.HouseholdMember`)

| API property | `HouseholdMember` path |
|---|---|
| `relationship` | `dependent.person.relationship` |
| `date_of_birth` | `dependent.person.date_of_birth` |
| `full_time_student` | `dependent.person.full_time_student` |
| `permanent_total_disability` | `dependent.person.permanent_total_disability` |
| `residency_duration` | `dependent.person.residency_duration` |
| `own_support` | `dependent.person.own_support` |
| `married` | `dependent.person.married` |
| `joint_return` | `dependent.person.writable_joint_return` |
| `required_to_file` | `dependent.person.writable_required_to_file` |
| `filing_only_for_refund` | `dependent.person.writable_filing_only_for_refund` |
| `could_be_qualifying_child_of_another` | `dependent.person.writable_could_be_qualifying_child_of_another` |
| `potential_claimer_must_file` | `dependent.person.writable_potential_claimer_must_file` |
| `potential_claimer_did_file` | `dependent.person.writable_potential_claimer_did_file` |
| `potential_claimer_filed_only_for_refund` | `dependent.person.writable_potential_claimer_filed_only_for_refund` |
| `gross_income` | `dependent.answers.gross_income` |
| `qr_support_test` | `dependent.answers.writable_qr_support_test` |
| `tin_type` | `dependent.answers.tin_type` |
| `is_us_citizen_full_year` | `dependent.answers.is_us_citizen_full_year` |
| `us_resident` | `dependent.answers.writable_us_resident` |
| `us_national` | `dependent.answers.writable_us_national` |
| `canada_mexico_resident` | `dependent.answers.writable_canada_mexico_resident` |
| `tp_claims` | `dependent.answers.tp_claims` |
| `custody` | `dependent.split` |
| `tp_paid_most_of_home_upkeep` | `upkeep.tp_paid_most_of_home_upkeep` |
| `tp_paid_most_of_parent_home_upkeep` | `upkeep.tp_paid_most_of_parent_home_upkeep` |
| `ssn_employment_validity` | `ssn_employment_validity` |
| `ssn_only_for_federally_funded_benefit` | `ssn_only_for_federally_funded_benefit` |
| `months_lived_with_tp_in_us` | `months_lived_with_tp_in_us` |
| `cdcc` | `cdcc` |


`dependents[].custody` is `Dependents_benefit_split.BenefitSplitAnswers` with the same field names;
`dependents[].cdcc` is `Calculator.CdccMemberAnswers` with the same field names (including its
`writable_qualifying_expense_amount`). Everything under `credits`, `cdcc`, `premium_tax_credit`
(including each Form 1095-A: `Ptc_allowed.Form1095A`), `screening`, `adjustments.hsa` (including each
`Hsa.HsaDistribution`) and the `hsa`, `cdcc`, `tin` and `disability` objects of a filer keeps the
Catala field name, so the schema entry of each is also its mapping. Money in all of them is cents on
the wire.

## What the API lacked, and what was decided (issue #38)

Schema 1.1.0 exposed only the W-2 and interest inputs of the old Lean `Form1040` and listed the other
accepted sections as "not used". `Calculator` uses every section, so the contract grows. The rule
was: **(a) add it to the contract, backward compatible**, for everything that drives a credit or the
filing status; **(b) default and warn** only for what has no honest answer to give. Every addition is
an optional property, so every 1.0 and 1.1 request stays valid (`schema_version` 1.2.0).

| `Calculator` input | In 1.1.0 | Decision | Now |
|---|---|---|---|
| `household` (children, qualifying relatives, dependents) | absent | (a) | `dependents[]` (`Dependent`): the Direct File per-person facts, flat |
| `credits` (EITC, CTC/ODC, Saver's, Schedule R answers) | absent | (a) | `credits` |
| `cdcc_answers`, per-filer and per-person CDCC expenses | absent | (a) | `cdcc`, `filers.*.cdcc`, `dependents[].cdcc` |
| HSA answers, distributions | "excluded from v1.0" | (a) | `adjustments.hsa`, `filers.*.hsa` |
| Premium tax credit answers, Forms 1095-A | absent | (a) | `premium_tax_credit` (with `form1095_as`) |
| `screening` (the questions that only feed knockouts) | absent | (a) | `screening` |
| `filers` marital and residence answers | absent | (a) | `filing_answers` |
| `FilerAnswers` (date of birth, citizenship, claimed) and `FilerExtra` (TIN, student, disability) | three flags | (a) | `filers.primary`, `.secondary` |
| `income.ssa_federal_tax_withheld` (SSA-1099 box 6) | absent | (a) | `social_security.federal_tax_withheld` |
| `income.combat_pay_election_made` | absent | (a) | `filing_details.combat_pay_election_made` (or implied) |
| `FilerExtra.disability.has_w2_wages`, `eligible_for_hoh` | n/a | derived | computed by `Calculator`; the request value is ignored |
| `treat_as_mfs`, `is_widowed_in_tax_year`, `mfj_deceased_spouse_reached_age65`, `mfs_spouse_provides_no_benefits`, `treat_filers_as_dependents` | inputs of the old scope | derived | folded into the filers' facts (above); server warns `field_superseded` |
| Name, address, SSN digits, bank account, itemized deductions | excluded | excluded permanently | no tax effect or unsupported; sending one is `unknown_field` |

There is no (b) item: every `Calculator` input is either given by the request, derived, or has the
default documented in the schema. The defaults that assume a fact are the ordinary-filer answers
(US citizen, SSN, income sources supported, a dependent lived with the filer all year and is claimed).
A client that collects these answers should send them; the frontend wizard (#72 onwards) should ask
every one that a credit depends on.

**Behaviour change for requests of 1.0 and 1.1.** The calculator now applies the eligibility rules of
the filing status. `HeadOfHousehold` and `QualifyingSurvivingSpouse` need a qualifying person in
`dependents[]` (with `tp_paid_most_of_home_upkeep` true), so the 1.1 examples `hoh-w2-60k` and
`qss-w2-80k`, which had no household, now carry one child; a request without one answers 422
`ExtraFilingStatusNotEligible` (`api/fixtures/knocked-out-hoh-no-qualifying-person.request.json`).
A single filer with $10,000 of wages and no children now gets the $632 earned income credit
(`refund-below-standard-deduction`), because the credit is computed instead of skipped.

## Checks

| Check | What it proves |
|---|---|
| `make difftest SCOPE=api_calculator` | the 157 oracle scenarios, converted to API requests by `scripts/oracle_to_api_request.mjs`, decoded and run through `ApiCalculator`, give the oracle's 19 line items and `supported` flag; scenarios the API cannot express are listed with the reason |
| `clerk test` (`catala/tests/test_api_calculator.catala_en`) | named cases: single, joint with two children, head of household with earned income credit and additional child tax credit, qualifying surviving spouse (marital defaults), legacy flags, reasons and their categories, `outcome`, and wrong outputs rejected |
| `make api-examples` | every response in `api/examples` and `api/fixtures` is the output of `ApiCalculator` on its request |
| `make api-check` | requests and responses validate against `api/schema.json`; `api/knockout-reasons.json` and `catala/api_reasons.catala_en` are fresh |

`api/apicalculator.catala-schema.json` is `catala json-schema -s ApiCalculator` (`make api-catala-schema`): the Catala
side's own description of the decoded input (`ApiRequest`) and of the output, the input to the Lean decoder (#51, #52).

Results and the list of inexpressible scenarios are in the PR description of issue #38 and in the
section "Whole return through the API" of `catala/DIFFTEST.md`.

## Trusted surface

The statement of the correctness of the API is `ApiCalculator`: its inputs (`ApiRequest`), the
mapping in `catala/api_calculator.catala_en`, and `Calculator` below it. Not trusted and not part of
any proof: the decode and encode scripts (`scripts/api_decode.mjs`, `scripts/api_catala.mjs`), the
converter `scripts/oracle_to_api_request.mjs`, and the pretty-printing of `clerk run`. The Lean port
(#48) must reproduce `ApiCalculator`; the server (#52) must reproduce the decode and encode rules
above; both are checked against this scope and the oracle.
