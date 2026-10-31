#!/usr/bin/env python3
"""Differential test of catala/form_w2s.catala_en against oracle/facts.csv.

Usage (from the repository root, with clerk on PATH):

    python3 oracle/w2_difftest.py          # generate, run `clerk test`, report

Generates catala/tests/oracle_form_w2s.catala_en: one #[test] scope per oracle
scenario, whose inputs are the scenario's /formW2s/* rows, /filingStatus,
/combatPayElection and the filers' canBeClaimed, and whose assertions are the
oracle values of /wages, /formW2Withholding, /socialSecurityTaxesWithheld,
/allCombatPay and /combatPayAmount. A scenario the engine marks knocked out
(/flowIsKnockedOut = true) is skipped and listed. Inputs the scenario leaves
unanswered are $0, as in DF (`Switch` on `IsComplete` falling back to `$0`).

Pass --no-run to only write the file.
"""
import csv, re, subprocess, sys, collections, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "catala/tests/oracle_form_w2s.catala_en")

# oracle (DF) field name -> Catala field of Form_w2s.FormW2
MONEY_FIELDS = {
    "writableWages": "writable_wages",
    "writableFederalWithholding": "writable_federal_withholding",
    "writableOasdiWages": "writable_oasdi_wages",
    "writableOasdiWithholding": "writable_oasdi_withholding",
    "writableMedicareWages": "writable_medicare_wages",
    "writableMedicareWithholding": "writable_medicare_withholding",
    "writableAllocatedTips": "writable_allocated_tips",
    "writableDependentCareBenefits": "writable_dependent_care_benefits",
    "writableNonQualifiedPlans": "writable_non_qualified_plans",
    "writableCombatPay": "writable_combat_pay",
    "uncollectedOasdiTaxOnTips": "uncollected_oasdi_tax_on_tips",
    "uncollectedMedicareTaxOnTips": "uncollected_medicare_tax_on_tips",
    "taxableLifeInsuranceOver50k": "taxable_life_insurance_over_50k",
    "401kDeferrals": "deferrals_401k",
    "403bDeferrals": "deferrals_403b",
    "sarsepDeferrals": "sarsep_deferrals",
    "457bDeferrals": "deferrals_457b",
    "501c18Deferrals": "deferrals_501c18",
    "nontaxableSickPay": "nontaxable_sick_pay",
    "goldenParachuteExciseTax": "golden_parachute_excise_tax",
    "expenseReimbursements": "expense_reimbursements",
    "uncollectedOasdiTaxOnLifeInsuranceOver50k": "uncollected_oasdi_tax_on_life_insurance_over_50k",
    "uncollectedMedicareTaxOnLifeInsuranceOver50k": "uncollected_medicare_tax_on_life_insurance_over_50k",
    "armedForcesMovingExpenses": "armed_forces_moving_expenses",
    "archerMsaContributions": "archer_msa_contributions",
    "simpleContributions": "simple_contributions",
    "adoptionBenefits": "adoption_benefits",
    "nsoIncome": "nso_income",
    "employerHsaContributions": "employer_hsa_contributions",
    "409aDeferrals": "deferrals_409a",
    "nqdcDeferrals": "nqdc_deferrals",
    "roth401kContributions": "roth401k_contributions",
    "roth403bContributions": "roth403b_contributions",
    "healthCoverageCost": "health_coverage_cost",
    "roth457bContributions": "roth457b_contributions",
    "qsehraBenefits": "qsehra_benefits",
    "83iIncome": "income_83i",
    "83iDeferrals": "deferrals_83i",
    "nonTaxableMedicaidWaiverPayments": "non_taxable_medicaid_waiver_payments",
}
BOOL_FIELDS = {
    "457bIsGovernmentalPlan": "plan_457b_is_governmental",
    "statutoryEmployee": "statutory_employee",
    "thirdPartySickPay": "third_party_sick_pay",
}
STATUS = {
    "single": "Single",
    "marriedFilingJointly": "MarriedFilingJointly",
    "marriedFilingSeparately": "MarriedFilingSeparately",
    "headOfHousehold": "HeadOfHousehold",
    "qualifiedSurvivingSpouse": "QualifyingSurvivingSpouse",
}
ELECTION = {
    "noCombatPay": "NoCombatPay",
    "usePrimaryCombatPay": "UsePrimaryCombatPay",
    "useSpouseCombatPay": "UseSpouseCombatPay",
    "useBothCombatPay": "UseBothCombatPay",
    "usePrimaryNotSpouseCombatPay": "UsePrimaryNotSpouseCombatPay",
    "useSpouseNotPrimaryCombatPay": "UseSpouseNotPrimaryCombatPay",
}
OUTPUTS = [
    ("/wages", "wages"),
    ("/formW2Withholding", "form_w2_withholding"),
    ("/socialSecurityTaxesWithheld", "social_security_taxes_withheld"),
    ("/allCombatPay", "all_combat_pay"),
    ("/combatPayAmount", "combat_pay_amount"),
]


def money(s):
    """'1234.50' -> '$1,234.50' (Catala literal)."""
    neg = s.startswith("-")
    whole, _, cents = s.lstrip("-").partition(".")
    cents = (cents + "00")[:2]
    body = f"{int(whole):,}.{cents}" if cents != "00" else f"{int(whole):,}"
    return ("-" if neg else "") + "$" + body


