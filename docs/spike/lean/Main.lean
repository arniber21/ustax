import Spike.RateA
import Spike.RateC

/-- Usage: spike a|c STEP MAX : prints status,ti_cents,tax_cents like the OCaml driver. -/
def main (args : List String) : IO Unit := do
  let which := args[0]!
  let step : Int := args[1]!.toInt!
  let maxc := args[2]!.toInt!
  let out ← IO.getStdout
  let fsA := [RateA.FilingStatus.single, .marriedFilingJointly, .marriedFilingSeparately,
    .headOfHousehold, .qualifyingSurvivingSpouse]
  let fsC := [RateC.FilingStatus.single, .mfj, .mfs, .hoh, .qss]
  for k in [0:5] do
    let mut ti : Int := -500
    while ti ≤ maxc do
      let t := if which == "a" then (RateA.tax fsA[k]! ti).getD (-1) else RateC.tax fsC[k]! ti
      out.putStrLn s!"{k},{ti},{t}"
      ti := ti + step
