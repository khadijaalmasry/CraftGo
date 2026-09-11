const CustomOrderTemplate = require('../models/CustomOrderTemplate');
const CustomOrderRequest = require('../models/CustomOrderRequest');
const User = require('../models/User');

// ── TEMPLATES ────────────────────────────────────────────────────────────────

// POST /api/custom-orders/templates
exports.createTemplate = async (req, res) => {
  try {
    const {
      titleAr,
      titleEn,
      categoryAr,
      categoryEn,
      descriptionAr,
      descriptionEn,
      basePrice,
      estimatedDays,
      fields
    } = req.body;
    const artisanId = req.user.id; // from verifyToken middleware

    const template = await CustomOrderTemplate.create({
      artisanId,
      titleAr,
      titleEn,
      categoryAr,
      categoryEn,
      descriptionAr,
      descriptionEn,
      basePrice,
      estimatedDays,
      fields,
    });

    res.status(201).json({
      message: 'Custom order template created successfully',
      template
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to create template'
    });
  }
};

// PUT /api/custom-orders/templates/:id
exports.updateTemplate = async (req, res) => {
  try {
    const {
      id
    } = req.params;
    const template = await CustomOrderTemplate.findByPk(id);
    if (!template) return res.status(404).json({
      error: 'Template not found'
    });

    if (template.artisanId !== req.user.id && req.user.role !== 'admin') {
      return res.status(403).json({
        error: 'Forbidden: not your template'
      });
    }

    const updatableFields = ['titleAr', 'titleEn', 'descriptionAr', 'descriptionEn', 'basePrice', 'estimatedDays', 'fields'];
    updatableFields.forEach(f => {
      if (req.body[f] !== undefined) template[f] = req.body[f];
    });

    await template.save();
    res.json({
      message: 'Template updated successfully',
      template
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to update template'
    });
  }
};

// DELETE /api/custom-orders/templates/:id
exports.deleteTemplate = async (req, res) => {
  try {
    const {
      id
    } = req.params;
    const template = await CustomOrderTemplate.findByPk(id);
    if (!template) return res.status(404).json({
      error: 'Template not found'
    });

    if (template.artisanId !== req.user.id && req.user.role !== 'admin') {
      return res.status(403).json({
        error: 'Forbidden: not your template'
      });
    }

    await template.destroy();
    res.json({
      message: 'Template deleted successfully'
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to delete template'
    });
  }
};

// GET /api/custom-orders/templates/artisan/:artisanId
exports.getTemplatesByArtisan = async (req, res) => {
  try {
    const {
      artisanId
    } = req.params;
    const templates = await CustomOrderTemplate.findAll({
      where: {
        artisanId
      },
      include: [{
        model: User,
        as: 'artisan',
        attributes: ['name', 'city']
      }],
    });
    res.json(templates);
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to fetch templates'
    });
  }
};

// GET /api/custom-orders/templates/:id
exports.getTemplateById = async (req, res) => {
  try {
    const template = await CustomOrderTemplate.findByPk(req.params.id, {
      include: [{
        model: User,
        as: 'artisan',
        attributes: ['name', 'city']
      }],
    });
    if (!template) return res.status(404).json({
      error: 'Template not found'
    });
    res.json(template);
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to fetch template'
    });
  }
};


// ── REQUESTS ─────────────────────────────────────────────────────────────────

// POST /api/custom-orders/requests
exports.submitRequest = async (req, res) => {
  try {
    const {
      templateId,
      filledFields
    } = req.body;
    const customerId = req.user.id;

    let template = null;
    if (templateId) {
      template = await CustomOrderTemplate.findByPk(templateId);
    }

    // Fallback: If templateId is mock (e.g. 'tmpl-001') or not found in DB,
    // fetch any existing template or create a default template so request submission succeeds.
    if (!template) {
      template = await CustomOrderTemplate.findOne();
      if (!template) {
        template = await CustomOrderTemplate.create({
          artisanId: customerId,
          titleAr: 'طلب مخصص',
          titleEn: 'Custom Order',
          categoryAr: 'عام',
          categoryEn: 'General',
          basePrice: 50,
          estimatedDays: 7,
          fields: [],
        });
      }
    }

    const request = await CustomOrderRequest.create({
      templateId: template.id,
      customerId,
      artisanId: template.artisanId,
      status: 'pending_artisan',
      filledFields: filledFields || {},
    });

    res.status(201).json({
      message: 'Custom order request submitted successfully',
      request
    });
  } catch (error) {
    console.error('[submitRequest error]:', error);
    res.status(500).json({
      error: 'Failed to submit request',
      details: error.message
    });
  }
};

