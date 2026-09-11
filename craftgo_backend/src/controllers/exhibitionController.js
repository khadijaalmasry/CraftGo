const Exhibition = require('../models/Exhibition');
const User = require('../models/User');
const ExhibitionCraftsman = require('../models/ExhibitionCraftsman');
const ExhibitionDayAttendance = require('../models/ExhibitionDayAttendance');
const Notification = require('../models/Notification');
const UserInteraction = require('../models/UserInteraction');
const {
  Op
} = require('sequelize');
// ── POST /api/exhibitions ──
exports.createExhibition = async (req, res) => {
  try {
    const {
      ownerId,
      name,
      nameEn,
      description,
      descriptionEn,
      location,
      locationEn,
      eventType,
      eventTheme,
      targetAudience,
      priceRange,
      isPublic,
      country,
      city,
      street,
      building,
      extraDetails,
      latitude,
      longitude,
      manualLocation,
      startDate,
      endDate,
      verified,
      featured,
      selectedDates,
      crafts,
      boothRows,
      boothColumns,
      boothPrice,
      venueType,
      permitDocumentUrl,
      hasPermit,
      hasBusinessLicense,
      permitNumber,
      issuerName,
      issuerPhone,
      issueDate,
      expiryDate,
      capacity,
      categoryCapacities,
      status,
      boothLayout,
      gradient,
      imageUrl,
    } = req.body;

    const exhibition = await Exhibition.create({
      ownerId,
      name,
      nameEn,
      description,
      descriptionEn,
      location,
      locationEn,
      eventType,
      eventTheme,
      targetAudience,
      priceRange,
      isPublic,
      country,
      city,
      street,
      building,
      extraDetails,
      latitude,
      longitude,
      manualLocation,
      startDate,
      endDate,
      selectedDates,
      crafts,
      boothRows,
      boothColumns,
      boothPrice,
      venueType,
      permitDocumentUrl: permitDocumentUrl || null,
      hasPermit,
      hasBusinessLicense,
      permitNumber,
      issuerName,
      issuerPhone,
      issueDate,
      expiryDate,
      verified: req.body.verified !== undefined ? req.body.verified : false,
      featured: req.body.featured !== undefined ? req.body.featured : false,
      capacity,
      categoryCapacities: categoryCapacities || {},
      status: status || 'upcoming',
      boothLayout: boothLayout || [],
      gradient: gradient || ['#1976D2', '#009688'],
      imageUrl: imageUrl || null,
    });

    res.status(201).json({
      message: 'Exhibition created successfully',
      exhibition
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Server error creating exhibition'
    });
  }
};

function resolveExhibitionStatus(e) {
  if (!e) return e;
  const item = typeof e.toJSON === 'function' ? e.toJSON() : { ...e };

  item.interestedCount = Array.isArray(item.UserInteractions) ? item.UserInteractions.length : 0;
  item.interested = item.interestedCount;

  // If status is cancelled, rejected, draft, or pending, do NOT dynamically change its status.
  if (['cancelled', 'rejected', 'draft', 'pending'].includes(item.status) || item.verified === false || item.verified === 0) {
    return item;
  }

  const now = new Date();
  const todayStr = now.toISOString().split('T')[0];

  const startDateStr = item.startDate ? new Date(item.startDate).toISOString().split('T')[0] : null;
  const endDateStr = item.endDate ? new Date(item.endDate).toISOString().split('T')[0] : null;

  if (endDateStr && todayStr > endDateStr) {
    item.status = 'completed';
  } else if (startDateStr && endDateStr && todayStr >= startDateStr && todayStr <= endDateStr) {
    item.status = 'active';
  } else if (startDateStr && todayStr < startDateStr) {
    item.status = 'upcoming';
  }

  return item;
}

// ── GET /api/exhibitions ──
exports.getAllExhibitions = async (req, res) => {
  try {
    const exhibitions = await Exhibition.findAll({
      where: {
        isPublic: true,
        verified: true,
        status: {
          [Op.notIn]: ['rejected', 'cancelled', 'draft', 'pending']
        }
      },
      include: [
        {
          model: User,
          as: 'Owner',
          attributes: ['id', 'name', 'email', 'city'],
        },
        {
          model: ExhibitionCraftsman,
          as: 'ExhibitionCraftsmen',
          include: [{
            model: User,
            as: 'Craftsman',
            attributes: ['id', 'name', 'city']
          }],
        },
        {
          model: UserInteraction,
          where: { interactionType: 'exhibition' },
          required: false,
        },
      ],
      order: [
        ['startDate', 'ASC']
      ],
    });
    res.json(exhibitions.map(resolveExhibitionStatus));
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Server error fetching exhibitions'
    });
  }
};

// GET /api/admin/exhibitions
exports.getAdminExhibitions = async (req, res) => {
  try {
    const exhibitions = await Exhibition.findAll({
      include: [{
          model: User,
          as: 'Owner',
          attributes: ['id', 'name', 'email', 'city'],
        },
        {
          model: ExhibitionCraftsman,
          as: 'ExhibitionCraftsmen',
        },
      ],
      order: [
        ['createdAt', 'DESC']
      ],
    });
    res.json(exhibitions.map(resolveExhibitionStatus));
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to fetch admin exhibitions'
    });
  }
};

