const admin = require("firebase-admin");
const { defineSecret } = require("firebase-functions/params");
const { onRequest } = require("firebase-functions/v2/https");
const Stripe = require("stripe");

const stripeLiveSecretKey =
  defineSecret("STRIPE_LIVE_SECRET_KEY");

const stripeLiveWebhookSecret =
  defineSecret("STRIPE_LIVE_WEBHOOK_SECRET");

const stripeLiveMonthlyPrice =
  defineSecret("SPARKLEARN_LIVE_MONTHLY_PRICE_ID");

const stripeLiveYearlyPrice =
  defineSecret("SPARKLEARN_LIVE_YEARLY_PRICE_ID");

function setCors(res) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set(
    "Access-Control-Allow-Headers",
    "Authorization, Content-Type"
  );
  res.set(
    "Access-Control-Allow-Methods",
    "POST, OPTIONS"
  );
}

async function requireAuthenticatedUser(req) {
  const authorization =
    String(req.headers?.authorization || "");

  if (!authorization.startsWith("Bearer ")) {
    throw new Error("AUTHENTICATION_REQUIRED");
  }

  const idToken =
    authorization.substring(7).trim();

  if (!idToken) {
    throw new Error("AUTHENTICATION_REQUIRED");
  }

  const decoded =
    await admin.auth().verifyIdToken(idToken);

  const email =
    String(decoded.email || "")
      .trim()
      .toLowerCase();

  if (!email) {
    throw new Error("EMAIL_REQUIRED");
  }

  return {
    uid: decoded.uid,
    email,
  };
}

function parseInterval(value) {
  const interval =
    String(value || "")
      .trim()
      .toLowerCase();

  if (
    interval !== "monthly" &&
    interval !== "yearly"
  ) {
    throw new Error("INVALID_INTERVAL");
  }

  return interval;
}

function resolvePriceId(interval) {
  const priceId =
    interval === "monthly"
      ? stripeLiveMonthlyPrice.value().trim()
      : stripeLiveYearlyPrice.value().trim();

  if (!priceId.startsWith("price_")) {
    throw new Error("PRICE_NOT_CONFIGURED");
  }

  return priceId;
}

function productIdForInterval(interval) {
  if (interval === "monthly") {
    return "sparklearn_premium_monthly";
  }

  return "sparklearn_premium_yearly";
}

function stringId(value) {
  if (typeof value === "string") {
    return value;
  }

  return value?.id || "";
}

function activeSubscriptionStatus(status) {
  return (
    status === "active" ||
    status === "trialing"
  );
}

function intervalFromSubscription(subscription) {
  const metadataInterval =
    String(
      subscription?.metadata?.interval || ""
    )
      .trim()
      .toLowerCase();

  if (
    metadataInterval === "monthly" ||
    metadataInterval === "yearly"
  ) {
    return metadataInterval;
  }

  return subscription
    ?.items
    ?.data?.[0]
    ?.price
    ?.recurring
    ?.interval === "year"
      ? "yearly"
      : "monthly";
}

function validateReturnUrl(value) {
  const raw =
    String(value || "").trim();

  if (!raw) {
    throw new Error("INVALID_RETURN_URL");
  }

  const parsed = new URL(raw);

  if (
    parsed.hostname === "localhost" ||
    parsed.hostname === "127.0.0.1"
  ) {
    return parsed.origin;
  }

  if (
    parsed.protocol === "https:" &&
    (
      parsed.hostname === "an2app.com" ||
      parsed.hostname === "www.an2app.com"
    )
  ) {
    return parsed.origin;
  }

  throw new Error("INVALID_RETURN_URL");
}

