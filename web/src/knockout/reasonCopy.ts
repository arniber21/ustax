import type { ReasonCategory } from '../api';

/** Friendly copy for one category of unsupported situations. */
export interface CategoryCopy {
  title: string;
  /** What this means for the person. */
  means: string;
  /** What to do instead. */
  todo: string;
}

/** Category-level copy; also the fallback for a reason code we have no specific line for. */
export const CATEGORY_COPY: Record<ReasonCategory, CategoryCopy> = {
  credits: {
    title: 'Tax credits',
    means: 'Some credits need extra paperwork and judgment calls that we can’t check reliably yet.',
    todo: 'A free-filing program or a volunteer preparer can work out these credits with you.',
  },
  estimated_payments: {
    title: 'Estimated tax payments',
    means: 'Payments you made to the IRS during the year need to be matched against IRS records, which we can’t do yet.',
    todo: 'Gather your payment confirmations and use a filing service that can match them for you.',
  },
  filers: {
    title: 'Who is filing',
    means: 'Something about who is on this return, such as age, residency or marital arrangements, needs special rules.',
    todo: 'Free help is available from IRS-certified volunteers, who can check which rules apply to you.',
  },
  health_coverage: {
    title: 'Health coverage',
    means: 'Marketplace plans and premium credits involve forms (like 1095-A) and calculations we don’t support yet.',
    todo: 'Keep your Form 1095-A handy and file with software that supports the Premium Tax Credit.',
  },
  household: {
    title: 'Your household',
    means: 'Dependents and household arrangements can have details, like ID numbers or custody splits, that we can’t handle yet.',
    todo: 'A volunteer preparer or free-filing program can walk through your household with you.',
  },
  hsa: {
    title: 'Health savings accounts',
    means: 'HSAs have many special rules about contributions, coverage and withdrawals that we don’t support yet.',
    todo: 'Bring your Form 1099-SA and 5498-SA to a free-filing program that handles Form 8889.',
  },
  income: {
    title: 'Types of income',
    means: 'You have income or accounts of a kind we don’t cover yet. Guessing here could give you a wrong number.',
    todo: 'Use a free-filing program or a preparer that supports this kind of income.',
  },
  interest: {
    title: 'Interest and investments',
    means: 'Some interest and investment situations need extra forms or limits that we don’t support yet.',
    todo: 'Free-filing programs handle these. Bring your 1099-INT and 1099-DIV forms.',
  },
  process: {
    title: 'How you file',
    means: 'The way or timing of your filing is outside what we can do right now.',
    todo: 'The IRS website explains late and amended filings, and a free-filing program can walk you through them.',
  },
  retirement: {
    title: 'Retirement accounts',
    means: 'Withdrawals, rollovers and pensions have many special cases, and we’d rather be careful than wrong.',
    todo: 'Keep your Form 1099-R and use a filing program that supports retirement distributions.',
  },
  social_security: {
    title: 'Social Security',
    means: 'Social Security benefits can be partly taxable, and some situations need a worksheet we don’t support yet.',
    todo: 'Keep your SSA-1099 and use a free-filing program that handles the benefits worksheet.',
  },
  state: {
    title: 'State taxes',
    means: 'Your state or local taxes need rules we don’t support yet.',
    todo: 'Check your state’s tax website, which often offers its own free filing.',
  },
  unemployment: {
    title: 'Unemployment',
    means: 'Unemployment payments or repayments in your situation need special handling.',
    todo: 'Keep your Form 1099-G and use a filing program that supports unemployment income.',
  },
  w2: {
    title: 'Your W-2',
    means: 'Something on your W-2, often in an unusual box or code, needs special handling we don’t have yet.',
    todo: 'A volunteer preparer or free-filing program can read the unusual box with you.',
  },
};

/** Shown when the API sends a category this build does not know (the contract adds categories in minor versions). */
export const GENERIC_COPY: CategoryCopy = {
  title: 'Something else',
  means: 'Part of your situation is something we don’t support yet.',
  todo: 'A free-filing program or a volunteer preparer can take it from here.',
};

