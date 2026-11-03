/**
 * The app applies plan limits only where paid plans can be bought
 * (FeatureGateService.planLimitsEnforced = SubscriptionService.paidPlansEnabled),
 * and that is false in a browser (kIsWeb). The web follows, for checklists and
 * for team seats alike: no limit, so a Free company is never stuck without a
 * place to buy a plan. The counts still show (Plano, Equipe).
 */
export const WEB_PLAN_LIMITS_ENFORCED = false