async function resolveStripeCustomer({
  stripe,
  user,
}) {
  const db = admin.firestore();

  const userRef =
    db.collection("users").doc(user.uid);

  const userSnap =
    await userRef.get();

  const userData =
    userSnap.data() || {};

  const existingCustomerId =
    String(
      userData.stripeCustomerId || ""
    ).trim();

  if (existingCustomerId) {
    try {
      const customer =
        await stripe.customers.retrieve(
          existingCustomerId
        );

      if (
        !("deleted" in customer) ||
        customer.deleted !== true
      ) {
        return customer.id;
      }
    } catch (error) {
      console.warn(
        "Stored Stripe customer was not usable",
        {
          uid: user.uid,
          customerId: existingCustomerId,
          error: String(error),
        }
      );
    }
  }

  const customer =
    await stripe.customers.create({
      email: user.email,
      metadata: {
        userId: user.uid,
        app: "sparklearn",
      },
    });

  await userRef.set(
    {
      stripeCustomerId: customer.id,
      billingProvider: "stripe",
      updatedAt:
        admin.firestore.FieldValue
          .serverTimestamp(),
    },
    { merge: true }
  );

  return customer.id;
}

async function resolveUserId({
  customerId,
  metadata,
}) {
  const metadataUserId =
    String(
      metadata?.userId || ""
    ).trim();

  if (metadataUserId) {
    return metadataUserId;
  }

  if (!customerId) {
    return "";
  }

  const snapshot =
    await admin
      .firestore()
      .collection("users")
      .where(
        "stripeCustomerId",
        "==",
        customerId
      )
      .limit(1)
      .get();

  if (snapshot.empty) {
    return "";
  }

  return snapshot.docs[0].id;
}

async function writeEntitlement({
  userId,
  customerId,
  subscriptionId,
  status,
  interval,
  cancelAtPeriodEnd,
  currentPeriodEnd,
  paymentStatus,
}) {
  if (!userId) {
    throw new Error(
      "STRIPE_USER_NOT_FOUND"
    );
  }

  const premiumActive =
    activeSubscriptionStatus(status);

  const productId =
    productIdForInterval(interval);

  const db = admin.firestore();

  await db
    .collection("entitlements")
    .doc(userId)
    .set(
      {
        premiumActive,
        platform: "stripe",
        provider: "stripe",
        productId,
        interval,
        subscriptionStatus: status,
        stripeCustomerId: customerId,
        stripeSubscriptionId:
          subscriptionId,
        cancelAtPeriodEnd:
          cancelAtPeriodEnd === true,
        currentPeriodEnd:
          currentPeriodEnd || null,
        paymentStatus:
          paymentStatus || "",
        updatedAt:
          admin.firestore.FieldValue
            .serverTimestamp(),
      },
      { merge: true }
    );

  await db
    .collection("users")
    .doc(userId)
    .set(
      {
        premiumActive,
        billingProvider: "stripe",
        stripeCustomerId: customerId,
        stripeSubscriptionId:
          subscriptionId,
        subscriptionStatus: status,
        subscriptionInterval: interval,
        cancelAtPeriodEnd:
          cancelAtPeriodEnd === true,
        currentPeriodEnd:
          currentPeriodEnd || null,
        paymentStatus:
          paymentStatus || "",
        updatedAt:
          admin.firestore.FieldValue
            .serverTimestamp(),
      },
      { merge: true }
    );
}

async function recordBillingHistory({
  event,
  userId,
  eventType,
  status,
  interval,
  customerId,
  subscriptionId,
  invoiceId,
  checkoutSessionId,
  amount,
  currency,
  invoiceUrl,
  receiptUrl,
}) {
  if (!userId) {
    return;
  }

  await admin
    .firestore()
    .collection("billingHistory")
    .doc(event.id)
    .set(
      {
        userId,
        app: "sparklearn",
        provider: "stripe",
        eventType,
        status,
        planId: "premium",
        interval,
        productId:
          productIdForInterval(interval),
        amount: Number(amount || 0),
        currency:
          String(currency || "usd")
            .toUpperCase(),
        stripeEventId: event.id,
        stripeCustomerId:
          customerId || "",
        stripeSubscriptionId:
          subscriptionId || "",
        stripeInvoiceId:
          invoiceId || "",
        stripeCheckoutSessionId:
          checkoutSessionId || "",
        invoiceUrl:
          invoiceUrl || "",
        receiptUrl:
          receiptUrl || "",
        eventCreatedAt:
          new Date(
            event.created * 1000
          ).toISOString(),
        createdAt:
          admin.firestore.FieldValue
            .serverTimestamp(),
      },
      { merge: true }
    );
}