/**
 * One plain-English line per reason code in api/knockout-reasons.json. The test in reasonCopy.test.ts
 * fails if a code is missing here, so a new Catala knockout cannot ship without wording.
 */
export const REASON_COPY: Record<string, string> = {
  // interest
  HasRequiredFactaFilings: 'You have a foreign financial account that triggers extra IRS reporting.',
  FlowKnockoutHasEarlyWithdrawlPenalty: 'You paid a penalty for taking money out of a savings account or CD early.',
  FlowKnockoutHasBonds: 'You have interest from savings bonds or other bonds.',
  FlowKnockoutHasForeignTaxPaid: 'Foreign tax was paid on some of your interest.',
  FlowKnockoutWithholdingUnsupportedState: 'Tax was withheld for a state we don’t support yet.',
  FlowKnockoutStateTaxWithheld: 'State tax was withheld on your interest.',
  HasInterestIncomeAndAgiAboveThresholdForMfs: 'Your interest and income are high enough to need extra forms for married filing separately.',
  HasInterestIncomeAndAgiAboveThresholdForMfjOrQss: 'Your interest and income are high enough to need extra forms for your filing status.',
  HasInterestIncomeAndAgiAboveThresholdForSingleOrHoh: 'Your interest and income are high enough to need extra forms.',
  FlowKnockoutTaxExemptInterest: 'You have tax-exempt interest, such as from municipal bonds.',
  // w2
  KnockoutForBox12Value: 'One of your W-2s has an entry in box 12 that we can’t handle yet.',
  KnockoutForBox12Dependency: 'A box 12 entry on your W-2 depends on other details we can’t check yet.',
  FlowKnockoutAllocatedTips: 'Your W-2 shows allocated tips.',
  FlowKnockoutStatutoryEmployee: 'Your W-2 marks you as a statutory employee.',
  FlowKnockoutThirdPartySickPay: 'Your W-2 shows sick pay paid by a third party.',
  FlowKnockoutNonQualifiedPlans: 'Your W-2 shows pay from a non-qualified deferred compensation plan.',
  KnockoutMedicareWages: 'Your Medicare wages look different from your regular wages in a way we can’t explain yet.',
  AnyFilerExceedsMaxOasdiWages: 'Your Social Security wages are above the yearly limit, which can mean too much was withheld.',
  FlowKnockoutBox15IncomeFromDifferentState: 'Your W-2 shows income from a state other than the one you live in.',
  FlowKnockoutHasRRTACodesInBox14NotInNY: 'Your W-2 has a railroad retirement entry in box 14.',
  HasABox14NYRRTAValueWeKnockout: 'Your W-2 has a New York or railroad retirement entry in box 14.',
  KnockoutYonkersPartYear: 'Your W-2 shows Yonkers tax for part of the year.',
  // unemployment
  FlowKnockout1099GRepayTooHigh: 'You repaid more unemployment than we can handle yet.',
  FlowKnockoutUnemploymentCompensationUnsupportedState: 'You received unemployment from a state we don’t support yet.',
  // income
  ExtraNonPfd1099Misc: 'You have extra income on a 1099-MISC.',
  IncomeSourcesNotSupported: 'You have a kind of income we don’t support yet.',
  NotDigitalAssets: 'Your answers about digital assets, such as crypto, mean we need more than we can do yet.',
  HasForeignAccountsOrTrusts: 'You have a foreign bank account or a foreign trust.',
  MadeIraContributions: 'You made contributions to an IRA.',
  // retirement
  FlowKnockoutRetirementTaxableAmountNotDetermined: 'The taxable amount of a retirement payment can’t be determined from your form.',
  FlowKnockoutRetirementTaxableAmountBlank: 'The taxable amount on your retirement form (1099-R) is blank.',
  FlowKnockoutRetirementTotalDistribution: 'Your retirement account was paid out in full (a total distribution).',
  KnockoutForForm1099RBox8Value: 'Your 1099-R shows other income allocated to an IRA (box 8).',
  KnockoutForForm1099RBox8Percentage: 'Your 1099-R shows a percentage in box 8.',
  KnockoutForForm1099RBox9aPercentage: 'Your 1099-R shows a percentage in box 9a.',
  FlowKnockoutRetirementCapitalGain: 'Your retirement payment includes a capital gain amount.',
  FlowKnockoutRetirementNetUnrealizedAppreciation: 'Your retirement payment includes employer stock with unrealized gains.',
  FlowKnockoutRetirementAmountAllocableToIRR: 'Your retirement payment has an amount allocable to an IRA rollover.',
  FlowKnockoutRetirementFactaFilingRequirement: 'Your retirement account triggers extra foreign-account reporting.',
  FlowKnockoutForRollover: 'You rolled money from one retirement account to another.',
  FlowKnockoutForDeathBenefitPaymentDate: 'Your retirement payment is a death benefit.',
  FlowKnockoutRetirementQualifiedDisasterDistribution: 'You took a retirement payment because of a federal disaster.',
  FlowKnockoutRetirementPublicSafetyOfficer: 'Your retirement payment involves public safety officer insurance.',
  FlowKnockoutForPreTaxToPostTaxRollover: 'You moved money from a pre-tax to a Roth-style retirement account.',
  FlowKnockoutBox15: 'Your retirement form shows state tax details in box 15.',
  KnockoutForForm1099RDistributionCode: 'Your 1099-R has a distribution code we can’t handle yet.',
  KnockoutIraSepSimple: 'You took money out of an IRA, SEP or SIMPLE plan.',
  KnockoutTaxablePensionRollover: 'You rolled over a taxable pension.',
  KnockoutIndirectRollover: 'You did an indirect retirement rollover, where the money passed through your hands.',
  KnockoutTaxableAmountNotDetermined: 'The taxable part of a retirement payment is not known.',
  // social_security
  SocialSecurityBenefitsAreLossGreaterThan3k: 'You received Social Security benefits and your situation needs the benefits worksheet.',
  // estimated_payments
  KnockoutPaidEstimatedTaxesUnderDifferentLastName: 'You paid estimated taxes under a different last name.',
  // hsa
  KnockoutNoPaymentsHsaDistribution: 'You have an HSA withdrawal with no matching payments recorded.',
  FlowKnockoutHsaMedicalSavingsAccountType: 'Your account is a medical savings account, not an HSA.',
  FlowKnockoutHsaDistributionCode: 'Your HSA form has a distribution code we can’t handle yet.',
  FlowKnockoutOtherCoveragePartOfYear: 'You had other health coverage for part of the year, which affects your HSA.',
  FlowKnockoutOtherCoverageWholeYear: 'You had other health coverage all year, which affects your HSA.',
  FlowKnockoutEarningsOnExcessContributions: 'Your HSA has earnings on contributions above the limit.',
  FlowKnockoutHsaTestingPeriodAdditionalIncomeYes: 'Your HSA is in a testing period that adds income.',
  FlowKnockoutHsaUnqualifiedDistributions: 'You took HSA money out for something that isn’t a qualified expense.',
  FlowKnockoutHsaDistributionFMV: 'Your HSA form reports the value of an account that was moved.',
  FlowKnockoutMaritalChangeAffectsContributionLimit: 'A change in marital status changes your HSA contribution limit.',
  FlowKnockoutMFSLine6Check: 'Filing separately changes how your HSA limit is split.',
  FlowHsaContributionsOverLimitKnockout: 'Your HSA contributions went over the yearly limit.',
  FlowKnockoutHsaExcessContributions: 'You have excess HSA contributions.',
  FlowKnockoutContributionSummaryNoneAllowed: 'Your HSA situation allows no contributions this year.',
  FlowKnockoutHdhpCoverageStatusNotNeeded: 'Your HSA answers need a coverage detail we can’t check yet.',
  FlowKnockoutNotEnrolledInHdhp: 'You weren’t enrolled in a high-deductible health plan, which affects HSA contributions.',
  FlowKnockoutMadeQualifiedHsaFundingDistribution: 'You moved IRA money into your HSA.',
  FlowKnockoutHsaCoverage: 'Your HSA coverage details need a check we can’t do yet.',
  FlowKnockoutFilerIsDependentAndContributesToHsa: 'You can be claimed as someone’s dependent and you contributed to an HSA.',
  ExtraHsaDistributionsWithoutActivity: 'You have HSA withdrawals without matching HSA activity.',
  ExtraHsaDistributionsSecondaryFilerWithoutMfj: 'Your spouse has HSA withdrawals but you aren’t filing jointly.',
  // state
  FlowKnockoutUnsupportedState: 'You live in or earned money in a state we don’t support yet.',
  // process
  IsTooLateToFileOrResubmit: 'It’s past the filing window, or this is a resubmission.',
  KnockoutHasNoPaymentsOrCredits: 'You have no payments or credits to report.',
  // filers
  FlowKnockoutFilerAgeYoungerThan16: 'A filer on this return is younger than 16.',
  SpouseItemizesKnockout: 'Your spouse itemizes deductions.',
  PrimaryFilerResidencyKnockout: 'Your residency situation needs special rules.',
  FlowKnockoutHasApplicableRegisteredDomesticPartnership: 'You are in a registered domestic partnership.',
  KnockoutSubjectToCommunityPropertyLaws: 'You live in a community property state, which changes how income is split.',
  // household
  KnockoutHohQpHasNoTin: 'A person you claim for head of household has no taxpayer ID number.',
  KnockoutPersonBornAndDiedInTaxYearWithoutTin: 'A child who was born and died this year has no taxpayer ID number.',
  KnockedOutByNonCustodialParentBenefitSplit: 'Parents who don’t live together are splitting tax benefits for a child.',
  KnockedOutByContradictory8832: 'Your answers about who claims a dependent contradict each other.',
  // health_coverage
  DependentTpRequiresAllocations: 'A dependent’s marketplace coverage needs the cost to be divided up.',
  HasPtcQualifyingPlanAndQsehra: 'You have a marketplace plan and a small-employer health reimbursement.',
  NeedsAllocations: 'Your marketplace coverage needs the cost to be divided up.',
  HasEmployerSponsoredPlan: 'You had a health plan through an employer, which affects premium credits.',
  DependentsRequiredToFile: 'Your dependents’ health coverage affects how you file.',
  SelfReportedHasMultiple1095As: 'You received more than one Form 1095-A.',
  HasImmigrationStatusNotEligibleForMarketplace: 'Your immigration status affects marketplace coverage rules.',
  WantsToUseAltCalculations: 'You want to use an alternative method for premium credit calculations.',
  // credits
  SaversCreditKnockouts: 'You may qualify for the Saver’s Credit.',
  KnockoutStudentOrDisabled: 'You or a dependent is a student or has a disability, which changes credit rules.',
  FlowKnockoutBenefitsDistribution: 'You received benefits that affect your credits.',
  KnockoutCdccWorksheetA: 'You paid for child or dependent care, which needs a special worksheet.',
  FlowKnockoutHouseholdEmployee: 'You paid someone to work in your home.',
};

export interface FriendlyReason {
  code: string;
  category: ReasonCategory;
  /** Plain-English line for this reason. */
  what: string;
  /** True when we had no wording for this code and used the category text. */
  fallback: boolean;
}

/** Wording for a reason code from the API, never empty, never the raw code. */
export function friendlyReason(code: string, category: ReasonCategory): FriendlyReason {
  const specific = REASON_COPY[code];
  if (specific) return { code, category, what: specific, fallback: false };
  const cat = CATEGORY_COPY[category] ?? GENERIC_COPY;
  return { code, category, what: `Something in your answers about “${cat.title.toLowerCase()}” isn’t supported yet.`, fallback: true };
}

/** Category copy, tolerating categories added after this build. */
export const categoryCopy = (category: string): CategoryCopy => CATEGORY_COPY[category as ReasonCategory] ?? GENERIC_COPY;
