const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

initializeApp();

const db = getFirestore();

function entitlementIsActive(data) {
  if (!data || data.premiumActive !== true) {
    return false;
  }

  const expiresAtMs = data.expiresAtMs;

  if (typeof expiresAtMs === "number" && expiresAtMs <= Date.now()) {
    return false;
  }

  return true;
}

function entitlementResponse(data, sourceOverride = null) {
  return {
    premiumActive: true,
    productId: data.productId ?? null,
    source: sourceOverride ?? data.source ?? "own_subscription",
    purchaseOwnerUid: data.purchaseOwnerUid ?? null,
    expiresAtMs: data.expiresAtMs ?? null,
  };
}

exports.getPremiumEntitlement = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "You must be signed in."
    );
  }

  const uid = request.auth.uid;

  const ownEntitlementSnap = await db
    .doc(`entitlements/${uid}`)
    .get();

  if (ownEntitlementSnap.exists) {
    const ownEntitlement = ownEntitlementSnap.data();

    if (entitlementIsActive(ownEntitlement)) {
      return entitlementResponse(
        ownEntitlement,
        "own_subscription"
      );
    }
  }

  const userSnap = await db
    .doc(`users/${uid}`)
    .get();

  if (!userSnap.exists) {
    return {
      premiumActive: false,
      source: "none",
      purchaseOwnerUid: null,
    };
  }

  const userData = userSnap.data();
  const role = userData.role;

  if (role === "student") {
    const parentQuery = await db
      .collection("users")
      .where("role", "==", "parent")
      .where("linkedStudentIds", "array-contains", uid)
      .limit(1)
      .get();

    if (!parentQuery.empty) {
      const parentUid = parentQuery.docs[0].id;

      const parentEntitlementSnap = await db
        .doc(`entitlements/${parentUid}`)
        .get();

      if (parentEntitlementSnap.exists) {
        const parentEntitlement =
          parentEntitlementSnap.data();

        if (entitlementIsActive(parentEntitlement)) {
          return entitlementResponse(
            parentEntitlement,
            "linked_parent_subscription"
          );
        }
      }
    }
  }

  if (role === "parent") {
    const linkedStudentIds =
      Array.isArray(userData.linkedStudentIds)
        ? userData.linkedStudentIds
        : [];

    for (const studentUid of linkedStudentIds) {
      const studentEntitlementSnap = await db
        .doc(`entitlements/${studentUid}`)
        .get();

      if (!studentEntitlementSnap.exists) {
        continue;
      }

      const studentEntitlement =
        studentEntitlementSnap.data();

      if (entitlementIsActive(studentEntitlement)) {
        return entitlementResponse(
          studentEntitlement,
          "linked_student_subscription"
        );
      }
    }
  }

  return {
    premiumActive: false,
    source: "none",
    purchaseOwnerUid: null,
  };
});

exports.verifyPremiumPurchase = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "You must be signed in."
    );
  }

  const uid = request.auth.uid;

  const productId = request.data?.productId;
  const purchaseId = request.data?.purchaseId;
  const source = request.data?.source;
  const verificationData = request.data?.verificationData;

  const allowedProducts = new Set([
    "sparklearn_premium_monthly",
    "sparklearn_premium_yearly",
  ]);

  if (!allowedProducts.has(productId)) {
    throw new HttpsError(
      "invalid-argument",
      "Unknown subscription product."
    );
  }

  if (!source || !verificationData) {
    throw new HttpsError(
      "invalid-argument",
      "Purchase verification data is missing."
    );
  }

  if (source !== "app_store" && source !== "google_play") {
    throw new HttpsError(
      "invalid-argument",
      "Unsupported purchase source."
    );
  }

  if (source == "google_play") {
    const { google } = require("googleapis");

    const auth = await google.auth.getClient({
      scopes: [
        "https://www.googleapis.com/auth/androidpublisher",
      ],
    });

    const androidPublisher = google.androidpublisher({
      version: "v3",
      auth,
    });

    let subscription;

    try {
      const response =
        await androidPublisher.purchases.subscriptionsv2.get({
          packageName: "com.example.sparklearn",
          token: verificationData,
        });

      subscription = response.data;
    } catch (error) {
      console.error(
        "Google Play subscription verification failed:",
        error
      );

      throw new HttpsError(
        "failed-precondition",
        "Google Play could not verify this subscription."
      );
    }

    const lineItems = subscription.lineItems ?? [];

    const verifiedProduct = lineItems.some(
      (item) => item.productId == productId
    );

    if (!verifiedProduct) {
      throw new HttpsError(
        "failed-precondition",
        "The verified subscription product does not match."
      );
    }

    const activeStates = new Set([
      "SUBSCRIPTION_STATE_ACTIVE",
      "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
    ]);

    if (!activeStates.has(subscription.subscriptionState)) {
      throw new HttpsError(
        "failed-precondition",
        "This Google Play subscription is not active."
      );
    }

    let expiresAtMs = null;

    for (const item of lineItems) {
      if (item.productId == productId && item.expiryTime) {
        expiresAtMs = Date.parse(item.expiryTime);
        break;
      }
    }

    await db.doc(`entitlements/${uid}`).set({
      premiumActive: true,
      productId,
      platform: "google_play",
      purchaseId: purchaseId ?? null,
      purchaseOwnerUid: uid,
      source: "own_subscription",
      expiresAtMs,
      subscriptionState: subscription.subscriptionState,
      updatedAt: FieldValue.serverTimestamp(),
    }, {
      merge: true,
    });

    return {
      premiumActive: true,
      productId,
      platform: "google_play",
      expiresAtMs,
    };
  }

  if (source == "app_store") {
    throw new HttpsError(
      "failed-precondition",
      "Apple subscription verification is not configured yet."
    );
  }

  throw new HttpsError(
    "invalid-argument",
    "Unsupported purchase source."
  );
});