async function retrieveSubscription(
  stripe,
  subscriptionId
) {
  if (!subscriptionId) {
    return null;
  }

  return await stripe
    .subscriptions
    .retrieve(subscriptionId);
}

exports.createSparkLearnStripeCheckoutHttp =
  onRequest(
    {
      region: "us-central1",
      invoker: "public",
      secrets: [
        stripeLiveSecretKey,
        stripeLiveMonthlyPrice,
        stripeLiveYearlyPrice,
      ],
    },
    async (req, res) => {
      setCors(res);

      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }

      if (req.method !== "POST") {
        res.status(405).json({
          error: "Method not allowed.",
        });
        return;
      }

      try {
        const user =
          await requireAuthenticatedUser(
            req
          );

        const interval =
          parseInterval(
            req.body?.interval
          );

        const priceId =
          resolvePriceId(interval);

        const returnOrigin =
          validateReturnUrl(
            req.body?.returnUrl
          );

        const stripe =
          new Stripe(
            stripeLiveSecretKey.value()
          );

        const customerId =
          await resolveStripeCustomer({
            stripe,
            user,
          });

        const productId =
          productIdForInterval(interval);

        const successUrl =
          `${returnOrigin}/` +
          `?sparklearn_checkout=success` +
          `&session_id={CHECKOUT_SESSION_ID}`;

        const cancelUrl =
          `${returnOrigin}/` +
          `?sparklearn_checkout=cancelled`;

        const session =
          await stripe
            .checkout
            .sessions
            .create({
              mode: "subscription",
              customer: customerId,
              client_reference_id:
                user.uid,
              line_items: [
                {
                  price: priceId,
                  quantity: 1,
                },
              ],
              allow_promotion_codes: true,
              success_url: successUrl,
              cancel_url: cancelUrl,
              metadata: {
                userId: user.uid,
                planId: "premium",
                interval,
                productId,
                app: "sparklearn",
              },
              subscription_data: {
                metadata: {
                  userId: user.uid,
                  planId: "premium",
                  interval,
                  productId,
                  app: "sparklearn",
                },
              },
            });

        if (!session.url) {
          throw new Error(
            "CHECKOUT_URL_MISSING"
          );
        }

        await admin
          .firestore()
          .collection(
            "stripeCheckoutSessions"
          )
          .doc(session.id)
          .set({
            userId: user.uid,
            email: user.email,
            app: "sparklearn",
            planId: "premium",
            interval,
            productId,
            priceId,
            stripeCustomerId:
              customerId,
            stripeSessionId:
              session.id,
            status: session.status,
            liveMode: session.livemode,
            createdAt:
              admin.firestore
                .FieldValue
                .serverTimestamp(),
          });

        res.status(200).json({
          success: true,
          checkoutUrl: session.url,
          sessionId: session.id,
        });
      } catch (error) {
        console.error(
          "SparkLearn live checkout failed",
          error
        );

        const message =
          String(error);

        if (
          message.includes(
            "AUTHENTICATION_REQUIRED"
          ) ||
          message.includes(
            "Firebase ID token"
          )
        ) {
          res.status(401).json({
            error:
              "Authentication required.",
          });
          return;
        }

        if (
          message.includes(
            "EMAIL_REQUIRED"
          )
        ) {
          res.status(403).json({
            error:
              "An account email is required.",
          });
          return;
        }

        if (
          message.includes(
            "INVALID_INTERVAL"
          )
        ) {
          res.status(400).json({
            error:
              "Billing interval must be monthly or yearly.",
          });
          return;
        }

        if (
          message.includes(
            "INVALID_RETURN_URL"
          )
        ) {
          res.status(400).json({
            error:
              "Invalid return URL.",
          });
          return;
        }

        if (
          message.includes(
            "PRICE_NOT_CONFIGURED"
          )
        ) {
          res.status(500).json({
            error:
              "Stripe live price is not configured.",
          });
          return;
        }

        res.status(500).json({
          error:
            "Unable to start Stripe Checkout.",
        });
      }
    }
  );

