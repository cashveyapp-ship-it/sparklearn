const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { defineSecret } = require("firebase-functions/params");

const stripeSecretKey = defineSecret("STRIPE_SECRET_KEY");
const stripeWebhookSecret = defineSecret("STRIPE_WEBHOOK_SECRET");
const openAiApiKey = defineSecret("OPENAI_API_KEY");
const STRIPE_MONTHLY_PRICE_ID =
  "price_1UEYDMBNqt2g5DVT991cJ8Sp";

const STRIPE_YEARLY_PRICE_ID =
  "price_1UEYDXBNqt2g5DVTJX02FL3g";

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
    const fs = require("fs");
    const path = require("path");

    const {
      SignedDataVerifier,
      Environment,
    } = require("@apple/app-store-server-library");

    const bundleId = "com.example.sparklearn";
    const appAppleId = 6806709516;

    const rootCertificate = fs.readFileSync(
      path.join(__dirname, "certs", "AppleRootCA-G3.cer")
    );

    async function verifyAppleTransaction(environment, appleId) {
      const verifier = new SignedDataVerifier(
        [rootCertificate],
        true,
        environment,
        bundleId,
        appleId
      );

      return verifier.verifyAndDecodeTransaction(
        verificationData
      );
    }

    let transaction;

    try {
      transaction = await verifyAppleTransaction(
        Environment.PRODUCTION,
        appAppleId
      );
    } catch (productionError) {
      try {
        transaction = await verifyAppleTransaction(
          Environment.SANDBOX,
          undefined
        );
      } catch (sandboxError) {
        console.error(
          "Apple subscription verification failed:",
          sandboxError
        );

        throw new HttpsError(
          "failed-precondition",
          "Apple could not verify this subscription."
        );
      }
    }

    if (transaction.productId !== productId) {
      throw new HttpsError(
        "failed-precondition",
        "The verified Apple subscription product does not match."
      );
    }

    const expiresAtMs =
      typeof transaction.expiresDate === "number"
        ? transaction.expiresDate
        : null;

    if (
      expiresAtMs !== null &&
      expiresAtMs <= Date.now()
    ) {
      throw new HttpsError(
        "failed-precondition",
        "This Apple subscription is not active."
      );
    }

    await db.doc(`entitlements/${uid}`).set({
      premiumActive: true,
      productId,
      platform: "app_store",
      purchaseId:
        transaction.transactionId ??
        purchaseId ??
        null,
      purchaseOwnerUid: uid,
      source: "own_subscription",
      expiresAtMs,
      subscriptionState: "ACTIVE",
      updatedAt: FieldValue.serverTimestamp(),
    }, {
      merge: true,
    });

    return {
      premiumActive: true,
      productId,
      platform: "app_store",
      expiresAtMs,
    };
  }

  throw new HttpsError(
    "invalid-argument",
    "Unsupported purchase source."
  );
});






function stripeClient() {
  const Stripe = require("stripe");
  return new Stripe(stripeSecretKey.value());
}

function validateReturnUrl(value) {
  if (typeof value !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "A valid return URL is required."
    );
  }

  let url;

  try {
    url = new URL(value);
  } catch (_) {
    throw new HttpsError(
      "invalid-argument",
      "The return URL is invalid."
    );
  }

  if (url.protocol !== "https:" &&
      url.hostname !== "localhost" &&
      url.hostname !== "127.0.0.1") {
    throw new HttpsError(
      "invalid-argument",
      "The return URL must use HTTPS."
    );
  }

  return url.origin;
}

exports.createStripeCheckoutSession = onCall(
  {
    secrets: [
      stripeSecretKey,
    ],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in."
      );
    }

    const uid = request.auth.uid;
    const email = request.auth.token.email ?? null;
    const productId = request.data?.productId;

    const allowedProducts = new Set([
      "sparklearn_premium_monthly",
      "sparklearn_premium_yearly",
    ]);

    if (!allowedProducts.has(productId)) {
      throw new HttpsError(
        "invalid-argument",
        "Unknown SparkLearn subscription product."
      );
    }

    const returnOrigin = validateReturnUrl(
      request.data?.returnUrl
    );

    const stripe = stripeClient();

    const priceId =
      productId === "sparklearn_premium_monthly"
        ? STRIPE_MONTHLY_PRICE_ID
        : STRIPE_YEARLY_PRICE_ID;

    const userRef = db.doc(`users/${uid}`);
    const userSnap = await userRef.get();
    const userData = userSnap.exists ? userSnap.data() : {};

    let customerId = userData?.stripeCustomerId ?? null;

    if (!customerId) {
      const customer = await stripe.customers.create({
        email,
        metadata: {
          firebaseUid: uid,
        },
      });

      customerId = customer.id;

      await userRef.set({
        stripeCustomerId: customerId,
        updatedAt: FieldValue.serverTimestamp(),
      }, {
        merge: true,
      });
    }

    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      customer: customerId,
      line_items: [
        {
          price: priceId,
          quantity: 1,
        },
      ],
      success_url:
        `${returnOrigin}/?sparklearn_checkout=success&session_id={CHECKOUT_SESSION_ID}`,
      cancel_url:
        `${returnOrigin}/?sparklearn_checkout=cancelled`,
      allow_promotion_codes: true,
      client_reference_id: uid,
      metadata: {
        firebaseUid: uid,
        productId,
      },
      subscription_data: {
        metadata: {
          firebaseUid: uid,
          productId,
        },
      },
    });

    return {
      url: session.url,
    };
  }
);

