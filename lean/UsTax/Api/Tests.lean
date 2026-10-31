import UsTax.Api.Parse
import UsTax.Api.Response
import UsTax.Api.Bridge

/-!
# Tests of the request layer (issue #51)

All checks are `#guard`s, so a regression fails the build.

* `table`: 55 bodies (40+ invalid, built from the schema's rules: wrong type,
  float money, over cap, unknown field, bad enum, missing field, bad date,
  too many items, wrong filer role, bad JSON) with the exact verdict
  `error.code:` then each detail as `path code`. The same kinds of mutant,
  generated from `api/schema.json`, are cross-checked against ajv by
  `scripts/api_conformance.mjs`.
* accepted bodies read into the expected values, every optional property
  given a distinct value so that a dropped field shows;
* the 400 fixtures reproduced byte for byte;
* the body pipeline (415, 413, UTF-8);
* the response serialisation against `api/examples/single-w2-and-interest.response.json`.

The oracle scenarios (issue text: "all 322 oracle scenarios (converted)
parse") need a converter from `oracle/facts.csv` to request JSON, which does
not exist yet; it belongs with the endpoint integration test (#52).
-/

namespace UsTax.Api.Tests

open UsTax

/-- `ok`, or `error.code:` followed by `path code` for each detail. -/
def verdict (s : String) : String :=
  match parseRequest s with
  | .ok _ => "ok"
  | .error e =>
    e.code.name ++ ":" ++ ", ".intercalate (e.details.map fun d => d.path ++ " " ++ d.code.name)

/-- (name, body, expected verdict). -/
def table : List (String × String × String) := [
  ("valid minimal", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":5000000}]}", "ok"),
  ("valid at cap", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":10000000000000}]}", "ok"),
  ("empty text", "", "invalid_json:"),
  ("truncated", "{\"api_version\":", "invalid_json:"),
  ("not json", "hello", "invalid_json:"),
  ("trailing garbage", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":5000000}]} x", "invalid_json:"),
  ("duplicate key", "{\"api_version\":1,\"api_version\":1}", "invalid_json:"),
  ("leading zero", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":05}]}", "invalid_json:"),
  ("top-level array", "[]", "invalid_request: type"),
  ("top-level number", "7", "invalid_request: type"),
  ("missing api_version", "{\"tax_year\":2024,\"filing_status\":\"Single\"}", "invalid_request:/api_version required"),
  ("api_version 2", "{\"api_version\":2,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":5000000}]}", "unsupported_api_version:/api_version enum"),
  ("api_version string", "{\"api_version\":\"1\",\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":5000000}]}", "invalid_request:/api_version type"),
  ("api_version float", "{\"api_version\":1.0,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":5000000}]}", "invalid_request:/api_version not_integer"),
  ("tax_year 2023", "{\"api_version\":1,\"tax_year\":2023,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":5000000}]}", "unsupported_tax_year:/tax_year enum"),
  ("missing filing_status", "{\"api_version\":1,\"tax_year\":2024}", "invalid_request:/filing_status required"),
  ("filing_status unknown", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Married\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":5000000}]}", "invalid_request:/filing_status enum"),
  ("filing_status lowercase", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":5000000}]}", "invalid_request:/filing_status enum"),
  ("filing_status number", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":1,\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":5000000}]}", "invalid_request:/filing_status type"),
  ("unknown top field", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":5000000}],\"w3s\":[]}", "unknown_field:/w3s unknown_field"),
  ("unknown w2 field", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":1,\"tips\":2}]}", "unknown_field:/w2s/0/tips unknown_field"),
  ("unknown box12 code", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":1,\"box12\":{\"I\":5}}]}", "unknown_field:/w2s/0/box12/I unknown_field"),
  ("float money", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":5000000.0}]}", "invalid_request:/w2s/0/wages not_integer"),
  ("exponent money", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":5e6}]}", "invalid_request:/w2s/0/wages not_integer"),
  ("string money", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":\"5000000\"}]}", "invalid_request:/w2s/0/wages type"),
  ("null money", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":null}]}", "invalid_request:/w2s/0/wages type"),
  ("bool money", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":true}]}", "invalid_request:/w2s/0/wages type"),
  ("negative wages", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":-1}]}", "invalid_request:/w2s/0/wages range"),
  ("wages over cap", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":10000000000001}]}", "invalid_request:/w2s/0/wages range"),
  ("box12 over cap", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":1,\"box12\":{\"D\":10000000000001}}]}", "invalid_request:/w2s/0/box12/D range"),
  ("box12 negative", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":1,\"box12\":{\"AA\":-5}}]}", "invalid_request:/w2s/0/box12/AA range"),
  ("w2 missing wages", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"statutory_employee\":true}]}", "invalid_request:/w2s/0/wages required"),
  ("w2 bad filer", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"Spouse\",\"wages\":1}]}", "invalid_request:/w2s/0/filer enum"),
  ("secondary on single", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"SecondaryFiler\",\"wages\":1}]}", "invalid_request:/w2s/0/filer filer_not_allowed"),
  ("secondary on mfj ok", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"MarriedFilingJointly\",\"w2s\":[{\"filer\":\"SecondaryFiler\",\"wages\":1}]}", "ok"),
  ("filers.secondary on single", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":5000000}],\"filers\":{\"secondary\":{\"is_blind\":true}}}", "invalid_request:/filers/secondary filer_not_allowed"),
  ("21 w2s", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1}]}", "invalid_request:/w2s too_many_items"),
  ("20 w2s ok", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1},{\"filer\":\"PrimaryFiler\",\"wages\":1}]}", "ok"),
  ("w2s is object", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":{}}", "invalid_request:/w2s type"),
  ("1099-R bad date", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"form_1099r\":[{\"filer\":\"PrimaryFiler\",\"distribution_code\":[\"7\"],\"gross_distribution\":1,\"taxable_amount\":1,\"recipient_date_of_birth\":\"2024-02-30\"}]}", "invalid_request:/form_1099r/0/recipient_date_of_birth invalid_date"),
  ("1099-R leap date ok", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"form_1099r\":[{\"filer\":\"PrimaryFiler\",\"distribution_code\":[\"7\"],\"gross_distribution\":1,\"taxable_amount\":1,\"recipient_date_of_birth\":\"2024-02-29\"}]}", "ok"),
  ("1099-R date format", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"form_1099r\":[{\"filer\":\"PrimaryFiler\",\"distribution_code\":[\"7\"],\"gross_distribution\":1,\"taxable_amount\":1,\"recipient_date_of_birth\":\"2024/01/01\"}]}", "invalid_request:/form_1099r/0/recipient_date_of_birth type"),
  ("1099-R 5 codes", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"form_1099r\":[{\"filer\":\"PrimaryFiler\",\"distribution_code\":[\"7\",\"7\",\"7\",\"7\",\"7\"],\"gross_distribution\":1,\"taxable_amount\":1}]}", "invalid_request:/form_1099r/0/distribution_code too_many_items"),
  ("1099-R bad code", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"form_1099r\":[{\"filer\":\"PrimaryFiler\",\"distribution_code\":[\"Z\"],\"gross_distribution\":1,\"taxable_amount\":1}]}", "invalid_request:/form_1099r/0/distribution_code/0 enum"),
  ("ss negative ok", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"social_security\":{\"net_benefits\":[-500]}}", "ok"),
  ("ss below -cap", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"social_security\":{\"net_benefits\":[-10000000000001]}}", "invalid_request:/social_security/net_benefits/0 range"),
  ("ss 5 items", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"social_security\":{\"net_benefits\":[1,2,3,4,5]}}", "invalid_request:/social_security/net_benefits too_many_items"),
  ("educator missing field", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"adjustments\":{\"educator_expenses\":{\"primary_expenses\":5}}}", "invalid_request:/adjustments/educator_expenses/was_k12_educators required"),
  ("educator bad enum", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"adjustments\":{\"educator_expenses\":{\"was_k12_educators\":\"Both\"}}}", "invalid_request:/adjustments/educator_expenses/was_k12_educators enum"),
  ("estimated over cap", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"estimated_payments\":{\"paid_estimated_taxes_or_from_last_year\":true,\"amount\":10000000000001}}", "invalid_request:/estimated_payments/amount range"),
  ("two shape errors", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":1.5,\"federal_withholding\":\"x\"}]}", "invalid_request:/w2s/0/wages not_integer, /w2s/0/federal_withholding type"),
  ("shape error hides range", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":-1,\"federal_withholding\":\"x\"}]}", "invalid_request:/w2s/0/federal_withholding type"),
  ("two range errors", "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":-1,\"federal_withholding\":-2}]}", "invalid_request:/w2s/0/wages range, /w2s/0/federal_withholding range"),
  ("version beats unknown field", "{\"api_version\":3,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":5000000}],\"zzz\":1}", "unsupported_api_version:/api_version enum"),
  ("deep nesting", "[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]", "invalid_json:")
]