def main():
    scen = collections.OrderedDict()
    for r in csv.DictReader(open(os.path.join(ROOT, "oracle/facts.csv"))):
        scen.setdefault(r["scenario"], {})[r["path"]] = r
    out = []
    skipped = []
    n_scopes = 0
    for name, facts in scen.items():
        ko = facts.get("/flowIsKnockedOut", {}).get("value") == "true"
        if ko:
            skipped.append(name)
            continue
        filers = {}
        for p, r in facts.items():
            m = re.fullmatch(r"/filers/#([^/]+)/(isPrimaryFiler|canBeClaimed)", p)
            if m:
                filers.setdefault(m.group(1), {})[m.group(2)] = r["value"] == "true"
        w2ids = [x for x in facts.get("/formW2s", {}).get("value", "").split(";") if x]
        status = STATUS[facts["/filingStatus"]["value"]]
        election = ELECTION[facts["/combatPayElection"]["value"]] if "/combatPayElection" in facts else "NoCombatPay"
        primary_id = next((i for i, f in filers.items() if f.get("isPrimaryFiler")), None)

        def role(fid):
            return "PrimaryFiler" if fid == primary_id else "SecondaryFiler"

        def claimed(rolename):
            fid = primary_id if rolename == "PrimaryFiler" else next((i for i in filers if i != primary_id), None)
            return bool(fid and filers.get(fid, {}).get("canBeClaimed"))

        ident = re.sub(r"[^0-9A-Za-z]", "_", name)
        n_scopes += 1
        decl = [f"#[test]", f"declaration scope Oracle_{ident}:"]
        body = [f"scope Oracle_{ident}:"]
        items = []
        for k, wid in enumerate(w2ids):
            inst = f"w{k}"
            decl.append(f"  {inst} scope MkW2")
            fid = facts.get(f"/formW2s/#{wid}/filer", {}).get("value", "")
            body.append(f"  definition {inst}.filer equals Types.FilerRole.{role(fid)}")
            for df, cat in MONEY_FIELDS.items():
                r = facts.get(f"/formW2s/#{wid}/{df}")
                if r and r["value"] != "":
                    body.append(f"  definition {inst}.{cat} equals {money(r['value'])}")
            for df, cat in BOOL_FIELDS.items():
                r = facts.get(f"/formW2s/#{wid}/{df}")
                if r and r["value"] != "":
                    body.append(f"  definition {inst}.{cat} equals {r['value']}")
            items.append(f"{inst}.w2")
        decl.append("  f scope W.FormW2s")
        body.append("  definition f.w2s equals [" + "; ".join(items) + "]")
        body.append(f"  definition f.filing_status equals Types.FilingStatus.{status}")
        body.append(f"  definition f.primary_filer_can_be_claimed equals {'true' if claimed('PrimaryFiler') else 'false'}")
        body.append(f"  definition f.secondary_filer_can_be_claimed equals {'true' if claimed('SecondaryFiler') else 'false'}")
        body.append(f"  definition f.combat_pay_election equals W.CombatPayElection.{election}")
        for path, field in OUTPUTS:
            body.append(f"  assertion f.{field} = {money(facts[path]['value'])}")
        # In every scenario the engine does not knock out, no W-2 knockout of
        # this module may fire either (the oracle has no per-knockout rows;
        # this checks the module does not knock out a return DF accepts).
        body.append("  assertion not f.unsupported")
        out.append("\n".join(decl) + "\n\n" + "\n".join(body))

    header = f"""# Oracle differential test for Form_w2s (generated; do not edit by hand)

Generated by `oracle/w2_difftest.py` from `oracle/facts.csv`. Each scope feeds
one scenario's W-2 inputs to `Form_w2s.FormW2s` and asserts the engine's
`/wages`, `/formW2Withholding`, `/socialSecurityTaxesWithheld`, `/allCombatPay`
and `/combatPayAmount`, and that the module's `unsupported` is false. Scenarios
with `/flowIsKnockedOut = true` ({len(skipped)}: {", ".join(skipped)}) are
skipped. Scenarios compared: {n_scopes}.

> Using Types
> Using Form_w2s as W

## Helper: a W-2 with every box defaulting to $0

Contexts have a default that each scenario overrides for the boxes it fills in.

```catala
declaration scope MkW2:
  context filer content Types.FilerRole
"""
    ctx = []
    for cat in list(MONEY_FIELDS.values()):
        ctx.append(f"  context {cat} content money")
    for cat in BOOL_FIELDS.values():
        ctx.append(f"  context {cat} content boolean")
    ctx.append("  output w2 content W.FormW2")
    defaults = ["scope MkW2:", "  definition filer equals Types.FilerRole.PrimaryFiler"]
    for cat in MONEY_FIELDS.values():
        defaults.append(f"  definition {cat} equals $0")
    for cat in BOOL_FIELDS.values():
        defaults.append(f"  definition {cat} equals false")
    defaults.append("  definition w2 equals W.FormW2 {")
    defaults.append("    -- filer: filer")
    for cat in list(MONEY_FIELDS.values()) + list(BOOL_FIELDS.values()):
        defaults.append(f"    -- {cat}: {cat}")
    defaults.append("  }")
    text = header + "\n".join(ctx) + "\n\n" + "\n".join(defaults) + "\n```\n\n"
    text += "\n\n".join("```catala\n" + o + "\n```" for o in out) + "\n"
    open(OUT, "w").write(text)
    print(f"wrote {OUT}: {n_scopes} scenarios compared, {len(skipped)} skipped: {skipped}")
    if "--no-run" in sys.argv:
        return
    p = subprocess.run(["clerk", "test"], cwd=ROOT, capture_output=True, text=True)
    sys.stdout.write(p.stdout[-3000:])
    sys.stderr.write(p.stderr[-3000:])
    sys.exit(p.returncode)


main()
