const ProductOrder = require('../models/Order');
const ReadyMadePayment = require('../models/ReadyMadePayment');
const DeliveryOrder = require('../models/DeliveryOrder');
const DeliveryPayment = require('../models/DeliveryPayment');
const DeliveryProfile = require('../models/DeliveryProfile');
const PaymentTransaction = require('../models/PaymentTransaction');

/**
 * Unified Escrow Release & Share Distribution Helper
 * Releases held funds to Artisan, Delivery Driver, and Platform when delivery/order completes.
 */
exports.releaseEscrowAndDistributeShares = async ({ orderId, deliveryOrderId, hireRequestId }) => {
  let productReleased = false;
  let deliveryReleased = false;
  let hireReleased = false;

  try {
    // ── 1. Handle Product Order & Artisan Share ─────────────────────────────
    let pOrderId = orderId;
    if (!pOrderId && deliveryOrderId) {
      const dOrd = await DeliveryOrder.findByPk(deliveryOrderId);
      if (dOrd) pOrderId = dOrd.productOrderId;
    }

    if (pOrderId) {
      const pOrder = await ProductOrder.findByPk(pOrderId);
      if (pOrder) {
        await pOrder.update({
          status: 'completed',
          escrowStatus: 'released',
          escrowReleasedAt: pOrder.escrowReleasedAt || new Date(),
        });

        const rmp = await ReadyMadePayment.findOne({ where: { orderId: pOrderId } });
        if (rmp && rmp.escrowStatus === 'held') {
          await rmp.update({
            escrowStatus: 'released',
            releasedAt: new Date(),
          });
          productReleased = true;
        }
      }
    }

    // ── 2. Handle Delivery Order & Driver Share ─────────────────────────────
    let dOrderId = deliveryOrderId;
    if (!dOrderId && pOrderId) {
      const dOrd = await DeliveryOrder.findOne({ where: { productOrderId: pOrderId } });
      if (dOrd) dOrderId = dOrd.id;
    }

    if (dOrderId) {
      const dOrder = await DeliveryOrder.findByPk(dOrderId);
      if (dOrder) {
        await dOrder.update({
          status: 'delivered',
          deliveredAt: dOrder.deliveredAt || new Date(),
        });

        // ── Complete all related product orders ──
        let allPIds = [];
        if (dOrder.productOrderId) allPIds.push(dOrder.productOrderId);
        if (dOrder.relatedOrderIds) {
          try {
            const parsed = JSON.parse(dOrder.relatedOrderIds);
            if (Array.isArray(parsed)) allPIds.push(...parsed);
          } catch (_) {}
        }
        allPIds = Array.from(new Set(allPIds.filter(Boolean)));

        for (const targetPId of allPIds) {
          try {
            const pOrd = await ProductOrder.findByPk(targetPId);
            if (pOrd) {
              await pOrd.update({
                status: 'completed',
                paymentStatus: 'paid',
                escrowStatus: 'released',
                escrowReleasedAt: pOrd.escrowReleasedAt || new Date(),
              });
              const rmp = await ReadyMadePayment.findOne({ where: { orderId: targetPId } });
              if (rmp && rmp.escrowStatus === 'held') {
                await rmp.update({
                  escrowStatus: 'released',
                  releasedAt: new Date(),
                });
                productReleased = true;
              }
            }
          } catch (pErr) {
            console.error(`Failed completing product order ${targetPId}:`, pErr.message || pErr);
          }
        }

        // ── Complete all related custom orders ──
        let allCIds = [];
        if (dOrder.customOrderId) allCIds.push(dOrder.customOrderId);
        if (dOrder.relatedCustomOrderIds) {
          try {
            const parsedC = JSON.parse(dOrder.relatedCustomOrderIds);
            if (Array.isArray(parsedC)) allCIds.push(...parsedC);
          } catch (_) {}
        }
        allCIds = Array.from(new Set(allCIds.filter(Boolean)));

        if (allCIds.length > 0) {
          const CustomOrderRequest = require('../models/CustomOrderRequest');
          for (const targetCId of allCIds) {
            try {
              const cReq = await CustomOrderRequest.findByPk(targetCId);
              if (cReq) {
                await cReq.update({ status: 'completed' });
              }
            } catch (cErr) {
              console.error(`Failed completing custom order ${targetCId}:`, cErr.message || cErr);
            }
          }
        }

        const delPayment = await DeliveryPayment.findOne({ where: { deliveryOrderId: dOrderId } });
        let driverEarning = Number(dOrder.earningAmount || 0);

        if (delPayment) {
          if (delPayment.driverAmount && Number(delPayment.driverAmount) > 0) {
            driverEarning = Number(delPayment.driverAmount);
          }
          if (delPayment.escrowStatus === 'held') {
            await delPayment.update({
              escrowStatus: 'released',
              releasedAt: new Date(),
            });
            deliveryReleased = true;
          }
        }

        // Update Delivery Driver Profile Wallet / Earnings
        if (dOrder.driverId && driverEarning > 0) {
          const profile = await DeliveryProfile.findOne({ where: { driverId: dOrder.driverId } });
          if (profile) {
            await profile.update({
              totalEarnings: Number((parseFloat(profile.totalEarnings || 0) + driverEarning).toFixed(2)),
              todayEarnings: Number((parseFloat(profile.todayEarnings || 0) + driverEarning).toFixed(2)),
              totalDeliveries: (profile.totalDeliveries || 0) + 1,
              todayDeliveries: (profile.todayDeliveries || 0) + 1,
            });
          }
        }
      }
    }

    // ── 3. Handle Hire Request / Custom Order Payment ────────────────────────
    if (hireRequestId) {
      const pt = await PaymentTransaction.findOne({ where: { hireRequestId } });
      if (pt && pt.escrowStatus === 'held') {
        await pt.update({
          escrowStatus: 'released',
          releasedAt: new Date(),
        });
        hireReleased = true;
      }
    }
  } catch (err) {
    console.error('[releaseEscrowAndDistributeShares Error]:', err.message || err);
  }

  return { productReleased, deliveryReleased, hireReleased };
};
