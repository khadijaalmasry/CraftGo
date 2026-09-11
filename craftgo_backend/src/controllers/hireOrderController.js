const HireRequest = require('../models/HireRequest');
const User = require('../models/User');
const PaymentTransaction = require('../models/PaymentTransaction');
// ======================================================
// POST /api/hire-orders/requests
// Customer creates on-site hire request
// ======================================================

exports.createRequest = async (req, res) => {
  try {
    const customerId = req.user?.id;

    if (!customerId) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
      });
    }

    const {
      artisanId,
      jobDescription,
      latitude,
      longitude,
      address,
      extraDetails,
      startDate,
      endDate,
      dailyHours,
      requiredMaterials,
      requiredTools,
    } = req.body;

    if (!artisanId) {
      return res.status(400).json({
        success: false,
        error: 'artisanId is required',
      });
    }

    if (!jobDescription || jobDescription.trim().length === 0) {
      return res.status(400).json({
        success: false,
        error: 'jobDescription is required',
      });
    }

    if (latitude == null || longitude == null) {
      return res.status(400).json({
        success: false,
        error: 'Location is required',
      });
    }

    if (!startDate || !endDate) {
      return res.status(400).json({
        success: false,
        error: 'Start date and end date are required',
      });
    }

    const artisan = await User.findByPk(artisanId);

    if (!artisan) {
      return res.status(404).json({
        success: false,
        error: 'Artisan not found',
      });
    }

    const request = await HireRequest.create({
      customerId,
      artisanId,
      jobDescription: jobDescription.trim(),
      latitude,
      longitude,
      address: address || null,
      extraDetails: extraDetails || null,
      startDate,
      endDate,
      dailyHours: dailyHours ?? 8,
      requiredMaterials: Array.isArray(requiredMaterials)
        ? requiredMaterials
        : [],
      requiredTools: Array.isArray(requiredTools)
        ? requiredTools
        : [],
      status: 'pending_artisan',
      progressPercent: 0,
    });

    return res.status(201).json({
      success: true,
      message: 'Hire request submitted successfully',
      request,
    });
  } catch (error) {
    console.error('[createHireRequest] ERROR:', error);

    return res.status(500).json({
      success: false,
      error: 'Failed to submit hire request',
      details: error.message,
    });
  }
};

// ======================================================
// GET /api/hire-orders/requests/artisan/:artisanId
// ======================================================

exports.getRequestsByArtisan = async (req, res) => {
  try {
    const { artisanId } = req.params;

    const requests = await HireRequest.findAll({
      where: { artisanId },
      include: [
        {
          model: User,
          as: 'customer',
          attributes: ['id', 'name', 'email', 'city'],
        },
      ],
      order: [['createdAt', 'DESC']],
    });

    const visibleRequests = await Promise.all(
      requests.map(async (request) => {
        // الطلبات الجديدة والمفاوضات تظهر بشكل طبيعي.
        if (
          request.status === 'pending_artisan' ||
          request.status === 'pending_customer' ||
          request.status === 'cancelled'
        ) {
          return request;
        }

        // الطلب الجاري أو المكتمل لا يظهر للحرفي إلا إذا تم دفعه فعلًا.
        if (
          request.status === 'in_progress' ||
          request.status === 'completed'
        ) {
          const payment = await PaymentTransaction.findOne({
            where: {
              hireRequestId: request.id,
              paymentStatus: 'succeeded',
            },
          });

          return payment ? request : null;
        }

        return request;
      }),
    );

    return res.json(
      visibleRequests.filter((request) => request !== null),
    );
  } catch (error) {
    console.error('[getHireRequestsByArtisan] ERROR:', error);

    return res.status(500).json({
      success: false,
      error: 'Failed to fetch artisan hire requests',
      details: error.message,
    });
  }
};

// ======================================================
// GET /api/hire-orders/requests/customer/:customerId
// ======================================================

