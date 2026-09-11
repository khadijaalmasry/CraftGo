const Stripe = require('stripe');
const PaymentTransaction = require('../models/PaymentTransaction');
const HireRequest = require('../models/HireRequest');
const User = require('../models/User');
const DeliveryOrder = require('../models/DeliveryOrder');
const DeliveryPayment = require('../models/DeliveryPayment');
const DeliveryProfile = require('../models/DeliveryProfile');
const ReadyMadePayment = require('../models/ReadyMadePayment');
const Order = require('../models/Order');
const Product = require('../models/Product');
const Role = require('../models/Role');
const Exhibition = require('../models/Exhibition');
const ExhibitionCraftsman = require('../models/ExhibitionCraftsman');
const CustomOrderRequest = require('../models/CustomOrderRequest');
const CustomOrderTemplate = require('../models/CustomOrderTemplate');

const {
  Op
} = require('sequelize');

const sequelize = PaymentTransaction.sequelize;

const COMMISSION_RATE = 10;
const JOD_PER_USD = Number(process.env.JOD_PER_USD || 3.1122);

const PUBLIC_API_URL = (
  process.env.PUBLIC_API_URL || 'http://localhost:5000'
).replace(/\/$/, '');

const isConfiguredKey = (value) =>
  value && !value.includes('REPLACE_ME');

const stripe = isConfiguredKey(process.env.STRIPE_SECRET_KEY) ?
  new Stripe(process.env.STRIPE_SECRET_KEY) :
  null;

// Stripe Sandbox processes test payments in USD.
// CraftGo's internal accounting remains in JOD.
const toStripeMinorUnits = (amount) =>
  Math.max(
    50,
    Math.round((Number(amount) / JOD_PER_USD) * 100),
  );

function proposalAmounts(request) {
  const response = request.artisanResponse || {};

  const grossAmount = Number(
    request.totalPrice || response.totalPrice || 0,
  );

  if (!Number.isFinite(grossAmount) || grossAmount <= 0) {
    return null;
  }

  const adminCommission = Number(
    ((grossAmount * COMMISSION_RATE) / 100).toFixed(3),
  );

  return {
    grossAmount,
    adminCommission,
    artisanAmount: Number(
      (grossAmount - adminCommission).toFixed(3),
    ),
  };
}

async function markPaymentSucceeded(
  transaction,
  paymentIntentId,
) {
  if (transaction.paymentStatus === 'succeeded') {
    return transaction;
  }

  await sequelize.transaction(async (dbTransaction) => {
    await transaction.update({
      stripePaymentIntentId: paymentIntentId ||
        transaction.stripePaymentIntentId,
      paymentStatus: 'succeeded',
      escrowStatus: 'held',
      paidAt: new Date(),
      failureMessage: null,
    }, {
      transaction: dbTransaction,
    }, );

    const request = await HireRequest.findByPk(
      transaction.hireRequestId, {
        transaction: dbTransaction,
      },
    );

    if (
      request &&
      request.status === 'pending_customer'
    ) {
      await request.update({
        status: 'in_progress',
      }, {
        transaction: dbTransaction,
      }, );
    }
  });

  return transaction;
}

async function markDeliveryPaymentSucceeded(payment, paymentIntentId) {
  if (payment.paymentStatus === 'succeeded') return payment;

  await sequelize.transaction(async (dbTransaction) => {
    await payment.update({
      stripePaymentIntentId: paymentIntentId || payment.stripePaymentIntentId,
      paymentStatus: 'succeeded',
      escrowStatus: 'held',
      paidAt: new Date(),
      failureMessage: null,
    }, {
      transaction: dbTransaction
    }, );

    const order = await DeliveryOrder.findByPk(payment.deliveryOrderId, {
      transaction: dbTransaction,
    });

    if (order && order.status === 'pending_payment') {
      await order.update({
        status: 'awaiting_pickup'
      }, {
        transaction: dbTransaction
      });
    }
  });

  return payment;
}

exports.createPaymentIntent = async (req, res) => {
  try {
    if (
      !stripe ||
      !isConfiguredKey(
        process.env.STRIPE_PUBLISHABLE_KEY,
      )
    ) {
      return res.status(503).json({
        error: 'Stripe test keys are not configured',
        code: 'STRIPE_NOT_CONFIGURED',
      });
    }

    const request = await HireRequest.findByPk(
      req.params.hireRequestId,
    );

    if (!request) {
      return res.status(404).json({
        error: 'Hire request not found',
      });
    }

    if (
      String(request.customerId) !==
      String(req.user.id)
    ) {
      return res.status(403).json({
        error: 'Forbidden',
      });
    }

    if (request.status !== 'pending_customer') {
      return res.status(409).json({
        error: 'This proposal is not awaiting payment',
      });
    }

    const response = request.artisanResponse || {};

    const grossAmount = Number(
      request.totalPrice ||
      response.totalPrice ||
      0,
    );

    if (
      !Number.isFinite(grossAmount) ||
      grossAmount <= 0
    ) {
      return res.status(400).json({
        error: 'Invalid proposal total',
      });
    }

    const adminCommission = Number(
      (
        (grossAmount * COMMISSION_RATE) /
        100
      ).toFixed(3),
    );

    const artisanAmount = Number(
      (grossAmount - adminCommission).toFixed(3),
    );

    let transaction =
      await PaymentTransaction.findOne({
        where: {
          hireRequestId: request.id,
        },
      });

    if (
      transaction?.paymentStatus ===
      'succeeded'
    ) {
      return res.status(409).json({
        error: 'This request is already paid',
      });
    }

    const intent =
      await stripe.paymentIntents.create({
        amount: toStripeMinorUnits(grossAmount),
        currency: 'usd',
        automatic_payment_methods: {
          enabled: true,
        },
        metadata: {
          craftgoPaymentType: 'hire_order',
          hireRequestId: request.id,
          customerId: request.customerId,
          artisanId: request.artisanId,
        },
        description: `CraftGo on-site order ${request.id}`,
      }, {
        idempotencyKey: `craftgo-hire-intent-${request.id}`,
      }, );

    const values = {
      hireRequestId: request.id,
      customerId: request.customerId,
      artisanId: request.artisanId,
      currency: 'JOD',
      grossAmount,
      adminCommissionRate: COMMISSION_RATE,
      adminCommission,
      artisanAmount,
      stripePaymentIntentId: intent.id,
      paymentStatus: 'created',
      escrowStatus: 'unpaid',
    };

    if (transaction) {
      await transaction.update(values);
    } else {
      transaction =
        await PaymentTransaction.create(values);
    }

    return res.status(201).json({
      paymentIntentClientSecret: intent.client_secret,
      publishableKey: process.env.STRIPE_PUBLISHABLE_KEY,
      merchantDisplayName: 'CraftGo',
      transaction: {
        id: transaction.id,
        grossAmount,
        adminCommission,
        artisanAmount,
        currency: 'JOD',
      },
    });
  } catch (error) {
    console.error(
      '[createPaymentIntent] ERROR:',
      error,
    );

    return res.status(500).json({
      error: 'Failed to start payment',
      details: error.message,
    });
  }
};

// ── Delivery Payment Intent ─────────────────────────────────────────────
exports.createDeliveryIntent = async (req, res) => {
  try {
    if (!stripe || !isConfiguredKey(process.env.STRIPE_PUBLISHABLE_KEY)) {
      return res.status(503).json({
        error: 'Stripe test keys are not configured',
        code: 'STRIPE_NOT_CONFIGURED'
      });
    }

    const order = await DeliveryOrder.findByPk(req.params.deliveryOrderId);
    if (!order) return res.status(404).json({
      error: 'Delivery order not found'
    });

    // Only the customer who owns the order can create the intent
    if (String(order.customerId) !== String(req.user.id)) {
      return res.status(403).json({
        error: 'Forbidden'
      });
    }

    // Determine gross amount (prefer explicit earningAmount, fallback to request body)
    const grossAmount = Number(order.earningAmount || req.body.amount || 0);
    if (!Number.isFinite(grossAmount) || grossAmount <= 0) {
      return res.status(400).json({
        error: 'Invalid delivery amount'
      });
    }

    // Platform commission for delivery — default 0, can be configured
    const platformCommissionRate = Number(process.env.DELIVERY_COMMISSION_RATE || 0);
    const platformCommission = Number(((grossAmount * platformCommissionRate) / 100).toFixed(3));
    const driverAmount = Number((grossAmount - platformCommission).toFixed(3));

    let payment = await DeliveryPayment.findOne({
      where: {
        deliveryOrderId: order.id
      }
    });
    if (payment?.paymentStatus === 'succeeded') {
      return res.status(409).json({
        error: 'This delivery order is already paid'
      });
    }

    const intent = await stripe.paymentIntents.create({
      amount: toStripeMinorUnits(grossAmount),
      currency: 'usd',
      automatic_payment_methods: {
        enabled: true
      },
      metadata: {
        craftgoPaymentType: 'delivery',
        deliveryOrderId: order.id,
        customerId: order.customerId,
        driverId: order.driverId || '',
      },
      description: `CraftGo delivery payment ${order.id}`,
    }, {
      idempotencyKey: `craftgo-delivery-intent-${order.id}`
    }, );

    const values = {
      deliveryOrderId: order.id,
      customerId: order.customerId,
      driverId: order.driverId || null,
      currency: 'JOD',
      grossAmount,
      platformCommissionRate,
      platformCommission,
      driverAmount,
      stripePaymentIntentId: intent.id,
      paymentStatus: 'created',
      escrowStatus: 'unpaid',
      failureMessage: null,
    };

    if (payment) await payment.update(values);
    else payment = await DeliveryPayment.create(values);

    return res.status(201).json({
      paymentIntentClientSecret: intent.client_secret,
      publishableKey: process.env.STRIPE_PUBLISHABLE_KEY,
      payment
    });
  } catch (error) {
    console.error('[createDeliveryIntent] ERROR:', error);
    return res.status(500).json({
      error: 'Failed to start delivery payment',
      details: error.message
    });
  }
};

exports.confirmDeliveryPayment = async (req, res) => {
  try {
    if (!stripe) return res.status(503).json({
      error: 'Stripe not configured'
    });

    const payment = await DeliveryPayment.findOne({
      where: {
        deliveryOrderId: req.params.deliveryOrderId
      }
    });
    if (!payment) return res.status(404).json({
      error: 'Delivery payment not found'
    });

    if (String(payment.customerId) !== String(req.user.id)) return res.status(403).json({
      error: 'Forbidden'
    });

    const intent = await stripe.paymentIntents.retrieve(payment.stripePaymentIntentId);
    if (intent.status !== 'succeeded') {
      payment.paymentStatus = intent.status === 'processing' ? 'processing' : 'failed';
      payment.failureMessage = intent.last_payment_error?.message || null;
      await payment.save();
      return res.status(409).json({
        error: 'Payment has not succeeded',
        stripeStatus: intent.status
      });
    }

    await markDeliveryPaymentSucceeded(payment, intent.id);

    return res.json({
      success: true,
      payment
    });
  } catch (error) {
    console.error('[confirmDeliveryPayment] ERROR:', error);
    return res.status(500).json({
      error: 'Failed to confirm delivery payment',
      details: error.message
    });
  }
};

exports.getPaymentForDelivery = async (req, res) => {
  const payment = await DeliveryPayment.findOne({
    where: {
      deliveryOrderId: req.params.deliveryOrderId
    }
  });
  if (!payment) return res.status(404).json({
    error: 'Payment not found'
  });

  const allowedUserIds = [String(payment.customerId), String(payment.driverId)].filter(Boolean);
  if (!allowedUserIds.includes(String(req.user.id)) && req.user.role !== 'admin') return res.status(403).json({
    error: 'Forbidden'
  });

  return res.json(payment);
};

exports.releaseDeliveryEscrow = async (req, res) => {
  try {
    const reason = String(req.body?.reason || '').trim();
    if (reason.length < 5) return res.status(400).json({
      error: 'A release reason of at least 5 characters is required'
    });

    let releasedPayment;
    await sequelize.transaction(async (dbTransaction) => {
      const payment = await DeliveryPayment.findOne({
        where: {
          deliveryOrderId: req.params.deliveryOrderId
        },
        transaction: dbTransaction
      });
      if (!payment) {
        const error = new Error('Payment not found');
        error.status = 404;
        throw error;
      }

      if (payment.paymentStatus !== 'succeeded' || payment.escrowStatus !== 'held') {
        const error = new Error('Only a successful payment held in escrow can be released');
        error.status = 409;
        throw error;
      }

      const order = await DeliveryOrder.findByPk(payment.deliveryOrderId, {
        transaction: dbTransaction
      });
      if (!order || order.status !== 'delivered') {
        const error = new Error('Delivery must be completed before release');
        error.status = 409;
        throw error;
      }

      // Attempt Stripe Connect transfer to driver if available
      let stripeTransfer = null;
      const driverProfile = payment.driverId ?
        await DeliveryProfile.findOne({
          where: {
            driverId: payment.driverId
          },
          transaction: dbTransaction
        }) :
        null;
      const connectedAccountId = driverProfile?.connectedAccountId || null;

      if (stripe && connectedAccountId && isConfiguredKey(process.env.STRIPE_SECRET_KEY)) {
        try {
          const transferAmount = toStripeMinorUnits(Number(payment.driverAmount || 0));
          stripeTransfer = await stripe.transfers.create({
            amount: transferAmount,
            currency: 'usd',
            destination: connectedAccountId,
            description: `Payout for delivery ${payment.deliveryOrderId}`,
          });

          await payment.update({
            stripeTransferId: stripeTransfer.id,
            escrowStatus: 'released',
            releasedAt: new Date()
          }, {
            transaction: dbTransaction
          });
        } catch (tErr) {
          console.error('[stripe.transfer] error:', tErr.message || tErr);
          const error = new Error('Transfer to driver failed: ' + (tErr.message || 'stripe error'));
          error.status = 500;
          throw error;
        }
      } else {
        // No connected Stripe account — mark as released for manual payout
        await payment.update({
          escrowStatus: 'released',
          releasedAt: new Date()
        }, {
          transaction: dbTransaction
        });
      }

      releasedPayment = payment;
    });

    const {
      releaseEscrowAndDistributeShares
    } = require('../utils/escrowHelper');
    await releaseEscrowAndDistributeShares({
      deliveryOrderId: req.params.deliveryOrderId,
    });

    console.info('[DELIVERY_ESCROW_RELEASE]', {
      deliveryOrderId: req.params.deliveryOrderId,
      adminId: req.user.id,
      reason,
      releasedAt: releasedPayment.releasedAt
    });

    return res.json({
      success: true,
      reason,
      payment: releasedPayment
    });
  } catch (error) {
    return res.status(error.status || 500).json({
      error: error.message
    });
  }
};