exports.sparkLearnStripeWebhookHttp =
  onRequest(
    {
      region: "us-central1",
      invoker: "public",
      secrets: [
        stripeLiveSecretKey,
        stripeLiveWebhookSecret,
      ],
    },
    async (req, res) => {
      if (req.method !== "POST") {
        res.status(405).send(
          "Method not allowed"
        );
        return;
      }

      const signature =
        req.headers[
          "stripe-signature"
        ];

      if (
        !signature ||
        Array.isArray(signature)
      ) {
        res.status(400).send(
          "Missing Stripe-Signature header."
        );
        return;
      }

      let event;

      try {
        const stripe =
          new Stripe(
            stripeLiveSecretKey.value()
          );

        event =
          stripe.webhooks
            .constructEvent(
              req.rawBody,
              signature,
              stripeLiveWebhookSecret
                .value()
            );

        const eventRef =
          admin
            .firestore()
            .collection("stripeEvents")
            .doc(event.id);

        const existing =
          await eventRef.get();

        if (
          existing.exists &&
          existing.data()?.status ===
            "processed"
        ) {
          res.status(200).json({
            received: true,
            duplicate: true,
          });
          return;
        }

        await eventRef.set(
          {
            app: "sparklearn",
            type: event.type,
            status: "processing",
            receivedAt:
              admin.firestore
                .FieldValue
                .serverTimestamp(),
          },
          { merge: true }
        );

        if (
          event.type ===
          "checkout.session.completed"
        ) {
          const session =
            event.data.object;

          if (
            session.mode ===
            "subscription"
          ) {
            const customerId =
              stringId(
                session.customer
              );

            const subscriptionId =
              stringId(
                session.subscription
              );

            const subscription =
              await retrieveSubscription(
                stripe,
                subscriptionId
              );

            const metadata =
              subscription?.metadata ||
              session.metadata ||
              {};

            const userId =
              await resolveUserId({
                customerId,
                metadata,
              });

            const interval =
              parseInterval(
                metadata.interval
              );

            await writeEntitlement({
              userId,
              customerId,
              subscriptionId,
              status:
                subscription?.status ||
                "active",
              interval,
              cancelAtPeriodEnd:
                subscription
                  ?.cancel_at_period_end ||
                false,
              currentPeriodEnd:
                subscription
                  ?.current_period_end
                  ? new Date(
                      subscription
                        .current_period_end *
                        1000
                    ).toISOString()
                  : null,
              paymentStatus:
                session.payment_status,
            });

            await recordBillingHistory({
              event,
              userId,
              eventType: event.type,
              status:
                subscription?.status ||
                session.payment_status ||
                "completed",
              interval,
              customerId,
              subscriptionId,
              checkoutSessionId:
                session.id,
              amount:
                session.amount_total,
              currency:
                session.currency,
            });
          }
        }

        if (
          event.type ===
            "customer.subscription.created" ||
          event.type ===
            "customer.subscription.updated"
        ) {
          const subscription =
            event.data.object;

          const customerId =
            stringId(
              subscription.customer
            );

          const userId =
            await resolveUserId({
              customerId,
              metadata:
                subscription.metadata,
            });

          const interval = intervalFromSubscription(subscription);

          await writeEntitlement({
            userId,
            customerId,
            subscriptionId:
              subscription.id,
            status:
              subscription.status,
            interval,
            cancelAtPeriodEnd:
              subscription
                .cancel_at_period_end,
            currentPeriodEnd:
              subscription
                .current_period_end
                ? new Date(
                    subscription
                      .current_period_end *
                      1000
                  ).toISOString()
                : null,
            paymentStatus: "",
          });

          await recordBillingHistory({
            event,
            userId,
            eventType: event.type,
            status:
              subscription.status,
            interval,
            customerId,
            subscriptionId:
              subscription.id,
          });
        }

        if (
          event.type ===
          "customer.subscription.deleted"
        ) {
          const subscription =
            event.data.object;

          const customerId =
            stringId(
              subscription.customer
            );

          const userId =
            await resolveUserId({
              customerId,
              metadata:
                subscription.metadata,
            });

          const interval =
            parseInterval(
              subscription
                .metadata
                ?.interval || "monthly"
            );

          await writeEntitlement({
            userId,
            customerId,
            subscriptionId:
              subscription.id,
            status: "cancelled",
            interval,
            cancelAtPeriodEnd: false,
            currentPeriodEnd: null,
            paymentStatus:
              "cancelled",
          });

          await recordBillingHistory({
            event,
            userId,
            eventType: event.type,
            status: "cancelled",
            interval,
            customerId,
            subscriptionId:
              subscription.id,
          });
        }

        if (
          event.type ===
            "invoice.paid" ||
          event.type ===
            "invoice.payment_failed"
        ) {
          const invoice =
            event.data.object;

          const subscriptionId =
            stringId(
              invoice.subscription
            ) ||
            stringId(
              invoice.parent
                ?.subscription_details
                ?.subscription
            );

          const subscription =
            await retrieveSubscription(
              stripe,
              subscriptionId
            );

          if (subscription) {
            const customerId =
              stringId(
                invoice.customer
              );

            const userId =
              await resolveUserId({
                customerId,
                metadata:
                  subscription.metadata,
              });

            const interval = intervalFromSubscription(subscription);

            const isPaid =
              event.type ===
              "invoice.paid";

            await writeEntitlement({
              userId,
              customerId,
              subscriptionId,
              status:
                subscription.status,
              interval,
              cancelAtPeriodEnd:
                subscription
                  .cancel_at_period_end,
              currentPeriodEnd:
                subscription
                  .current_period_end
                  ? new Date(
                      subscription
                        .current_period_end *
                        1000
                    ).toISOString()
                  : null,
              paymentStatus:
                isPaid
                  ? "paid"
                  : "failed",
            });

            await recordBillingHistory({
              event,
              userId,
              eventType:
                event.type,
              status:
                isPaid
                  ? "paid"
                  : "failed",
              interval,
              customerId,
              subscriptionId,
              invoiceId:
                invoice.id,
              amount:
                isPaid
                  ? invoice.amount_paid
                  : invoice.amount_due,
              currency:
                invoice.currency,
              invoiceUrl:
                invoice
                  .hosted_invoice_url ||
                "",
              receiptUrl:
                invoice.invoice_pdf ||
                "",
            });
          }
        }

        await eventRef.set(
          {
            status: "processed",
            processedAt:
              admin.firestore
                .FieldValue
                .serverTimestamp(),
          },
          { merge: true }
        );

        res.status(200).json({
          received: true,
          eventId: event.id,
          eventType: event.type,
        });
      } catch (error) {
        console.error(
          "SparkLearn Stripe webhook failed",
          error
        );

        if (event) {
          await admin
            .firestore()
            .collection("stripeEvents")
            .doc(event.id)
            .set(
              {
                status: "failed",
                error: String(error),
                failedAt:
                  admin.firestore
                    .FieldValue
                    .serverTimestamp(),
              },
              { merge: true }
            )
            .catch(
              () => undefined
            );
        }

        res.status(400).send(
          `Webhook Error: ${String(error)}`
        );
      }
    }
  );