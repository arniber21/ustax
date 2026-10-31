/-!
# A strict JSON reader for the API boundary (issue #51)

`Lean.Json.parse` is not used here, on purpose. The contract (`docs/api.md`,
"Money: integer cents") needs three things it does not give:

* integer literals told apart from `100.0` and `1e2` (`Lean.JsonNumber` folds
  all three to the same value), so money can be accepted only as an integer
  literal and floats rejected with `not_integer`;
* duplicate object keys rejected (`Lean.Json` silently keeps one);
* a hard nesting limit, so no input can overflow the stack.

`parseJson` is total: it is structural on a fuel counter, never `partial`. Fuel
is twice the input length plus two, which is enough because every recursive
call consumes at least one character (otherwise it fails with "input too
large", which cannot happen). Numbers are kept as `J.int` (no fraction, no
exponent) or `J.float` (everything else, original text, never interpreted).

This file is trusted code (untrusted JSON enters here). It is tested by
`UsTax/Api/Tests.lean` and by `scripts/api_conformance.mjs`.
-/

namespace UsTax.Api

/-- A JSON value. Numbers without fraction or exponent are `int`; all other
numbers are `float`, which carries the source text. -/
inductive J where
  /-- `null`. -/
  | null
  /-- `true` or `false`. -/
  | bool (b : Bool)
  /-- A number with no fraction and no exponent. -/
  | int (n : Int)
  /-- Any other number, as source text; never interpreted. -/
  | float (text : String)
  /-- A string. -/
  | str (s : String)
  /-- An array. -/
  | arr (xs : List J)
  /-- An object, members in source order, keys unique. -/
  | obj (kvs : List (String × J))
  deriving Inhabited

namespace J

/-- Escape a string as a JSON string literal (with quotes). -/
def quote (s : String) : String :=
  let esc (c : Char) : String :=
    if c == '"' then "\\\"" else if c == '\\' then "\\\\"
    else if c == '\n' then "\\n" else if c == '\r' then "\\r" else if c == '\t' then "\\t"
    else if c.val < 0x20 then
      let h := Nat.toDigits 16 c.val.toNat
      "\\u" ++ String.ofList (List.replicate (4 - h.length) '0' ++ h)
    else String.singleton c
  "\"" ++ String.join (s.toList.map esc) ++ "\""

mutual
/-- Compact serialisation (no whitespace), keys in the order given. -/
def render : J → String
  | null => "null"
  | bool b => if b then "true" else "false"
  | int n => toString n
  | float t => t
  | str s => quote s
  | arr xs => "[" ++ ",".intercalate (renderList xs) ++ "]"
  | obj kvs => "{" ++ ",".intercalate (renderMembers kvs) ++ "}"

/-- Serialise array elements. -/
def renderList : List J → List String
  | [] => []
  | x :: xs => render x :: renderList xs

/-- Serialise object members. -/
def renderMembers : List (String × J) → List String
  | [] => []
  | (k, v) :: rest => (quote k ++ ":" ++ render v) :: renderMembers rest
end

/-- Look a key up in an object's member list. -/
def lookup (kvs : List (String × J)) (k : String) : Option J :=
  (kvs.find? (·.1 == k)).map (·.2)

end J

namespace Json

/-- Nesting limit: the deepest request in the schema nests 5 levels. -/
def maxDepth : Nat := 32

/-- Parse failure: characters left when it happened, and what was expected. -/
abbrev PErr := Nat × String

/-- Fail at the position where `cs` is what remains. -/
def fail {α : Type} (cs : List Char) (msg : String) : Except PErr α :=
  .error (cs.length, msg)

/-- Skip JSON whitespace. -/
def skipWs : List Char → List Char
  | c :: cs => if c == ' ' || c == '\n' || c == '\t' || c == '\r' then skipWs cs else c :: cs
  | [] => []