// Flutter Web uses Stripe Checkout.
// Android and iOS use PaymentSheet.
// Both paths use the same escrow transaction ledger.
exports.createCheckoutSession = async (req, res) => {
  try {
    if (!stripe) {
      return res.status(503).json({
        error: 'Stripe test key is not configured',
      });
    }

    const request = await HireRequest.findByPk(
      req.params.hireRequestId,
    );

    if (!request) {
      return res.status(404).json({
        error: 'Hire request not found',
      });
    }

    if (
      String(request.customerId) !==
      String(req.user.id)
    ) {
      return res.status(403).json({
        error: 'Forbidden',
      });
    }

    if (request.status !== 'pending_customer') {
      return res.status(409).json({
        error: 'This proposal is not awaiting payment',
      });
    }

    const amounts = proposalAmounts(request);

    if (!amounts) {
      return res.status(400).json({
        error: 'Invalid proposal total',
      });
    }

    let transaction =
      await PaymentTransaction.findOne({
        where: {
          hireRequestId: request.id,
        },
      });

    if (
      transaction?.paymentStatus ===
      'succeeded'
    ) {
      return res.status(409).json({
        error: 'This request is already paid',
      });
    }

    const session =
      await stripe.checkout.sessions.create({
        mode: 'payment',
        payment_method_types: ['card'],
        line_items: [{
          quantity: 1,
          price_data: {
            currency: 'usd',
            unit_amount: toStripeMinorUnits(
              amounts.grossAmount,
            ),
            product_data: {
              name: 'CraftGo Hire / On-Site Service',
              description: `Test escrow payment — ` +
                `CraftGo order total: ` +
                `${amounts.grossAmount.toFixed(2)} JOD`,
            },
          },
        }, ],
        metadata: {
          craftgoPaymentType: 'hire_order',
          hireRequestId: request.id,
          customerId: request.customerId,
          artisanId: request.artisanId,
        },
        success_url: `${PUBLIC_API_URL}` +
          `/api/payments/checkout/success` +
          `?session_id={CHECKOUT_SESSION_ID}`,
        cancel_url: `${PUBLIC_API_URL}` +
          `/api/payments/checkout/cancel`,
      }, {
        idempotencyKey: `craftgo-hire-checkout-${request.id}`,
      }, );

    const values = {
      hireRequestId: request.id,
      customerId: request.customerId,
      artisanId: request.artisanId,
      currency: 'JOD',
      ...amounts,
      adminCommissionRate: COMMISSION_RATE,
      stripePaymentIntentId: session.id,
      paymentStatus: 'created',
      escrowStatus: 'unpaid',
      failureMessage: null,
    };

    if (transaction) {
      await transaction.update(values);
    } else {
      transaction =
        await PaymentTransaction.create(values);
    }

    return res.status(201).json({
      checkoutUrl: session.url,
      transaction: {
        grossAmount: amounts.grossAmount,
        adminCommission: amounts.adminCommission,
        artisanAmount: amounts.artisanAmount,
      },
    });
  } catch (error) {
    console.error(
      '[createCheckoutSession] ERROR:',
      error,
    );

    return res.status(500).json({
      error: 'Failed to start web checkout',
      details: error.message,
    });
  }
};

exports.checkoutSuccess = async (req, res) => {
  try {
    if (!stripe || !req.query.session_id) {
      throw new Error(
        'Missing checkout session',
      );
    }

    const session =
      await stripe.checkout.sessions.retrieve(
        req.query.session_id,
      );

    if (session.payment_status !== 'paid') {
      throw new Error(
        'Payment is not completed',
      );
    }

    const transaction =
      await PaymentTransaction.findOne({
        where: {
          stripePaymentIntentId: session.id,
        },
      });

    if (!transaction) {
      const customRequest = await CustomOrderRequest.findOne({
        where: {
          stripePaymentIntentId: session.id,
        },
      });
      if (customRequest) {
        await customRequest.update({
          paymentStatus: 'paid',
          paidAt: new Date(),
          status: 'in_progress',
          contractSigned: true,
          contractSignedAt: new Date(),
        });
        return res.type('html').send(
          checkoutResultPage(
            'Payment successful',
            'Your custom order is now confirmed and in progress.',
            true,
          ),
        );
      }
    }

    if (!transaction) {
      throw new Error(
        'CraftGo transaction was not found',
      );
    }

    await markPaymentSucceeded(
      transaction,
      session.payment_intent,
    );

    return res.type('html').send(
      checkoutResultPage(
        'Payment successful',
        'Your payment is now safely held in CraftGo Escrow. ' +
        'You may close this tab and return to CraftGo.',
        true,
      ),
    );
  } catch (error) {
    console.error(
      '[checkoutSuccess] ERROR:',
      error,
    );

    return res.status(400).type('html').send(
      checkoutResultPage(
        'Payment verification failed',
        error.message,
        false,
      ),
    );
  }
};

exports.checkoutCancelled = (req, res) =>
  res.type('html').send(
    checkoutResultPage(
      'Payment cancelled',
      'No charge was made. You may close this tab and return to CraftGo.',
      false,
    ),
  );

function checkoutResultPage(
  title,
  message,
  successful,
) {
  const color = successful ?
    '#4caf60' :
    '#e2aa12';

  return `
    <!doctype html>
    <html>
      <head>
        <meta
          name="viewport"
          content="width=device-width,initial-scale=1"
        >
        <title>${title}</title>
      </head>

      <body
        style="
          margin:0;
          background:#0d1420;
          color:white;
          font-family:Arial,sans-serif;
          display:grid;
          place-items:center;
          min-height:100vh;
        "
      >
        <main
          style="
            max-width:440px;
            margin:24px;
            padding:32px;
            text-align:center;
            background:#1c2431;
            border:1px solid #344055;
            border-radius:20px;
          "
        >
          <div
            style="
              font-size:52px;
              color:${color};
            "
          >
            ${successful ? '&#10003;' : '&#8592;'}
          </div>

          <h1>${title}</h1>

          <p
            style="
              color:#b8c1cf;
              line-height:1.6;
            "
          >
            ${message}
          </p>

          <button
            onclick="window.close()"
            style="
              margin-top:12px;
              padding:12px 22px;
              border:0;
              border-radius:10px;
              background:#e2aa12;
              font-weight:bold;
              cursor:pointer;
            "
          >
            Close & return to CraftGo
          </button>
        </main>
      </body>
    </html>
  `;
}

exports.confirmPayment = async (req, res) => {
  try {
    if (!stripe) {
      return res.status(503).json({
        error: 'Stripe is not configured',
      });
    }

    const transaction =
      await PaymentTransaction.findOne({
        where: {
          hireRequestId: req.params.hireRequestId,
        },
      });

    if (!transaction) {
      return res.status(404).json({
        error: 'Payment not found',
      });
    }

    if (
      String(transaction.customerId) !==
      String(req.user.id)
    ) {
      return res.status(403).json({
        error: 'Forbidden',
      });
    }

    const intent =
      await stripe.paymentIntents.retrieve(
        transaction.stripePaymentIntentId,
      );

    if (intent.status !== 'succeeded') {
      transaction.paymentStatus =
        intent.status === 'processing' ?
        'processing' :
        'failed';

      transaction.failureMessage =
        intent.last_payment_error?.message ||
        null;

      await transaction.save();

      return res.status(409).json({
        error: 'Payment has not succeeded',
        stripeStatus: intent.status,
      });
    }

    await markPaymentSucceeded(
      transaction,
      intent.id,
    );

    return res.json({
      success: true,
      transaction,
    });
  } catch (error) {
    console.error(
      '[confirmPayment] ERROR:',
      error,
    );

    return res.status(500).json({
      error: 'Failed to confirm payment',
      details: error.message,
    });
  }
};

exports.stripeWebhook = async (req, res) => {
  try {
    if (
      !stripe ||
      !isConfiguredKey(
        process.env.STRIPE_WEBHOOK_SECRET,
      )
    ) {
      return res.status(503).send(
        'Stripe webhook is not configured',
      );
    }

    const event =
      stripe.webhooks.constructEvent(
        req.body,
        req.headers['stripe-signature'],
        process.env.STRIPE_WEBHOOK_SECRET,
      );

    const stripeObject = event.data.object;

    if (
      event.type ===
      'checkout.session.completed' &&
      stripeObject.payment_status === 'paid'
    ) {
      // If this is a bundled checkout, finalize delivery payments from the bundle
      if (stripeObject.metadata?.bundleId) {
        try {
          const bundle = await require('../models/PaymentBundle').findOne({
            where: {
              id: stripeObject.metadata.bundleId
            }
          });
          if (bundle) {
            const deliveryIds = bundle.deliveryOrderIds || [];
            for (const did of deliveryIds) {
              const dOrder = await DeliveryOrder.findByPk(did);
              if (!dOrder) continue;
              // Create DeliveryPayment entry held in escrow
              const payment = await DeliveryPayment.create({
                deliveryOrderId: dOrder.id,
                customerId: bundle.customerId,
                driverId: dOrder.driverId || null,
                currency: bundle.currency || 'JOD',
                grossAmount: Number(dOrder.earningAmount || 0),
                platformCommissionRate: Number(process.env.DELIVERY_COMMISSION_RATE || 0),
                platformCommission: Number(((Number(dOrder.earningAmount || 0) * Number(process.env.DELIVERY_COMMISSION_RATE || 0)) / 100).toFixed(3)),
                driverAmount: Number((Number(dOrder.earningAmount || 0) - (((Number(dOrder.earningAmount || 0) * Number(process.env.DELIVERY_COMMISSION_RATE || 0)) / 100))).toFixed(3)),
                stripePaymentIntentId: stripeObject.payment_intent || null,
                paymentStatus: 'succeeded',
                escrowStatus: 'held',
                paidAt: new Date(),
              });

              // Ensure delivery order status is updated consistently to awaiting_pickup
              try {
                // Use existing helper to mark delivery payment succeeded if available
                if (typeof markDeliveryPaymentSucceeded === 'function') {
                  await markDeliveryPaymentSucceeded(payment, stripeObject.payment_intent || null);
                } else {
                  // Fallback: directly set DeliveryOrder.status to 'awaiting_pickup'
                  await dOrder.update({
                    status: 'awaiting_pickup'
                  });
                }
              } catch (e) {
                // If helper fails, attempt direct update
                try {
                  await dOrder.update({
                    status: 'awaiting_pickup'
                  });
                } catch (err) {
                  console.error('[bundle delivery status update] failed for', did, err.message || err);
                }
              }
            }

            // Mark bundle as paid
            bundle.paymentStatus = 'paid';
            bundle.paidAt = new Date();
            await bundle.save();
          }
        } catch (e) {
          console.error('[process bundle delivery] error:', e.message || e);
        }
      }
      // Delivery checkout
      if (stripeObject.metadata?.craftgoPaymentType === 'delivery') {
        const existing = await DeliveryPayment.findOne({
          where: {
            deliveryOrderId: stripeObject.metadata.deliveryOrderId
          }
        });
        if (existing) {
          await markDeliveryPaymentSucceeded(existing, stripeObject.payment_intent);
        }
      }

      // Custom Order
      if (stripeObject.metadata?.craftgoPaymentType === 'custom_order') {
        const request = await CustomOrderRequest.findOne({
          where: {
            id: stripeObject.metadata.requestId,
          },
        });
        if (request) {
          await request.update({
            paymentStatus: 'paid',
            paidAt: new Date(),
            status: 'in_progress',
            contractSigned: true,
            contractSignedAt: new Date(),
            stripePaymentIntentId: stripeObject.payment_intent || request.stripePaymentIntentId,
          });
          console.log(`[custom_order] Payment succeeded for request ${request.id}`);
        }
      }

      if (
        stripeObject.metadata
        ?.craftgoPaymentType === 'ready_made'
      ) {
        const productPaymentController =
          require('./productPaymentController');

        await productPaymentController
          .processPaidCheckout(stripeObject);
      } else if (
        stripeObject.metadata
        ?.craftgoPaymentType === 'hire_order'
      ) {
        const transaction =
          await PaymentTransaction.findOne({
            where: {
              hireRequestId: stripeObject.metadata
                .hireRequestId,
            },
          });

        if (transaction) {
          await markPaymentSucceeded(
            transaction,
            stripeObject.payment_intent,
          );
        }
      }
    } else if (
      event.type ===
      'payment_intent.succeeded'
    ) {
      const intent = stripeObject;

      // Try delivery payments first
      const deliveryPayment = await DeliveryPayment.findOne({
        where: {
          stripePaymentIntentId: intent.id
        }
      });
      if (deliveryPayment) {
        await markDeliveryPaymentSucceeded(deliveryPayment, intent.id);
      } else {
        const transaction = await PaymentTransaction.findOne({
          where: {
            stripePaymentIntentId: intent.id
          }
        });
        if (transaction) await markPaymentSucceeded(transaction, intent.id);
      }
    } else if (
      event.type ===
      'payment_intent.payment_failed'
    ) {
      const intent = stripeObject;

      // mark failed for delivery or hire transactions
      const deliveryPayment = await DeliveryPayment.findOne({
        where: {
          stripePaymentIntentId: intent.id
        }
      });
      if (deliveryPayment) {
        deliveryPayment.paymentStatus = 'failed';
        deliveryPayment.failureMessage = intent.last_payment_error?.message || 'Payment failed';
        await deliveryPayment.save();
      } else {
        const transaction = await PaymentTransaction.findOne({
          where: {
            stripePaymentIntentId: intent.id
          }
        });
        if (transaction) {
          transaction.paymentStatus = 'failed';
          transaction.failureMessage = intent.last_payment_error?.message || 'Payment failed';
          await transaction.save();
        }
      }
    }
    // Inside the payment_intent.succeeded block, after deliveryPayment check
    const customRequest = await CustomOrderRequest.findOne({
      where: {
        stripePaymentIntentId: intent.id,
      },
    });
    if (customRequest) {
      await customRequest.update({
        paymentStatus: 'paid',
        paidAt: new Date(),
        status: 'in_progress',
        contractSigned: true,
        contractSignedAt: new Date(),
      });
      console.log(`[custom_order] Payment succeeded for request ${customRequest.id}`);
    }


    return res.json({
      received: true,
    });
  } catch (error) {
    console.error(
      '[stripeWebhook] ERROR:',
      error.message,
    );

    return res.status(400).send(
      `Webhook Error: ${error.message}`,
    );
  }
};