#guard table.length ≥ 50
#guard table.all fun (_, b, v) => verdict b == v
#guard (table.filter fun (_, _, v) => v != "ok").length ≥ 40

/-! ### Accepted requests are read into the right values -/

/-- `api/examples/mfj-two-w2s.request.json`. -/
def mfjText : String :=
  "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"MarriedFilingJointly\"," ++
  "\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":4000000}," ++
  "{\"filer\":\"SecondaryFiler\",\"wages\":3000000}]}"

/-- Does `s` parse to exactly `r`? -/
def parsesTo (s : String) (r : Request) : Bool :=
  match parseRequest s with
  | .ok r' => r' == r
  | .error _ => false

#guard parsesTo mfjText
  { filingStatus := .marriedFilingJointly,
    w2s := [{ filer := .primaryFiler, wages := 4000000 },
            { filer := .secondaryFiler, wages := 3000000 }] }

/-- A 1099-INT with every optional box given a distinct value. -/
def interestText : String :=
  "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\"," ++
  "\"interest_reports\":[{\"filer\":\"PrimaryFiler\",\"has_1099\":true," ++
  "\"no_1099_amount\":1,\"interest_income\":2,\"early_withdrawal_penalty\":3," ++
  "\"government_bond_interest\":4,\"federal_tax_withheld\":5,\"foreign_tax_paid\":6," ++
  "\"tax_exempt_interest\":7,\"private_activity_bond_interest\":8,\"market_discount\":9," ++
  "\"bond_premium\":10,\"bond_premium_treasury\":11,\"bond_premium_tax_exempt\":12," ++
  "\"state_is_different\":true,\"state_tax_withheld\":13,\"facta_filing_required\":true}]}"