/-- Value of a hexadecimal digit. -/
def hexVal (c : Char) : Option Nat :=
  if '0' ≤ c ∧ c ≤ '9' then some (c.toNat - '0'.toNat)
  else if 'a' ≤ c ∧ c ≤ 'f' then some (c.toNat - 'a'.toNat + 10)
  else if 'A' ≤ c ∧ c ≤ 'F' then some (c.toNat - 'A'.toNat + 10)
  else none

/-- Body of a string literal after the opening quote; `acc` is reversed. -/
def strBody : List Char → List Char → Except PErr (String × List Char)
  | [], _ => .error (0, "unterminated string")
  | '"' :: rest, acc => .ok (String.ofList acc.reverse, rest)
  | '\\' :: '"' :: rest, acc => strBody rest ('"' :: acc)
  | '\\' :: '\\' :: rest, acc => strBody rest ('\\' :: acc)
  | '\\' :: '/' :: rest, acc => strBody rest ('/' :: acc)
  | '\\' :: 'b' :: rest, acc => strBody rest (Char.ofNat 8 :: acc)
  | '\\' :: 'f' :: rest, acc => strBody rest (Char.ofNat 12 :: acc)
  | '\\' :: 'n' :: rest, acc => strBody rest ('\n' :: acc)
  | '\\' :: 'r' :: rest, acc => strBody rest ('\r' :: acc)
  | '\\' :: 't' :: rest, acc => strBody rest ('\t' :: acc)
  | '\\' :: 'u' :: a :: b :: c :: d :: rest, acc =>
    match hexVal a, hexVal b, hexVal c, hexVal d with
    | some a, some b, some c, some d =>
      let v := ((a * 16 + b) * 16 + c) * 16 + d
      -- A lone surrogate half is not a character: keep U+FFFD (keys and enum names are ASCII).
      strBody rest ((if 0xD800 ≤ v ∧ v ≤ 0xDFFF then Char.ofNat 0xFFFD else Char.ofNat v) :: acc)
    | _, _, _, _ => fail (a :: b :: c :: d :: rest) "bad \\u escape"
  | '\\' :: cs, _ => fail cs "bad escape"
  | c :: rest, acc =>
    if c.val < 0x20 then fail (c :: rest) "control character in string"
    else strBody rest (c :: acc)

/-- Maximal run of ASCII digits and what follows it. -/
def digits : List Char → List Char × List Char
  | c :: cs => if '0' ≤ c ∧ c ≤ '9' then
      let (d, r) := digits cs
      (c :: d, r)
    else ([], c :: cs)
  | [] => ([], [])

/-- Natural number of a digit string. -/
def natOfDigits (ds : List Char) : Nat :=
  ds.foldl (fun n c => n * 10 + (c.toNat - '0'.toNat)) 0

/-- A number starting at `cs` (optional `-`, then digits): `J.int` when there is
no fraction or exponent, else `J.float` with the source text. -/
def number (cs : List Char) : Except PErr (J × List Char) :=
  let (neg, afterSign) := match cs with | '-' :: r => (true, r) | r => (false, r)
  let (intDs, afterInt) := digits afterSign
  if intDs.isEmpty then fail cs "expected a digit"
  else if intDs.length > 1 && intDs.head! == '0' then fail cs "leading zero"
  else
    let hasFrac := afterInt.head? == some '.'
    let (fracDs, afterFrac, okFrac) := match afterInt with
      | '.' :: r => let (d, r') := digits r; (d, r', !d.isEmpty)
      | r => ([], r, true)
    if !okFrac then fail afterInt "expected digits after '.'"
    else
      let (expPart, afterExp, okExp) := match afterFrac with
        | e :: r =>
          if e == 'e' || e == 'E' then
            let (sg, r1) := match r with
              | '+' :: t => (['+'], t) | '-' :: t => (['-'], t) | t => ([], t)
            let (d, r2) := digits r1
            (e :: sg ++ d, r2, !d.isEmpty)
          else ([], afterFrac, true)
        | [] => ([], [], true)
      if !okExp then fail afterFrac "expected digits in exponent"
      else if !hasFrac && expPart.isEmpty then
        let n : Int := natOfDigits intDs
        .ok (J.int (if neg then -n else n), afterInt)
      else
        let text := (if neg then "-" else "") ++ String.ofList intDs ++
          (if hasFrac then "." ++ String.ofList fracDs else "") ++ String.ofList expPart
        .ok (J.float text, afterExp)