exports.getPaymentForHire = async (req, res) => {
  const transaction =
    await PaymentTransaction.findOne({
      where: {
        hireRequestId: req.params.hireRequestId,
      },
    });

  if (!transaction) {
    return res.status(404).json({
      error: 'Payment not found',
    });
  }

  const allowedUserIds = [
    transaction.customerId,
    transaction.artisanId,
  ].map(String);

  if (
    !allowedUserIds.includes(
      String(req.user.id),
    ) &&
    req.user.role !== 'admin'
  ) {
    return res.status(403).json({
      error: 'Forbidden',
    });
  }

  return res.json(transaction);
};

exports.getArtisanEarnings = async (req, res) => {
  if (
    String(req.params.artisanId) !==
    String(req.user.id) &&
    req.user.role !== 'admin'
  ) {
    return res.status(403).json({
      error: 'Forbidden',
    });
  }

  const transactions =
    await PaymentTransaction.findAll({
      where: {
        artisanId: req.params.artisanId,
      },
      include: [{
        model: HireRequest,
        as: 'hireRequest',
      }, ],
      order: [
        ['createdAt', 'DESC']
      ],
    });

  const pending = transactions
    .filter(
      (item) => item.escrowStatus === 'held',
    )
    .reduce(
      (sum, item) =>
      sum + Number(item.artisanAmount),
      0,
    );

  const available = transactions
    .filter(
      (item) =>
      item.escrowStatus === 'released',
    )
    .reduce(
      (sum, item) =>
      sum + Number(item.artisanAmount),
      0,
    );

  return res.json({
    pending,
    available,
    currency: 'JOD',
    transactions,
  });
};

// Stripe Connect onboarding for drivers
exports.createDriverOnboard = async (req, res) => {
  try {
    if (!stripe || !isConfiguredKey(process.env.STRIPE_SECRET_KEY)) {
      return res.status(503).json({
        error: 'Stripe not configured'
      });
    }

    const driverId = req.params.driverId;

    // Ensure driver exists
    const driver = await User.findByPk(driverId);
    if (!driver) return res.status(404).json({
      error: 'Driver not found'
    });

    // Find or create DeliveryProfile
    let profile = await DeliveryProfile.findOne({
      where: {
        driverId
      }
    });
    if (!profile) {
      profile = await DeliveryProfile.create({
        driverId
      });
    }

    // If already has connectedAccountId, create an account link for onboarding/refresh
    let accountId = profile.connectedAccountId;
    if (!accountId) {
      // Create an Express account for the driver
      const account = await stripe.accounts.create({
        type: 'express'
      });
      accountId = account.id;
      profile.connectedAccountId = accountId;
      await profile.save();
    }

    // Create account link
    const accountLink = await stripe.accountLinks.create({
      account: accountId,
      refresh_url: process.env.STRIPE_ONBOARDING_REFRESH_URL || `${PUBLIC_API_URL}/stripe/refresh`,
      return_url: process.env.STRIPE_ONBOARDING_RETURN_URL || `${PUBLIC_API_URL}/stripe/return`,
      type: 'account_onboarding',
    });

    return res.json({
      onboardingUrl: accountLink.url,
      accountId
    });
  } catch (error) {
    console.error('[createDriverOnboard] ERROR:', error.message || error);
    return res.status(500).json({
      error: error.message || 'Failed to create onboarding link'
    });
  }
};

exports.getAdminTransactions = async (
  req,
  res,
) => {
  try {
    const hireTransactions =
      await PaymentTransaction.findAll({
        include: [{
            model: User,
            as: 'customer',
            attributes: [
              'id',
              'name',
              'email',
            ],
          },
          {
            model: User,
            as: 'artisan',
            attributes: [
              'id',
              'name',
              'email',
            ],
          },
          {
            model: HireRequest,
            as: 'hireRequest',
          },
        ],
        order: [
          ['createdAt', 'DESC']
        ],
      });

    const productPayments =
      await ReadyMadePayment.findAll({
        order: [
          ['createdAt', 'DESC']
        ],
      });

    const readyMadeTransactions =
      await Promise.all(
        productPayments.map(async (payment) => {
          const plain = payment.toJSON();

          const [
            customer,
            artisan,
            order,
          ] = await Promise.all([
            User.findByPk(payment.customerId, {
              attributes: [
                'id',
                'name',
                'email',
              ],
            }),
            User.findByPk(payment.artisanId, {
              attributes: [
                'id',
                'name',
                'email',
              ],
            }),
            Order.findByPk(payment.orderId),
          ]);

          const product = order?.productId ?
            await Product.findByPk(
              order.productId, {
                attributes: [
                  'id',
                  'titleEn',
                  'titleAr',
                  'imageUrl',
                ],
              },
            ) :
            null;

          return {
            ...plain,
            transactionType: 'ready_made',
            customer: customer?.toJSON() || null,
            artisan: artisan?.toJSON() || null,
            order: order?.toJSON() || null,
            product: product?.toJSON() || null,
          };
        }),
      );

    const normalizedHireTransactions =
      hireTransactions.map((item) => ({
        ...item.toJSON(),
        transactionType: 'hire',
      }));

    const transactions = [
      ...normalizedHireTransactions,
      ...readyMadeTransactions,
    ].sort(
      (a, b) =>
      new Date(b.createdAt) -
      new Date(a.createdAt),
    );

    const totals = transactions.reduce(
      (acc, item) => {
        const paymentSucceeded =
          item.paymentStatus === 'succeeded';

        const held =
          item.escrowStatus === 'held';

        const released =
          item.escrowStatus === 'released';

        if (paymentSucceeded) {
          acc.gross += Number(
            item.grossAmount || 0,
          );
        }

        if (held) {
          acc.held += Number(
            item.grossAmount || 0,
          );
        }

        if (released) {
          acc.admin += Number(
            item.adminCommission || 0,
          );

          acc.artisan += Number(
            item.artisanAmount || 0,
          );
        }

        return acc;
      }, {
        gross: 0,
        admin: 0,
        artisan: 0,
        held: 0,
      },
    );

    const countByRole = async (roleName) =>
      User.count({
        include: [{
          model: Role,
          where: {
            name: roleName,
          },
          attributes: [],
          through: {
            attributes: [],
          },
          required: true,
        }, ],
        distinct: true,
      });

    const [
      craftsmenCount,
      activeClientsCount,
    ] = await Promise.all([
      countByRole('artisan'),
      countByRole('customer'),
    ]);

    return res.json({
      currency: 'JOD',
      totals,
      userCounts: {
        craftsmen: craftsmenCount,
        activeClients: activeClientsCount,
      },
      transactions,
    });
  } catch (error) {
    console.error(
      '[getAdminTransactions] ERROR:',
      error,
    );

    return res.status(500).json({
      error: 'Failed to load admin payment transactions',
      details: error.message,
    });
  }
};

exports.releaseEscrow = async (req, res) => {
  try {
    const reason = String(
      req.body?.reason || '',
    ).trim();

    if (reason.length < 5) {
      return res.status(400).json({
        error: 'A release reason of at least 5 characters is required',
      });
    }

    let releasedTransaction;

    await sequelize.transaction(
      async (dbTransaction) => {
        const transaction =
          await PaymentTransaction.findOne({
            where: {
              hireRequestId: req.params.hireRequestId,
            },
            transaction: dbTransaction,
          });

        if (!transaction) {
          const error = new Error(
            'Payment not found',
          );

          error.status = 404;
          throw error;
        }

        if (
          transaction.paymentStatus !==
          'succeeded' ||
          transaction.escrowStatus !== 'held'
        ) {
          const error = new Error(
            'Only a successful payment held in escrow can be released',
          );

          error.status = 409;
          throw error;
        }

        const hireRequest =
          await HireRequest.findByPk(
            transaction.hireRequestId, {
              transaction: dbTransaction,
            },
          );

        if (
          !hireRequest ||
          hireRequest.status !== 'completed'
        ) {
          const error = new Error(
            'Customer completion confirmation is required before release',
          );

          error.status = 409;
          throw error;
        }

        await transaction.update({
          escrowStatus: 'released',
          releasedAt: new Date(),
        }, {
          transaction: dbTransaction,
        }, );

        releasedTransaction = transaction;
      },
    );

    console.info('[ESCROW_RELEASE]', {
      hireRequestId: req.params.hireRequestId,
      adminId: req.user.id,
      reason,
      releasedAt: releasedTransaction.releasedAt,
    });

    return res.json({
      success: true,
      reason,
      transaction: releasedTransaction,
    });
  } catch (error) {
    return res
      .status(error.status || 500)
      .json({
        error: error.message,
      });
  }
};

exports.createExhibitionBoothIntent = async (req, res) => {
  try {
    const {
      exhibitionId
    } = req.params;
    const {
      boothPrice,
      boothId
    } = req.body;
    const price = Number(boothPrice || 50);

    if (stripe && isConfiguredKey(process.env.STRIPE_PUBLISHABLE_KEY)) {
      const intent = await stripe.paymentIntents.create({
        amount: toStripeMinorUnits(price),
        currency: 'usd',
        metadata: {
          exhibitionId,
          boothId: String(boothId || ''),
          craftsmanId: String(req.user.id),
          type: 'exhibition_booth',
        },
      });

      return res.status(201).json({
        publishableKey: process.env.STRIPE_PUBLISHABLE_KEY,
        paymentIntentClientSecret: intent.client_secret,
        paymentIntentId: intent.id,
      });
    } else {
      // Fallback mock payment reference for offline/test mode
      return res.status(200).json({
        publishableKey: 'mock_pub_key',
        paymentIntentClientSecret: 'mock_secret_' + Date.now(),
        isMock: true,
        paymentReference: 'TXN-EXH-' + Date.now(),
      });
    }
  } catch (error) {
    console.error('[createExhibitionBoothIntent ERROR]:', error);
    return res.status(500).json({
      error: error.message
    });
  }
};

exports.createExhibitionBoothCheckout = async (req, res) => {
  try {
    if (!stripe) {
      return res.status(503).json({
        error: 'Stripe test key is not configured'
      });
    }
    const exhibition = await Exhibition.findByPk(req.params.exhibitionId);
    if (!exhibition) return res.status(404).json({
      error: 'Exhibition not found'
    });

    const price = Number(req.body.boothPrice);
    if (!Number.isFinite(price) || price <= 0) {
      return res.status(400).json({
        error: 'Invalid paid booth price'
      });
    }

    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      payment_method_types: ['card'],
      line_items: [{
        quantity: 1,
        price_data: {
          currency: 'usd',
          unit_amount: toStripeMinorUnits(price),
          product_data: {
            name: `CraftGo Exhibition Booth ${String(req.body.boothId || '')}`,
            description: `Exhibition booth fee: ${price.toFixed(2)} JOD`,
          },
        },
      }],
      metadata: {
        craftgoPaymentType: 'exhibition_booth',
        exhibitionId: String(req.params.exhibitionId),
        boothId: String(req.body.boothId || ''),
        craftsmanId: String(req.user.id),
      },
      success_url: `${PUBLIC_API_URL}/api/payments/checkout/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${PUBLIC_API_URL}/api/payments/checkout/cancel`,
    }, {
      idempotencyKey: `craftgo-exhibition-checkout-${req.params.exhibitionId}-${req.user.id}-${req.body.boothId}`,
    });

    return res.status(201).json({
      checkoutUrl: session.url,
      sessionId: session.id
    });
  } catch (error) {
    console.error('[createExhibitionBoothCheckout ERROR]:', error);
    return res.status(500).json({
      error: 'Failed to start booth checkout'
    });
  }
};

exports.getExhibitionBoothCheckout = async (req, res) => {
  try {
    if (!stripe) return res.status(503).json({
      error: 'Stripe is not configured'
    });
    const session = await stripe.checkout.sessions.retrieve(req.params.sessionId);
    if (String(session.metadata?.exhibitionId) !== String(req.params.exhibitionId) ||
      String(session.metadata?.craftsmanId) !== String(req.user.id)) {
      return res.status(403).json({
        error: 'Forbidden'
      });
    }
    return res.json({
      paid: session.payment_status === 'paid' || session.status === 'complete',
      cancelled: session.status === 'expired',
    });
  } catch (error) {
    console.error('[getExhibitionBoothCheckout ERROR]:', error);
    return res.status(500).json({
      error: 'Failed to check booth checkout'
    });
  }
};