/-- The expected 1099-INT. -/
def interestForm : Form1099Int :=
  { filer := .primaryFiler, has1099 := true, no1099Amount := 1,
    interestIncome := 2, earlyWithdrawalPenalty := 3, governmentBondInterest := 4,
    federalTaxWithheld := 5, foreignTaxPaid := 6, taxExemptInterest := 7,
    privateActivityBondInterest := 8, marketDiscount := 9, bondPremium := 10,
    bondPremiumTreasury := 11, bondPremiumTaxExempt := 12, stateIsDifferent := true,
    stateTaxWithheld := 13, factaFilingRequired := true }

#guard parsesTo interestText { filingStatus := .single, interestReports := [interestForm] }

/-- A W-2 with box 12, a 1099-R and every other section, all optional properties given. -/
def richText : String :=
  "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\"," ++
  "\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":1,\"federal_withholding\":2," ++
  "\"oasdi_wages\":3,\"oasdi_withholding\":4,\"medicare_wages\":5,\"medicare_withholding\":6," ++
  "\"allocated_tips\":7,\"dependent_care_benefits\":8,\"non_qualified_plans\":9," ++
  "\"box12\":{\"D\":10,\"AA\":11},\"statutory_employee\":true,\"third_party_sick_pay\":true," ++
  "\"plan_457b_is_governmental\":true}]," ++
  "\"form_1099r\":[{\"filer\":\"PrimaryFiler\",\"distribution_code\":[\"2\",\"G\"]," ++
  "\"gross_distribution\":20,\"taxable_amount\":21,\"recipient_date_of_birth\":\"1960-02-29\"}]," ++
  "\"social_security\":{\"net_benefits\":[-5,6],\"lived_apart_all_year\":true}," ++
  "\"adjustments\":{\"educator_expenses\":{\"was_k12_educators\":\"BothDid\"," ++
  "\"primary_expenses\":30,\"secondary_expenses\":31}," ++
  "\"student_loan_interest\":{\"had_payments\":true,\"loans_qualify\":true,\"interest_amount\":32}}," ++
  "\"estimated_payments\":{\"paid_estimated_taxes_or_from_last_year\":true,\"amount\":33," ++
  "\"paid_under_different_name\":true,\"paid_with_former_spouse\":\"Neither\"}," ++
  "\"filing_details\":{\"treat_as_mfs\":false,\"combat_pay_election\":\"UseBothCombatPay\"}," ++
  "\"filers\":{\"primary\":{\"is_blind\":true}}}"