// GET /api/admin/exhibitions/analytics
exports.getAdminAnalytics = async (req, res) => {
  try {
    const total = await Exhibition.count();
    const pending = await Exhibition.count({
      where: {
        [Op.or]: [{
          verified: false
        }, {
          status: 'pending'
        }]
      }
    });
    const active = await Exhibition.count({
      where: {
        status: 'active'
      }
    });

    const totalCapacityResult = await Exhibition.sum('capacity');
    const totalCapacity = totalCapacityResult || 0;
    const totalArtisans = await ExhibitionCraftsman.count({
      where: {
        status: 'confirmed'
      }
    });

    const occupancy = totalCapacity > 0 ? totalArtisans / totalCapacity : 0;

    res.json({
      total,
      pending,
      active,
      occupancy,
      totalCapacity,
      totalArtisans,
      categoryCount: {},
      cityCount: {},
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to fetch analytics'
    });
  }
};

// PUT /api/admin/exhibitions/:id/approve
exports.approveExhibition = async (req, res) => {
  try {
    const exhibition = await Exhibition.findByPk(req.params.id);
    if (!exhibition) return res.status(404).json({
      error: 'Exhibition not found'
    });

    await exhibition.update({
      verified: true,
      status: 'active'
    });
    res.json({
      message: 'Exhibition approved',
      exhibition
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to approve exhibition'
    });
  }
};

// PUT /api/admin/exhibitions/:id/reject
exports.rejectExhibition = async (req, res) => {
  try {
    const {
      reason
    } = req.body;
    const exhibition = await Exhibition.findByPk(req.params.id);
    if (!exhibition) return res.status(404).json({
      error: 'Exhibition not found'
    });

    await exhibition.update({
      verified: false,
      status: 'rejected',
      rejectionReason: reason
    });
    res.json({
      message: 'Exhibition rejected',
      exhibition
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to reject exhibition'
    });
  }
};

// PUT /api/admin/exhibitions/:id/status
exports.adminOverrideStatus = async (req, res) => {
  try {
    const {
      status
    } = req.body;
    const exhibition = await Exhibition.findByPk(req.params.id);
    if (!exhibition) return res.status(404).json({
      error: 'Exhibition not found'
    });

    await exhibition.update({
      status
    });
    res.json({
      message: 'Status updated',
      exhibition
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to update status'
    });
  }
};

// PUT /api/admin/exhibitions/:id/featured
exports.toggleFeatured = async (req, res) => {
  try {
    const {
      featured
    } = req.body;
    const exhibition = await Exhibition.findByPk(req.params.id);
    if (!exhibition) return res.status(404).json({
      error: 'Exhibition not found'
    });

    await exhibition.update({
      featured
    });
    res.json({
      message: 'Featured status updated',
      exhibition
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to update featured status'
    });
  }
};

// ── GET /api/exhibitions/:exhibitionId ──
exports.getExhibitionById = async (req, res) => {
  try {
    const exhibition = await Exhibition.findByPk(req.params.exhibitionId, {
      include: [{
          model: User,
          as: 'Owner',
          attributes: ['id', 'name', 'email', 'city']
        },
        {
          model: ExhibitionCraftsman,
          as: 'ExhibitionCraftsmen',
          include: [{
            model: User,
            as: 'Craftsman',
            attributes: ['id', 'name', 'city']
          }],
        },
        {
          model: UserInteraction,
          where: { interactionType: 'exhibition' },
          required: false,
        },
      ],
    });
    if (!exhibition) return res.status(404).json({
      error: 'Exhibition not found'
    });

    // Compute isFull dynamically from confirmed count vs capacity
    const confirmedCount = (exhibition.ExhibitionCraftsmen || [])
      .filter(ec => ec.status === 'confirmed').length;
    const capacity = exhibition.capacity || 0;
    const computedIsFull = capacity > 0 && confirmedCount >= capacity;

    // Sync DB if out of date (fire-and-forget)
    if (computedIsFull !== exhibition.isFull) {
      exhibition.update({ isFull: computedIsFull }).catch(() => {});
    }

    const result = exhibition.toJSON();
    result.isFull = computedIsFull;
    result.confirmedCount = confirmedCount;
    result.interestedCount = Array.isArray(result.UserInteractions) ? result.UserInteractions.length : 0;
    result.interested = result.interestedCount;

    res.json(result);
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to fetch exhibition details'
    });
  }
};

// ── GET /api/exhibitions/craftsman/:craftsmanId ──
exports.getCraftsmanRegistrations = async (req, res) => {
  try {
    const {
      craftsmanId
    } = req.params;
    const registrations = await ExhibitionCraftsman.findAll({
      where: {
        craftsmanId
      },
      include: [{
        model: Exhibition,
        as: 'Exhibition',
        include: [{
          model: User,
          as: 'Owner',
          attributes: ['id', 'name', 'email'],
        }],
      }],
      order: [
        ['createdAt', 'DESC']
      ],
    });
    res.json(registrations);
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to fetch craftsman registrations'
    });
  }
};

