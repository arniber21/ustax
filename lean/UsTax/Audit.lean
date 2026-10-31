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