exports.createStripeBillingPortalSession = onCall(
  {
    secrets: [stripeSecretKey],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in."
      );
    }

    const uid = request.auth.uid;

    const userSnap = await db
      .doc(`users/${uid}`)
      .get();

    const customerId =
      userSnap.exists
        ? userSnap.data()?.stripeCustomerId
        : null;

    if (!customerId) {
      throw new HttpsError(
        "failed-precondition",
        "No Stripe subscription account was found."
      );
    }

    const returnOrigin = validateReturnUrl(
      request.data?.returnUrl
    );

    const stripe = stripeClient();

    const session =
      await stripe.billingPortal.sessions.create({
        customer: customerId,
        return_url: returnOrigin,
      });

    return {
      url: session.url,
    };
  }
);

async function updateStripeEntitlement(subscription) {
  const uid = subscription.metadata?.firebaseUid;
  const productId = subscription.metadata?.productId;

  if (!uid) {
    console.error(
      "Stripe subscription does not contain firebaseUid metadata.",
      subscription.id
    );
    return;
  }

  const activeStates = new Set([
    "active",
    "trialing",
  ]);

  const premiumActive =
    activeStates.has(subscription.status);

  const firstItem =
    subscription.items?.data?.[0] ?? null;

  const currentPeriodEnd =
    firstItem?.current_period_end ??
    subscription.current_period_end ??
    null;

  const expiresAtMs =
    typeof currentPeriodEnd === "number"
      ? currentPeriodEnd * 1000
      : null;

  await db.doc(`entitlements/${uid}`).set({
    premiumActive,
    productId: productId ?? null,
    platform: "stripe",
    purchaseId: subscription.id,
    purchaseOwnerUid: uid,
    source: "own_subscription",
    stripeCustomerId:
      typeof subscription.customer === "string"
        ? subscription.customer
        : subscription.customer?.id ?? null,
    stripeSubscriptionId: subscription.id,
    subscriptionState: subscription.status,
    expiresAtMs,
    updatedAt: FieldValue.serverTimestamp(),
  }, {
    merge: true,
  });
}

exports.stripeWebhook = onRequest(
  {
    secrets: [
      stripeSecretKey,
      stripeWebhookSecret,
    ],
  },
  async (request, response) => {
    if (request.method !== "POST") {
      response.status(405).send("Method Not Allowed");
      return;
    }

    const signature = request.headers["stripe-signature"];

    if (!signature) {
      response.status(400).send(
        "Missing Stripe signature."
      );
      return;
    }

    const stripe = stripeClient();

    let event;

    try {
      event = stripe.webhooks.constructEvent(
        request.rawBody,
        signature,
        stripeWebhookSecret.value()
      );
    } catch (error) {
      console.error(
        "Stripe webhook signature verification failed:",
        error
      );

      response.status(400).send(
        "Invalid Stripe webhook signature."
      );
      return;
    }

    try {
      switch (event.type) {
        case "customer.subscription.created":
        case "customer.subscription.updated":
        case "customer.subscription.deleted":
          await updateStripeEntitlement(
            event.data.object
          );
          break;

        case "checkout.session.completed": {
          const session = event.data.object;

          if (session.subscription) {
            const subscription =
              await stripe.subscriptions.retrieve(
                session.subscription
              );

            await updateStripeEntitlement(
              subscription
            );
          }

          break;
        }

        case "invoice.payment_succeeded":
        case "invoice.payment_failed":
          console.log(
            `Stripe event received: ${event.type}`
          );
          break;

        default:
          console.log(
            `Unhandled Stripe event: ${event.type}`
          );
      }

      response.status(200).json({
        received: true,
      });
    } catch (error) {
      console.error(
        "Stripe webhook processing failed:",
        error
      );

      response.status(500).send(
        "Webhook processing failed."
      );
    }
  }
);



Object.assign(exports, require('./sparklearn_stripe_live'));