exports.getRequestsByCustomer = async (req, res) => {
  try {
    const { customerId } = req.params;

    const requests = await HireRequest.findAll({
      where: { customerId },
      include: [
        {
          model: User,
          as: 'artisan',
          attributes: ['id', 'name', 'email', 'city'],
        },
      ],
      order: [['createdAt', 'DESC']],
    });

    return res.json(requests);
  } catch (error) {
    console.error('[getHireRequestsByCustomer] ERROR:', error);

    return res.status(500).json({
      success: false,
      error: 'Failed to fetch customer hire requests',
      details: error.message,
    });
  }
};

// ======================================================
// POST /api/hire-orders/requests/:id/respond
// Artisan sends proposal
// ======================================================

exports.artisanRespond = async (req, res) => {
  try {
    const { id } = req.params;

    const {
      dailyRate,
      materialCost,
      schedule,
      notesAr,
      notesEn,
      totalPrice,
    } = req.body;

    const request = await HireRequest.findByPk(id);

    if (!request) {
      return res.status(404).json({
        success: false,
        error: 'Hire request not found',
      });
    }

    if (
      String(request.artisanId) !== String(req.user.id) &&
      req.user.role !== 'admin'
    ) {
      return res.status(403).json({
        success: false,
        error: 'Forbidden',
      });
    }

    request.artisanResponse = {
      dailyRate: dailyRate ?? 0,
      materialCost: materialCost ?? 0,
      schedule: Array.isArray(schedule) ? schedule : [],
      notesAr: notesAr || null,
      notesEn: notesEn || null,
    };

    request.totalPrice = totalPrice ?? null;
    request.status = 'pending_customer';

    await request.save();

    return res.json({
      success: true,
      message: 'Hire proposal sent successfully',
      request,
    });
  } catch (error) {
    console.error('[artisanRespondHire] ERROR:', error);

    return res.status(500).json({
      success: false,
      error: 'Failed to respond to hire request',
      details: error.message,
    });
  }
};

// ======================================================
// PATCH /api/hire-orders/requests/:id/status
// ======================================================

exports.updateStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status, progressStage, progressPercent } = req.body;

    const request = await HireRequest.findByPk(id);

    if (!request) {
      return res.status(404).json({
        success: false,
        error: 'Hire request not found',
      });
    }

    const actorId = String(req.user?.id || '');
    const isCustomer = actorId === String(request.customerId);
    const isArtisan = actorId === String(request.artisanId);
    const isAdmin = req.user?.role === 'admin';
    if (!isCustomer && !isArtisan && !isAdmin) {
      return res.status(403).json({ success: false, error: 'Forbidden' });
    }

    if (status === 'in_progress' && !isAdmin) {
      return res.status(409).json({
        success: false,
        error: 'Hire work can start only after a successful escrow payment',
      });
    }

    const allowedStatuses = [
      'pending_artisan',
      'pending_customer',
      'in_progress',
      'completed',
      'cancelled',
    ];

    if (status && !allowedStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid status',
      });
    }

    if (status) {
      request.status = status;
    }

    if (progressStage != null) {
      request.progressStage = progressStage;
    }

    if (progressPercent != null) {
      const percent = Number(progressPercent);

      if (percent < 0 || percent > 100) {
        return res.status(400).json({
          success: false,
          error: 'progressPercent must be between 0 and 100',
        });
      }

      request.progressPercent = percent;
    }

    if (status === 'completed') {
      request.progressPercent = 100;
      request.completedAt = new Date();
    }

    await request.save();

    // Customer completion releases the internal escrow ledger to the artisan.
    if (status === 'completed' && (isCustomer || isAdmin)) {
      const PaymentTransaction = require('../models/PaymentTransaction');
      const payment = await PaymentTransaction.findOne({ where: { hireRequestId: id } });
      if (payment?.escrowStatus === 'held') {
        payment.escrowStatus = 'released';
        payment.releasedAt = new Date();
        await payment.save();
      }
    }

    return res.json({
      success: true,
      message: 'Hire request updated successfully',
      request,
    });
  } catch (error) {
    console.error('[updateHireStatus] ERROR:', error);

    return res.status(500).json({
      success: false,
      error: 'Failed to update hire request',
      details: error.message,
    });
  }
};
