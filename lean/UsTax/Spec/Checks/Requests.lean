import UsTax.Api.Parse
import UsTax.Api.Tests
import UsTax.ApiCalculator

/-!
# Concrete requests for the spec checks (issues #61, #68)

The whole-return statements (`Calculator`, `ApiCalculator`, `calculateRequest`) are instantiated
on requests of the API contract, `api/examples/*.request.json`. Each request is obtained here by
running the server's own reader on the example:

* `<name>Text` is the example file, verbatim. `scripts/gen_spec_checks.py` (`make spec-checks`)
  fails if it differs from the file in `api/examples/`.
* `<name>Json` is the JSON value of that text. The `#guard` below checks that `Api.parseJson`
  reads the text into exactly this value (compared through `J.render`).
* `<name>Req` is `Api.checkJson <name>Json` (phases 1 and 2 of `Api.parseRequest`: version,
  decoding, validation), so the request is *derived by parsing*, not written by hand. The
  theorem `<name>_checkJson` shows by kernel computation that the reader accepts it, and
  `<name>_valid` that it is `Valid` (via `Api.checkJson_sound`), which discharges the hypothesis
  of `calculateRequest_ne_fault`.

The text-to-value step (`Api.parseJson` on a `String`) is checked by `#guard`, not by the
kernel: reducing the string reader in the kernel does not terminate in reasonable memory. The
`#guard parsesTo` lines check the whole `parseRequest` path end to end.
-/

namespace UsTax.Checks

open UsTax.Api

/-- The request read from a JSON value, or the default request if the reader rejects it (the
theorems `*_checkJson` below show it does not, for every value used here). -/
def reqOf (j : J) : Request :=
  match checkJson j with
  | .ok r => r
  | .error _ => default

/-- `checkJson j` accepted the value. -/
def Accepted (j : J) : Prop := (checkJson j).toOption = some (reqOf j)

theorem checkJson_eq_of_accepted {j : J} (h : Accepted j) : checkJson j = .ok (reqOf j) := by
  unfold Accepted at h
  revert h
  cases checkJson j <;> simp [Except.toOption]

/-- Every accepted request is `Valid`. -/
theorem valid_of_accepted {j : J} (h : Accepted j) : (reqOf j).Valid :=
  checkJson_sound (checkJson_eq_of_accepted h)

/-- Does `Api.parseJson` read `s` into `j`? (`J` has no `BEq`; compare the rendered text.) -/
def readsAs (s : String) (j : J) : Bool :=
  match parseJson s with
  | .ok j' => j'.render == j.render
  | .error _ => false

/-! ## `api/examples/single-w2-50k.request.json`: single, one W-2 of $50,000, nothing withheld -/

/-- The example file, verbatim. -/
def singleW2Text : String := "{
  \"api_version\": 1,
  \"tax_year\": 2024,
  \"filing_status\": \"Single\",
  \"w2s\": [
    {
      \"filer\": \"PrimaryFiler\",
      \"wages\": 5000000
    }
  ]
}
"

/-- Its JSON value. -/
def singleW2Json : J := .obj [
  ("api_version", .int 1), ("tax_year", .int 2024), ("filing_status", .str "Single"),
  ("w2s", .arr [.obj [("filer", .str "PrimaryFiler"), ("wages", .int 5000000)]])]

/-- The request, read by the server's reader. -/
def singleW2Req : Request := reqOf singleW2Json

#guard readsAs singleW2Text singleW2Json
#guard Tests.parsesTo singleW2Text singleW2Req

theorem singleW2_accepted : Accepted singleW2Json := by unfold Accepted; decide +kernel
theorem singleW2_valid : singleW2Req.Valid := valid_of_accepted singleW2_accepted

/-! ## `api/examples/family-mfj-two-kids.request.json`: married filing jointly, two children,
$80,000 of wages, $3,000 withheld -/

/-- The example file, verbatim. -/
def mfjKidsText : String := "{
  \"api_version\": 1,
  \"tax_year\": 2024,
  \"filing_status\": \"MarriedFilingJointly\",
  \"filers\": {
    \"primary\": { \"date_of_birth\": \"1986-04-12\" },
    \"secondary\": { \"date_of_birth\": \"1987-09-30\" }
  },
  \"filing_answers\": { \"marital_status\": \"Married\" },
  \"dependents\": [
    { \"relationship\": \"BiologicalChild\", \"date_of_birth\": \"2016-03-01\", \"tin_type\": \"Ssn\" },
    { \"relationship\": \"BiologicalChild\", \"date_of_birth\": \"2019-05-01\", \"tin_type\": \"Ssn\" }
  ],
  \"w2s\": [
    { \"filer\": \"PrimaryFiler\", \"wages\": 8000000, \"federal_withholding\": 300000 }
  ]
}
"