/-- The expected W-2. -/
def richW2 : FormW2 :=
  { filer := .primaryFiler, wages := 1, federalWithholding := 2, oasdiWages := 3,
    oasdiWithholding := 4, medicareWages := 5, medicareWithholding := 6,
    allocatedTips := 7, dependentCareBenefits := 8, nonQualifiedPlans := 9,
    box12 := { entries := [(.d, 10), (.aa, 11)] }, statutoryEmployee := true,
    thirdPartySickPay := true, plan457bIsGovernmental := true }

/-- The expected 1099-R. -/
def richR : Form1099R :=
  { filer := .primaryFiler, distributionCode := [.c2, .g], grossDistribution := 20,
    taxableAmount := 21, recipientDateOfBirth := some { year := 1960, month := 2, day := 29 } }

/-- The expected adjustments. -/
def richAdj : Adjustments :=
  { educatorExpenses := some { wasK12Educators := .bothDid, primaryExpenses := 30,
                               secondaryExpenses := 31 },
    studentLoanInterest := some { hadPayments := true, loansQualify := true,
                                  interestAmount := 32 } }

/-- The expected estimated payments. -/
def richEst : EstimatedPayments :=
  { paidEstimatedTaxesOrFromLastYear := true, amount := 33, paidUnderDifferentName := true,
    paidWithFormerSpouse := some .neither }

#guard parsesTo richText
  { filingStatus := .single,
    filers := { primary := some { isBlind := true } },
    filingDetails := { treatAsMfs := some false, combatPayElection := .useBothCombatPay },
    w2s := [richW2], form1099r := [richR],
    socialSecurity := some { netBenefits := [-5, 6], livedApartAllYear := true },
    adjustments := richAdj,
    estimatedPayments := some richEst }

-- Absent means the Direct File default: list empty, box 0, flag false.
#guard parsesTo "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\"}"
  { filingStatus := .single }

-- Box 12 lookup used by the bridge.
#guard ({ entries := [(.d, 10), (.aa, 11)] } : Box12).amount .aa == 11
#guard ({ entries := [(.d, 10)] } : Box12).amount .e == 0

/-! ### JSON reader -/

#guard (parseJson "[1, -2, 0, 100.0, 1e2, 1E-2, \"a\\u0041\\n\", true, null, {}]").toOption.map J.render ==
  some "[1,-2,0,100.0,1e2,1E-2,\"aA\\n\",true,null,{}]"
#guard (parseJson " { \"a\" : [ ] } ").toOption.map J.render == some "{\"a\":[]}"
#guard (parseJson "01").toOption.isNone
#guard (parseJson "1.").toOption.isNone
#guard (parseJson "-").toOption.isNone
#guard (parseJson "\"\\q\"").toOption.isNone
#guard (parseJson "\"a\nb\"").toOption.isNone
#guard (parseJson "{\"a\":1,}").toOption.isNone
#guard (parseJson "[1,]").toOption.isNone
#guard (parseJson "{\"a\":1,\"a\":2}").toOption.isNone
#guard (parseJson ("".pushn '[' 31 ++ "".pushn ']' 31)).toOption.isSome
#guard (parseJson ("".pushn '[' 33 ++ "".pushn ']' 33)).toOption.isNone
-- Integers are exact beyond 2^64.
#guard (parseJson "123456789012345678901234567890").toOption.map J.render ==
  some "123456789012345678901234567890"

/-! ### Error values match the 400 fixtures byte for byte -/

#guard (match parseRequest "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w3s\":[]}" with
  | .error e => e.render
  | .ok _ => "") ==
  "{\"api_version\":1,\"error\":{\"code\":\"unknown_field\",\"message\":\"The request body is invalid.\",\"details\":[{\"path\":\"/w3s\",\"code\":\"unknown_field\",\"message\":\"unknown property\"}]}}"

