const { Op } = require('sequelize');
const Stripe = require('stripe');
const OrderDispute = require('../models/OrderDispute');
const User = require('../models/User');
const Order = require('../models/Order');
const CustomOrderRequest = require('../models/CustomOrderRequest');
const HireRequest = require('../models/HireRequest');
const DeliveryOrder = require('../models/DeliveryOrder');
const PaymentTransaction = require('../models/PaymentTransaction');
const DeliveryPayment = require('../models/DeliveryPayment');
const ReadyMadePayment = require('../models/ReadyMadePayment');
const ArtisanProfile = require('../models/ArtisanProfile');
const Product = require('../models/Product');

const isConfiguredKey = (v) => v && !v.includes('REPLACE_ME');
const stripe = isConfiguredKey(process.env.STRIPE_SECRET_KEY) ?
  new Stripe(process.env.STRIPE_SECRET_KEY) :
  null;

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/disputes
// Submit a dispute for any completed order. Available to customers or craftsmen.
// ─────────────────────────────────────────────────────────────────────────────
exports.submitDispute = async (req, res) => {
  try {
    const reporterId = req.user?.id;
    // IMPORTANT: Do NOT use req.user.role to decide which party is reporter/reported.
    // Multi-role users (e.g. both 'customer' and 'artisan') may have the wrong primary
    // role in their JWT token. Instead, compare reporterId against actual order party
    // IDs to determine who the "other party" is.

    if (!reporterId) {
      return res.status(403).json({
        error: 'Authentication required to file a dispute'
      });
    }

    // Allow any authenticated user (customer, artisan, or multi-role) to file disputes
    const reporterRoleClaim = req.user?.role;
    const reporterRoles = req.user?.roles || (reporterRoleClaim ? [reporterRoleClaim] : []);
    if (!reporterRoles.some(r => ['customer', 'artisan'].includes(r))) {
      return res.status(403).json({
        error: 'Only customers or craftsmen can file disputes'
      });
    }

    const {
      orderId,
      customOrderRequestId,
      hireRequestId,
      deliveryOrderId,
      issueCategory,
      description,
      photoUrl,
      requestedAction,
    } = req.body;

    if (!description || description.trim().length < 10) {
      return res.status(400).json({
        error: 'Description must be at least 10 characters'
      });
    }

    if (!issueCategory) {
      return res.status(400).json({
        error: 'issueCategory is required'
      });
    }

    // Validate issueCategory
    const validCategories = ['damaged_in_transit', 'wrong_item', 'quality_issue', 'customer_unresponsive', 'delivery_fault', 'other'];
    if (!validCategories.includes(issueCategory)) {
      return res.status(400).json({
        error: `Invalid issueCategory. Must be one of: ${validCategories.join(', ')}`
      });
    }

    // ── Helper: given two party IDs from an order, pick the one that is NOT the reporter.
    // This avoids relying on the JWT role claim, which can be wrong for multi-role users.
    const resolveOtherParty = (partyA, partyB) => {
      if (partyA && String(partyA) !== String(reporterId)) return partyA;
      if (partyB && String(partyB) !== String(reporterId)) return partyB;
      return null; // reporter is neither known party (should not happen)
    };

    // Resolve IDs flexibly
    let resolvedOrderId = orderId || null;
    let resolvedCustomOrderId = customOrderRequestId || null;
    let resolvedHireRequestId = hireRequestId || null;
    let resolvedDeliveryOrderId = deliveryOrderId || null;
    let reportedUserId = null;
    let driverId = null;

    // Check customOrderRequestId if provided
    if (resolvedCustomOrderId) {
      const req_ = await CustomOrderRequest.findByPk(resolvedCustomOrderId);
      if (req_) {
        reportedUserId = resolveOtherParty(req_.artisanId, req_.customerId);
      }
    }

    // Check hireRequestId if provided and reportedUserId not set
    if (!reportedUserId && resolvedHireRequestId) {
      const hire = await HireRequest.findByPk(resolvedHireRequestId);
      if (hire) {
        reportedUserId = resolveOtherParty(hire.artisanId, hire.customerId);
      }
    }

    // Check resolvedOrderId if provided and reportedUserId not set
    if (!reportedUserId && resolvedOrderId) {
      // 1. Try ready-made Order first
      const order = await Order.findByPk(resolvedOrderId);
      if (order) {
        reportedUserId = resolveOtherParty(order.craftsmanId, order.customerId);
      } else {
        // 2. Fallback: try CustomOrderRequest
        const req_ = await CustomOrderRequest.findByPk(resolvedOrderId);
        if (req_) {
          resolvedCustomOrderId = resolvedOrderId;
          resolvedOrderId = null;
          reportedUserId = resolveOtherParty(req_.artisanId, req_.customerId);
        } else {
          // 3. Fallback: try HireRequest
          const hire = await HireRequest.findByPk(resolvedOrderId);
          if (hire) {
            resolvedHireRequestId = resolvedOrderId;
            resolvedOrderId = null;
            reportedUserId = resolveOtherParty(hire.artisanId, hire.customerId);
          }
        }
      }
    }

    if (!reportedUserId) {
      return res.status(404).json({
        error: 'Order or Request not found'
      });
    }

    // Auto-link DeliveryOrder if not explicitly passed
    if (!resolvedDeliveryOrderId) {
      const searchId = resolvedOrderId || resolvedCustomOrderId || resolvedHireRequestId;
      if (searchId) {
        const del = await DeliveryOrder.findOne({
          where: {
            [Op.or]: [
              { productOrderId: searchId },
              { id: searchId }
            ]
          }
        });
        if (del) resolvedDeliveryOrderId = del.id;
      }
    }

    // Attach driver if delivery order exists
    if (resolvedDeliveryOrderId) {
      const delOrder = await DeliveryOrder.findByPk(resolvedDeliveryOrderId);
      if (delOrder) driverId = delOrder.driverId || null;
    }

    if (!reportedUserId) {
      return res.status(404).json({
        error: 'Order or Request not found'
      });
    }

    // Determine the reporter's actual role in THIS order (not the JWT claim, which can be wrong
    // for multi-role users). We already know reportedUserId is the other party; so the reporter
    // is acting in the opposite role relative to the order parties.
    // We figure it out by checking: if reportedUserId is the artisanId -> reporter is the customer.
    // We can derive this by fetching the order again, but it's simpler to infer from what we know:
    // "the other party" (reportedUserId) is either artisanId or customerId.
    // If reportedUserId matches the artisan side -> reporter is acting as customer.
    let actualReporterRole = reporterRoleClaim; // fallback
    try {
      if (resolvedCustomOrderId) {
        const r = await CustomOrderRequest.findByPk(resolvedCustomOrderId);
        if (r) actualReporterRole = String(r.customerId) === String(reporterId) ? 'customer' : 'artisan';
      } else if (resolvedHireRequestId) {
        const h = await HireRequest.findByPk(resolvedHireRequestId);
        if (h) actualReporterRole = String(h.customerId) === String(reporterId) ? 'customer' : 'artisan';
      } else if (resolvedOrderId) {
        const o = await Order.findByPk(resolvedOrderId);
        if (o) actualReporterRole = String(o.customerId) === String(reporterId) ? 'customer' : 'artisan';
      }
    } catch (_) {}

    const dispute = await OrderDispute.create({
      orderId: resolvedOrderId,
      customOrderRequestId: resolvedCustomOrderId,
      hireRequestId: resolvedHireRequestId,
      deliveryOrderId: resolvedDeliveryOrderId,
      reporterId,
      reporterRole: actualReporterRole,
      reportedUserId,
      driverId,
      issueCategory,
      description: description.trim(),
      photoUrl: photoUrl || null,
      requestedAction: requestedAction || 'none',
      adminStatus: 'pending',
    });

    return res.status(201).json({
      success: true,
      message: 'Dispute submitted successfully. The admin will review it shortly.',
      dispute,
    });
  } catch (error) {
    console.error('[submitDispute] ERROR:', error);
    return res.status(500).json({
      error: 'Failed to submit dispute',
      details: error.message
    });
  }
};

