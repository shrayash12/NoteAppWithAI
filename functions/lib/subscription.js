"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PLAN_LIMITS = void 0;
exports.consumeQuota = consumeQuota;
exports.refundQuota = refundQuota;
exports.getUsageSummary = getUsageSummary;
exports.setSubscriptionState = setSubscriptionState;
const admin = require("firebase-admin");
const https_1 = require("firebase-functions/v2/https");
exports.PLAN_LIMITS = {
    free: { summarize: 10, enhance: 10, translate: 10 },
    pro_monthly: { summarize: 300, enhance: 300, translate: 300 },
    pro_yearly: { summarize: 6000, enhance: 6000, translate: 6000 },
};
const ZERO_USAGE = { summarize: 0, enhance: 0, translate: 0 };
function addInterval(date, plan) {
    const d = new Date(date.getTime());
    if (plan === "pro_yearly") {
        d.setUTCFullYear(d.getUTCFullYear() + 1);
    }
    else {
        d.setUTCMonth(d.getUTCMonth() + 1);
    }
    return d;
}
function userDocRef(uid) {
    return admin.firestore().collection("users").doc(uid);
}
/**
 * Derives the effective plan/usage state from stored data, applying a lazy
 * period reset if the stored period has elapsed. Does not write anything.
 */
function effectiveState(data, now) {
    let plan = data?.plan ?? "free";
    const planStatus = data?.planStatus ?? "active";
    if (planStatus !== "active")
        plan = "free";
    let periodStart = data?.periodStart;
    let periodEnd = data?.periodEnd;
    let usage = data?.usage ?? { ...ZERO_USAGE };
    let didReset = false;
    if (!periodEnd || now.toMillis() >= periodEnd.toMillis()) {
        const newStart = periodEnd ? periodEnd.toDate() : now.toDate();
        periodStart = admin.firestore.Timestamp.fromDate(newStart);
        periodEnd = admin.firestore.Timestamp.fromDate(addInterval(newStart, plan));
        usage = { ...ZERO_USAGE };
        didReset = true;
    }
    return {
        plan,
        planStatus,
        periodStart: periodStart,
        periodEnd: periodEnd,
        usage,
        didReset,
    };
}
/**
 * Atomically checks quota for `action` and consumes one unit if available.
 * Throws HttpsError('resource-exhausted') if the user is out of quota.
 */
async function consumeQuota(uid, action) {
    const ref = userDocRef(uid);
    return admin.firestore().runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        const now = admin.firestore.Timestamp.now();
        const state = effectiveState(snap.data(), now);
        const limit = exports.PLAN_LIMITS[state.plan][action];
        const used = state.usage[action] ?? 0;
        if (used >= limit) {
            throw new https_1.HttpsError("resource-exhausted", `You've used all ${limit} ${action} actions for this period. ` +
                "Upgrade to Pro for more.", { plan: state.plan, limit, used, action });
        }
        const newUsage = { ...state.usage, [action]: used + 1 };
        tx.set(ref, {
            plan: state.plan,
            planStatus: state.planStatus,
            periodStart: state.periodStart,
            periodEnd: state.periodEnd,
            usage: newUsage,
        }, { merge: true });
        return { plan: state.plan, limit, used: used + 1, remaining: limit - used - 1 };
    });
}
/** Best-effort: gives back one unit of quota after a failed generation. */
async function refundQuota(uid, action) {
    const ref = userDocRef(uid);
    try {
        await ref.set({ usage: { [action]: admin.firestore.FieldValue.increment(-1) } }, { merge: true });
    }
    catch (e) {
        console.error("Failed to refund quota", e);
    }
}
/** Read-only usage summary for the client to display, applying lazy reset. */
async function getUsageSummary(uid) {
    const ref = userDocRef(uid);
    const snap = await ref.get();
    const now = admin.firestore.Timestamp.now();
    const state = effectiveState(snap.data(), now);
    if (state.didReset) {
        await ref.set({
            plan: state.plan,
            planStatus: state.planStatus,
            periodStart: state.periodStart,
            periodEnd: state.periodEnd,
            usage: state.usage,
        }, { merge: true });
    }
    const limits = exports.PLAN_LIMITS[state.plan];
    const features = Object.keys(limits).reduce((acc, action) => {
        const used = state.usage[action] ?? 0;
        acc[action] = {
            used,
            limit: limits[action],
            remaining: Math.max(0, limits[action] - used),
        };
        return acc;
    }, {});
    return {
        plan: state.plan,
        periodEnd: state.periodEnd.toDate().toISOString(),
        features,
    };
}
/** Applies a RevenueCat subscription state change to the user's doc. */
async function setSubscriptionState(uid, opts) {
    const ref = userDocRef(uid);
    const now = admin.firestore.Timestamp.now();
    const update = {
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
        update.usage = { ...ZERO_USAGE };
    }
    await ref.set(update, { merge: true });
}
//# sourceMappingURL=subscription.js.map