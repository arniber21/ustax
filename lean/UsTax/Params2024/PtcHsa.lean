import UsTax.TaxRates

/-!
# Tax year 2024 parameters of the premium tax credit and HSA modules

The `Params_2024` figures `catala/ptc_family.catala_en`, `catala/ptc_allowed.catala_en` and
`catala/hsa.catala_en` read (`catala/params_2024.catala_en`, sections "Premium tax credit:
poverty line and applicable figure" and the HSA lines), copied one for one with the Catala
names in lower camel case. Kept in this file, not in `Params2024.lean`, so that parallel
modules do not edit the same file. Amounts are cents (`TaxRates.usd`); decimals are exact
`Rat`s; Catala integers are `Int`.

The Table 5 repayment limits are declared in `catala/ptc_net.catala_en` itself, not in
`Params_2024`; they are in `UsTax/PtcNet.lean`.
-/

namespace UsTax.Params

open TaxRates (usd)

/-! ### HSA (Rev. Proc. 2023-23 section 3.04, IRC 223(b)(3)(B)) -/

/-- Rev. Proc. 2023-23, `rp-23-23.pdf` p 2: annual limitation, self-only coverage, $4,150. -/
def hsaLimitSelfOnly : Int := usd 4_150
/-- Rev. Proc. 2023-23, `rp-23-23.pdf` p 2: annual limitation, family coverage, $8,300. -/
def hsaLimitFamily : Int := usd 8_300
/-- IRC 223(b)(3)(B): additional contribution amount at 55 or older, $1,000 (not indexed). -/
def hsaCatchUp55 : Int := usd 1_000

/-! ### Premium tax credit (Form 8962 instructions, `i8962--2024.pdf` pp 8 to 10) -/

/-- Table 1-1: 48 states and DC, a family of one, $14,580. -/
def ptcPovertyLineFamilyOfOneOther : Int := usd 14_580
/-- Table 1-1: each additional person, $5,140. -/
def ptcPovertyLineIncrementOther : Int := usd 5_140
/-- Table 1-2: Alaska, a family of one, $18,210. -/
def ptcPovertyLineFamilyOfOneAlaska : Int := usd 18_210
/-- Table 1-2: Alaska, each additional person, $6,430. -/
def ptcPovertyLineIncrementAlaska : Int := usd 6_430
/-- Table 1-3: Hawaii, a family of one, $16,770. -/
def ptcPovertyLineFamilyOfOneHawaii : Int := usd 16_770
/-- Table 1-3: Hawaii, each additional person, $5,910. -/
def ptcPovertyLineIncrementHawaii : Int := usd 5_910

/-- Worksheet 2 line 3: "Multiply the amount on line 2 by 4.0". -/
def ptcPovertyPercentCapMultiple : Int := 4
/-- Worksheet 2 line 4: above the cap, "Enter 401". -/
def ptcPovertyPercentOverCap : Rat := 401

/-- Table 2: 0.0000 up to this row (150). -/
def ptcApplicableFigureZeroThrough : Int := 150
/-- Table 2: the first linear part ends at row 300. -/
def ptcApplicableFigureLinearThrough : Int := 300
/-- Table 2: the last printed interpolated row, 399. -/
def ptcApplicableFigureLastRow : Int := 399
/-- Table 2: "400 or more". -/
def ptcApplicableFigureMaxRow : Int := 400
/-- Table 2: 0.0004 per point from 150 to 300. -/
def ptcApplicableFigurePerPointLow : Rat := 4 / 10000
/-- Table 2: 0.0600 at 300. -/
def ptcApplicableFigureAt300 : Rat := 6 / 100
/-- Table 2: 0.00025 per point from 300 to 400. -/
def ptcApplicableFigurePerPointHigh : Rat := 25 / 100000
/-- Table 2: 0.0850 at 400 or more. -/
def ptcApplicableFigureMax : Rat := 85 / 1000

/-- IRC 36B(c)(1)(A): an applicable taxpayer's household income is at least 100 percent of
the poverty line. -/
def ptcApplicableTaxpayerPovertyPercentFloor : Rat := 100

end UsTax.Params