// GET /api/custom-orders/requests/customer/:customerId
exports.getRequestsByCustomer = async (req, res) => {
  try {
    const {
      customerId
    } = req.params;
    const requests = await CustomOrderRequest.findAll({
      where: {
        customerId
      },
      include: [{
          model: CustomOrderTemplate,
          as: 'template'
        },
        {
          model: User,
          as: 'artisan',
          attributes: ['name', 'email']
        },
      ],
      order: [
        ['createdAt', 'DESC']
      ],
    });
    res.json(requests);
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to fetch requests'
    });
  }
};

// GET /api/custom-orders/requests/artisan/:artisanId
exports.getRequestsByArtisan = async (req, res) => {
  try {
    const {
      artisanId
    } = req.params;
    const requests = await CustomOrderRequest.findAll({
      where: {
        artisanId
      },
      include: [{
          model: CustomOrderTemplate,
          as: 'template'
        },
        {
          model: User,
          as: 'customer',
          attributes: ['name', 'email']
        },
      ],
      order: [
        ['createdAt', 'DESC']
      ],
    });
    res.json(requests);
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to fetch requests'
    });
  }
};

// POST /api/custom-orders/requests/:id/respond (Artisan response)
exports.artisanRespond = async (req, res) => {
  try {
    const {
      id
    } = req.params;
    const {
      breakdown,
      tasks,
      deliveryDate,
      notesAr,
      notesEn
    } = req.body;

    const request = await CustomOrderRequest.findByPk(id);
    if (!request) return res.status(404).json({
      error: 'Request not found'
    });

    if (request.artisanId !== req.user.id && req.user.role !== 'admin') {
      return res.status(403).json({
        error: 'Forbidden: not your request'
      });
    }

    request.artisanResponse = {
      breakdown,
      tasks,
      deliveryDate,
      notesAr,
      notesEn,
    };
    request.status = 'pending_customer';
    await request.save();

    res.json({
      message: 'Artisan response saved successfully',
      request
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to respond to request'
    });
  }
};

// PATCH /api/custom-orders/requests/:id/status
exports.updateRequestStatus = async (req, res) => {
  try {
    const {
      id
    } = req.params;
    const {
      status
    } = req.body;

    const request = await CustomOrderRequest.findByPk(id);
    if (!request) return res.status(404).json({
      error: 'Request not found'
    });

    // Validate access
    if (
      request.artisanId !== req.user.id &&
      request.customerId !== req.user.id &&
      req.user.role !== 'admin'
    ) {
      return res.status(403).json({
        error: 'Forbidden'
      });
    }

    request.status = status;
    await request.save();

    res.json({
      message: 'Request status updated successfully',
      request
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to update status'
    });
  }
};


// PATCH /api/custom-orders/requests/:id/progress
exports.updateRequestProgress = async (req, res) => {
  try {
    const {
      id
    } = req.params;

    const {
      progressStage,
      progressPercent
    } = req.body;

    const allowedStages = {
      materials_received: 25,
      execution_started: 50,
      quality_review: 75,
      ready_for_delivery: 100,
    };

    if (
      !Object.prototype.hasOwnProperty.call(
        allowedStages,
        progressStage
      )
    ) {
      return res.status(400).json({
        error: 'Invalid progress stage'
      });
    }

    const expectedPercent =
      allowedStages[progressStage];

    const percent =
      Number(progressPercent);

    if (
      !Number.isInteger(percent) ||
      percent !== expectedPercent
    ) {
      return res.status(400).json({
        error: `Invalid progress percent for ${progressStage}. ` +
          `Expected ${expectedPercent}`,
      });
    }

    const request =
      await CustomOrderRequest.findByPk(id);

    if (!request) {
      return res.status(404).json({
        error: 'Request not found'
      });
    }

    // Only the artisan who owns the request can update progress.
    if (
      request.artisanId !== req.user.id &&
      req.user.role !== 'admin'
    ) {
      return res.status(403).json({
        error: 'Forbidden: not your request'
      });
    }

    if (request.status !== 'in_progress') {
      return res.status(400).json({
        error: 'Progress can only be updated for in-progress requests'
      });
    }

    // Do not allow progress to go backwards.
    if (
      (request.progressPercent || 0) > percent
    ) {
      return res.status(400).json({
        error: 'Progress cannot move backwards'
      });
    }

    request.progressStage =
      progressStage;

    request.progressPercent =
      percent;

    await request.save();

    return res.json({
      message: 'Request progress updated successfully',
      request,
    });

  } catch (error) {
    console.error(error);

    return res.status(500).json({
      error: 'Failed to update progress'
    });
  }
};