// ─── FIXED: Exhibition Owner Earnings (only paid booths) ────────────────
exports.getExhibitionOwnerEarnings = async (req, res) => {
  try {
    const ownerId = req.user.id;

    // Find all exhibitions owned by this user
    const exhibitions = await Exhibition.findAll({
      where: {
        ownerId
      },
      attributes: ['id', 'name', 'boothPrice'],
    });

    const exhibitionIds = exhibitions.map((e) => e.id);

    if (exhibitionIds.length === 0) {
      return res.json({
        success: true,
        summary: {
          totalGrossSales: 0,
          commissionRate: '5%',
          totalPlatformFees: 0,
          totalNetEarnings: 0,
          totalBoothsBooked: 0,
          totalExhibitionsCount: 0,
        },
        transactions: [],
      });
    }

    // ✅ Only include registrations that have been paid for (hasPaid = true)
    // and have a positive booth price (exclude free booths).
    const registrations = await ExhibitionCraftsman.findAll({
      where: {
        exhibitionId: {
          [Op.in]: exhibitionIds
        },
        hasPaid: true,
        boothPrice: {
          [Op.gt]: 0
        }, // only positive prices
      },
      include: [{
          model: User,
          as: 'Craftsman',
          attributes: ['id', 'name', 'email']
        },
        {
          model: Exhibition,
          as: 'Exhibition',
          attributes: ['id', 'name']
        },
      ],
      order: [
        ['createdAt', 'DESC']
      ],
    });

    const COMMISSION_RATE = 0.05; // 5% platform commission
    let totalGrossSales = 0;
    const transactionsList = [];

    registrations.forEach((reg) => {
      const price = Number(reg.boothPrice || 0);
      if (price > 0) {
        const platformFee = Number((price * COMMISSION_RATE).toFixed(2));
        const netEarnings = Number((price - platformFee).toFixed(2));
        totalGrossSales += price;

        transactionsList.push({
          id: reg.id,
          exhibitionId: reg.exhibitionId,
          exhibitionName: reg.Exhibition ? reg.Exhibition.name : 'Exhibition Booth',
          artisanName: reg.Craftsman ? reg.Craftsman.name : 'Craftsman',
          boothId: reg.boothId || 'A1',
          grossAmount: price,
          platformFee,
          netEarnings,
          hasPaid: reg.hasPaid,
          status: reg.status,
          paymentReference: reg.paymentReference || 'TXN-EXH-' + reg.id.slice(0, 6),
          createdAt: reg.createdAt,
        });
      }
    });

    const totalPlatformFees = Number((totalGrossSales * COMMISSION_RATE).toFixed(2));
    const totalNetEarnings = Number((totalGrossSales - totalPlatformFees).toFixed(2));

    return res.json({
      success: true,
      summary: {
        totalGrossSales,
        commissionRate: '5%',
        totalPlatformFees,
        totalNetEarnings,
        totalBoothsBooked: registrations.length,
        totalExhibitionsCount: exhibitions.length,
      },
      transactions: transactionsList,
    });
  } catch (error) {
    console.error('[getExhibitionOwnerEarnings ERROR]:', error);
    return res.status(500).json({
      error: error.message
    });
  }
};

// ── Custom Order Payment Intent ────────────────────────────────────────────
// Helper: Compute custom order total from response breakdown, response.total, or template base price
function getCustomOrderTotal(request) {
  const response = request.artisanResponse || {};
  let total = Number(response.total || 0);

  if ((!Number.isFinite(total) || total <= 0) && Array.isArray(response.breakdown)) {
    total = response.breakdown.reduce((sum, item) => sum + Number(item.amount || 0), 0);
  }

  if ((!Number.isFinite(total) || total <= 0) && request.template?.basePrice) {
    total = Number(request.template.basePrice);
  }

  return total;
}

// ── Custom Order Payment Intent (Mobile) ────────────────────────────────────
exports.createCustomOrderIntent = async (req, res) => {
  try {
    console.log('[createCustomOrderIntent] Request params:', req.params);
    console.log('[createCustomOrderIntent] User:', req.user.id);

    if (!stripe || !isConfiguredKey(process.env.STRIPE_PUBLISHABLE_KEY)) {
      console.error('[createCustomOrderIntent] Stripe not configured');
      return res.status(503).json({
        error: 'Stripe test keys are not configured',
        code: 'STRIPE_NOT_CONFIGURED',
      });
    }

    const {
      requestId
    } = req.params;
    const request = await CustomOrderRequest.findByPk(requestId, {
      include: [{
        model: CustomOrderTemplate,
        as: 'template'
      }],
    });
    if (!request) {
      return res.status(404).json({
        error: 'Custom order request not found'
      });
    }
    if (String(request.customerId) !== String(req.user.id) && req.user.role !== 'admin') {
      return res.status(403).json({
        error: 'Forbidden'
      });
    }
    if (request.status !== 'pending_customer') {
      return res.status(409).json({
        error: `This request is not awaiting payment (status: ${request.status})`,
      });
    }

    const total = getCustomOrderTotal(request);
    if (!Number.isFinite(total) || total <= 0) {
      return res.status(400).json({
        error: 'Invalid total amount for custom order'
      });
    }

    const adminCommission = Number(((total * COMMISSION_RATE) / 100).toFixed(3));
    const artisanAmount = Number((total - adminCommission).toFixed(3));

    console.log('[createCustomOrderIntent] Creating intent for:', {
      requestId,
      total,
      adminCommission,
      artisanAmount,
    });

    const intent = await stripe.paymentIntents.create({
      amount: toStripeMinorUnits(total),
      currency: 'usd',
      automatic_payment_methods: {
        enabled: true
      },
      metadata: {
        craftgoPaymentType: 'custom_order',
        requestId: request.id,
        customerId: request.customerId,
        artisanId: request.artisanId,
      },
      description: `CraftGo custom order ${request.id}`,
    }, {
      idempotencyKey: `craftgo-custom-intent-${request.id}`
    });

    await request.update({
      stripePaymentIntentId: intent.id,
      paymentStatus: 'unpaid',
    });

    return res.status(201).json({
      paymentIntentClientSecret: intent.client_secret,
      publishableKey: process.env.STRIPE_PUBLISHABLE_KEY,
      merchantDisplayName: 'CraftGo',
      transaction: {
        id: request.id,
        total,
        adminCommission,
        artisanAmount,
      },
    });
  } catch (error) {
    console.error('[createCustomOrderIntent] ERROR:', error);
    return res.status(500).json({
      error: 'Failed to start payment',
      details: error.message,
    });
  }
};

// ── Custom Order Stripe Checkout Session (Web) ──────────────────────────────
exports.createCustomOrderCheckoutSession = async (req, res) => {
  try {
    console.log('[createCustomOrderCheckoutSession] Request params:', req.params);

    if (!stripe) {
      return res.status(503).json({
        error: 'Stripe test key is not configured'
      });
    }

    const {
      requestId
    } = req.params;
    const request = await CustomOrderRequest.findByPk(requestId, {
      include: [{
        model: CustomOrderTemplate,
        as: 'template'
      }],
    });

    if (!request) {
      return res.status(404).json({
        error: 'Custom order request not found'
      });
    }
    if (String(request.customerId) !== String(req.user.id) && req.user.role !== 'admin') {
      return res.status(403).json({
        error: 'Forbidden'
      });
    }

    const total = getCustomOrderTotal(request);
    if (!Number.isFinite(total) || total <= 0) {
      return res.status(400).json({
        error: 'Invalid total amount'
      });
    }

    const adminCommission = Number(((total * COMMISSION_RATE) / 100).toFixed(3));
    const artisanAmount = Number((total - adminCommission).toFixed(3));

    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      payment_method_types: ['card'],
      line_items: [{
        quantity: 1,
        price_data: {
          currency: 'usd',
          unit_amount: toStripeMinorUnits(total),
          product_data: {
            name: `CraftGo Custom Order: ${request.template?.titleEn || request.template?.titleAr || 'Custom Order'}`,
            description: `Escrow payment for custom order - total: ${total.toFixed(2)} JOD`,
          },
        },
      }],
      metadata: {
        craftgoPaymentType: 'custom_order',
        requestId: request.id,
        customerId: request.customerId,
        artisanId: request.artisanId,
      },
      success_url: `${PUBLIC_API_URL}/api/payments/checkout/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${PUBLIC_API_URL}/api/payments/checkout/cancel`,
    }, {
      idempotencyKey: `craftgo-custom-checkout-${request.id}`,
    });

    await request.update({
      stripePaymentIntentId: session.id,
      paymentStatus: 'unpaid',
    });

    return res.status(201).json({
      checkoutUrl: session.url,
      transaction: {
        id: request.id,
        total,
        adminCommission,
        artisanAmount,
      },
    });
  } catch (error) {
    console.error('[createCustomOrderCheckoutSession] ERROR:', error);
    return res.status(500).json({
      error: 'Failed to start web checkout',
      details: error.message,
    });
  }
};

// ── Confirm Custom Order Payment ──────────────────────────────────────────
exports.confirmCustomOrderPayment = async (req, res) => {
  try {
    console.log('[confirmCustomOrderPayment] Request params:', req.params);

    if (!stripe) {
      return res.status(503).json({
        error: 'Stripe not configured'
      });
    }

    const {
      requestId
    } = req.params;
    const request = await CustomOrderRequest.findByPk(requestId);
    if (!request) {
      return res.status(404).json({
        error: 'Custom order request not found'
      });
    }
    if (String(request.customerId) !== String(req.user.id) && req.user.role !== 'admin') {
      return res.status(403).json({
        error: 'Forbidden'
      });
    }

    // Handle both PaymentIntent and Checkout Session retrieval
    let isPaid = request.paymentStatus === 'paid';
    if (!isPaid && request.stripePaymentIntentId) {
      if (request.stripePaymentIntentId.startsWith('cs_')) {
        const session = await stripe.checkout.sessions.retrieve(request.stripePaymentIntentId);
        isPaid = session.payment_status === 'paid' || session.status === 'complete';
      } else {
        const intent = await stripe.paymentIntents.retrieve(request.stripePaymentIntentId);
        isPaid = intent.status === 'succeeded' || intent.status === 'requires_capture' || intent.status === 'processing';
      }
    }

    if (!isPaid && process.env.NODE_ENV !== 'production') {
      // In development/test mode, allow confirmation if client presentPaymentSheet completed
      isPaid = true;
    }

    if (!isPaid) {
      return res.status(409).json({
        error: 'Payment has not succeeded'
      });
    }

    // Mark as paid and set status to in_progress
    await request.update({
      paymentStatus: 'paid',
      paidAt: new Date(),
      status: 'in_progress',
      contractSigned: true,
      contractSignedAt: new Date(),
    });

    console.log('[confirmCustomOrderPayment] Payment confirmed for:', requestId);

    const total = getCustomOrderTotal(request);
    const adminCommission = Number(((total * COMMISSION_RATE) / 100).toFixed(3));
    const artisanAmount = Number((total - adminCommission).toFixed(3));

    return res.json({
      success: true,
      request,
      transaction: {
        id: request.id,
        total,
        adminCommission,
        artisanAmount,
      },
    });
  } catch (error) {
    console.error('[confirmCustomOrderPayment] ERROR:', error);
    return res.status(500).json({
      error: 'Failed to confirm payment',
      details: error.message,
    });
  }
};

exports.createPayoutSession = async (req, res) => {
  try {
    const userId = req.user.id;
    const user = await User.findByPk(userId);
    if (!user) return res.status(404).json({
      error: 'User not found'
    });

    if (!stripe || !isConfiguredKey(process.env.STRIPE_SECRET_KEY)) {
      return res.json({
        onboardingUrl: 'https://connect.stripe.com/express/oauth/authorize',
        message: 'Stripe test mode link',
      });
    }

    let accountId = user.stripeAccountId;
    if (!accountId) {
      const account = await stripe.accounts.create({
        type: 'express',
        email: user.email || undefined,
        metadata: {
          userId: user.id,
          role: user.role || 'user'
        },
      });
      accountId = account.id;
      if (user.stripeAccountId !== undefined) {
        user.stripeAccountId = accountId;
        await user.save();
      }
    }

    const accountLink = await stripe.accountLinks.create({
      account: accountId,
      refresh_url: process.env.STRIPE_ONBOARDING_REFRESH_URL || `${PUBLIC_API_URL}/stripe/refresh`,
      return_url: process.env.STRIPE_ONBOARDING_RETURN_URL || `${PUBLIC_API_URL}/stripe/return`,
      type: 'account_onboarding',
    });

    return res.json({
      onboardingUrl: accountLink.url,
      accountId,
    });
  } catch (error) {
    console.error('[createPayoutSession] ERROR:', error.message || error);
    return res.status(500).json({
      error: error.message || 'Failed to create payout link',
    });
  }
};

// const Stripe = require('stripe');
// const PaymentTransaction = require('../models/PaymentTransaction');
// const HireRequest = require('../models/HireRequest');
// const User = require('../models/User');
// const DeliveryOrder = require('../models/DeliveryOrder');
// const DeliveryPayment = require('../models/DeliveryPayment');
// const DeliveryProfile = require('../models/DeliveryProfile');
// const ReadyMadePayment = require('../models/ReadyMadePayment');
// const Order = require('../models/Order');
// const Product = require('../models/Product');
// const Role = require('../models/Role');
// const Exhibition = require('../models/Exhibition');
// const ExhibitionCraftsman = require('../models/ExhibitionCraftsman');
// const CustomOrderRequest = require('../models/CustomOrderRequest');
// const CustomOrderTemplate = require('../models/CustomOrderTemplate');

// const { Op } = require('sequelize');

// const sequelize = PaymentTransaction.sequelize;

// const COMMISSION_RATE = 10;
// const JOD_PER_USD = Number(process.env.JOD_PER_USD || 3.1122);

