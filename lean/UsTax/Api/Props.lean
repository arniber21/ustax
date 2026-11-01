import Plausible
import UsTax.Api.Parse

/-!
# Property tests of the request layer (issue #51)

`plausible` runs on every build. These statements were tested before the
corresponding lemmas in `Lemmas.lean` were proved; the leaf tests scale the
random integer by `10^k` so that values near the cap are reached.
-/

namespace UsTax.Api.Props

open UsTax Plausible

/-- `#prop p`: run plausible on `p` with 300 random instances; a
counterexample fails the build. (`Testable.check`, not the `plausible` tactic,
so nothing is admitted with `sorry`.) -/
local macro "#prop " p:term : command =>
  `(command| #eval Testable.check $p { numInst := 300 })

/-- Spread a random integer over many magnitudes (cap is 10^13). -/
def scale (a : Int) (k : Nat) : Int := a * 10 ^ (k % 14)

-- The leaf rule, stated independently of `nonNegErrs`.
#prop (∀ (a : Int) (k : Nat),
    (nonNegErrs "" ("x", scale a k) = []) = (decide (0 ≤ scale a k ∧ scale a k ≤ 10000000000000)))

-- Signed list rule.
#prop (∀ (xs : List Int) (k : Nat),
    (netBenefitErrs "/n" 0 (xs.map (scale · k)) = []) =
      decide (∀ n ∈ xs.map (scale · k), -10000000000000 ≤ n ∧ n ≤ 10000000000000))

/-- Scale every wage. -/
def sc (k : Nat) (ws : List (Bool × Int)) : List (Bool × Int) :=
  ws.map fun x => (x.1, scale x.2 k)

/-- A request with these W-2 wages, on a return with filing status index `st`
and secondary-filer flags. -/
def mk (st : Nat) (ws : List (Bool × Int)) : Request :=
  { filingStatus := FilingStatus.all.getD (st % 5) .single,
    w2s := ws.map fun (sec, w) =>
      { filer := if sec then .secondaryFiler else .primaryFiler, wages := w } }

-- `validate` agrees with an independent boolean reading of the rules.
#prop (∀ (st : Nat) (ws : List (Bool × Int)) (k : Nat),
    ((mk st (sc k ws)).validate = []) =
      ((sc k ws).length ≤ 20 && (sc k ws).all fun x =>
        decide (0 ≤ x.2 ∧ x.2 ≤ 10000000000000) &&
        (!x.1 || FilingStatus.all.getD (st % 5) .single == .marriedFilingJointly)))

-- Integer arrays survive the JSON reader.
#prop (∀ (xs : List Int),
    (match parseJson ("[" ++ ",".intercalate (xs.map toString) ++ "]") with
     | .ok j => j.render
     | .error e => e) = "[" ++ ",".intercalate (xs.map toString) ++ "]")

-- A decimal point on a money box is always `not_integer`, never accepted.
#prop (∀ (n : Nat),
    (match parseRequest ("{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\"," ++
        "\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":" ++ toString n ++ ".0}]}") with
     | .error e => e.details.map (·.code) == [.notInteger]
     | .ok _ => false) = true)


-- Schema 1.2.0 rules, tested before they were proved (`validate_eq_nil_iff`).

-- Bounded integers (months, counts).
#prop (∀ (lo hi n : Int),
    (rangeAt lo hi "x" n = []) = decide (lo ≤ n ∧ n ≤ hi))

-- A date is accepted exactly when it exists in the calendar.
#prop (∀ (y : Int) (m d : Nat),
    (dateAt "x" { year := y, month := m % 14, day := d % 33 } = []) =
      decide (1 ≤ m % 14 ∧ m % 14 ≤ 12 ∧ 1 ≤ d % 33 ∧
        d % 33 ≤ Date.daysInMonth y (m % 14)))

/-- A single return with this Social Security section. -/
def mkSs (ns fs : List Int) (k : Nat) : Request :=
  { filingStatus := .single,
    socialSecurity := some { netBenefits := ns.map (scale · k), federalTaxWithheld := fs.map (scale · k) } }

-- `net_benefits` is signed and at most 4 long; `federal_tax_withheld` is non-negative, at most 4
-- long and no longer than `net_benefits`.
#prop (∀ (ns fs : List Int) (k : Nat),
    ((mkSs ns fs k).validate = []) =
      (decide (ns.length ≤ 4 ∧ fs.length ≤ 4 ∧ fs.length ≤ ns.length) &&
       (ns.map (scale · k)).all (fun n => decide (-10000000000000 ≤ n ∧ n ≤ 10000000000000)) &&
       (fs.map (scale · k)).all (fun n => decide (0 ≤ n ∧ n ≤ 10000000000000))))

/-- A joint return with one dependent. -/
def mkDep (months : Int) (y : Int) (m d : Nat) (income : Int) (k : Nat) : Request :=
  let dep : Dependent :=
    { relationship := .biologicalChild
      dateOfBirth := { year := y, month := m % 14, day := d % 33 }
      tinType := .ssn
      monthsLivedWithTpInUs := months
      grossIncome := scale income k }
  { filingStatus := .marriedFilingJointly, dependents := [dep] }

/-- A dependent that is valid. -/
def okDep : Dependent :=
  { relationship := .parent, dateOfBirth := { year := 1950, month := 1, day := 1 }, tinType := .ssn }

/-- A secondary-filer HSA distribution. -/
def secDist : HsaDistribution :=
  { filer := .secondaryFiler
    writableDistributionsRolloverBool := false
    writableDistributionsRolloverAmount := 0
    writableGrossDistribution := 1
    hasWithdrawnExcessContributions := false
    writableWithdrawnExcessContributionsAmount := 0
    writableEarningsOnExcessContributions := 0
    hsaDistributionCode := .normalDistribution
    writableFmvOnDateOfDeath := 0
    writableQualifiedMedExpenses := 0 }

/-- A Form 1095-A with these coverage months. -/
def mk1095 (ms : List Int) : Form1095A :=
  { writablePolicyStartDate := { year := 2024, month := 1, day := 1 }
    writablePolicyEndDate := { year := 2024, month := 12, day := 31 }
    writableSpecialPolicyModificationInStartingMonth := false
    writableHasPolicyDateException := false
    hasCoverageMonths := true
    coverageMonths := ms
    writablePremiumsOrSlcspChange := false
    hasChangeInCircumstance := false
    writablePtcAnnualPremium := 0
    writableSlcspAnnualPremium := 0
    writableAptcAnnualAmount := 0
    writablePtcMonthlyPremium := []
    writablePtcMonthlySlcspPremium := []
    writablePtcMonthlyAptcPremium := [] }

-- A dependent is valid exactly when its month count, date of birth and income are.
#prop (∀ (months y : Int) (m d : Nat) (income : Int) (k : Nat),
    ((mkDep months y m d income k).validate = []) =
      (decide (0 ≤ months ∧ months ≤ 12) &&
       decide (1 ≤ m % 14 ∧ m % 14 ≤ 12 ∧ 1 ≤ d % 33 ∧ d % 33 ≤ Date.daysInMonth y (m % 14)) &&
       decide (0 ≤ scale income k ∧ scale income k ≤ 10000000000000)))

-- More than 20 dependents are refused, at most 20 accepted.
#prop (∀ (n : Nat),
    (({ filingStatus := .single, dependents := List.replicate (n % 40) okDep } : Request).validate = []) =
      decide (n % 40 ≤ 20))

-- A secondary-filer HSA distribution is allowed only on a joint return.
#prop (∀ (st : Nat),
    (({ filingStatus := FilingStatus.all.getD (st % 5) .single,
        adjustments := { hsa := some { hsaDistributions := [secDist] } } } : Request).validate = []) =
      decide (FilingStatus.all.getD (st % 5) .single = .marriedFilingJointly))

-- A Form 1095-A month list: 1 to 12 only, at most 12 long.
#prop (∀ (ms : List Int),
    (({ filingStatus := .single,
        premiumTaxCredit := some { form1095As := [mk1095 (ms.map (· % 20))] } } : Request).validate = []) =
      decide (ms.length ≤ 12 ∧ ∀ n ∈ ms.map (· % 20), 1 ≤ n ∧ n ≤ 12))

-- Negative control: "every request with a W-2 is valid" is false, and
-- plausible must find a counterexample.
#eval do
  let r ← Testable.checkIO (NamedBinder "w" <| ∀ w : Int,
    (mk 0 [(false, w)]).validate = [])
    { numInst := 300, quiet := true }
  unless r matches .failure .. do throw (IO.userError "plausible missed a false statement")

end UsTax.Api.Props