/-- Its JSON value. -/
def mfjKidsJson : J := .obj [
  ("api_version", .int 1), ("tax_year", .int 2024), ("filing_status", .str "MarriedFilingJointly"),
  ("filers", .obj [
    ("primary", .obj [("date_of_birth", .str "1986-04-12")]),
    ("secondary", .obj [("date_of_birth", .str "1987-09-30")])]),
  ("filing_answers", .obj [("marital_status", .str "Married")]),
  ("dependents", .arr [
    .obj [("relationship", .str "BiologicalChild"), ("date_of_birth", .str "2016-03-01"),
      ("tin_type", .str "Ssn")],
    .obj [("relationship", .str "BiologicalChild"), ("date_of_birth", .str "2019-05-01"),
      ("tin_type", .str "Ssn")]]),
  ("w2s", .arr [.obj [("filer", .str "PrimaryFiler"), ("wages", .int 8000000),
    ("federal_withholding", .int 300000)]])]

/-- The request, read by the server's reader. -/
def mfjKidsReq : Request := reqOf mfjKidsJson

#guard readsAs mfjKidsText mfjKidsJson
#guard Tests.parsesTo mfjKidsText mfjKidsReq

theorem mfjKids_accepted : Accepted mfjKidsJson := by unfold Accepted; decide +kernel
theorem mfjKids_valid : mfjKidsReq.Valid := valid_of_accepted mfjKids_accepted

/-! ## `api/examples/eitc-hoh-one-child.request.json`: head of household, one child, $40,000 of
wages, $2,000 withheld -/

/-- The example file, verbatim. -/
def hohEitcText : String := "{
  \"api_version\": 1,
  \"tax_year\": 2024,
  \"filing_status\": \"HeadOfHousehold\",
  \"filers\": { \"primary\": { \"date_of_birth\": \"1990-06-15\" } },
  \"filing_answers\": { \"marital_status\": \"NeverMarried\" },
  \"dependents\": [
    {
      \"relationship\": \"BiologicalChild\",
      \"date_of_birth\": \"2014-09-10\",
      \"tin_type\": \"Ssn\",
      \"tp_paid_most_of_home_upkeep\": true
    }
  ],
  \"w2s\": [
    { \"filer\": \"PrimaryFiler\", \"wages\": 4000000, \"federal_withholding\": 200000 }
  ]
}
"

/-- Its JSON value. -/
def hohEitcJson : J := .obj [
  ("api_version", .int 1), ("tax_year", .int 2024), ("filing_status", .str "HeadOfHousehold"),
  ("filers", .obj [("primary", .obj [("date_of_birth", .str "1990-06-15")])]),
  ("filing_answers", .obj [("marital_status", .str "NeverMarried")]),
  ("dependents", .arr [
    .obj [("relationship", .str "BiologicalChild"), ("date_of_birth", .str "2014-09-10"),
      ("tin_type", .str "Ssn"), ("tp_paid_most_of_home_upkeep", .bool true)]]),
  ("w2s", .arr [.obj [("filer", .str "PrimaryFiler"), ("wages", .int 4000000),
    ("federal_withholding", .int 200000)]])]

/-- The request, read by the server's reader. -/
def hohEitcReq : Request := reqOf hohEitcJson

#guard readsAs hohEitcText hohEitcJson
#guard Tests.parsesTo hohEitcText hohEitcReq

theorem hohEitc_accepted : Accepted hohEitcJson := by unfold Accepted; decide +kernel
theorem hohEitc_valid : hohEitcReq.Valid := valid_of_accepted hohEitc_accepted

/-! ## `api/examples/knocked-out-bond-interest.request.json`: knocked out (private activity bond
interest) -/

/-- The example file, verbatim. -/
def bondKoText : String := "{
  \"api_version\": 1,
  \"tax_year\": 2024,
  \"filing_status\": \"Single\",
  \"w2s\": [
    {
      \"filer\": \"PrimaryFiler\",
      \"wages\": 5000000,
      \"federal_withholding\": 500000
    }
  ],
  \"interest_reports\": [
    {
      \"filer\": \"PrimaryFiler\",
      \"has_1099\": true,
      \"interest_income\": 100000,
      \"private_activity_bond_interest\": 50000
    }
  ]
}
"

/-- Its JSON value. -/
def bondKoJson : J := .obj [
  ("api_version", .int 1), ("tax_year", .int 2024), ("filing_status", .str "Single"),
  ("w2s", .arr [.obj [("filer", .str "PrimaryFiler"), ("wages", .int 5000000),
    ("federal_withholding", .int 500000)]]),
  ("interest_reports", .arr [.obj [("filer", .str "PrimaryFiler"), ("has_1099", .bool true),
    ("interest_income", .int 100000), ("private_activity_bond_interest", .int 50000)]])]

/-- The request, read by the server's reader. -/
def bondKoReq : Request := reqOf bondKoJson

#guard readsAs bondKoText bondKoJson
#guard Tests.parsesTo bondKoText bondKoReq

theorem bondKo_accepted : Accepted bondKoJson := by unfold Accepted; decide +kernel
theorem bondKo_valid : bondKoReq.Valid := valid_of_accepted bondKo_accepted

end UsTax.Checks
