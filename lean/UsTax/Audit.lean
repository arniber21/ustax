import Lean
import UsTax.Basic
open Lean Elab Command

namespace UsTax.Audit

/-- Definitions a theorem's statement mentions, followed transitively through
their bodies. The proof is not followed. -/
partial def specSurface (env : Environment) (thm : Name) : NameSet :=
  let rec go (todo : List Name) (seen : NameSet) : NameSet :=
    match todo with
    | [] => seen
    | c :: rest =>
      if seen.contains c then go rest seen else
      let next := match env.find? c with
        | some (.defnInfo d) => d.type.getUsedConstants.toList ++ d.value.getUsedConstants.toList
        | some ci => ci.type.getUsedConstants.toList
        | none => []
      go (next ++ rest) (seen.insert c)
  match env.find? thm with
  | some ci => go ci.type.getUsedConstants.toList {}
  | none => {}

/-- True when the constant lives in this project (module name starts with `UsTax`). -/
def isOwn (env : Environment) (c : Name) : Bool :=
  match env.getModuleIdxFor? c with
  | some idx => (env.header.moduleNames[idx.toNat]!).getRoot == `UsTax
  | none => true  -- declared in the current file

/-- `#spec_surface thm`: list the project's own definitions the statement of `thm` depends on. -/
elab "#spec_surface " id:ident : command => do
  let env ← getEnv
  let thm ← liftCoreM <| realizeGlobalConstNoOverloadWithInfo id
  let own := (specSurface env thm).toList.filter fun c =>
    isOwn env c && !c.isInternal && !Meta.isMatcherCore env c
  logInfo m!"{own}"

/-- `#audit_axioms thm`: print the axioms `thm` depends on. -/
elab "#audit_axioms " id:ident : command => do
  let thm ← liftCoreM <| realizeGlobalConstNoOverloadWithInfo id
  let axs ← liftCoreM <| collectAxioms thm
  logInfo m!"{thm}: {axs.toList}"


/-- Module name of a constant, if it was imported (none: declared in the current file). -/
def moduleOf? (env : Environment) (c : Name) : Option Name :=
  (env.getModuleIdxFor? c).map fun idx => env.header.moduleNames[idx.toNat]!

/-- Axioms a proof may use (CLAUDE.md section 7). -/
def allowedAxioms : List Name := [``propext, ``Classical.choice, ``Quot.sound]

/-- `#audit_all`: for every non-internal declaration of this project (modules under
`UsTax`, except `UsTax.Comparator`), compute the axioms it depends on. Logs the
count of theorems and definitions audited and fails if a declaration is an
`axiom`, or depends on an axiom outside `allowedAxioms` (`sorryAx` for `sorry`,
`Lean.ofReduceBool` and friends for `native_decide`). Used by `scripts/audit.sh`. -/
elab "#audit_all" : command => do
  let env ← getEnv
  let mut own : Array Name := #[]
  for (c, _) in env.constants.toList do
    if c.isInternal || Meta.isMatcherCore env c then continue
    let ok := match moduleOf? env c with
      | some m => m.getRoot == `UsTax && !(`UsTax.Comparator).isPrefixOf m
      | none => true
    if ok then own := own.push c
  own := own.qsort Name.lt
  let mut nthm : Nat := 0
  let mut ndef : Nat := 0
  let mut bad : Array MessageData := #[]
  for c in own do
    match env.find? c with
    | some (.axiomInfo _) => bad := bad.push m!"{c}: declared as an axiom"
    | some ci =>
      match ci with
      | .thmInfo _ => nthm := nthm + 1
      | .defnInfo _ | .opaqueInfo _ => ndef := ndef + 1
      | _ => continue
      let axs ← liftCoreM <| collectAxioms c
      let extra := axs.filter (!allowedAxioms.contains ·)
      if !extra.isEmpty then bad := bad.push m!"{c}: uses {extra.toList}"
    | none => pure ()
  for c in own do
    if let some (.thmInfo _) := env.find? c then logInfo m!"theorem {c}"
  if bad.isEmpty then
    logInfo m!"AUDIT OK: {nthm} theorems and {ndef} definitions use only propext, Classical.choice, Quot.sound"
  else
    throwError m!"AUDIT FAILED:\n{MessageData.joinSep bad.toList "\n"}"

end UsTax.Audit

-- demo
namespace UsTax.Demo

/-- Demo spec: `x` is a valid TY2024 label length (placeholder). -/
def IsVersionLabel (s : String) : Prop := s = UsTax.version

theorem version_is_label : IsVersionLabel UsTax.version := rfl

end UsTax.Demo

#spec_surface UsTax.Demo.version_is_label
#audit_axioms UsTax.Demo.version_is_label
#print axioms UsTax.Demo.version_is_label