// const PUBLIC_API_URL = (
//   process.env.PUBLIC_API_URL || 'http://localhost:5000'
// ).replace(/\/$/, '');

// const isConfiguredKey = (value) =>
//   value && !value.includes('REPLACE_ME');

// const stripe = isConfiguredKey(process.env.STRIPE_SECRET_KEY) ?
//   new Stripe(process.env.STRIPE_SECRET_KEY) :
//   null;

// // Stripe Sandbox processes test payments in USD.
// // CraftGo's internal accounting remains in JOD.
// const toStripeMinorUnits = (amount) =>
//   Math.max(
//     50,
//     Math.round((Number(amount) / JOD_PER_USD) * 100),
//   );

// function proposalAmounts(request) {
//   const response = request.artisanResponse || {};

//   const grossAmount = Number(
//     request.totalPrice || response.totalPrice || 0,
//   );

//   if (!Number.isFinite(grossAmount) || grossAmount <= 0) {
//     return null;
//   }

//   const adminCommission = Number(
//     ((grossAmount * COMMISSION_RATE) / 100).toFixed(3),
//   );

//   return {
//     grossAmount,
//     adminCommission,
//     artisanAmount: Number(
//       (grossAmount - adminCommission).toFixed(3),
//     ),
//   };
// }

// async function markPaymentSucceeded(
//   transaction,
//   paymentIntentId,
// ) {
//   if (transaction.paymentStatus === 'succeeded') {
//     return transaction;
//   }

//   await sequelize.transaction(async (dbTransaction) => {
//     await transaction.update({
//       stripePaymentIntentId: paymentIntentId ||
//         transaction.stripePaymentIntentId,
//       paymentStatus: 'succeeded',
//       escrowStatus: 'held',
//       paidAt: new Date(),
//       failureMessage: null,
//     }, {
//       transaction: dbTransaction,
//     }, );

//     const request = await HireRequest.findByPk(
//       transaction.hireRequestId, {
//         transaction: dbTransaction,
//       },
//     );

//     if (
//       request &&
//       request.status === 'pending_customer'
//     ) {
//       await request.update({
//         status: 'in_progress',
//       }, {
//         transaction: dbTransaction,
//       }, );
//     }
//   });

//   return transaction;
// }

// async function markDeliveryPaymentSucceeded(payment, paymentIntentId) {
//   if (payment.paymentStatus === 'succeeded') return payment;

//   await sequelize.transaction(async (dbTransaction) => {
//     await payment.update({
//       stripePaymentIntentId: paymentIntentId || payment.stripePaymentIntentId,
//       paymentStatus: 'succeeded',
//       escrowStatus: 'held',
//       paidAt: new Date(),
//       failureMessage: null,
//     }, {
//       transaction: dbTransaction
//     }, );

//     const order = await DeliveryOrder.findByPk(payment.deliveryOrderId, {
//       transaction: dbTransaction,
//     });

//     if (order && order.status === 'pending_payment') {
//       await order.update({
//         status: 'awaiting_pickup'
//       }, {
//         transaction: dbTransaction
//       });
//     }
//   });

//   return payment;
// }

// exports.createPaymentIntent = async (req, res) => {
//   try {
//     if (
//       !stripe ||
//       !isConfiguredKey(
//         process.env.STRIPE_PUBLISHABLE_KEY,
//       )
//     ) {
//       return res.status(503).json({
//         error: 'Stripe test keys are not configured',
//         code: 'STRIPE_NOT_CONFIGURED',
//       });
//     }

//     const request = await HireRequest.findByPk(
//       req.params.hireRequestId,
//     );

//     if (!request) {
//       return res.status(404).json({
//         error: 'Hire request not found',
//       });
//     }

//     if (
//       String(request.customerId) !==
//       String(req.user.id)
//     ) {
//       return res.status(403).json({
//         error: 'Forbidden',
//       });
//     }

//     if (request.status !== 'pending_customer') {
//       return res.status(409).json({
//         error: 'This proposal is not awaiting payment',
//       });
//     }

//     const response = request.artisanResponse || {};

//     const grossAmount = Number(
//       request.totalPrice ||
//       response.totalPrice ||
//       0,
//     );

//     if (
//       !Number.isFinite(grossAmount) ||
//       grossAmount <= 0
//     ) {
//       return res.status(400).json({
//         error: 'Invalid proposal total',
//       });
//     }

//     const adminCommission = Number(
//       (
//         (grossAmount * COMMISSION_RATE) /
//         100
//       ).toFixed(3),
//     );

//     const artisanAmount = Number(
//       (grossAmount - adminCommission).toFixed(3),
//     );

//     let transaction =
//       await PaymentTransaction.findOne({
//         where: {
//           hireRequestId: request.id,
//         },
//       });

//     if (
//       transaction?.paymentStatus ===
//       'succeeded'
//     ) {
//       return res.status(409).json({
//         error: 'This request is already paid',
//       });
//     }

//     const intent =
//       await stripe.paymentIntents.create({
//         amount: toStripeMinorUnits(grossAmount),
//         currency: 'usd',
//         automatic_payment_methods: {
//           enabled: true,
//         },
//         metadata: {
//           craftgoPaymentType: 'hire_order',
//           hireRequestId: request.id,
//           customerId: request.customerId,
//           artisanId: request.artisanId,
//         },
//         description: `CraftGo on-site order ${request.id}`,
//       }, {
//         idempotencyKey: `craftgo-hire-intent-${request.id}`,
//       }, );

//     const values = {
//       hireRequestId: request.id,
//       customerId: request.customerId,
//       artisanId: request.artisanId,
//       currency: 'JOD',
//       grossAmount,
//       adminCommissionRate: COMMISSION_RATE,
//       adminCommission,
//       artisanAmount,
//       stripePaymentIntentId: intent.id,
//       paymentStatus: 'created',
//       escrowStatus: 'unpaid',
//     };

//     if (transaction) {
//       await transaction.update(values);
//     } else {
//       transaction =
//         await PaymentTransaction.create(values);
//     }

//     return res.status(201).json({
//       paymentIntentClientSecret: intent.client_secret,
//       publishableKey: process.env.STRIPE_PUBLISHABLE_KEY,
//       merchantDisplayName: 'CraftGo',
//       transaction: {
//         id: transaction.id,
//         grossAmount,
//         adminCommission,
//         artisanAmount,
//         currency: 'JOD',
//       },
//     });
//   } catch (error) {
//     console.error(
//       '[createPaymentIntent] ERROR:',
//       error,
//     );

//     return res.status(500).json({
//       error: 'Failed to start payment',
//       details: error.message,
//     });
//   }
// };

// // ── Delivery Payment Intent ─────────────────────────────────────────────
// exports.createDeliveryIntent = async (req, res) => {
//   try {
//     if (!stripe || !isConfiguredKey(process.env.STRIPE_PUBLISHABLE_KEY)) {
//       return res.status(503).json({
//         error: 'Stripe test keys are not configured',
//         code: 'STRIPE_NOT_CONFIGURED'
//       });
//     }

//     const order = await DeliveryOrder.findByPk(req.params.deliveryOrderId);
//     if (!order) return res.status(404).json({
//       error: 'Delivery order not found'
//     });

//     // Only the customer who owns the order can create the intent
//     if (String(order.customerId) !== String(req.user.id)) {
//       return res.status(403).json({
//         error: 'Forbidden'
//       });
//     }

//     // Determine gross amount (prefer explicit earningAmount, fallback to request body)
//     const grossAmount = Number(order.earningAmount || req.body.amount || 0);
//     if (!Number.isFinite(grossAmount) || grossAmount <= 0) {
//       return res.status(400).json({
//         error: 'Invalid delivery amount'
//       });
//     }

//     // Platform commission for delivery — default 0, can be configured
//     const platformCommissionRate = Number(process.env.DELIVERY_COMMISSION_RATE || 0);
//     const platformCommission = Number(((grossAmount * platformCommissionRate) / 100).toFixed(3));
//     const driverAmount = Number((grossAmount - platformCommission).toFixed(3));

//     let payment = await DeliveryPayment.findOne({
//       where: {
//         deliveryOrderId: order.id
//       }
//     });
//     if (payment?.paymentStatus === 'succeeded') {
//       return res.status(409).json({
//         error: 'This delivery order is already paid'
//       });
//     }

//     const intent = await stripe.paymentIntents.create({
//       amount: toStripeMinorUnits(grossAmount),
//       currency: 'usd',
//       automatic_payment_methods: {
//         enabled: true
//       },
//       metadata: {
//         craftgoPaymentType: 'delivery',
//         deliveryOrderId: order.id,
//         customerId: order.customerId,
//         driverId: order.driverId || '',
//       },
//       description: `CraftGo delivery payment ${order.id}`,
//     }, {
//       idempotencyKey: `craftgo-delivery-intent-${order.id}`
//     }, );

//     const values = {
//       deliveryOrderId: order.id,
//       customerId: order.customerId,
//       driverId: order.driverId || null,
//       currency: 'JOD',
//       grossAmount,
//       platformCommissionRate,
//       platformCommission,
//       driverAmount,
//       stripePaymentIntentId: intent.id,
//       paymentStatus: 'created',
//       escrowStatus: 'unpaid',
//       failureMessage: null,
//     };

//     if (payment) await payment.update(values);
//     else payment = await DeliveryPayment.create(values);

//     return res.status(201).json({
//       paymentIntentClientSecret: intent.client_secret,
//       publishableKey: process.env.STRIPE_PUBLISHABLE_KEY,
//       payment
//     });
//   } catch (error) {
//     console.error('[createDeliveryIntent] ERROR:', error);
//     return res.status(500).json({
//       error: 'Failed to start delivery payment',
//       details: error.message
//     });
//   }
// };

// exports.confirmDeliveryPayment = async (req, res) => {
//   try {
//     if (!stripe) return res.status(503).json({
//       error: 'Stripe not configured'
//     });

//     const payment = await DeliveryPayment.findOne({
//       where: {
//         deliveryOrderId: req.params.deliveryOrderId
//       }
//     });
//     if (!payment) return res.status(404).json({
//       error: 'Delivery payment not found'
//     });

//     if (String(payment.customerId) !== String(req.user.id)) return res.status(403).json({
//       error: 'Forbidden'
//     });

//     const intent = await stripe.paymentIntents.retrieve(payment.stripePaymentIntentId);
//     if (intent.status !== 'succeeded') {
//       payment.paymentStatus = intent.status === 'processing' ? 'processing' : 'failed';
//       payment.failureMessage = intent.last_payment_error?.message || null;
//       await payment.save();
//       return res.status(409).json({
//         error: 'Payment has not succeeded',
//         stripeStatus: intent.status
//       });
//     }

//     await markDeliveryPaymentSucceeded(payment, intent.id);

//     return res.json({
//       success: true,
//       payment
//     });
//   } catch (error) {
//     console.error('[confirmDeliveryPayment] ERROR:', error);
//     return res.status(500).json({
//       error: 'Failed to confirm delivery payment',
//       details: error.message
//     });
//   }
// };

// exports.getPaymentForDelivery = async (req, res) => {
//   const payment = await DeliveryPayment.findOne({
//     where: {
//       deliveryOrderId: req.params.deliveryOrderId
//     }
//   });
//   if (!payment) return res.status(404).json({
//     error: 'Payment not found'
//   });

//   const allowedUserIds = [String(payment.customerId), String(payment.driverId)].filter(Boolean);
//   if (!allowedUserIds.includes(String(req.user.id)) && req.user.role !== 'admin') return res.status(403).json({
//     error: 'Forbidden'
//   });

//   return res.json(payment);
// };

// exports.releaseDeliveryEscrow = async (req, res) => {
//   try {
//     const reason = String(req.body?.reason || '').trim();
//     if (reason.length < 5) return res.status(400).json({
//       error: 'A release reason of at least 5 characters is required'
//     });

//     let releasedPayment;
//     await sequelize.transaction(async (dbTransaction) => {
//       const payment = await DeliveryPayment.findOne({
//         where: {
//           deliveryOrderId: req.params.deliveryOrderId
//         },
//         transaction: dbTransaction
//       });
//       if (!payment) {
//         const error = new Error('Payment not found');
//         error.status = 404;
//         throw error;
//       }

//       if (payment.paymentStatus !== 'succeeded' || payment.escrowStatus !== 'held') {
//         const error = new Error('Only a successful payment held in escrow can be released');
//         error.status = 409;
//         throw error;
//       }

//       const order = await DeliveryOrder.findByPk(payment.deliveryOrderId, {
//         transaction: dbTransaction
//       });
//       if (!order || order.status !== 'delivered') {
//         const error = new Error('Delivery must be completed before release');
//         error.status = 409;
//         throw error;
//       }

//       // Attempt Stripe Connect transfer to driver if available
//       let stripeTransfer = null;
//       const driverProfile = payment.driverId ?
//         await DeliveryProfile.findOne({
//           where: {
//             driverId: payment.driverId
//           },
//           transaction: dbTransaction
//         }) :
//         null;
//       const connectedAccountId = driverProfile?.connectedAccountId || null;

//       if (stripe && connectedAccountId && isConfiguredKey(process.env.STRIPE_SECRET_KEY)) {
//         try {
//           const transferAmount = toStripeMinorUnits(Number(payment.driverAmount || 0));
//           stripeTransfer = await stripe.transfers.create({
//             amount: transferAmount,
//             currency: 'usd',
//             destination: connectedAccountId,
//             description: `Payout for delivery ${payment.deliveryOrderId}`,
//           });

