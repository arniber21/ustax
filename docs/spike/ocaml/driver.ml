(* Spike differential driver: prints "status,ti_cents,tax_cents" for a grid,
   using the Catala-generated OCaml (Spike_rate.tax_schedule). *)
open Spike_rate

let statuses =
  [ 0, FilingStatus.Single; 1, FilingStatus.MarriedFilingJointly;
    2, FilingStatus.MarriedFilingSeparately; 3, FilingStatus.HeadOfHousehold;
    4, FilingStatus.QualifyingSurvivingSpouse ]

let () =
  let step = int_of_string Sys.argv.(1) in   (* in cents *)
  let maxc = int_of_string Sys.argv.(2) in   (* in cents *)
  List.iter (fun (k, fs) ->
    let ti = ref (-500) in
    while !ti <= maxc do
      let r = tax_schedule { TaxSchedule_in.filing_status_in = fs;
                             taxable_income_in = Z.of_int !ti } in
      Printf.printf "%d,%d,%s\n" k !ti (Z.to_string r.TaxSchedule.tax);
      ti := !ti + step
    done) statuses
