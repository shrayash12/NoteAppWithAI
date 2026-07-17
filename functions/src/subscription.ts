import * as admin from "firebase-admin";
import {HttpsError} from "firebase-functions/v2/https";

export type Plan = "free" | "pro_monthly" | "pro_yearly";
export type AIAction = "enhance" | "summarize" | "translate";

export const PLAN_LIMITS: Record<Plan, Record<AIAction, number>> = {
  free: {summarize: 10, enhance: 10, translate: 10},
  pro_monthly: {summarize: 300, enhance: 300, translate: 300},
  pro_yearly: {summarize: 6000, enhance: 6000, translate: 6000},
};

interface UsageCounts {
  summarize: number;
  enhance: number;
  translate: number;
}

const ZERO_USAGE: UsageCounts = {summarize: 0, enhance: 0, translate: 0};

interface UserSubscriptionDoc {
  plan: Plan;
  planStatus: "active" | "inactive";
  periodStart: admin.firestore.Timestamp;
  periodEnd: admin.firestore.Timestamp;
  usage: UsageCounts;
  revenueCatAppUserId?: string;
}

function addInterval(date: Date, plan: Plan): Date {
  const d = new Date(date.getTime());
  if (plan === "pro_yearly") {
    d.setUTCFullYear(d.getUTCFullYear() + 1);
  } else {
    d.setUTCMonth(d.getUTCMonth() + 1);
  }
  return d;
}

function userDocRef(uid: string) {
  return admin.firestore().collection("users").doc(uid);
}

/**
 * Derives the effective plan/usage state from stored data, applying a lazy
 * period reset if the stored period has elapsed. Does not write anything.
 */
function effectiveState(
  data: Partial<UserSubscriptionDoc> | undefined,
  now: admin.firestore.Timestamp
) {
  let plan: Plan = data?.plan ?? "free";
  const planStatus = data?.planStatus ?? "active";
  if (planStatus !== "active") plan = "free";

  let periodStart = data?.periodStart;
  let periodEnd = data?.periodEnd;
  let usage: UsageCounts = data?.usage ?? {...ZERO_USAGE};
  let didReset = false;

  if (!periodEnd || now.toMillis() >= periodEnd.toMillis()) {
    const newStart = periodEnd ? periodEnd.toDate() : now.toDate();
    periodStart = admin.firestore.Timestamp.fromDate(newStart);
    periodEnd = admin.firestore.Timestamp.fromDate(addInterval(newStart, plan));
    usage = {...ZERO_USAGE};
    didReset = true;
  }

  return {
    plan,
    planStatus,
    periodStart: periodStart as admin.firestore.Timestamp,
    periodEnd: periodEnd as admin.firestore.Timestamp,
    usage,
    didReset,
  };
}

/**
 * Atomically checks quota for `action` and consumes one unit if available.
 * Throws HttpsError('resource-exhausted') if the user is out of quota.
 */
export async function consumeQuota(uid: string, action: AIAction) {
  const ref = userDocRef(uid);

  return admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = admin.firestore.Timestamp.now();
    const state = effectiveState(
      snap.data() as Partial<UserSubscriptionDoc> | undefined,
      now
    );

    const limit = PLAN_LIMITS[state.plan][action];
    const used = state.usage[action] ?? 0;

    if (used >= limit) {
      throw new HttpsError(
        "resource-exhausted",
        `You've used all ${limit} ${action} actions for this period. ` +
          "Upgrade to Pro for more.",
        {plan: state.plan, limit, used, action}
      );
    }

    const newUsage = {...state.usage, [action]: used + 1};
    tx.set(
      ref,
      {
        plan: state.plan,
        planStatus: state.planStatus,
        periodStart: state.periodStart,
        periodEnd: state.periodEnd,
        usage: newUsage,
      },
      {merge: true}
    );

    return {plan: state.plan, limit, used: used + 1, remaining: limit - used - 1};
  });
}

/** Best-effort: gives back one unit of quota after a failed generation. */
export async function refundQuota(uid: string, action: AIAction) {
  const ref = userDocRef(uid);
  try {
    await ref.set(
      {usage: {[action]: admin.firestore.FieldValue.increment(-1)}},
      {merge: true}
    );
  } catch (e) {
    console.error("Failed to refund quota", e);
  }
}

/** Read-only usage summary for the client to display, applying lazy reset. */
export async function getUsageSummary(uid: string) {
  const ref = userDocRef(uid);
  const snap = await ref.get();
  const now = admin.firestore.Timestamp.now();
  const state = effectiveState(
    snap.data() as Partial<UserSubscriptionDoc> | undefined,
    now
  );

  if (state.didReset) {
    await ref.set(
      {
        plan: state.plan,
        planStatus: state.planStatus,
        periodStart: state.periodStart,
        periodEnd: state.periodEnd,
        usage: state.usage,
      },
      {merge: true}
    );
  }

  const limits = PLAN_LIMITS[state.plan];
  const features = (Object.keys(limits) as AIAction[]).reduce(
    (acc, action) => {
      const used = state.usage[action] ?? 0;
      acc[action] = {
        used,
        limit: limits[action],
        remaining: Math.max(0, limits[action] - used),
      };
      return acc;
    },
    {} as Record<AIAction, {used: number; limit: number; remaining: number}>
  );

  return {
    plan: state.plan,
    periodEnd: state.periodEnd.toDate().toISOString(),
    features,
  };
}

/** Applies a RevenueCat subscription state change to the user's doc. */
export async function setSubscriptionState(
  uid: string,
  opts: {
    plan: Plan;
    planStatus: "active" | "inactive";
    periodEndMs: number | null;
    resetUsage: boolean;
    revenueCatAppUserId: string;
  }
) {
  const ref = userDocRef(uid);
  const now = admin.firestore.Timestamp.now();
  const update: Record<string, unknown> = {
    plan: opts.plan,
    planStatus: opts.planStatus,
    revenueCatAppUserId: opts.revenueCatAppUserId,
  };
  if (opts.planStatus === "active") {
    update.periodStart = now;
    update.periodEnd = opts.periodEndMs ?
      admin.firestore.Timestamp.fromMillis(opts.periodEndMs) :
      admin.firestore.Timestamp.fromDate(addInterval(now.toDate(), opts.plan));
  }
  if (opts.resetUsage) {
    update.usage = {...ZERO_USAGE};
  }
  await ref.set(update, {merge: true});
}