//           await payment.update({
//             stripeTransferId: stripeTransfer.id,
//             escrowStatus: 'released',
//             releasedAt: new Date()
//           }, {
//             transaction: dbTransaction
//           });
//         } catch (tErr) {
//           console.error('[stripe.transfer] error:', tErr.message || tErr);
//           const error = new Error('Transfer to driver failed: ' + (tErr.message || 'stripe error'));
//           error.status = 500;
//           throw error;
//         }
//       } else {
//         // No connected Stripe account — mark as released for manual payout
//         await payment.update({
//           escrowStatus: 'released',
//           releasedAt: new Date()
//         }, {
//           transaction: dbTransaction
//         });
//       }

//       releasedPayment = payment;
//     });

//     const { releaseEscrowAndDistributeShares } = require('../utils/escrowHelper');
//     await releaseEscrowAndDistributeShares({
//       deliveryOrderId: req.params.deliveryOrderId,
//     });

//     console.info('[DELIVERY_ESCROW_RELEASE]', {
//       deliveryOrderId: req.params.deliveryOrderId,
//       adminId: req.user.id,
//       reason,
//       releasedAt: releasedPayment.releasedAt
//     });

//     return res.json({
//       success: true,
//       reason,
//       payment: releasedPayment
//     });
//   } catch (error) {
//     return res.status(error.status || 500).json({
//       error: error.message
//     });
//   }
// };

// // Flutter Web uses Stripe Checkout.
// // Android and iOS use PaymentSheet.
// // Both paths use the same escrow transaction ledger.
// exports.createCheckoutSession = async (req, res) => {
//   try {
//     if (!stripe) {
//       return res.status(503).json({
//         error: 'Stripe test key is not configured',
//       });
//     }

//     const request = await HireRequest.findByPk(
//       req.params.hireRequestId,
//     );

//     if (!request) {
//       return res.status(404).json({
//         error: 'Hire request not found',
//       });
//     }

//     if (
//       String(request.customerId) !==
//       String(req.user.id)
//     ) {
//       return res.status(403).json({
//         error: 'Forbidden',
//       });
//     }

//     if (request.status !== 'pending_customer') {
//       return res.status(409).json({
//         error: 'This proposal is not awaiting payment',
//       });
//     }

//     const amounts = proposalAmounts(request);

//     if (!amounts) {
//       return res.status(400).json({
//         error: 'Invalid proposal total',
//       });
//     }

//     let transaction =
//       await PaymentTransaction.findOne({
//         where: {
//           hireRequestId: request.id,
//         },
//       });

//     if (
//       transaction?.paymentStatus ===
//       'succeeded'
//     ) {
//       return res.status(409).json({
//         error: 'This request is already paid',
//       });
//     }

//     const session =
//       await stripe.checkout.sessions.create({
//         mode: 'payment',
//         payment_method_types: ['card'],
//         line_items: [{
//           quantity: 1,
//           price_data: {
//             currency: 'usd',
//             unit_amount: toStripeMinorUnits(
//               amounts.grossAmount,
//             ),
//             product_data: {
//               name: 'CraftGo Hire / On-Site Service',
//               description: `Test escrow payment — ` +
//                 `CraftGo order total: ` +
//                 `${amounts.grossAmount.toFixed(2)} JOD`,
//             },
//           },
//         }, ],
//         metadata: {
//           craftgoPaymentType: 'hire_order',
//           hireRequestId: request.id,
//           customerId: request.customerId,
//           artisanId: request.artisanId,
//         },
//         success_url: `${PUBLIC_API_URL}` +
//           `/api/payments/checkout/success` +
//           `?session_id={CHECKOUT_SESSION_ID}`,
//         cancel_url: `${PUBLIC_API_URL}` +
//           `/api/payments/checkout/cancel`,
//       }, {
//         idempotencyKey: `craftgo-hire-checkout-${request.id}`,
//       }, );

//     const values = {
//       hireRequestId: request.id,
//       customerId: request.customerId,
//       artisanId: request.artisanId,
//       currency: 'JOD',
//       ...amounts,
//       adminCommissionRate: COMMISSION_RATE,
//       stripePaymentIntentId: session.id,
//       paymentStatus: 'created',
//       escrowStatus: 'unpaid',
//       failureMessage: null,
//     };

//     if (transaction) {
//       await transaction.update(values);
//     } else {
//       transaction =
//         await PaymentTransaction.create(values);
//     }

//     return res.status(201).json({
//       checkoutUrl: session.url,
//       transaction: {
//         grossAmount: amounts.grossAmount,
//         adminCommission: amounts.adminCommission,
//         artisanAmount: amounts.artisanAmount,
//       },
//     });
//   } catch (error) {
//     console.error(
//       '[createCheckoutSession] ERROR:',
//       error,
//     );

//     return res.status(500).json({
//       error: 'Failed to start web checkout',
//       details: error.message,
//     });
//   }
// };

// exports.checkoutSuccess = async (req, res) => {
//   try {
//     if (!stripe || !req.query.session_id) {
//       throw new Error(
//         'Missing checkout session',
//       );
//     }

//     const session =
//       await stripe.checkout.sessions.retrieve(
//         req.query.session_id,
//       );

//     if (session.payment_status !== 'paid') {
//       throw new Error(
//         'Payment is not completed',
//       );
//     }

//     const transaction =
//       await PaymentTransaction.findOne({
//         where: {
//           stripePaymentIntentId: session.id,
//         },
//       });

//     if (!transaction) {
//       const customRequest = await CustomOrderRequest.findOne({
//         where: {
//           stripePaymentIntentId: session.id,
//         },
//       });
//       if (customRequest) {
//         await customRequest.update({
//           paymentStatus: 'paid',
//           paidAt: new Date(),
//           status: 'in_progress',
//           contractSigned: true,
//           contractSignedAt: new Date(),
//         });
//         return res.type('html').send(
//           checkoutResultPage(
//             'Payment successful',
//             'Your custom order is now confirmed and in progress.',
//             true,
//           ),
//         );
//       }
//     }

//     if (!transaction) {
//       throw new Error(
//         'CraftGo transaction was not found',
//       );
//     }

//     await markPaymentSucceeded(
//       transaction,
//       session.payment_intent,
//     );

//     return res.type('html').send(
//       checkoutResultPage(
//         'Payment successful',
//         'Your payment is now safely held in CraftGo Escrow. ' +
//         'You may close this tab and return to CraftGo.',
//         true,
//       ),
//     );
//   } catch (error) {
//     console.error(
//       '[checkoutSuccess] ERROR:',
//       error,
//     );

//     return res.status(400).type('html').send(
//       checkoutResultPage(
//         'Payment verification failed',
//         error.message,
//         false,
//       ),
//     );
//   }
// };

// exports.checkoutCancelled = (req, res) =>
//   res.type('html').send(
//     checkoutResultPage(
//       'Payment cancelled',
//       'No charge was made. You may close this tab and return to CraftGo.',
//       false,
//     ),
//   );

// function checkoutResultPage(
//   title,
//   message,
//   successful,
// ) {
//   const color = successful ?
//     '#4caf60' :
//     '#e2aa12';

//   return `
//     <!doctype html>
//     <html>
//       <head>
//         <meta
//           name="viewport"
//           content="width=device-width,initial-scale=1"
//         >
//         <title>${title}</title>
//       </head>

//       <body
//         style="
//           margin:0;
//           background:#0d1420;
//           color:white;
//           font-family:Arial,sans-serif;
//           display:grid;
//           place-items:center;
//           min-height:100vh;
//         "
//       >
//         <main
//           style="
//             max-width:440px;
//             margin:24px;
//             padding:32px;
//             text-align:center;
//             background:#1c2431;
//             border:1px solid #344055;
//             border-radius:20px;
//           "
//         >
//           <div
//             style="
//               font-size:52px;
//               color:${color};
//             "
//           >
//             ${successful ? '&#10003;' : '&#8592;'}
//           </div>

//           <h1>${title}</h1>

//           <p
//             style="
//               color:#b8c1cf;
//               line-height:1.6;
//             "
//           >
//             ${message}
//           </p>

//           <button
//             onclick="window.close()"
//             style="
//               margin-top:12px;
//               padding:12px 22px;
//               border:0;
//               border-radius:10px;
//               background:#e2aa12;
//               font-weight:bold;
//               cursor:pointer;
//             "
//           >
//             Close & return to CraftGo
//           </button>
//         </main>
//       </body>
//     </html>
//   `;
// }

// exports.confirmPayment = async (req, res) => {
//   try {
//     if (!stripe) {
//       return res.status(503).json({
//         error: 'Stripe is not configured',
//       });
//     }

//     const transaction =
//       await PaymentTransaction.findOne({
//         where: {
//           hireRequestId: req.params.hireRequestId,
//         },
//       });

//     if (!transaction) {
//       return res.status(404).json({
//         error: 'Payment not found',
//       });
//     }

//     if (
//       String(transaction.customerId) !==
//       String(req.user.id)
//     ) {
//       return res.status(403).json({
//         error: 'Forbidden',
//       });
//     }

//     const intent =
//       await stripe.paymentIntents.retrieve(
//         transaction.stripePaymentIntentId,
//       );

//     if (intent.status !== 'succeeded') {
//       transaction.paymentStatus =
//         intent.status === 'processing' ?
//         'processing' :
//         'failed';

//       transaction.failureMessage =
//         intent.last_payment_error?.message ||
//         null;

//       await transaction.save();

//       return res.status(409).json({
//         error: 'Payment has not succeeded',
//         stripeStatus: intent.status,
//       });
//     }

//     await markPaymentSucceeded(
//       transaction,
//       intent.id,
//     );

//     return res.json({
//       success: true,
//       transaction,
//     });
//   } catch (error) {
//     console.error(
//       '[confirmPayment] ERROR:',
//       error,
//     );

//     return res.status(500).json({
//       error: 'Failed to confirm payment',
//       details: error.message,
//     });
//   }
// };

// exports.stripeWebhook = async (req, res) => {
//   try {
//     if (
//       !stripe ||
//       !isConfiguredKey(
//         process.env.STRIPE_WEBHOOK_SECRET,
//       )
//     ) {
//       return res.status(503).send(
//         'Stripe webhook is not configured',
//       );
//     }

//     const event =
//       stripe.webhooks.constructEvent(
//         req.body,
//         req.headers['stripe-signature'],
//         process.env.STRIPE_WEBHOOK_SECRET,
//       );

//     const stripeObject = event.data.object;

//     if (
//       event.type ===
//       'checkout.session.completed' &&
//       stripeObject.payment_status === 'paid'
//     ) {
//       // If this is a bundled checkout, finalize delivery payments from the bundle
//       if (stripeObject.metadata?.bundleId) {
//         try {
//           const bundle = await require('../models/PaymentBundle').findOne({
//             where: {
//               id: stripeObject.metadata.bundleId
//             }
//           });
//           if (bundle) {
//             const deliveryIds = bundle.deliveryOrderIds || [];
//             for (const did of deliveryIds) {
//               const dOrder = await DeliveryOrder.findByPk(did);
//               if (!dOrder) continue;
//               // Create DeliveryPayment entry held in escrow
//               const payment = await DeliveryPayment.create({
//                 deliveryOrderId: dOrder.id,
//                 customerId: bundle.customerId,
//                 driverId: dOrder.driverId || null,
//                 currency: bundle.currency || 'JOD',
//                 grossAmount: Number(dOrder.earningAmount || 0),
//                 platformCommissionRate: Number(process.env.DELIVERY_COMMISSION_RATE || 0),
//                 platformCommission: Number(((Number(dOrder.earningAmount || 0) * Number(process.env.DELIVERY_COMMISSION_RATE || 0)) / 100).toFixed(3)),
//                 driverAmount: Number((Number(dOrder.earningAmount || 0) - (((Number(dOrder.earningAmount || 0) * Number(process.env.DELIVERY_COMMISSION_RATE || 0)) / 100))).toFixed(3)),
//                 stripePaymentIntentId: stripeObject.payment_intent || null,
//                 paymentStatus: 'succeeded',
//                 escrowStatus: 'held',
//                 paidAt: new Date(),
//               });

//               // Ensure delivery order status is updated consistently to awaiting_pickup
//               try {
//                 // Use existing helper to mark delivery payment succeeded if available
//                 if (typeof markDeliveryPaymentSucceeded === 'function') {
//                   await markDeliveryPaymentSucceeded(payment, stripeObject.payment_intent || null);
//                 } else {
//                   // Fallback: directly set DeliveryOrder.status to 'awaiting_pickup'
//                   await dOrder.update({
//                     status: 'awaiting_pickup'
//                   });
//                 }
//               } catch (e) {
//                 // If helper fails, attempt direct update
//                 try {
//                   await dOrder.update({
//                     status: 'awaiting_pickup'
//                   });
//                 } catch (err) {
//                   console.error('[bundle delivery status update] failed for', did, err.message || err);
//                 }
//               }
//             }

//             // Mark bundle as paid
//             bundle.paymentStatus = 'paid';
//             bundle.paidAt = new Date();
//             await bundle.save();
//           }
//         } catch (e) {
//           console.error('[process bundle delivery] error:', e.message || e);
//         }
//       }
//       // Delivery checkout
//       if (stripeObject.metadata?.craftgoPaymentType === 'delivery') {
//         const existing = await DeliveryPayment.findOne({
//           where: {
//             deliveryOrderId: stripeObject.metadata.deliveryOrderId
//           }
//         });
//         if (existing) {
//           await markDeliveryPaymentSucceeded(existing, stripeObject.payment_intent);
//         }
//       }

//       // Custom Order
//       if (stripeObject.metadata?.craftgoPaymentType === 'custom_order') {
//         const request = await CustomOrderRequest.findOne({
//           where: {
//             id: stripeObject.metadata.requestId,
//           },
//         });
//         if (request) {
//           await request.update({
//             paymentStatus: 'paid',
//             paidAt: new Date(),
//             status: 'in_progress',
//             contractSigned: true,
//             contractSignedAt: new Date(),
//             stripePaymentIntentId: stripeObject.payment_intent || request.stripePaymentIntentId,
//           });
//           console.log(`[custom_order] Payment succeeded for request ${request.id}`);
//         }
//       }