// ── GET /api/exhibitions/owner/:ownerId ──
exports.getOwnerExhibitions = async (req, res) => {
  try {
    const {
      ownerId
    } = req.params;
    const exhibitions = await Exhibition.findAll({
      where: {
        ownerId
      },
      include: [{
          model: User,
          as: 'Owner',
          attributes: ['id', 'name', 'email']
        },
        {
          model: ExhibitionCraftsman,
          as: 'ExhibitionCraftsmen',
          include: [{
            model: User,
            as: 'Craftsman',
            attributes: ['id', 'name', 'city']
          }],
        },
      ],
      order: [
        ['startDate', 'ASC']
      ],
    });
    res.json(exhibitions);
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to fetch owner exhibitions'
    });
  }
};

// ── POST /api/exhibitions/:exhibitionId/register ──
exports.registerForExhibition = async (req, res) => {
  try {
    const {
      exhibitionId
    } = req.params;
    const {
      craftsmanId,
      craftCategory,
      boothId,
      boothPrice,
      hasPaid,
      paymentReference,
      isInvited,
    } = req.body;

    const exhibition = await Exhibition.findByPk(exhibitionId);
    if (!exhibition) return res.status(404).json({
      error: 'Exhibition not found'
    });

    const existing = await ExhibitionCraftsman.findOne({
      where: {
        exhibitionId,
        craftsmanId
      }
    });
    if (existing) return res.status(400).json({
      error: 'Already registered'
    });

    // Check if the craftsman was invited to this exhibition
    const inviteNotif = await Notification.findOne({
      where: {
        userId: craftsmanId,
        type: 'exhibition_invite'
      }
    });
    const hasInvite = Boolean(
      isInvited || (inviteNotif && inviteNotif.metadata && inviteNotif.metadata.exhibitionId === exhibitionId)
    );

    const price = boothPrice !== undefined ? Number(boothPrice) : Number(exhibition.boothPrice || 0);

    let status = 'confirmed';
    let standbyRank = null;

    // Count current confirmed participants
    const confirmedCount = await ExhibitionCraftsman.count({
      where: { exhibitionId, status: 'confirmed' }
    });
    const exhibitionIsFull = confirmedCount >= exhibition.capacity;

    // RULE 1: If the client explicitly says this is a reserve registration, or
    //         the exhibition is already at capacity → always standby
    if (req.body.isReserve || exhibitionIsFull) {
      status = 'standby';
    }
    // RULE 2: Free booth + no invite (and NOT reserve) → pending approval
    else if (price === 0 && !hasInvite) {
      status = 'pending';
    }
    // RULE 3: Check category capacity
    else if (craftCategory && exhibition.categoryCapacities && exhibition.categoryCapacities[craftCategory] !== undefined) {
      const maxCap = exhibition.categoryCapacities[craftCategory];
      const catCount = await ExhibitionCraftsman.count({
        where: { exhibitionId, status: 'confirmed', craftCategory }
      });
      if (catCount >= maxCap) status = 'standby';
    }

    if (status === 'standby') {
      const standbyCount = await ExhibitionCraftsman.count({
        where: { exhibitionId, status: 'standby' }
      });
      standbyRank = standbyCount + 1;
      if (!exhibition.isFull && exhibitionIsFull) {
        await exhibition.update({ isFull: true });
      }
    }

    const registration = await ExhibitionCraftsman.create({
      exhibitionId,
      craftsmanId,
      craftCategory,
      boothId: boothId || null,
      boothPrice: price,
      hasPaid: hasPaid || false,
      paymentReference: paymentReference || null,
      status,
      standbyRank,
    });

    // Update booth layout in Exhibition model if boothId is provided
    if (boothId && Array.isArray(exhibition.boothLayout)) {
      try {
        const updatedLayout = exhibition.boothLayout.map(booth => {
          const bId = (booth.id || booth.name || '').toString();
          if (bId === boothId.toString()) {
            return {
              ...booth,
              available: false,
              reservedBy: craftsmanId,
              artisanId: craftsmanId,
              craftsmanId: craftsmanId,
              status: status,
            };
          }
          return booth;
        });
        await exhibition.update({ boothLayout: updatedLayout });
      } catch (e) {
        console.error('Failed to update booth layout during registration:', e);
      }
    }

    let message = 'Registered successfully';
    if (status === 'pending') {
      message = 'Participation request submitted. Awaiting exhibition owner approval.';
    } else if (status === 'standby') {
      message = `Standby #${standbyRank}`;
    }

    res.status(201).json({
      message,
      status,
      registration,
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Server error during registration'
    });
  }
};

// ── GET /api/exhibitions/:exhibitionId/register ──
exports.getCraftsmanRegistrationForExhibition = async (req, res) => {
  try {
    const { exhibitionId } = req.params;
    const craftsmanId = (req.user && req.user.id) || req.query.craftsmanId;
    if (!craftsmanId) {
      return res.json({ registered: false, status: 'none', registration: null });
    }
    const registration = await ExhibitionCraftsman.findOne({
      where: { exhibitionId, craftsmanId }
    });
    if (!registration) {
      return res.json({ registered: false, status: 'none', registration: null });
    }
    return res.json({ registered: true, status: registration.status, registration });
  } catch (error) {
    console.error('getCraftsmanRegistrationForExhibition error:', error);
    res.status(500).json({ error: 'Failed to fetch registration status' });
  }
};