// Helper to safely get linked payment details across all 3 order types
async function getPaymentForDispute(d) {
  try {
    if (d.customOrderRequestId) {
      const cor = await CustomOrderRequest.findByPk(d.customOrderRequestId);
      const rmp = await ReadyMadePayment.findOne({ where: { orderId: d.customOrderRequestId } });
      return {
        amount: cor?.artisanResponse?.totalPrice || cor?.filledFields?.price || rmp?.grossAmount || 0,
        stripePaymentIntentId: cor?.stripePaymentIntentId || rmp?.stripePaymentIntentId,
        paymentStatus: cor?.paymentStatus || rmp?.paymentStatus || 'succeeded',
        escrowStatus: cor?.status === 'completed' ? 'released' : (rmp?.escrowStatus || 'held'),
      };
    } else if (d.orderId) {
      const rmp = await ReadyMadePayment.findOne({ where: { orderId: d.orderId } });
      const ord = await Order.findByPk(d.orderId);
      return {
        amount: rmp?.grossAmount || ord?.totalAmount || 0,
        stripePaymentIntentId: rmp?.stripePaymentIntentId || ord?.stripePaymentIntentId,
        paymentStatus: rmp?.paymentStatus || 'succeeded',
        escrowStatus: rmp?.escrowStatus || ord?.escrowStatus || 'held',
      };
    } else if (d.hireRequestId) {
      const pt = await PaymentTransaction.findOne({ where: { hireRequestId: d.hireRequestId } });
      return pt ? pt.toJSON() : null;
    }
  } catch (e) {
    console.error('getPaymentForDispute error:', e.message || e);
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/admin/disputes
// Returns all disputes for admin review with full linked order & payment data.
// ─────────────────────────────────────────────────────────────────────────────
exports.getAdminDisputes = async (req, res) => {
  try {
    const {
      status,
      limit = 50,
      offset = 0
    } = req.query;
    const where = status ? {
      adminStatus: status
    } : {};

    const disputes = await OrderDispute.findAll({
      where,
      order: [
        ['createdAt', 'DESC']
      ],
      limit: parseInt(limit),
      offset: parseInt(offset),
      include: [{
          model: User,
          as: 'reporter',
          attributes: ['id', 'name', 'email', 'phone']
        },
        {
          model: User,
          as: 'reportedUser',
          attributes: ['id', 'name', 'email', 'phone']
        },
      ],
    });

    // For each dispute, attach payment data and order contract
    const enriched = await Promise.all(disputes.map(async (d) => {
      const obj = d.toJSON();

      // Fetch linked order contract
      if (d.customOrderRequestId) {
        obj.contract = await CustomOrderRequest.findByPk(d.customOrderRequestId);
      } else if (d.orderId) {
        obj.contract = await Order.findByPk(d.orderId);
      } else if (d.hireRequestId) {
        obj.contract = await HireRequest.findByPk(d.hireRequestId);
      }

      // Fetch linked payment safely
      obj.payment = await getPaymentForDispute(d);

      // Fetch delivery order if present
      if (d.deliveryOrderId) {
        obj.deliveryOrder = await DeliveryOrder.findByPk(d.deliveryOrderId, {
          include: [{
            model: User,
            as: 'driver',
            attributes: ['id', 'name', 'email', 'phone']
          }],
        });
        obj.deliveryPayment = await DeliveryPayment.findOne({
          where: {
            deliveryOrderId: d.deliveryOrderId
          }
        });
      }

      return obj;
    }));

    const total = await OrderDispute.count({
      where
    });
    return res.json({
      disputes: enriched,
      total,
      limit: parseInt(limit),
      offset: parseInt(offset)
    });
  } catch (error) {
    console.error('[getAdminDisputes] ERROR:', error);
    return res.status(500).json({
      error: 'Failed to fetch disputes',
      details: error.message
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/admin/disputes/:id
// Get single dispute full details.
// ─────────────────────────────────────────────────────────────────────────────
exports.getDisputeById = async (req, res) => {
  try {
    const dispute = await OrderDispute.findByPk(req.params.id, {
      include: [{
          model: User,
          as: 'reporter',
          attributes: ['id', 'name', 'email', 'phone']
        },
        {
          model: User,
          as: 'reportedUser',
          attributes: ['id', 'name', 'email', 'phone']
        },
      ],
    });
    if (!dispute) return res.status(404).json({
      error: 'Dispute not found'
    });

    const obj = dispute.toJSON();

    if (dispute.customOrderRequestId) {
      obj.contract = await CustomOrderRequest.findByPk(dispute.customOrderRequestId);
    } else if (dispute.orderId) {
      obj.contract = await Order.findByPk(dispute.orderId);
    } else if (dispute.hireRequestId) {
      obj.contract = await HireRequest.findByPk(dispute.hireRequestId);
    }

    obj.payment = await getPaymentForDispute(dispute);

    if (dispute.deliveryOrderId) {
      obj.deliveryOrder = await DeliveryOrder.findByPk(dispute.deliveryOrderId, {
        include: [{
          model: User,
          as: 'driver',
          attributes: ['id', 'name', 'email', 'phone']
        }],
      });
      obj.deliveryPayment = await DeliveryPayment.findOne({
        where: {
          deliveryOrderId: dispute.deliveryOrderId
        }
      });
    }

    return res.json(obj);
  } catch (error) {
    console.error('[getDisputeById] ERROR:', error);
    return res.status(500).json({
      error: 'Failed to fetch dispute',
      details: error.message
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/admin/disputes/:id/resolve
// Admin resolves a dispute with one of: customer_refund | artisan_release | driver_penalty | no_action
// ─────────────────────────────────────────────────────────────────────────────
exports.resolveDispute = async (req, res) => {
  try {
    const {
      resolutionType,
      adminNotes
    } = req.body;

    const validResolutions = ['customer_refund', 'artisan_release', 'driver_penalty', 'no_action'];
    if (!validResolutions.includes(resolutionType)) {
      return res.status(400).json({
        error: `Invalid resolutionType. Must be one of: ${validResolutions.join(', ')}`
      });
    }

    const dispute = await OrderDispute.findByPk(req.params.id);
    if (!dispute) return res.status(404).json({
      error: 'Dispute not found'
    });

    if (['resolved_refunded', 'resolved_released', 'dismissed'].includes(dispute.adminStatus)) {
      return res.status(409).json({
        error: 'This dispute is already resolved'
      });
    }

    let stripeRefundId = null;
    let adminStatus = 'dismissed';

    // ── A. Refund the customer ───────────────────────────────────────────────
    if (resolutionType === 'customer_refund') {
      // Locate the Stripe payment intent
      let paymentIntentId = null;

      if (dispute.customOrderRequestId) {
        const cor = await CustomOrderRequest.findByPk(dispute.customOrderRequestId);
        paymentIntentId = cor?.stripePaymentIntentId;
        if (!paymentIntentId) {
          const rmp = await ReadyMadePayment.findOne({ where: { orderId: dispute.customOrderRequestId } });
          paymentIntentId = rmp?.stripePaymentIntentId;
        }
      } else if (dispute.orderId) {
        const rmp = await ReadyMadePayment.findOne({ where: { orderId: dispute.orderId } });
        paymentIntentId = rmp?.stripePaymentIntentId;
        if (!paymentIntentId) {
          const ord = await Order.findByPk(dispute.orderId);
          paymentIntentId = ord?.stripePaymentIntentId;
        }
      } else if (dispute.hireRequestId) {
        const pt = await PaymentTransaction.findOne({ where: { hireRequestId: dispute.hireRequestId } });
        paymentIntentId = pt?.stripePaymentIntentId;
      }

      if (paymentIntentId && stripe && isConfiguredKey(process.env.STRIPE_SECRET_KEY)) {
        try {
          const intent = await stripe.paymentIntents.retrieve(paymentIntentId);
          const chargeId = intent.latest_charge;
          if (chargeId) {
            const refund = await stripe.refunds.create({ charge: chargeId });
            stripeRefundId = refund.id;
            console.info('[DISPUTE_REFUND] Stripe refund created:', refund.id);
          }
        } catch (stripeErr) {
          console.error('[DISPUTE_REFUND] Stripe error:', stripeErr.message);
        }
      } else {
        console.warn('[DISPUTE_REFUND] Processing internal refund without Stripe reversal or intent not found');
      }

      // Update payment status across appropriate tables
      if (dispute.customOrderRequestId) {
        await CustomOrderRequest.update(
          { paymentStatus: 'refunded' },
          { where: { id: dispute.customOrderRequestId } }
        );
        await ReadyMadePayment.update(
          { paymentStatus: 'refunded', escrowStatus: 'refunded' },
          { where: { orderId: dispute.customOrderRequestId } }
        );
      } else if (dispute.orderId) {
        await Order.update(
          { status: 'cancelled', escrowStatus: 'refunded' },
          { where: { id: dispute.orderId } }
        );
        await ReadyMadePayment.update(
          { paymentStatus: 'refunded', escrowStatus: 'refunded' },
          { where: { orderId: dispute.orderId } }
        );
      } else if (dispute.hireRequestId) {
        await PaymentTransaction.update(
          { paymentStatus: 'refunded', escrowStatus: 'refunded' },
          { where: { hireRequestId: dispute.hireRequestId } }
        );
      }
      adminStatus = 'resolved_refunded';
    }

    // ── B. Release escrow to artisan ─────────────────────────────────────────
    if (resolutionType === 'artisan_release') {
      if (dispute.customOrderRequestId) {
        await ReadyMadePayment.update(
          { escrowStatus: 'released', releasedAt: new Date() },
          { where: { orderId: dispute.customOrderRequestId } }
        );
      } else if (dispute.orderId) {
        await ReadyMadePayment.update(
          { escrowStatus: 'released', releasedAt: new Date() },
          { where: { orderId: dispute.orderId } }
        );
      } else if (dispute.hireRequestId) {
        await PaymentTransaction.update(
          { escrowStatus: 'released', releasedAt: new Date() },
          { where: { hireRequestId: dispute.hireRequestId } }
        );
      }
      adminStatus = 'resolved_released';
    }

    // ── C. Driver penalty (release artisan, penalty driver) ──────────────────
    if (resolutionType === 'driver_penalty') {
      if (dispute.deliveryOrderId) {
        await DeliveryPayment.update(
          { escrowStatus: 'disputed', releasedAt: new Date() },
          { where: { deliveryOrderId: dispute.deliveryOrderId } }
        );
      }
      adminStatus = 'resolved_released';
    }

    // ── D. No action ─────────────────────────────────────────────────────────
    if (resolutionType === 'no_action') {
      adminStatus = 'dismissed';
    }

    await dispute.update({
      adminStatus,
      resolutionType,
      adminNotes: adminNotes || null,
      updatedAt: new Date(),
    });

    return res.json({
      success: true,
      message: `Dispute resolved: ${resolutionType}`,
      dispute,
      stripeRefundId,
    });
  } catch (error) {
    console.error('[resolveDispute] ERROR:', error);
    return res.status(500).json({
      error: 'Failed to resolve dispute',
      details: error.message
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/disputes/my
// Get disputes filed by the current user (customer or craftsman)
// ─────────────────────────────────────────────────────────────────────────────
exports.getMyDisputes = async (req, res) => {
  try {
    const disputes = await OrderDispute.findAll({
      where: {
        reporterId: req.user.id
      },
      order: [
        ['createdAt', 'DESC']
      ],
    });
    return res.json({
      disputes
    });
  } catch (error) {
    console.error('[getMyDisputes] ERROR:', error);
    return res.status(500).json({
      error: 'Failed to fetch your disputes',
      details: error.message
    });
  }
};