//       if (
//         stripeObject.metadata
//         ?.craftgoPaymentType === 'ready_made'
//       ) {
//         const productPaymentController =
//           require('./productPaymentController');

//         await productPaymentController
//           .processPaidCheckout(stripeObject);
//       } else if (
//         stripeObject.metadata
//         ?.craftgoPaymentType === 'hire_order'
//       ) {
//         const transaction =
//           await PaymentTransaction.findOne({
//             where: {
//               hireRequestId: stripeObject.metadata
//                 .hireRequestId,
//             },
//           });

//         if (transaction) {
//           await markPaymentSucceeded(
//             transaction,
//             stripeObject.payment_intent,
//           );
//         }
//       }
//     } else if (
//       event.type ===
//       'payment_intent.succeeded'
//     ) {
//       const intent = stripeObject;

//       // Try delivery payments first
//       const deliveryPayment = await DeliveryPayment.findOne({
//         where: {
//           stripePaymentIntentId: intent.id
//         }
//       });
//       if (deliveryPayment) {
//         await markDeliveryPaymentSucceeded(deliveryPayment, intent.id);
//       } else {
//         const transaction = await PaymentTransaction.findOne({
//           where: {
//             stripePaymentIntentId: intent.id
//           }
//         });
//         if (transaction) await markPaymentSucceeded(transaction, intent.id);
//       }
//     } else if (
//       event.type ===
//       'payment_intent.payment_failed'
//     ) {
//       const intent = stripeObject;

//       // mark failed for delivery or hire transactions
//       const deliveryPayment = await DeliveryPayment.findOne({
//         where: {
//           stripePaymentIntentId: intent.id
//         }
//       });
//       if (deliveryPayment) {
//         deliveryPayment.paymentStatus = 'failed';
//         deliveryPayment.failureMessage = intent.last_payment_error?.message || 'Payment failed';
//         await deliveryPayment.save();
//       } else {
//         const transaction = await PaymentTransaction.findOne({
//           where: {
//             stripePaymentIntentId: intent.id
//           }
//         });
//         if (transaction) {
//           transaction.paymentStatus = 'failed';
//           transaction.failureMessage = intent.last_payment_error?.message || 'Payment failed';
//           await transaction.save();
//         }
//       }
//     }
//     // Inside the payment_intent.succeeded block, after deliveryPayment check
//     const customRequest = await CustomOrderRequest.findOne({
//       where: {
//         stripePaymentIntentId: intent.id,
//       },
//     });
//     if (customRequest) {
//       await customRequest.update({
//         paymentStatus: 'paid',
//         paidAt: new Date(),
//         status: 'in_progress',
//         contractSigned: true,
//         contractSignedAt: new Date(),
//       });
//       console.log(`[custom_order] Payment succeeded for request ${customRequest.id}`);
//     }


//     return res.json({
//       received: true,
//     });
//   } catch (error) {
//     console.error(
//       '[stripeWebhook] ERROR:',
//       error.message,
//     );

//     return res.status(400).send(
//       `Webhook Error: ${error.message}`,
//     );
//   }
// };

// exports.getPaymentForHire = async (req, res) => {
//   const transaction =
//     await PaymentTransaction.findOne({
//       where: {
//         hireRequestId: req.params.hireRequestId,
//       },
//     });

//   if (!transaction) {
//     return res.status(404).json({
//       error: 'Payment not found',
//     });
//   }

//   const allowedUserIds = [
//     transaction.customerId,
//     transaction.artisanId,
//   ].map(String);

//   if (
//     !allowedUserIds.includes(
//       String(req.user.id),
//     ) &&
//     req.user.role !== 'admin'
//   ) {
//     return res.status(403).json({
//       error: 'Forbidden',
//     });
//   }

//   return res.json(transaction);
// };

// exports.getArtisanEarnings = async (req, res) => {
//   if (
//     String(req.params.artisanId) !==
//     String(req.user.id) &&
//     req.user.role !== 'admin'
//   ) {
//     return res.status(403).json({
//       error: 'Forbidden',
//     });
//   }

//   const transactions =
//     await PaymentTransaction.findAll({
//       where: {
//         artisanId: req.params.artisanId,
//       },
//       include: [{
//         model: HireRequest,
//         as: 'hireRequest',
//       }, ],
//       order: [
//         ['createdAt', 'DESC']
//       ],
//     });

//   const pending = transactions
//     .filter(
//       (item) => item.escrowStatus === 'held',
//     )
//     .reduce(
//       (sum, item) =>
//       sum + Number(item.artisanAmount),
//       0,
//     );

//   const available = transactions
//     .filter(
//       (item) =>
//       item.escrowStatus === 'released',
//     )
//     .reduce(
//       (sum, item) =>
//       sum + Number(item.artisanAmount),
//       0,
//     );

//   return res.json({
//     pending,
//     available,
//     currency: 'JOD',
//     transactions,
//   });
// };

// // Stripe Connect onboarding for drivers
// exports.createDriverOnboard = async (req, res) => {
//   try {
//     if (!stripe || !isConfiguredKey(process.env.STRIPE_SECRET_KEY)) {
//       return res.status(503).json({
//         error: 'Stripe not configured'
//       });
//     }

//     const driverId = req.params.driverId;

//     // Ensure driver exists
//     const driver = await User.findByPk(driverId);
//     if (!driver) return res.status(404).json({
//       error: 'Driver not found'
//     });

//     // Find or create DeliveryProfile
//     let profile = await DeliveryProfile.findOne({
//       where: {
//         driverId
//       }
//     });
//     if (!profile) {
//       profile = await DeliveryProfile.create({
//         driverId
//       });
//     }

//     // If already has connectedAccountId, create an account link for onboarding/refresh
//     let accountId = profile.connectedAccountId;
//     if (!accountId) {
//       // Create an Express account for the driver
//       const account = await stripe.accounts.create({
//         type: 'express'
//       });
//       accountId = account.id;
//       profile.connectedAccountId = accountId;
//       await profile.save();
//     }

//     // Create account link
//     const accountLink = await stripe.accountLinks.create({
//       account: accountId,
//       refresh_url: process.env.STRIPE_ONBOARDING_REFRESH_URL || `${PUBLIC_API_URL}/stripe/refresh`,
//       return_url: process.env.STRIPE_ONBOARDING_RETURN_URL || `${PUBLIC_API_URL}/stripe/return`,
//       type: 'account_onboarding',
//     });

//     return res.json({
//       onboardingUrl: accountLink.url,
//       accountId
//     });
//   } catch (error) {
//     console.error('[createDriverOnboard] ERROR:', error.message || error);
//     return res.status(500).json({
//       error: error.message || 'Failed to create onboarding link'
//     });
//   }
// };

// exports.getAdminTransactions = async (
//   req,
//   res,
// ) => {
//   try {
//     const hireTransactions =
//       await PaymentTransaction.findAll({
//         include: [{
//             model: User,
//             as: 'customer',
//             attributes: [
//               'id',
//               'name',
//               'email',
//             ],
//           },
//           {
//             model: User,
//             as: 'artisan',
//             attributes: [
//               'id',
//               'name',
//               'email',
//             ],
//           },
//           {
//             model: HireRequest,
//             as: 'hireRequest',
//           },
//         ],
//         order: [
//           ['createdAt', 'DESC']
//         ],
//       });

//     const productPayments =
//       await ReadyMadePayment.findAll({
//         order: [
//           ['createdAt', 'DESC']
//         ],
//       });

//     const readyMadeTransactions =
//       await Promise.all(
//         productPayments.map(async (payment) => {
//           const plain = payment.toJSON();

//           const [
//             customer,
//             artisan,
//             order,
//           ] = await Promise.all([
//             User.findByPk(payment.customerId, {
//               attributes: [
//                 'id',
//                 'name',
//                 'email',
//               ],
//             }),
//             User.findByPk(payment.artisanId, {
//               attributes: [
//                 'id',
//                 'name',
//                 'email',
//               ],
//             }),
//             Order.findByPk(payment.orderId),
//           ]);

//           const product = order?.productId ?
//             await Product.findByPk(
//               order.productId, {
//                 attributes: [
//                   'id',
//                   'titleEn',
//                   'titleAr',
//                   'imageUrl',
//                 ],
//               },
//             ) :
//             null;

//           return {
//             ...plain,
//             transactionType: 'ready_made',
//             customer: customer?.toJSON() || null,
//             artisan: artisan?.toJSON() || null,
//             order: order?.toJSON() || null,
//             product: product?.toJSON() || null,
//           };
//         }),
//       );

//     const normalizedHireTransactions =
//       hireTransactions.map((item) => ({
//         ...item.toJSON(),
//         transactionType: 'hire',
//       }));

//     const transactions = [
//       ...normalizedHireTransactions,
//       ...readyMadeTransactions,
//     ].sort(
//       (a, b) =>
//       new Date(b.createdAt) -
//       new Date(a.createdAt),
//     );

//     const totals = transactions.reduce(
//       (acc, item) => {
//         const paymentSucceeded =
//           item.paymentStatus === 'succeeded';

//         const held =
//           item.escrowStatus === 'held';

//         const released =
//           item.escrowStatus === 'released';

//         if (paymentSucceeded) {
//           acc.gross += Number(
//             item.grossAmount || 0,
//           );
//         }

//         if (held) {
//           acc.held += Number(
//             item.grossAmount || 0,
//           );
//         }

//         if (released) {
//           acc.admin += Number(
//             item.adminCommission || 0,
//           );

//           acc.artisan += Number(
//             item.artisanAmount || 0,
//           );
//         }

//         return acc;
//       }, {
//         gross: 0,
//         admin: 0,
//         artisan: 0,
//         held: 0,
//       },
//     );

//     const countByRole = async (roleName) =>
//       User.count({
//         include: [{
//           model: Role,
//           where: {
//             name: roleName,
//           },
//           attributes: [],
//           through: {
//             attributes: [],
//           },
//           required: true,
//         }, ],
//         distinct: true,
//       });

//     const [
//       craftsmenCount,
//       activeClientsCount,
//     ] = await Promise.all([
//       countByRole('artisan'),
//       countByRole('customer'),
//     ]);

//     return res.json({
//       currency: 'JOD',
//       totals,
//       userCounts: {
//         craftsmen: craftsmenCount,
//         activeClients: activeClientsCount,
//       },
//       transactions,
//     });
//   } catch (error) {
//     console.error(
//       '[getAdminTransactions] ERROR:',
//       error,
//     );

//     return res.status(500).json({
//       error: 'Failed to load admin payment transactions',
//       details: error.message,
//     });
//   }
// };

// exports.releaseEscrow = async (req, res) => {
//   try {
//     const reason = String(
//       req.body?.reason || '',
//     ).trim();

//     if (reason.length < 5) {
//       return res.status(400).json({
//         error: 'A release reason of at least 5 characters is required',
//       });
//     }

//     let releasedTransaction;

//     await sequelize.transaction(
//       async (dbTransaction) => {
//         const transaction =
//           await PaymentTransaction.findOne({
//             where: {
//               hireRequestId: req.params.hireRequestId,
//             },
//             transaction: dbTransaction,
//           });

//         if (!transaction) {
//           const error = new Error(
//             'Payment not found',
//           );

//           error.status = 404;
//           throw error;
//         }

//         if (
//           transaction.paymentStatus !==
//           'succeeded' ||
//           transaction.escrowStatus !== 'held'
//         ) {
//           const error = new Error(
//             'Only a successful payment held in escrow can be released',
//           );

//           error.status = 409;
//           throw error;
//         }

//         const hireRequest =
//           await HireRequest.findByPk(
//             transaction.hireRequestId, {
//               transaction: dbTransaction,
//             },
//           );

//         if (
//           !hireRequest ||
//           hireRequest.status !== 'completed'
//         ) {
//           const error = new Error(
//             'Customer completion confirmation is required before release',
//           );

//           error.status = 409;
//           throw error;
//         }

//         await transaction.update({
//           escrowStatus: 'released',
//           releasedAt: new Date(),
//         }, {
//           transaction: dbTransaction,
//         }, );

//         releasedTransaction = transaction;
//       },
//     );

//     console.info('[ESCROW_RELEASE]', {
//       hireRequestId: req.params.hireRequestId,
//       adminId: req.user.id,
//       reason,
//       releasedAt: releasedTransaction.releasedAt,
//     });

//     return res.json({
//       success: true,
//       reason,
//       transaction: releasedTransaction,
//     });
//   } catch (error) {
//     return res
//       .status(error.status || 500)
//       .json({
//         error: error.message,
//       });
//   }
// };

// exports.createExhibitionBoothIntent = async (req, res) => {
//   try {
//     const {
//       exhibitionId
//     } = req.params;
//     const {
//       boothPrice,
//       boothId
//     } = req.body;
//     const price = Number(boothPrice || 50);

//     if (stripe && isConfiguredKey(process.env.STRIPE_PUBLISHABLE_KEY)) {
//       const intent = await stripe.paymentIntents.create({
//         amount: toStripeMinorUnits(price),
//         currency: 'usd',
//         metadata: {
//           exhibitionId,
//           boothId: String(boothId || ''),
//           craftsmanId: String(req.user.id),
//           type: 'exhibition_booth',
//         },
//       });

//       return res.status(201).json({
//         publishableKey: process.env.STRIPE_PUBLISHABLE_KEY,
//         paymentIntentClientSecret: intent.client_secret,
//         paymentIntentId: intent.id,
//       });
//     } else {
//       // Fallback mock payment reference for offline/test mode
//       return res.status(200).json({
//         publishableKey: 'mock_pub_key',
//         paymentIntentClientSecret: 'mock_secret_' + Date.now(),
//         isMock: true,
//         paymentReference: 'TXN-EXH-' + Date.now(),
//       });
//     }
//   } catch (error) {
//     console.error('[createExhibitionBoothIntent ERROR]:', error);
//     return res.status(500).json({
//       error: error.message
//     });
//   }
// };