// ── POST /api/exhibitions/:exhibitionId/invite/:craftsmanId ──
exports.inviteCraftsman = async (req, res) => {
  try {
    const { exhibitionId, craftsmanId } = req.params;
    const { message } = req.body;

    const exhibition = await Exhibition.findByPk(exhibitionId);
    if (!exhibition) {
      return res.status(404).json({ error: 'Exhibition not found' });
    }

    const craftsman = await User.findByPk(craftsmanId);
    if (!craftsman) {
      return res.status(404).json({ error: 'Craftsman not found' });
    }

    // Create a new notification for the craftsman
    const notification = await Notification.create({
      userId: craftsmanId,
      type: 'exhibition_invite',
      titleAr: 'دعوة للمشاركة في معرض',
      titleEn: 'Exhibition Invitation',
      bodyAr: `تمت دعوتك للمشاركة في معرض "${exhibition.name}". اضغط للتفاصيل والتسجيل.${message ? '\nرسالة: ' + message : ''}`,
      bodyEn: `You have been invited to participate in "${exhibition.nameEn || exhibition.name}". Tap for details and registration.${message ? '\nMessage: ' + message : ''}`,
      metadata: {
        exhibitionId: exhibition.id
      },
      isRead: false
    });

    res.json({
      message: 'Invitation sent successfully',
      success: true,
      notification
    });
  } catch (error) {
    console.error('inviteCraftsman error:', error);
    res.status(500).json({ error: 'Failed to send invitation' });
  }
};