// ------------------------------------------------------------
// AI practice generation based on the student's Today's Goal.
// Existing local practice questions remain available as fallback.
// ------------------------------------------------------------
exports.generatePractice = onCall(
  {
    region: "us-central1",
    secrets: [openAiApiKey],
    timeoutSeconds: 60,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in."
      );
    }

    const goal =
      typeof request.data?.goal === "string"
        ? request.data.goal.trim()
        : "";

    const readingLevelRaw = Number(request.data?.readingLevel);
    const readingLevel = Number.isFinite(readingLevelRaw)
      ? Math.min(12, Math.max(1, readingLevelRaw))
      : 4;

    if (!goal) {
      throw new HttpsError(
        "invalid-argument",
        "A practice goal is required."
      );
    }

    if (goal.length > 200) {
      throw new HttpsError(
        "invalid-argument",
        "The practice goal is too long."
      );
    }

    const systemPrompt = `
You create educational practice activities for SparkLearn.

Create exactly 5 practice items based specifically on the student's Today's Goal.

Today's Goal: ${goal}
Student reading level: Grade ${readingLevel}

Rules:
- Every item must directly relate to the Today's Goal.
- Keep the content appropriate for Grade ${readingLevel}.
- Use clear, student-friendly language.
- Each item must contain a short passage or sentence.
- Each item must contain one comprehension or knowledge question.
- Each item must contain an ideal answer.
- Do not drift into unrelated generic reading passages.
- Be educational and fact-focused.
- Return JSON only.
- Do not include markdown or explanatory text.

Return exactly this structure:
{
  "items": [
    {
      "sentence": "Short passage or sentence",
      "question": "Question about the passage and Today's Goal",
      "ideal": "Ideal student answer"
    }
  ]
}
`.trim();

    try {
      const response = await fetch(
        "https://api.openai.com/v1/chat/completions",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${openAiApiKey.value()}`,
          },
          body: JSON.stringify({
            model: "gpt-4o-mini",
            messages: [
              {
                role: "system",
                content: systemPrompt,
              },
              {
                role: "user",
                content:
                  `Generate practice for Today's Goal: ${goal}`,
              },
            ],
            response_format: {
              type: "json_object",
            },
            temperature: 0.4,
            max_tokens: 1400,
          }),
        }
      );

      if (!response.ok) {
        const errorText = await response.text();

        console.error(
          "OpenAI practice generation failed:",
          response.status,
          errorText
        );

        throw new HttpsError(
          "internal",
          "Practice generation could not be completed."
        );
      }

      const body = await response.json();

      const content =
        body?.choices?.[0]?.message?.content;

      if (
        typeof content !== "string" ||
        content.trim().length === 0
      ) {
        throw new Error(
          "OpenAI returned empty practice content."
        );
      }

      const parsed = JSON.parse(content);
      const rawItems = Array.isArray(parsed?.items)
        ? parsed.items
        : [];

      const items = rawItems
        .filter((item) => {
          return (
            item &&
            typeof item.sentence === "string" &&
            typeof item.question === "string" &&
            typeof item.ideal === "string" &&
            item.sentence.trim().length > 0 &&
            item.question.trim().length > 0 &&
            item.ideal.trim().length > 0
          );
        })
        .slice(0, 5)
        .map((item) => ({
          sentence: item.sentence.trim(),
          question: item.question.trim(),
          ideal: item.ideal.trim(),
        }));

      if (items.length !== 5) {
        throw new Error(
          `Expected 5 practice items but received ${items.length}.`
        );
      }

      return {
        ok: true,
        goal,
        readingLevel,
        items,
      };
    } catch (error) {
      console.error(
        "generatePractice failed:",
        error
      );

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError(
        "internal",
        "Practice generation could not be completed."
      );
    }
  }
);

// AI Tutor backend - keeps the OpenAI API key out of the client app.
// The existing Flutter Tutor continues to manage Firestore chat history.
exports.aiTutorReply = onCall(
  {
    region: "us-central1",
    secrets: [openAiApiKey],
    timeoutSeconds: 60,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in."
      );
    }

    const rawMessages = Array.isArray(request.data?.messages)
      ? request.data.messages
      : [];

    if (rawMessages.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "Tutor messages are required."
      );
    }

    const messages = rawMessages
      .slice(-12)
      .filter((message) => {
        return (
          message &&
          typeof message.role === "string" &&
          typeof message.content === "string" &&
          ["system", "user", "assistant"].includes(message.role) &&
          message.content.trim().length > 0
        );
      })
      .map((message) => ({
        role: message.role,
        content: message.content.trim().slice(0, 4000),
      }));

    if (messages.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "No valid tutor messages were provided."
      );
    }

    try {
      const response = await fetch(
        "https://api.openai.com/v1/chat/completions",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${openAiApiKey.value()}`,
          },
          body: JSON.stringify({
            model: "gpt-4o-mini",
            messages,
            max_tokens: 200,
            temperature: 0.7,
          }),
        }
      );

      if (!response.ok) {
        const errorText = await response.text();

        console.error(
          "OpenAI AI Tutor request failed:",
          response.status,
          errorText
        );

        throw new HttpsError(
          "internal",
          "The AI Tutor could not complete the request."
        );
      }

      const body = await response.json();

      const reply =
        body?.choices?.[0]?.message?.content;

      if (
        typeof reply !== "string" ||
        reply.trim().length === 0
      ) {
        throw new Error(
          "OpenAI returned an empty AI Tutor response."
        );
      }

      return {
        ok: true,
        reply: reply.trim(),
      };
    } catch (error) {
      console.error(
        "AI Tutor backend failed:",
        error
      );

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError(
        "internal",
        "The AI Tutor could not complete the request."
      );
    }
  }
);
