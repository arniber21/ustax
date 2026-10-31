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

-- Negative control: "every request with a W-2 is valid" is false, and
-- plausible must find a counterexample.
#eval do
  let r ← Testable.checkIO (NamedBinder "w" <| ∀ w : Int,
    (mk 0 [(false, w)]).validate = [])
    { numInst := 300, quiet := true }
  unless r matches .failure .. do throw (IO.userError "plausible missed a false statement")

end UsTax.Api.Props