// ── PATCH /api/exhibitions/:exhibitionId/registrations/:registrationId/status ──
exports.updateRegistrationStatus = async (req, res) => {
  try {
    const {
      exhibitionId,
      registrationId
    } = req.params;
    const {
      status,
      boothId,
      reason,
      rejectionReason,
    } = req.body;

    const exhibition = await Exhibition.findByPk(exhibitionId);
    if (!exhibition) return res.status(404).json({
      error: 'Exhibition not found'
    });

    if (req.user.role !== 'admin' && exhibition.ownerId !== req.user.id) {
      return res.status(403).json({
        error: 'Forbidden'
      });
    }

    const registration = await ExhibitionCraftsman.findOne({
      where: {
        id: registrationId,
        exhibitionId
      }
    });
    if (!registration) return res.status(404).json({
      error: 'Registration not found'
    });

    registration.status = status;
    if (status === 'confirmed' && boothId) registration.boothId = boothId;

    const reasonText = reason || rejectionReason || '';
    if (status === 'rejected' && reasonText) {
      registration.rejectionReason = reasonText;
    }

    await registration.save();

    // Update booth layout in Exhibition model
    const targetBoothId = boothId || registration.boothId;
    if (targetBoothId && Array.isArray(exhibition.boothLayout)) {
      try {
        const updatedLayout = exhibition.boothLayout.map(booth => {
          const bId = (booth.id || booth.name || '').toString();
          if (bId === targetBoothId.toString()) {
            if (status === 'confirmed') {
              return {
                ...booth,
                available: false,
                reservedBy: registration.craftsmanId,
                artisanId: registration.craftsmanId,
                craftsmanId: registration.craftsmanId,
                status: 'confirmed',
              };
            } else if (status === 'rejected' || status === 'cancelled') {
              return {
                ...booth,
                available: true,
                reservedBy: null,
                artisanId: null,
                craftsmanId: null,
                status: 'available',
              };
            }
          }
          return booth;
        });
        await exhibition.update({ boothLayout: updatedLayout });
      } catch (e) {
        console.error('Failed to update booth layout in updateRegistrationStatus:', e);
      }
    }

    // Send notifications to craftsman
    if (status === 'confirmed') {
      await Notification.create({
        userId: registration.craftsmanId,
        type: 'exhibition_registration_approved',
        titleAr: 'تمت الموافقة على طلب مشاركتك',
        titleEn: 'Participation Request Approved',
        bodyAr: `تمت الموافقة على طلب مشاركتك في معرض "${exhibition.name}". يمكنك الآن الاطلاع على كشكك ومتابعة المعرض.`,
        bodyEn: `Your participation request for "${exhibition.nameEn || exhibition.name}" has been approved!`,
        metadata: {
          exhibitionId: exhibition.id,
          registrationId: registration.id,
          status: 'confirmed',
          boothId: registration.boothId,
        },
        isRead: false
      });
    } else if (status === 'standby') {
      await Notification.create({
        userId: registration.craftsmanId,
        type: 'exhibition_registration_standby',
        titleAr: 'تم قبول انضمامك لقائمة الاحتياط',
        titleEn: 'Accepted to Standby List',
        bodyAr: `تمت الموافقة على انضمامك لقائمة الاحتياط في معرض "${exhibition.name}". وسيتم إخطارك عند توفر كشك.`,
        bodyEn: `Your request to join the standby list for "${exhibition.nameEn || exhibition.name}" has been accepted!`,
        metadata: {
          exhibitionId: exhibition.id,
          registrationId: registration.id,
          status: 'standby',
          boothId: registration.boothId,
        },
        isRead: false
      });
    } else if (status === 'rejected') {
      const finalReason = reasonText || 'لم يحدد سبب من قبل المنظم';
      await Notification.create({
        userId: registration.craftsmanId,
        type: 'exhibition_registration_rejected',
        titleAr: 'لم تتم الموافقة على طلب مشاركتك',
        titleEn: 'Participation Request Not Approved',
        bodyAr: `للأسف لم تتم الموافقة على طلب مشاركتك في معرض "${exhibition.name}".\nالسبب: ${finalReason}`,
        bodyEn: `Regrettably, your participation request for "${exhibition.nameEn || exhibition.name}" was not approved.\nReason: ${finalReason}`,
        metadata: {
          exhibitionId: exhibition.id,
          registrationId: registration.id,
          status: 'rejected',
          reason: finalReason,
        },
        isRead: false
      });
    }

    res.json({
      message: `Status updated to ${status}`,
      registration
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to update status'
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/exhibitions/:exhibitionId/registrations/:registrationId/absence
// Craftsman reports they cannot attend
// → Sets their status to 'cancelled' + marks reportedAbsence = true
// → Automatically finds the next standby craftsman (lowest standbyRank)
//   and promotes them to 'confirmed', assigning the freed booth
// ─────────────────────────────────────────────────────────────────────────────
exports.reportAbsence = async (req, res) => {
  try {
    const {
      exhibitionId,
      registrationId
    } = req.params;
    const {
      reason,
      apologyText
    } = req.body;

    const registration = await ExhibitionCraftsman.findOne({
      where: {
        id: registrationId,
        exhibitionId
      },
    });
    if (!registration) return res.status(404).json({
      error: 'Registration not found'
    });

    if (registration.status !== 'confirmed') {
      return res.status(400).json({
        error: 'Only confirmed registrations can report absence'
      });
    }

    const freedBoothId = registration.boothId;

    // Cancel the current registration
    await registration.update({
      status: 'cancelled',
      reportedAbsence: true,
      absenceReason: reason || 'unspecified',
      absenceApology: apologyText || null,
      boothId: null,
    });

    // ── Auto-promote the next standby craftsman ──────────────────
    let promoted = null;
    const nextStandby = await ExhibitionCraftsman.findOne({
      where: {
        exhibitionId,
        status: 'standby',
        ...(registration.craftCategory ? {
          craftCategory: registration.craftCategory
        } : {}),
      },
      order: [
        ['standbyRank', 'ASC']
      ],
    });

    if (nextStandby) {
      await nextStandby.update({
        status: 'confirmed',
        boothId: freedBoothId,
        standbyRank: null,
      });

      // Update isFull on the exhibition since we now have a slot taken again
      const confirmedCount = await ExhibitionCraftsman.count({
        where: {
          exhibitionId,
          status: 'confirmed'
        },
      });
      const exhibition = await Exhibition.findByPk(exhibitionId);
      if (exhibition) {
        await exhibition.update({
          isFull: confirmedCount >= exhibition.capacity
        });
      }

      promoted = {
        craftsmanId: nextStandby.craftsmanId,
        boothId: freedBoothId,
        message: 'Standby craftsman automatically promoted to confirmed',
      };
    } else {
      // No standby — free up the exhibition slot
      const exhibition = await Exhibition.findByPk(exhibitionId);
      if (exhibition && exhibition.isFull) {
        await exhibition.update({
          isFull: false
        });
      }
    }

    res.json({
      message: 'Absence reported successfully',
      cancelledRegistration: registration,
      promoted,
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to report absence'
    });
  }
};

// ── PUT /api/exhibitions/:exhibitionId ──
exports.updateExhibition = async (req, res) => {
  try {
    const {
      exhibitionId
    } = req.params;
    const exhibition = await Exhibition.findByPk(exhibitionId);
    if (!exhibition) return res.status(404).json({
      error: 'Exhibition not found'
    });

    if (req.user.role !== 'admin' && exhibition.ownerId !== req.user.id) {
      return res.status(403).json({
        error: 'Forbidden'
      });
    }

    const fields = [
      'name', 'nameEn', 'description', 'descriptionEn', 'location', 'locationEn',
      'eventType', 'eventTheme', 'targetAudience', 'priceRange', 'isPublic',
      'country', 'city', 'street', 'building', 'extraDetails',
      'latitude', 'longitude', 'manualLocation',
      'startDate', 'endDate', 'selectedDates',
      'crafts',
      'boothRows', 'boothColumns', 'boothPrice',
      'venueType', 'permitDocumentUrl', 'hasPermit', 'hasBusinessLicense',
      'permitNumber', 'issuerName', 'issuerPhone', 'issueDate', 'expiryDate',
      'capacity', 'categoryCapacities', 'status', 'boothLayout', 'gradient', 'imageUrl',
    ];
    const updateData = {};
    for (const key of fields) {
      if (req.body[key] !== undefined) updateData[key] = req.body[key];
    }
    await exhibition.update(updateData);

    res.json({
      message: 'Exhibition updated',
      exhibition
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to update exhibition'
    });
  }
};

// ── DELETE /api/exhibitions/:exhibitionId ──
exports.deleteExhibition = async (req, res) => {
  try {
    const {
      exhibitionId
    } = req.params;
    const exhibition = await Exhibition.findByPk(exhibitionId);
    if (!exhibition) return res.status(404).json({
      error: 'Exhibition not found'
    });

    if (req.user.role !== 'admin' && exhibition.ownerId !== req.user.id) {
      return res.status(403).json({
        error: 'Forbidden'
      });
    }

    await ExhibitionCraftsman.destroy({
      where: {
        exhibitionId
      }
    });
    await exhibition.destroy();

    res.json({
      message: 'Exhibition deleted'
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to delete exhibition'
    });
  }
};

// ── PUT /api/exhibitions/:exhibitionId/capacity ──
exports.updateCapacity = async (req, res) => {
  try {
    const {
      exhibitionId
    } = req.params;
    const {
      capacity,
      categoryCapacities
    } = req.body;
    const exhibition = await Exhibition.findByPk(exhibitionId);
    if (!exhibition) return res.status(404).json({
      error: 'Exhibition not found'
    });

    if (req.user.role !== 'admin' && exhibition.ownerId !== req.user.id) {
      return res.status(403).json({
        error: 'Forbidden'
      });
    }

    const updatedCapacity = capacity !== undefined ? capacity : exhibition.capacity;
    const updatedCategoryCapacities = categoryCapacities !== undefined ? categoryCapacities : exhibition.categoryCapacities;
    const confirmedCount = await ExhibitionCraftsman.count({
      where: {
        exhibitionId,
        status: 'confirmed'
      }
    });
    const isFull = confirmedCount >= updatedCapacity;

    await exhibition.update({
      capacity: updatedCapacity,
      categoryCapacities: updatedCategoryCapacities,
      isFull,
    });

    res.json({
      message: 'Capacity updated',
      exhibition
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to update capacity'
    });
  }
};

// ── PUT /api/exhibitions/:exhibitionId/booth-layout ──
exports.updateBoothLayout = async (req, res) => {
  try {
    const {
      exhibitionId
    } = req.params;
    const {
      boothLayout
    } = req.body;
    const exhibition = await Exhibition.findByPk(exhibitionId);
    if (!exhibition) return res.status(404).json({
      error: 'Exhibition not found'
    });

    if (req.user.role !== 'admin' && exhibition.ownerId !== req.user.id) {
      return res.status(403).json({
        error: 'Forbidden'
      });
    }

    await exhibition.update({
      boothLayout: boothLayout || []
    });
    res.json({
      message: 'Booth layout updated',
      boothLayout: exhibition.boothLayout
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to update booth layout'
    });
  }
};

// ── GET /api/exhibitions/:exhibitionId/attendance ──
// Get attendance for all dates of an exhibition
exports.getAttendance = async (req, res) => {
  try {
    const {
      exhibitionId
    } = req.params;
    const attendance = await ExhibitionDayAttendance.findAll({
      where: {
        exhibitionId
      },
      include: [{
        model: User,
        as: 'craftsman',
        attributes: ['id', 'name'],
      }, ],
      order: [
        ['date', 'ASC']
      ],
    });
    res.json(attendance);
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to fetch attendance'
    });
  }
};

// ── POST /api/exhibitions/:exhibitionId/attendance ──
// Update attendance for a specific craftsman on a specific date
// Body: { craftsmanId, date, isPresent, absenceReason? }
exports.updateAttendance = async (req, res) => {
  try {
    const {
      exhibitionId
    } = req.params;
    const {
      craftsmanId,
      date,
      isPresent,
      absenceReason
    } = req.body;

    // Verify the exhibition exists
    const exhibition = await Exhibition.findByPk(exhibitionId);
    if (!exhibition) return res.status(404).json({
      error: 'Exhibition not found'
    });

    // Check that the craftsman is actually registered for this exhibition
    const registration = await ExhibitionCraftsman.findOne({
      where: {
        exhibitionId,
        craftsmanId
      },
    });
    if (!registration) {
      return res.status(404).json({
        error: 'Craftsman not registered for this exhibition'
      });
    }

    // Find or create the attendance record
    const [record, created] = await ExhibitionDayAttendance.findOrCreate({
      where: {
        exhibitionId,
        craftsmanId,
        date
      },
      defaults: {
        exhibitionId,
        craftsmanId,
        date,
        isPresent: isPresent !== undefined ? isPresent : true,
        absenceReason: absenceReason || null,
      },
    });

    if (!created) {
      // Update existing
      await record.update({
        isPresent: isPresent !== undefined ? isPresent : record.isPresent,
        absenceReason: absenceReason || record.absenceReason,
      });
    }

    res.json({
      message: 'Attendance updated',
      record
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to update attendance'
    });
  }
};

// ── POST /api/exhibitions/:exhibitionId/attendance/promote ──
// Promote a standby craftsman to confirmed for a specific day, assigning a booth
// Body: { standbyCraftsmanId, boothId, date }
exports.promoteStandby = async (req, res) => {
  try {
    const {
      exhibitionId
    } = req.params;
    const {
      standbyCraftsmanId,
      boothId,
      date
    } = req.body;

    // 1. Find the standby registration
    const standbyReg = await ExhibitionCraftsman.findOne({
      where: {
        exhibitionId,
        craftsmanId: standbyCraftsmanId,
        status: 'standby',
      },
    });
    if (!standbyReg) {
      return res.status(404).json({
        error: 'Standby craftsman not found'
      });
    }

    // 2. Promote in the main registration
    const assignedBoothId = boothId || standbyReg.boothId;
    await standbyReg.update({
      status: 'confirmed',
      boothId: assignedBoothId,
      standbyRank: null,
    });

    const exhibition = await Exhibition.findByPk(exhibitionId);

    // Update booth layout in Exhibition model
    if (assignedBoothId && exhibition && Array.isArray(exhibition.boothLayout)) {
      try {
        const updatedLayout = exhibition.boothLayout.map(booth => {
          const bId = (booth.id || booth.name || '').toString();
          if (bId === assignedBoothId.toString()) {
            return {
              ...booth,
              available: false,
              reservedBy: standbyCraftsmanId,
              artisanId: standbyCraftsmanId,
              craftsmanId: standbyCraftsmanId,
              status: 'confirmed',
            };
          }
          return booth;
        });
        await exhibition.update({ boothLayout: updatedLayout });
      } catch (e) {
        console.error('Failed to update booth layout during promoteStandby:', e);
      }
    }

    // 3. Update attendance record for this day if provided
    if (date) {
      await ExhibitionDayAttendance.upsert({
        exhibitionId,
        craftsmanId: standbyCraftsmanId,
        date,
        isPresent: true,
      });
    }

    // 4. Update exhibition's isFull status (recalculate)
    const confirmedCount = await ExhibitionCraftsman.count({
      where: {
        exhibitionId,
        status: 'confirmed'
      },
    });
    if (exhibition) {
      await exhibition.update({
        isFull: confirmedCount >= exhibition.capacity
      });
    }

    // 5. Send notification to the promoted craftsman
    await Notification.create({
      userId: standbyCraftsmanId,
      type: 'exhibition_registration_approved',
      titleAr: 'تمت ترقيتك للمشاركة في المعرض',
      titleEn: 'Promoted to Exhibition Participant',
      bodyAr: `تهانينا! تمت ترقيتك وتأكيد مشاركتك في معرض "${exhibition ? exhibition.name : ''}". كشكك المخصص: ${assignedBoothId || 'محدد'}.`,
      bodyEn: `Congratulations! You have been promoted to a confirmed participant for "${exhibition ? (exhibition.nameEn || exhibition.name) : ''}". Assigned booth: ${assignedBoothId || 'assigned'}.`,
      metadata: {
        exhibitionId,
        registrationId: standbyReg.id,
        status: 'confirmed',
        boothId: assignedBoothId,
      },
      isRead: false,
    });

    res.json({
      message: 'Standby promoted successfully',
      registration: standbyReg,
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Failed to promote standby'
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN ENDPOINTS – Added for Admin Exhibition Screen
// ─────────────────────────────────────────────────────────────────────────────

/**
 * GET /api/admin/exhibitions
 * Fetch all exhibitions with optional filters (admin only)
 * Query: status, city, search, featured, pending
 */
exports.getAdminExhibitions = async (req, res) => {
  try {
    const {
      status,
      city,
      search,
      featured,
      pending
    } = req.query;
    const where = {};

    // Status filter (case-insensitive)
    if (status && status !== 'All' && status !== 'الكل') {
      where.status = status.toLowerCase();
    }

    // City filter
    if (city && city !== 'All' && city !== 'الكل') {
      where.location = {
        [Op.like]: `%${city}%`
      };
    }

    // Featured filter
    if (featured === 'true') {
      where.featured = true;
    } else if (featured === 'false') {
      where.featured = false;
    }

    // Pending approvals (exhibitions not yet verified)
    if (pending === 'true') {
      where.verified = false;
    }

    // Search by name or location
    if (search && search.trim() !== '') {
      const searchTerm = `%${search.trim()}%`;
      where[Op.or] = [{
          name: {
            [Op.like]: searchTerm
          }
        },
        {
          nameEn: {
            [Op.like]: searchTerm
          }
        },
        {
          location: {
            [Op.like]: searchTerm
          }
        },
        {
          locationEn: {
            [Op.like]: searchTerm
          }
        },
      ];
    }

    const exhibitions = await Exhibition.findAll({
      where,
      include: [{
          model: User,
          as: 'Owner',
          attributes: ['id', 'name', 'email', 'city', 'profileImage'],
        },
        {
          model: ExhibitionCraftsman,
          as: 'ExhibitionCraftsmen',
          include: [{
            model: User,
            as: 'Craftsman',
            attributes: ['id', 'name', 'city'],
          }, ],
        },
      ],
      order: [
        ['createdAt', 'DESC']
      ],
    });

    res.json(exhibitions);
  } catch (error) {
    console.error('getAdminExhibitions error:', error);
    res.status(500).json({
      error: 'Failed to fetch admin exhibitions'
    });
  }
};

/**
 * PATCH /api/admin/exhibitions/:id/feature
 * Toggle featured status of an exhibition
 * Body: { featured: boolean }
 */
exports.toggleFeatured = async (req, res) => {
  try {
    const {
      id
    } = req.params;
    const {
      featured
    } = req.body;

    const exhibition = await Exhibition.findByPk(id);
    if (!exhibition) {
      return res.status(404).json({
        error: 'Exhibition not found'
      });
    }

    await exhibition.update({
      featured: featured ?? false
    });
    res.json({
      message: 'Featured status updated',
      featured: exhibition.featured,
      exhibition,
    });
  } catch (error) {
    console.error('toggleFeatured error:', error);
    res.status(500).json({
      error: 'Failed to update featured status'
    });
  }
};

/**
 * PATCH /api/admin/exhibitions/:id/status
 * Admin override status (suspend/reactivate)
 * Body: { status: 'active' | 'suspended' | 'upcoming' | 'past' }
 */
exports.adminOverrideStatus = async (req, res) => {
  try {
    const {
      id
    } = req.params;
    const {
      status
    } = req.body;

    const allowed = ['active', 'suspended', 'upcoming', 'past'];
    if (!allowed.includes(status)) {
      return res.status(400).json({
        error: 'Invalid status value'
      });
    }

    const exhibition = await Exhibition.findByPk(id);
    if (!exhibition) {
      return res.status(404).json({
        error: 'Exhibition not found'
      });
    }

    await exhibition.update({
      status
    });
    res.json({
      message: `Exhibition status updated to ${status}`,
      status: exhibition.status,
      exhibition,
    });
  } catch (error) {
    console.error('adminOverrideStatus error:', error);
    res.status(500).json({
      error: 'Failed to update status'
    });
  }
};

/**
 * POST /api/admin/exhibitions/:id/approve
 * Approve a pending exhibition → sets status = 'active', verified = true
 */
exports.approveExhibition = async (req, res) => {
  try {
    const {
      id
    } = req.params;

    const exhibition = await Exhibition.findByPk(id);
    if (!exhibition) {
      return res.status(404).json({
        error: 'Exhibition not found'
      });
    }

    await exhibition.update({
      status: 'active',
      verified: true,
    });

    // Optionally: send notification to owner (placeholder)
    // await notifyOwner(exhibition.ownerId, 'approved');

    res.json({
      message: 'Exhibition approved successfully',
      exhibition,
    });
  } catch (error) {
    console.error('approveExhibition error:', error);
    res.status(500).json({
      error: 'Failed to approve exhibition'
    });
  }
};

/**
 * POST /api/admin/exhibitions/:id/reject
 * Reject a pending exhibition with reason
 * Body: { reason: string }
 */
exports.rejectExhibition = async (req, res) => {
  try {
    const {
      id
    } = req.params;
    const {
      reason
    } = req.body;

    const exhibition = await Exhibition.findByPk(id);
    if (!exhibition) {
      return res.status(404).json({
        error: 'Exhibition not found'
      });
    }

    // Store rejection reason (add column if needed, or just update status)
    await exhibition.update({
      status: 'rejected',
      verified: false,
      // Optionally save rejection reason in a new field if you add it
      // rejectionReason: reason || 'No reason provided',
    });

    // Optionally: send notification to owner (placeholder)
    // await notifyOwner(exhibition.ownerId, 'rejected', reason);

    res.json({
      message: 'Exhibition rejected',
      reason: reason || 'No reason provided',
      exhibition,
    });
  } catch (error) {
    console.error('rejectExhibition error:', error);
    res.status(500).json({
      error: 'Failed to reject exhibition'
    });
  }
};

/**
 * GET /api/admin/exhibitions/analytics
 * Platform-wide analytics for exhibitions
 */
exports.getAdminAnalytics = async (req, res) => {
  try {
    const total = await Exhibition.count();
    const active = await Exhibition.count({
      where: {
        status: 'active'
      }
    });
    const upcoming = await Exhibition.count({
      where: {
        status: 'upcoming'
      }
    });
    const past = await Exhibition.count({
      where: {
        status: 'past'
      }
    });
    const pending = await Exhibition.count({
      where: {
        verified: false
      }
    });
    const featured = await Exhibition.count({
      where: {
        featured: true
      }
    });

    // Total capacity and artisans
    const capacityResult = await Exhibition.sum('capacity');
    const totalCapacity = capacityResult || 0;
    const totalArtisans = await ExhibitionCraftsman.count();

    // Category distribution
    const allExhibitions = await Exhibition.findAll({
      attributes: ['crafts'],
      where: {
        crafts: {
          [Op.ne]: null
        }
      },
    });
    const categoryCount = {};
    for (const ex of allExhibitions) {
      if (ex.crafts && Array.isArray(ex.crafts)) {
        for (const c of ex.crafts) {
          categoryCount[c] = (categoryCount[c] || 0) + 1;
        }
      }
    }

    // City distribution
    const cityCount = {};
    const cityExhibitions = await Exhibition.findAll({
      attributes: ['city'],
      where: {
        city: {
          [Op.ne]: null
        }
      },
    });
    for (const ex of cityExhibitions) {
      if (ex.city) {
        cityCount[ex.city] = (cityCount[ex.city] || 0) + 1;
      }
    }

    const occupancy = totalCapacity > 0 ? (totalArtisans / totalCapacity) : 0;

    res.json({
      total,
      active,
      upcoming,
      past,
      pending,
      featured,
      totalCapacity,
      totalArtisans,
      occupancy: parseFloat(occupancy.toFixed(2)),
      categoryCount,
      cityCount,
    });
  } catch (error) {
    console.error('getAdminAnalytics error:', error);
    res.status(500).json({
      error: 'Failed to fetch analytics'
    });
  }
};