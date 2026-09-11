const Stripe = require('stripe');
const {
  Op
} = require('sequelize');

const Order = require('../models/Order');
const Product = require('../models/Product');
const ReadyMadePayment = require('../models/ReadyMadePayment');
const Notification = require('../models/Notification');
const ProductOffer = require('../models/ProductOffer');
const DeliveryOrder = require('../models/DeliveryOrder');
const PaymentBundle = require('../models/PaymentBundle');
const User = require('../models/User');

const stripe = process.env.STRIPE_SECRET_KEY ?
  new Stripe(process.env.STRIPE_SECRET_KEY) :
  null;

const sequelize = ReadyMadePayment.sequelize;

const COMMISSION_RATE = 10;

const JOD_PER_USD = Number(
  process.env.JOD_PER_USD || 3.1122,
);

const PUBLIC_API_URL = (
  process.env.PUBLIC_API_URL ||
  'http://localhost:5000'
).replace(/\/$/, '');

const usdCentsFromJod = (value) =>
  Math.max(
    50,
    Math.round(
      (Number(value) / JOD_PER_USD) * 100,
    ),
  );

function money(value) {
  return Number(
    Number(value || 0).toFixed(3),
  );
}

async function notifyArtisan(
  order,
  gross,
  dbTransaction,
) {
  await Notification.create({
    userId: order.craftsmanId,
    type: 'paid_product_order',

    titleEn: 'New paid product order',
    titleAr: 'طلب منتج مدفوع جديد',

    bodyEn: `A paid order worth ${money(gross)} JOD ` +
      'is waiting for your response.',

    bodyAr: `يوجد طلب مدفوع بقيمة ${money(gross)} ` +
      'دينار بانتظار ردك.',

    metadata: {
      orderId: order.id,
    },
  }, {
    transaction: dbTransaction,
  }, );
}

async function processPaidCheckout(session) {
  if (
    !session ||
    session.payment_status !== 'paid'
  ) {
    throw new Error(
      'Payment was not completed',
    );
  }

  const payments =
    await ReadyMadePayment.findAll({
      where: {
        stripeCheckoutSessionId: session.id,
      },
    });

  if (!payments.length) {
    throw new Error(
      'CraftGo product transaction was not found',
    );
  }

  for (const payment of payments) {
    // Prevents processing the same Stripe session twice.
    if (
      payment.paymentStatus === 'succeeded'
    ) {
      continue;
    }

    await sequelize.transaction(
      async (dbTransaction) => {
        await payment.update({
          stripePaymentIntentId: session.payment_intent ||
            payment.stripePaymentIntentId,

          paymentStatus: 'succeeded',
          escrowStatus: 'held',
          paidAt: new Date(),
        }, {
          transaction: dbTransaction,
        }, );

        const order = await Order.findByPk(
          payment.orderId, {
            transaction: dbTransaction,
          },
        );

        if (!order) {
          throw new Error(
            `Order ${payment.orderId} was not found`,
          );
        }

        await order.update({
          status: 'pending',
          paymentStatus: 'paid',
          escrowStatus: 'held',
          paidAt: new Date(),
        }, {
          transaction: dbTransaction,
        }, );

        if (order.offerId) {
          await ProductOffer.update({
            status: 'paid',
          }, {
            where: {
              id: order.offerId,
            },
            transaction: dbTransaction,
          }, );
        }

        await notifyArtisan(
          order,
          payment.grossAmount,
          dbTransaction,
        );
      },
    );
  }

  return payments;
}

exports.processPaidCheckout =
  processPaidCheckout;

exports.refundOrderPayment = async (
  orderId,
  reason = 'Order cancelled',
) => {
  if (!stripe) {
    throw new Error(
      'Stripe is not configured',
    );
  }

  const payment =
    await ReadyMadePayment.findOne({
      where: {
        orderId,
      },
    });

  if (!payment) {
    throw new Error(
      'Payment transaction was not found',
    );
  }

  if (
    payment.paymentStatus === 'refunded'
  ) {
    return payment;
  }

  if (
    payment.paymentStatus !== 'succeeded' ||
    payment.escrowStatus !== 'held'
  ) {
    throw new Error(
      'Only a successful payment held in escrow can be refunded',
    );
  }

  if (!payment.stripePaymentIntentId) {
    throw new Error(
      'Stripe payment reference is missing',
    );
  }

  await stripe.refunds.create({
    payment_intent: payment.stripePaymentIntentId,

    metadata: {
      craftgoPaymentType: 'ready_made_refund',

      orderId: String(orderId),
      reason,
    },
  }, {
    idempotencyKey: `craftgo-product-refund-${orderId}`,
  }, );

  await sequelize.transaction(
    async (dbTransaction) => {
      await payment.update({
        paymentStatus: 'refunded',
        escrowStatus: 'refunded',
      }, {
        transaction: dbTransaction,
      }, );

      await Order.update({
        paymentStatus: 'refunded',
        escrowStatus: 'refunded',
      }, {
        where: {
          id: orderId,
        },
        transaction: dbTransaction,
      }, );
    },
  );

  return payment;
};

