(* Print Catala runtime primitive results, to cross-check the Lean runtime #guards. *)
open Catala_runtime
let q a b = Q.make (Z.of_int a) (Z.of_int b)
let p name v = Printf.printf "%s = %s\n" name (Z.to_string v)
let () =
  p "round(1/2)" (round (q 1 2));
  p "round(5/2)" (round (q 5 2));
  p "round(-1/2)" (round (q (-1) 2));
  p "round(-5/2)" (round (q (-5) 2));
  p "round(249/100)" (round (q 249 100));
  p "integer_of_decimal(-7/2)" (integer_of_decimal (q (-7) 2));
  p "integer_of_decimal(7/2)" (integer_of_decimal (q 7 2));
  p "money_round(1250)" (money_round (Z.of_int 1250));
  p "money_round(-1250)" (money_round (Z.of_int (-1250)));
  p "money_round(-1249)" (money_round (Z.of_int (-1249)));
  p "mult_mon_rat(1,1/2)" (o_mult_mon_rat (Z.of_int 1) (q 1 2));
  p "mult_mon_rat(-1,1/2)" (o_mult_mon_rat (Z.of_int (-1)) (q 1 2));
  p "mult_mon_rat(5,1/4)" (o_mult_mon_rat (Z.of_int 5) (q 1 4));
  p "money_of_decimal(0.005)" (money_of_decimal (q 1 200));
  p "div_mon_rat(100,3)" (o_div_mon_rat { filename=""; start_line=0; start_column=0; end_line=0; end_column=0; law_headings=[] } (Z.of_int 100) (q 3 1))