/-- A duplicate key among object members (sort, then compare neighbours). -/
def hasDupKey (kvs : List (String × J)) : Bool :=
  let ks := (kvs.map (·.1)).mergeSort (fun a b => decide (a ≤ b))
  let rec go : List String → Bool
    | a :: b :: rest => a == b || go (b :: rest)
    | _ => false
  go ks

mutual
/-- One value. `fuel` bounds the total work, `depth` the nesting. -/
def value (depth fuel : Nat) (cs : List Char) : Except PErr (J × List Char) :=
  match fuel with
  | 0 => .error (cs.length, "input too large")
  | fuel + 1 =>
    match skipWs cs with
    | [] => .error (0, "unexpected end of input")
    | '{' :: rest =>
      if depth ≥ maxDepth then fail cs "nesting too deep"
      else
        match skipWs rest with
        | '}' :: r => .ok (J.obj [], r)
        | r => members depth fuel r []
    | '[' :: rest =>
      if depth ≥ maxDepth then fail cs "nesting too deep"
      else
        match skipWs rest with
        | ']' :: r => .ok (J.arr [], r)
        | r => elems depth fuel r []
    | '"' :: rest => do
      let (s, r) ← strBody rest []
      return (J.str s, r)
    | 't' :: 'r' :: 'u' :: 'e' :: r => .ok (J.bool true, r)
    | 'f' :: 'a' :: 'l' :: 's' :: 'e' :: r => .ok (J.bool false, r)
    | 'n' :: 'u' :: 'l' :: 'l' :: r => .ok (J.null, r)
    | c :: r =>
      if c == '-' || ('0' ≤ c ∧ c ≤ '9') then number (c :: r)
      else fail (c :: r) "unexpected character"

/-- Array elements after the opening bracket; `acc` is reversed. -/
def elems (depth fuel : Nat) (cs : List Char) (acc : List J) : Except PErr (J × List Char) :=
  match fuel with
  | 0 => .error (cs.length, "input too large")
  | fuel + 1 => do
    let (v, r) ← value (depth + 1) fuel cs
    match skipWs r with
    | ',' :: r' => elems depth fuel r' (v :: acc)
    | ']' :: r' => return (J.arr (v :: acc).reverse, r')
    | r' => fail r' "expected ',' or ']'"

/-- Object members after the opening brace; `acc` is reversed. -/
def members (depth fuel : Nat) (cs : List Char) (acc : List (String × J)) : Except PErr (J × List Char) :=
  match fuel with
  | 0 => .error (cs.length, "input too large")
  | fuel + 1 =>
    match skipWs cs with
    | '"' :: rest => do
      let (k, r) ← strBody rest []
      match skipWs r with
      | ':' :: r' => do
        let (v, r'') ← value (depth + 1) fuel r'
        match skipWs r'' with
        | ',' :: r3 => members depth fuel r3 ((k, v) :: acc)
        | '}' :: r3 =>
          let kvs := ((k, v) :: acc).reverse
          if hasDupKey kvs then fail r'' "duplicate object key"
          else return (J.obj kvs, r3)
        | r3 => fail r3 "expected ',' or '}'"
      | r' => fail r' "expected ':'"
    | r => fail r "expected a string key"
end

end Json

/-- Parse a complete JSON text. The error is `offset N: message`, N counted in
characters. Total. -/
def parseJson (s : String) : Except String J :=
  let cs := s.toList
  match Json.value 0 (2 * cs.length + 2) cs with
  | .error (left, msg) => .error s!"offset {cs.length - left}: {msg}"
  | .ok (v, rest) =>
    match Json.skipWs rest with
    | [] => .ok v
    | r => .error s!"offset {cs.length - r.length}: trailing characters"

end UsTax.Api