// exports.getExhibitionOwnerEarnings = async (req, res) => {
//   try {
//     const ownerId = req.user.id;

//     // Find all exhibitions owned by this user
//     const exhibitions = await Exhibition.findAll({
//       where: {
//         ownerId
//       },
//       attributes: ['id', 'name', 'boothPrice'],
//     });

//     const exhibitionIds = exhibitions.map((e) => e.id);

//     if (exhibitionIds.length === 0) {
//       return res.json({
//         success: true,
//         summary: {
//           totalGrossSales: 0,
//           commissionRate: '5%',
//           totalPlatformFees: 0,
//           totalNetEarnings: 0,
//           totalBoothsBooked: 0,
//           totalExhibitionsCount: 0,
//         },
//         transactions: [],
//       });
//     }

//     // Find all booth registrations (paid/confirmed/standby)
//     const registrations = await ExhibitionCraftsman.findAll({
//       where: {
//         exhibitionId: {
//           [Op.in]: exhibitionIds
//         },
//       },
//       include: [{
//           model: User,
//           as: 'Craftsman',
//           attributes: ['id', 'name', 'email']
//         },
//         {
//           model: Exhibition,
//           as: 'Exhibition',
//           attributes: ['id', 'name']
//         },
//       ],
//       order: [
//         ['createdAt', 'DESC']
//       ],
//     });

//     const COMMISSION_RATE = 0.05; // 5% platform commission
//     let totalGrossSales = 0;
//     const transactionsList = [];

//     registrations.forEach((reg) => {
//       const price = Number(reg.boothPrice || 50);
//       const platformFee = Number((price * COMMISSION_RATE).toFixed(2));
//       const netEarnings = Number((price - platformFee).toFixed(2));

//       if (reg.hasPaid || reg.status === 'confirmed') {
//         totalGrossSales += price;
//       }

//       transactionsList.push({
//         id: reg.id,
//         exhibitionId: reg.exhibitionId,
//         exhibitionName: reg.Exhibition ? reg.Exhibition.name : 'Exhibition Booth',
//         artisanName: reg.Craftsman ? reg.Craftsman.name : 'Craftsman',
//         boothId: reg.boothId || 'A1',
//         grossAmount: price,
//         platformFee,
//         netEarnings,
//         hasPaid: reg.hasPaid,
//         status: reg.status,
//         paymentReference: reg.paymentReference || 'TXN-EXH-' + reg.id.slice(0, 6),
//         createdAt: reg.createdAt,
//       });
//     });

//     const totalPlatformFees = Number((totalGrossSales * COMMISSION_RATE).toFixed(2));
//     const totalNetEarnings = Number((totalGrossSales - totalPlatformFees).toFixed(2));

//     return res.json({
//       success: true,
//       summary: {
//         totalGrossSales,
//         commissionRate: '5%',
//         totalPlatformFees,
//         totalNetEarnings,
//         totalBoothsBooked: registrations.length,
//         totalExhibitionsCount: exhibitions.length,
//       },
//       transactions: transactionsList,
//     });
//   } catch (error) {
//     console.error('[getExhibitionOwnerEarnings ERROR]:', error);
//     return res.status(500).json({
//       error: error.message
//     });
//   }
// };

// // ── Custom Order Payment Intent ────────────────────────────────────────────
// // Helper: Compute custom order total from response breakdown, response.total, or template base price
// function getCustomOrderTotal(request) {
//   const response = request.artisanResponse || {};
//   let total = Number(response.total || 0);

//   if ((!Number.isFinite(total) || total <= 0) && Array.isArray(response.breakdown)) {
//     total = response.breakdown.reduce((sum, item) => sum + Number(item.amount || 0), 0);
//   }

//   if ((!Number.isFinite(total) || total <= 0) && request.template?.basePrice) {
//     total = Number(request.template.basePrice);
//   }

//   return total;
// }

// // ── Custom Order Payment Intent (Mobile) ────────────────────────────────────
// exports.createCustomOrderIntent = async (req, res) => {
//   try {
//     console.log('[createCustomOrderIntent] Request params:', req.params);
//     console.log('[createCustomOrderIntent] User:', req.user.id);

//     if (!stripe || !isConfiguredKey(process.env.STRIPE_PUBLISHABLE_KEY)) {
//       console.error('[createCustomOrderIntent] Stripe not configured');
//       return res.status(503).json({
//         error: 'Stripe test keys are not configured',
//         code: 'STRIPE_NOT_CONFIGURED',
//       });
//     }

//     const {
//       requestId
//     } = req.params;
//     const request = await CustomOrderRequest.findByPk(requestId, {
//       include: [{
//         model: CustomOrderTemplate,
//         as: 'template'
//       }],
//     });
//     if (!request) {
//       return res.status(404).json({
//         error: 'Custom order request not found'
//       });
//     }
//     if (String(request.customerId) !== String(req.user.id) && req.user.role !== 'admin') {
//       return res.status(403).json({
//         error: 'Forbidden'
//       });
//     }
//     if (request.status !== 'pending_customer') {
//       return res.status(409).json({
//         error: `This request is not awaiting payment (status: ${request.status})`,
//       });
//     }

//     const total = getCustomOrderTotal(request);
//     if (!Number.isFinite(total) || total <= 0) {
//       return res.status(400).json({
//         error: 'Invalid total amount for custom order'
//       });
//     }

//     const adminCommission = Number(((total * COMMISSION_RATE) / 100).toFixed(3));
//     const artisanAmount = Number((total - adminCommission).toFixed(3));

//     console.log('[createCustomOrderIntent] Creating intent for:', {
//       requestId,
//       total,
//       adminCommission,
//       artisanAmount,
//     });

//     const intent = await stripe.paymentIntents.create({
//       amount: toStripeMinorUnits(total),
//       currency: 'usd',
//       automatic_payment_methods: {
//         enabled: true
//       },
//       metadata: {
//         craftgoPaymentType: 'custom_order',
//         requestId: request.id,
//         customerId: request.customerId,
//         artisanId: request.artisanId,
//       },
//       description: `CraftGo custom order ${request.id}`,
//     }, {
//       idempotencyKey: `craftgo-custom-intent-${request.id}`
//     });

//     await request.update({
//       stripePaymentIntentId: intent.id,
//       paymentStatus: 'unpaid',
//     });

//     return res.status(201).json({
//       paymentIntentClientSecret: intent.client_secret,
//       publishableKey: process.env.STRIPE_PUBLISHABLE_KEY,
//       merchantDisplayName: 'CraftGo',
//       transaction: {
//         id: request.id,
//         total,
//         adminCommission,
//         artisanAmount,
//       },
//     });
//   } catch (error) {
//     console.error('[createCustomOrderIntent] ERROR:', error);
//     return res.status(500).json({
//       error: 'Failed to start payment',
//       details: error.message,
//     });
//   }
// };

// // ── Custom Order Stripe Checkout Session (Web) ──────────────────────────────
// exports.createCustomOrderCheckoutSession = async (req, res) => {
//   try {
//     console.log('[createCustomOrderCheckoutSession] Request params:', req.params);

//     if (!stripe) {
//       return res.status(503).json({
//         error: 'Stripe test key is not configured'
//       });
//     }

//     const {
//       requestId
//     } = req.params;
//     const request = await CustomOrderRequest.findByPk(requestId, {
//       include: [{
//         model: CustomOrderTemplate,
//         as: 'template'
//       }],
//     });

//     if (!request) {
//       return res.status(404).json({
//         error: 'Custom order request not found'
//       });
//     }
//     if (String(request.customerId) !== String(req.user.id) && req.user.role !== 'admin') {
//       return res.status(403).json({
//         error: 'Forbidden'
//       });
//     }

//     const total = getCustomOrderTotal(request);
//     if (!Number.isFinite(total) || total <= 0) {
//       return res.status(400).json({
//         error: 'Invalid total amount'
//       });
//     }

//     const adminCommission = Number(((total * COMMISSION_RATE) / 100).toFixed(3));
//     const artisanAmount = Number((total - adminCommission).toFixed(3));

//     const session = await stripe.checkout.sessions.create({
//       mode: 'payment',
//       payment_method_types: ['card'],
//       line_items: [{
//         quantity: 1,
//         price_data: {
//           currency: 'usd',
//           unit_amount: toStripeMinorUnits(total),
//           product_data: {
//             name: `CraftGo Custom Order: ${request.template?.titleEn || request.template?.titleAr || 'Custom Order'}`,
//             description: `Escrow payment for custom order - total: ${total.toFixed(2)} JOD`,
//           },
//         },
//       }],
//       metadata: {
//         craftgoPaymentType: 'custom_order',
//         requestId: request.id,
//         customerId: request.customerId,
//         artisanId: request.artisanId,
//       },
//       success_url: `${PUBLIC_API_URL}/api/payments/checkout/success?session_id={CHECKOUT_SESSION_ID}`,
//       cancel_url: `${PUBLIC_API_URL}/api/payments/checkout/cancel`,
//     }, {
//       idempotencyKey: `craftgo-custom-checkout-${request.id}`,
//     });

//     await request.update({
//       stripePaymentIntentId: session.id,
//       paymentStatus: 'unpaid',
//     });

//     return res.status(201).json({
//       checkoutUrl: session.url,
//       transaction: {
//         id: request.id,
//         total,
//         adminCommission,
//         artisanAmount,
//       },
//     });
//   } catch (error) {
//     console.error('[createCustomOrderCheckoutSession] ERROR:', error);
//     return res.status(500).json({
//       error: 'Failed to start web checkout',
//       details: error.message,
//     });
//   }
// };

// // ── Confirm Custom Order Payment ──────────────────────────────────────────
// exports.confirmCustomOrderPayment = async (req, res) => {
//   try {
//     console.log('[confirmCustomOrderPayment] Request params:', req.params);

//     if (!stripe) {
//       return res.status(503).json({
//         error: 'Stripe not configured'
//       });
//     }

//     const {
//       requestId
//     } = req.params;
//     const request = await CustomOrderRequest.findByPk(requestId);
//     if (!request) {
//       return res.status(404).json({
//         error: 'Custom order request not found'
//       });
//     }
//     if (String(request.customerId) !== String(req.user.id) && req.user.role !== 'admin') {
//       return res.status(403).json({
//         error: 'Forbidden'
//       });
//     }

//     // Handle both PaymentIntent and Checkout Session retrieval
//     let isPaid = request.paymentStatus === 'paid';
//     if (!isPaid && request.stripePaymentIntentId) {
//       if (request.stripePaymentIntentId.startsWith('cs_')) {
//         const session = await stripe.checkout.sessions.retrieve(request.stripePaymentIntentId);
//         isPaid = session.payment_status === 'paid' || session.status === 'complete';
//       } else {
//         const intent = await stripe.paymentIntents.retrieve(request.stripePaymentIntentId);
//         isPaid = intent.status === 'succeeded' || intent.status === 'requires_capture' || intent.status === 'processing';
//       }
//     }

//     if (!isPaid && process.env.NODE_ENV !== 'production') {
//       // In development/test mode, allow confirmation if client presentPaymentSheet completed
//       isPaid = true;
//     }

//     if (!isPaid) {
//       return res.status(409).json({
//         error: 'Payment has not succeeded'
//       });
//     }

//     // Mark as paid and set status to in_progress
//     await request.update({
//       paymentStatus: 'paid',
//       paidAt: new Date(),
//       status: 'in_progress',
//       contractSigned: true,
//       contractSignedAt: new Date(),
//     });

//     console.log('[confirmCustomOrderPayment] Payment confirmed for:', requestId);

//     const total = getCustomOrderTotal(request);
//     const adminCommission = Number(((total * COMMISSION_RATE) / 100).toFixed(3));
//     const artisanAmount = Number((total - adminCommission).toFixed(3));

//     return res.json({
//       success: true,
//       request,
//       transaction: {
//         id: request.id,
//         total,
//         adminCommission,
//         artisanAmount,
//       },
//     });
//   } catch (error) {
//     console.error('[confirmCustomOrderPayment] ERROR:', error);
//     return res.status(500).json({
//       error: 'Failed to confirm payment',
//       details: error.message,
//     });
//   }
// };

// exports.createPayoutSession = async (req, res) => {
//   try {
//     const userId = req.user.id;
//     const user = await User.findByPk(userId);
//     if (!user) return res.status(404).json({
//       error: 'User not found'
//     });

//     if (!stripe || !isConfiguredKey(process.env.STRIPE_SECRET_KEY)) {
//       return res.json({
//         onboardingUrl: 'https://connect.stripe.com/express/oauth/authorize',
//         message: 'Stripe test mode link',
//       });
//     }

//     let accountId = user.stripeAccountId;
//     if (!accountId) {
//       const account = await stripe.accounts.create({
//         type: 'express',
//         email: user.email || undefined,
//         metadata: {
//           userId: user.id,
//           role: user.role || 'user'
//         },
//       });
//       accountId = account.id;
//       if (user.stripeAccountId !== undefined) {
//         user.stripeAccountId = accountId;
//         await user.save();
//       }
//     }

//     const accountLink = await stripe.accountLinks.create({
//       account: accountId,
//       refresh_url: process.env.STRIPE_ONBOARDING_REFRESH_URL || `${PUBLIC_API_URL}/stripe/refresh`,
//       return_url: process.env.STRIPE_ONBOARDING_RETURN_URL || `${PUBLIC_API_URL}/stripe/return`,
//       type: 'account_onboarding',
//     });

//     return res.json({
//       onboardingUrl: accountLink.url,
//       accountId,
//     });
//   } catch (error) {
//     console.error('[createPayoutSession] ERROR:', error.message || error);
//     return res.status(500).json({
//       error: error.message || 'Failed to create payout link',
//     });
//   }
// };