exports.createCheckout = async (req, res) => {
  try {
    if (!stripe) {
      return res.status(503).json({
        error: 'Stripe test key is not configured',
      });
    }

    const orderIds = [
      ...new Set(
        (req.body.orderIds || []).map(String),
      ),
    ].sort();

    if (!orderIds.length) {
      return res.status(400).json({
        error: 'orderIds are required',
      });
    }

    const { deliveryAddress, customerPhone } = req.body;

    const orders = await Order.findAll({
      where: {
        id: {
          [Op.in]: orderIds,
        },
        customerId: req.user.id,
        status: {
          [Op.in]: ['pending_customer', 'awaiting_payment', 'pending_artisan'],
        },
      },
      include: [{
        model: Product,
      }, ],
    });

    if (orders.length !== orderIds.length) {
      return res.status(409).json({
        error: 'One or more orders cannot be paid',
      });
    }

    const session =
      await stripe.checkout.sessions.create({
        mode: 'payment',

        payment_method_types: ['card'],

        line_items: orders.map(
          (order) => ({
            quantity: 1,

            price_data: {
              currency: 'usd',

              unit_amount: usdCentsFromJod(
                order.totalAmount,
              ),

              product_data: {
                name: order.Product?.titleEn ||
                  order.Product?.titleAr ||
                  'CraftGo handmade product',

                description: 'CraftGo sandbox escrow • ' +
                  `${money(order.totalAmount)} JOD`,
              },
            },
          }),
        ),

        metadata: {
          craftgoPaymentType: 'ready_made',
          orderIds: JSON.stringify(orderIds),
          customerId: String(req.user.id),
        },

        success_url: `${PUBLIC_API_URL}` +
          `/api/payments/products/success` +
          `?session_id={CHECKOUT_SESSION_ID}`,

        cancel_url: `${PUBLIC_API_URL}` +
          `/api/payments/checkout/cancel`,
      }, {
        idempotencyKey: `craftgo-products-` +
          `${req.user.id}-` +
          `${orderIds.join('-')}`,
      }, );

    await sequelize.transaction(
      async (dbTransaction) => {
        for (const order of orders) {
          const gross = money(
            order.totalAmount,
          );

          const admin = money(
            (gross * COMMISSION_RATE) / 100,
          );

          const [payment, created] =
          await ReadyMadePayment.findOrCreate({
            where: {
              orderId: order.id,
            },

            transaction: dbTransaction,

            defaults: {
              orderId: order.id,
              customerId: order.customerId,
              artisanId: order.craftsmanId,

              currency: 'JOD',

              grossAmount: gross,

              adminCommissionRate: COMMISSION_RATE,

              adminCommission: admin,

              artisanAmount: money(gross - admin),

              stripeCheckoutSessionId: session.id,

              paymentStatus: 'created',
              escrowStatus: 'unpaid',
            },
          });

          if (deliveryAddress || customerPhone) {
            await order.update({
              shippingAddress: deliveryAddress || order.shippingAddress,
              customerPhone: customerPhone || order.customerPhone,
            }, {
              transaction: dbTransaction,
            });
          }

          if (!created) {
            if (
              payment.paymentStatus ===
              'succeeded'
            ) {
              throw new Error(
                'Order is already paid',
              );
            }

            await payment.update({
              grossAmount: gross,

              adminCommission: admin,

              artisanAmount: money(gross - admin),

              stripeCheckoutSessionId: session.id,

              paymentStatus: 'created',
              escrowStatus: 'unpaid',
            }, {
              transaction: dbTransaction,
            }, );
          }

          await order.update({
            stripeCheckoutSessionId: session.id,
            paymentStatus: 'processing',

            paymentStatus: 'processing',
          }, {
            transaction: dbTransaction,
          }, );
        }
        // Create delivery orders grouped by craftsman for this bundle
        const DELIVERY_FLAT_FEE = Number(process.env.DELIVERY_FLAT_FEE_JOD || 15);
        const craftsmanGroups = {};
        for (const order of orders) {
          const key = String(order.craftsmanId);
          craftsmanGroups[key] = craftsmanGroups[key] || [];
          craftsmanGroups[key].push(order);
        }

        const deliveryOrderIds = [];
        let bundleGross = 0;

        for (const craftsmanId of Object.keys(craftsmanGroups)) {
          const group = craftsmanGroups[craftsmanId];
          // Compute delivery fee per craftsman (flat fee)
          const fee = DELIVERY_FLAT_FEE;

          // Use the first order in the group as representative for addresses
          const rep = group[0];
          const craftsmanUser = await User.findByPk(craftsmanId, {
            transaction: dbTransaction
          });
          const pickup = (craftsmanUser && craftsmanUser.city) ? craftsmanUser.city : 'Pickup';

          const deliveryOrder = await DeliveryOrder.create({
            orderCode: `DEL-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
            customerId: req.user.id,
            craftsmanId,
            productId: rep.productId,
            orderType: 'ready_made',
            pickupAddress: pickup,
            dropoffAddress: rep.shippingAddress || '',
            earningAmount: fee,
            distanceKm: 1.0,
          }, {
            transaction: dbTransaction
          });

          deliveryOrderIds.push(deliveryOrder.id);
          bundleGross += Number(group.reduce((s, o) => s + Number(o.totalAmount || 0), 0));
          bundleGross += fee;
        }

        // Persist PaymentBundle for this session
        await PaymentBundle.create({
          customerId: req.user.id,
          orderIds,
          deliveryOrderIds,
          currency: 'JOD',
          grossAmount: bundleGross,
          stripeCheckoutSessionId: session.id,
          paymentStatus: 'created',
        }, {
          transaction: dbTransaction
        });
      },
    );

    // After persisting bundle, attach bundleId into session metadata for webhook processing
    try {
      const bundle = await PaymentBundle.findOne({
        where: {
          stripeCheckoutSessionId: session.id
        }
      });
      if (bundle) {
        await stripe.checkout.sessions.update(session.id, {
          metadata: {
            craftgoPaymentType: 'ready_made',
            orderIds: JSON.stringify(orderIds),
            customerId: String(req.user.id),
            bundleId: bundle.id,
          },
        });
      }
    } catch (e) {
      console.error('[attach bundle to session] error:', e.message || e);
    }

    return res.status(201).json({
      checkoutUrl: session.url,
      sessionId: session.id,
    });
  } catch (error) {
    console.error(
      '[product checkout]',
      error,
    );

    return res.status(500).json({
      error: 'Failed to start product checkout',
      details: error.message,
    });
  }
};

exports.checkoutSuccess = async (
  req,
  res,
) => {
  try {
    if (
      !stripe ||
      !req.query.session_id
    ) {
      throw new Error(
        'Missing checkout session',
      );
    }

    const session =
      await stripe.checkout.sessions.retrieve(
        req.query.session_id,
      );

    await processPaidCheckout(session);

    return res.type('html').send(`
      <!doctype html>

      <html>
        <head>
          <meta
            name="viewport"
            content="width=device-width,initial-scale=1"
          >

          <title>Payment successful</title>
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
                color:#4caf60;
                font-size:54px;
              "
            >
              &#10003;
            </div>

            <h1 style="color:#4caf60">
              Payment successful
            </h1>

            <p
              style="
                color:#b8c1cf;
                line-height:1.6;
              "
            >
              Your test payment is safely
              recorded as held in CraftGo
              Escrow.
            </p>

            <p
              style="
                color:#b8c1cf;
                line-height:1.6;
              "
            >
              You may close this tab and
              return to My Orders in CraftGo.
            </p>

            <button
              onclick="window.close()"
              style="
                margin-top:12px;
                padding:12px 22px;
                border:0;
                border-radius:10px;
                background:#e2aa12;
                color:#111;
                font-weight:bold;
                cursor:pointer;
              "
            >
              Close & return to CraftGo
            </button>
          </main>
        </body>
      </html>
    `);
  } catch (error) {
    console.error(
      '[product checkout success]',
      error,
    );

    return res
      .status(400)
      .type('html')
      .send(`
        <!doctype html>

        <html>
          <head>
            <meta
              name="viewport"
              content="width=device-width,initial-scale=1"
            >

            <title>
              Payment verification failed
            </title>
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
              <h1 style="color:#ff5252">
                Payment verification failed
              </h1>

              <p
                style="
                  color:#b8c1cf;
                  line-height:1.6;
                "
              >
                ${error.message}
              </p>
            </main>
          </body>
        </html>
      `);
  }
};

exports.getStatus = async (req, res) => {
  try {
    const orders = await Order.findAll({
      where: {
        stripeCheckoutSessionId: req.params.sessionId,

        customerId: req.user.id,
      },
    });

    return res.json({
      paid: orders.length > 0 &&
        orders.every(
          (order) =>
          order.paymentStatus === 'paid',
        ),

      orders,
    });
  } catch (error) {
    console.error(
      '[get product payment status]',
      error,
    );

    return res.status(500).json({
      error: 'Failed to check product payment status',

      details: error.message,
    });
  }
};