#guard (match parseRequest "{\"api_version\":1,\"tax_year\":2023,\"filing_status\":\"Single\"}" with
  | .error e => e.render
  | .ok _ => "") ==
  "{\"api_version\":1,\"error\":{\"code\":\"unsupported_tax_year\",\"message\":\"Only tax_year 2024 is supported.\",\"details\":[{\"path\":\"/tax_year\",\"code\":\"enum\",\"message\":\"must be 2024\"}]}}"

#guard ApiError.payloadTooLarge.render ==
  "{\"api_version\":1,\"error\":{\"code\":\"payload_too_large\",\"message\":\"Request body exceeds 262144 bytes.\"}}"

#guard ApiError.payloadTooLarge.status == 413
#guard ApiError.unsupportedMediaType.status == 415
#guard ApiError.internal.status == 500
#guard (ApiError.invalidJson "x").status == 400

/-! ### The body pipeline -/

/-- A small valid body as bytes. -/
def okBody : ByteArray := "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\"}".toUTF8

#guard (parseBody (some "application/json") okBody).toOption.isSome
#guard (parseBody (some "Application/JSON; charset=utf-8") okBody).toOption.isSome
#guard (match parseBody (some "text/plain") okBody with | .error e => e.status | .ok _ => 0) == 415
#guard (match parseBody none okBody with | .error e => e.status | .ok _ => 0) == 415
#guard (match parseBody (some "application/json") (ByteArray.mk (Array.replicate 262145 32)) with
  | .error e => e.status | .ok _ => 0) == 413
-- At the cap the body is parsed (here: all whitespace, so not JSON, a 400).
#guard (match parseBody (some "application/json") (ByteArray.mk (Array.replicate 262144 32)) with
  | .error e => e.status | .ok _ => 0) == 400
#guard (match parseBody (some "application/json") (ByteArray.mk #[0xff, 0xfe]) with
  | .error e => e.code.name | .ok _ => "") == "invalid_json"

/-! ### Response serialisation: `api/examples/single-w2-and-interest.response.json` -/

/-- Its `lines`. -/
def exampleLines : Lines :=
  { wages := 5000000, employerIncomeSubtotal := 5000000, interestIncome := 100000,
    totalIncome := 5100000, adjustmentsToIncome := 0, agi := 5100000,
    standardOrItemizedDeductions := 1460000, totalDeductions := 1460000,
    taxableIncome := 3640000, tentativeTaxFromTaxableIncome := 413900,
    totalTentativeTax := 413900, nonRefundableCredits := 0,
    taxLessNonRefundableCredits := 413900, totalTax := 413900, totalWithholding := 10000,
    totalOtherPaymentsRefundableCredits := 0, totalPayments := 10000, overpayment := 0,
    balanceDue := 403900 }

#guard (calculateSuccess exampleLines).render ==
  "{\"api_version\":1,\"tax_year\":2024,\"supported\":true,\"reasons\":[],\"outcome\":\"balance_due\",\"lines\":{\"wages\":5000000,\"employer_income_subtotal\":5000000,\"interest_income\":100000,\"total_income\":5100000,\"adjustments_to_income\":0,\"agi\":5100000,\"standard_or_itemized_deductions\":1460000,\"total_deductions\":1460000,\"taxable_income\":3640000,\"tentative_tax_from_taxable_income\":413900,\"total_tentative_tax\":413900,\"non_refundable_credits\":0,\"tax_less_non_refundable_credits\":413900,\"total_tax\":413900,\"total_withholding\":10000,\"total_other_payments_refundable_credits\":0,\"total_payments\":10000,\"overpayment\":0,\"balance_due\":403900}}"

#guard exampleLines.outcome == .balanceDue
#guard ({ exampleLines with overpayment := 5, balanceDue := 0 }).outcome == .refund
#guard ({ exampleLines with overpayment := 0, balanceDue := 0 }).outcome == .even

/-- The 422 example reason. -/
def bondsReason : UnsupportedReason :=
  { code := "FlowKnockoutHasBonds", category := "interest", message := "Flow Knockout Has Bonds" }

#guard (calculateUnsupported [bondsReason]).render ==
  "{\"api_version\":1,\"tax_year\":2024,\"supported\":false,\"reasons\":[{\"code\":\"FlowKnockoutHasBonds\",\"category\":\"interest\",\"message\":\"Flow Knockout Has Bonds\"}]}"

#guard healthResponse.render == "{\"status\":\"ok\"}"

end UsTax.Api.Tests