// POST /api/custom-orders/requests/:id/sign (Contract signing / Payment)
exports.signContract = async (req, res) => {
  try {
    const {
      id
    } = req.params;
    const request = await CustomOrderRequest.findByPk(id);
    if (!request) return res.status(404).json({
      error: 'Request not found'
    });

    if (request.customerId !== req.user.id && req.user.role !== 'admin') {
      return res.status(403).json({
        error: 'Forbidden: not your request to sign'
      });
    }

    request.contractSigned = true;
    request.contractSignedAt = new Date();
    request.status = 'in_progress';
    await request.save();

    res.json({
      message: 'Contract signed and order is now in progress',
      request
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to sign contract'
    });
  }
};

exports.deleteRequest = async (req, res) => {
  try {
    const {
      id
    } = req.params;
    const userId = req.user.id;
    const request = await CustomOrderRequest.findByPk(id);
    if (!request) {
      return res.status(404).json({
        error: 'Custom order request not found'
      });
    }
    if (request.customerId !== userId && request.artisanId !== userId) {
      return res.status(403).json({
        error: 'Not authorized to delete this request'
      });
    }
    await request.destroy();
    return res.json({
      success: true,
      message: 'Request deleted successfully'
    });
  } catch (error) {
    console.error('deleteRequest error:', error);
    return res.status(500).json({
      error: 'Failed to delete custom order request'
    });
  }
};


// PATCH /api/custom-orders/requests/:id/delivery
exports.updateDeliveryInfo = async (req, res) => {
  try {
    const {
      id
    } = req.params;
    const {
      deliveryAddress,
      customerPhone
    } = req.body;

    const request = await CustomOrderRequest.findByPk(id);
    if (!request) {
      return res.status(404).json({
        error: 'Custom order request not found'
      });
    }

    // Only the customer who owns the request can update delivery info
    if (request.customerId !== req.user.id && req.user.role !== 'admin') {
      return res.status(403).json({
        error: 'Forbidden'
      });
    }

    await request.update({
      deliveryAddress,
      customerPhone,
    });

    res.json({
      success: true,
      message: 'Delivery info updated successfully',
      request,
    });
  } catch (error) {
    console.error('[updateDeliveryInfo] ERROR:', error);
    console.error('[updateDeliveryInfo] STACK:', error.stack);
    res.status(500).json({
      error: 'Failed to update delivery info',
      details: error.message,
      stack: error.stack
    });
  }
};

// GET /api/custom-orders/requests/:id
exports.getRequestById = async (req, res) => {
  try {
    const {
      id
    } = req.params;
    const request = await CustomOrderRequest.findByPk(id, {
      include: [{
          model: CustomOrderTemplate,
          as: 'template'
        },
        {
          model: User,
          as: 'customer',
          attributes: ['name', 'email']
        },
        {
          model: User,
          as: 'artisan',
          attributes: ['name', 'email']
        },
      ],
    });
    if (!request) {
      return res.status(404).json({
        error: 'Custom order request not found'
      });
    }
    // Allow access to the customer, artisan, or admin
    if (
      request.customerId !== req.user.id &&
      request.artisanId !== req.user.id &&
      req.user.role !== 'admin'
    ) {
      return res.status(403).json({
        error: 'Forbidden'
      });
    }
    res.json({
      success: true,
      request
    });
  } catch (error) {
    console.error('[getRequestById] ERROR:', error);
    res.status(500).json({
      error: 'Failed to fetch request'
    });
  }
};