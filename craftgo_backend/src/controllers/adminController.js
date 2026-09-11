const { Op } = require('sequelize');
const sequelize = require('../config/database');
const User = require('../models/User');
const ArtisanProfile = require('../models/ArtisanProfile');
const PortfolioItem = require('../models/PortfolioItem');
const Role = require('../models/Role');
const UserRole = require('../models/UserRole');
const Exhibition = require('../models/Exhibition');
const Product = require('../models/Product');
const Order = require('../models/Order');
const DeliveryProfile = require('../models/DeliveryProfile');
const CustomOrderRequest = require('../models/CustomOrderRequest');
const HireRequest = require('../models/HireRequest');
const OrderDispute = require('../models/OrderDispute');
const DeliveryOrder = require('../models/DeliveryOrder');
const Message = require('../models/Message');
const Notification = require('../models/Notification');
const Review = require('../models/Review');
const Story = require('../models/Story');
const FavoriteArtisan = require('../models/FavoriteArtisan');
const UserInteraction = require('../models/UserInteraction');
const ExhibitionCraftsman = require('../models/ExhibitionCraftsman');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');
require('dotenv').config();

const ADMIN_STAFF_ID = process.env.ADMIN_STAFF_ID || 'AD-9042';
const JWT_SECRET = process.env.JWT_SECRET;

const adminMailTransporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

function maskEmail(email) {
  const [name = '', domain = ''] = String(email).split('@');

  if (!domain) {
    return email;
  }

  const visible =
    name.length <= 2
      ? name[0] || '*'
      : name.substring(0, 2);

  return `${visible}${'*'.repeat(
    Math.max(3, name.length - visible.length),
  )}@${domain}`;
}

function getSecurityAssessment() {
  const hour = new Date().getHours();
  const unusualHours = hour >= 23 || hour < 6;

  return {
    unusualHours,

    securityMessageAr: unusualHours
      ? '???� ?�?�???�?�?? ?�?�?�?�?�?� ?�?�?�?� ???? ?�?�?�?�?? ?????� ?�?�???�?�?� ?�???� ???�?�???�?�?� ?�?�?�?�?�?�?�?�.'
      : '???� ?�?�???�?�?� ?�?� ?�???�?�?�?? ?�?�?�?�?�?� ?�?�?� ?????� ?�?�???�?�?? ?�?�?�?�?�?? ?????� ?�?�???�?�?�.',

    securityMessageEn: unusualHours
      ? 'A login attempt during unusual hours was detected and logged for review.'
      : 'The login credentials were verified and no unusual indicators were detected.',
  };
}

// ── Admin secure login: validate credentials and send OTP ────────────────────
exports.requestAdminLoginOtp = async (req, res) => {
  try {
    const {
      staffId,
      email,
      password,
    } = req.body;

    if (!staffId || !email || !password) {
      return res.status(400).json({
        error: 'Staff ID, email and password are required',
      });
    }

    if (
      staffId.trim().toUpperCase() !==
      ADMIN_STAFF_ID.toUpperCase()
    ) {
      return res.status(401).json({
        error: 'Invalid admin staff ID',
      });
    }

    const user = await User.findOne({
      where: {
        email: email.trim().toLowerCase(),
      },
      include: [
        {
          model: Role,
          attributes: ['name'],
        },
      ],
    });

    if (!user) {
      return res.status(401).json({
        error: 'Invalid admin credentials',
      });
    }

    const roles = (user.Roles || []).map(
      (role) => role.name,
    );

    if (!roles.includes('admin')) {
      return res.status(403).json({
        error: 'This account does not have admin access',
      });
    }

    const passwordMatches = await bcrypt.compare(
      password,
      user.password,
    );

    if (!passwordMatches) {
      return res.status(401).json({
        error: 'Invalid admin credentials',
      });
    }

    const otp = Math.floor(
      100000 + Math.random() * 900000,
    ).toString();

    const otpExpiresAt =
      Date.now() + 5 * 60 * 1000;

    await user.update({
      otpCode: otp,
      otpExpiresAt,
    });

    const isDummyDomain = (emailStr) => {
      const lower = (emailStr || '').toLowerCase();
      return (
        lower.endsWith('@craftgo.com') ||
        lower.endsWith('@example.com') ||
        lower.endsWith('@test.com') ||
        lower.endsWith('@localhost')
      );
    };

    const recipientList = [user.email];
    if (process.env.ADMIN_OTP_EMAIL && process.env.ADMIN_OTP_EMAIL.trim()) {
      recipientList.push(process.env.ADMIN_OTP_EMAIL.trim());
    }

    const uniqueRecipients = Array.from(
      new Set(
        recipientList
          .filter(Boolean)
          .map((e) => e.trim().toLowerCase()),
      ),
    );

    const validSmtpRecipients = uniqueRecipients.filter(
      (e) => !isDummyDomain(e),
    );

    console.log(
      `[Admin OTP] Verification code ${otp} for ${user.email} (all targets: ${uniqueRecipients.join(', ')} | valid SMTP targets: ${validSmtpRecipients.join(', ') || 'none'})`,
    );

    if (validSmtpRecipients.length > 0) {
      await Promise.allSettled(
        validSmtpRecipients.map((toEmail) =>
          adminMailTransporter
            .sendMail({
              from:
                `"CraftGo Admin Security" <${process.env.EMAIL_USER}>`,

              to: toEmail,

              subject:
                'CraftGo Admin – Verification Code',

              html: `
        <div
          style="
            font-family: Arial, sans-serif;
            max-width: 430px;
            margin: auto;
            padding: 32px;
            background: #0A0F1E;
            color: #ffffff;
            border-radius: 18px;
            text-align: center;
          "
        >
          <h2 style="color: #3D7BFF;">
            CraftGo Admin Portal
          </h2>

          <p>
            Your administrator verification code is:
          </p>

          <div
            style="
              font-size: 42px;
              font-weight: 700;
              letter-spacing: 10px;
              color: #F7B500;
              margin: 24px 0;
            "
          >
            ${otp}
          </div>

          <p
            style="
              color: #aab2c5;
              font-size: 13px;
            "
          >
            Valid for 5 minutes.
          </p>
        </div>
      `,
            })
            .catch((err) =>
              console.error(
                `[Admin OTP] Failed sending to ${toEmail}:`,
                err.message || err,
              ),
            ),
        ),
      );
    }

    const security =
      getSecurityAssessment();

    return res.json({
      success: true,

      message:
        'OTP sent successfully',

      otpDestination: uniqueRecipients
        .map(maskEmail)
        .join(', '),

      ...security,
    });
  } catch (error) {
    console.error(
      'Admin login OTP error:',
      error,
    );

    return res.status(500).json({
      error:
        'Failed to verify admin credentials or send OTP',

      details:
        error.message,
    });
  }
};
// ── Admin secure login: verify OTP and issue token ───────────────────────────
exports.verifyAdminLoginOtp = async (req, res) => {
  try {
    const {
      staffId,
      email,
      otp,
    } = req.body;

    if (!staffId || !email || !otp) {
      return res.status(400).json({
        error: 'Staff ID, email and OTP are required',
      });
    }

    if (
      staffId.trim().toUpperCase() !==
      ADMIN_STAFF_ID.toUpperCase()
    ) {
      return res.status(401).json({
        error: 'Invalid admin staff ID',
      });
    }

    const user = await User.findOne({
      where: {
        email: email.trim().toLowerCase(),
      },
      include: [
        {
          model: Role,
          attributes: ['name'],
        },
      ],
    });

    if (!user) {
      return res.status(401).json({
        error: 'Admin account not found',
      });
    }

    const roles = (user.Roles || []).map(
      (role) => role.name,
    );

    if (!roles.includes('admin')) {
      return res.status(403).json({
        error: 'This account does not have admin access',
      });
    }

    if (!user.otpCode || !user.otpExpiresAt) {
      return res.status(400).json({
        error: 'No active OTP. Request a new code.',
      });
    }

    if (Date.now() > Number(user.otpExpiresAt)) {
      await user.update({
        otpCode: null,
        otpExpiresAt: null,
      });

      return res.status(400).json({
        error: 'OTP expired. Request a new code.',
      });
    }

    if (user.otpCode !== otp.toString().trim()) {
      return res.status(400).json({
        error: 'Invalid OTP',
      });
    }

    await user.update({
      otpCode: null,
      otpExpiresAt: null,
    });

    const token = jwt.sign(
  {
    id: user.id,
    role: 'admin',
    roles: roles,
  },
  JWT_SECRET,
  {
    expiresIn: '7d',
  },
);

    return res.json({
      success: true,
      message: 'Admin login successful',

      token,

      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        roles,
      },
    });
  } catch (error) {
    console.error(
      'Admin OTP verification error:',
      error,
    );

    return res.status(500).json({
      error: 'Failed to verify admin OTP',
      details: error.message,
    });
  }
};

// ============================================================================
// ?�?�?�?�?� ?�?�?�?�?�?? ?�?�?�?�?�?�?� ???�?�?� ?�?� ?�?�?�
// ============================================================================

exports.getStats = async (req, res) => {
  try {
    const totalUsers = await User.count();

    const customers = await User.count({
      where: { role: 'customer' },
    });

    const craftsmen = await User.count({
      where: { role: 'craftsman' },
    });

    const exhibitionOwners = await User.count({
      where: { role: 'exhibition_owner' },
    });

    const admins = await User.count({
      where: { role: 'admin' },
    });

    const totalExhibitions =
      await Exhibition.count();

    const totalProducts =
      await Product.count();

    const totalOrders =
      await Order.count();

    const orders =
      await Order.findAll();

    const revenue =
      orders.reduce(
        (sum, o) =>
          sum + (o.totalPrice || 0),
        0,
      );

    res.json({
      stats: {
        totalUsers,
        roles: {
          customer: customers,
          craftsman: craftsmen,
          exhibition_owner:
            exhibitionOwners,
          admin: admins,
        },
        totalExhibitions,
        totalProducts,
        totalOrders,
        revenue,
      },
    });
  } catch (error) {
    console.error(
      'Error fetching admin stats:',
      error,
    );

    res.status(500).json({
      error:
        'Failed to retrieve system statistics',
    });
  }
};
exports.getCraftsmanReport = async (req, res) => {
  try {
    const { craftsmanId } = req.params;
    const { period = 'all' } = req.query;
    const { Op } = require('sequelize');

    const craftsman = await User.findByPk(craftsmanId);

    if (!craftsman || craftsman.role !== 'craftsman') {
      return res.status(404).json({
        error: 'Craftsman not found',
      });
    }

    let dateFilter = {};
    const now = new Date();

    if (period === 'monthly') {
      const firstDay = new Date(
        now.getFullYear(),
        now.getMonth(),
        1,
      );

      dateFilter = {
        createdAt: {
          [Op.gte]: firstDay,
        },
      };
    } else if (period === 'yearly') {
      const firstDay = new Date(
        now.getFullYear(),
        0,
        1,
      );

      dateFilter = {
        createdAt: {
          [Op.gte]: firstDay,
        },
      };
    }

    const products = await Product.findAll({
      where: { craftsmanId },
    });

    const productIds = products.map(
      (p) => p.id,
    );

    const orders = await Order.findAll({
      where: {
        productId: {
          [Op.in]: productIds,
        },
        ...dateFilter,
      },
    });

    const totalSales = orders.reduce(
      (sum, o) =>
        sum + (o.totalPrice || 0),
      0,
    );

    const completedOrders =
      orders.filter(
        (o) => o.status === 'completed',
      ).length;

    const pendingOrders =
      orders.filter(
        (o) => o.status === 'pending',
      ).length;

    const cancelledOrders =
      orders.filter(
        (o) => o.status === 'cancelled',
      ).length;

    res.json({
      success: true,

      craftsman: {
        id: craftsman.id,
        name: craftsman.name,
        email: craftsman.email,
        city: craftsman.city,
      },

      period,

      report: {
        totalProducts:
          products.length,

        totalOrders:
          orders.length,

        completedOrders,

        pendingOrders,

        cancelledOrders,

        totalSales,
      },
    });
  } catch (error) {
    console.error(
      'Error generating craftsman report:',
      error,
    );

    res.status(500).json({
      error:
        'Failed to generate report',
    });
  }
};

exports.getPendingArtisans = async (req, res) => {
  try {
    const artisanRole = await Role.findOne({ where: { name: 'artisan' } });
    if (artisanRole) {
      const artisanUsers = await User.findAll({
        include: [
          {
            model: Role,
            where: { name: 'artisan' },
          },
          {
            model: ArtisanProfile,
          },
        ],
      });

      for (const user of artisanUsers) {
        if (!user.ArtisanProfile) {
          await ArtisanProfile.create({
            userId: user.id,
            isVerified: false,
            primaryCategory: 'General',
          });
        }
      }
    }

    const pendingProfiles =
      await ArtisanProfile.findAll({
        where: {
          isVerified: false,
        },

        include: [
          {
            model: PortfolioItem,
            attributes: [
              'id',
              'imageUrl',
              'titleAr',
              'titleEn',
            ],
          },

          {
            model: User,

            attributes: [
              'id',
              'name',
              'email',
              'phone',
              'city',
              'createdAt',
            ],

            include: [
              {
                model: Role,
                attributes: ['name'],
              },
            ],
          },
        ],

        order: [
          ['createdAt', 'DESC'],
        ],
      });

    const result =
      pendingProfiles.map((profile) => {
        const idDetails =
          profile.idVerificationDetails &&
          typeof profile.idVerificationDetails === 'object'
            ? profile.idVerificationDetails
            : {};

        const portfolioImages =
          Array.isArray(profile.PortfolioItems)
            ? profile.PortfolioItems
                .map((item) => item.imageUrl)
                .filter(Boolean)
            : [];

        return {
          artisanProfileId: profile.id,

          userId:
            profile.User?.id || '',

          name:
            profile.User?.name || '',

          email:
            profile.User?.email || '',

          phone:
            profile.User?.phone || '',

          city:
            profile.User?.city || '',

          // Correct artisan category
          category:
            profile.primaryCategory ||
            profile.primaryCategoryEn ||
            '',

          primaryCategory:
            profile.primaryCategory || '',

          bio:
            profile.bio || '',

          experienceYears:
            profile.experienceYears || 0,

          // NEW
          priceRange:
            profile.priceRange || '',

          // NEW
          specializations:
            Array.isArray(profile.specializations)
              ? profile.specializations
              : [],

          // NEW
          trustedHands:
            profile.trustedHands === true,

          verificationType:
            profile.trustedHands === true
              ? 'trusted_hands'
              : 'standard',

          idFrontUrl:
            profile.idFrontUrl ||
            idDetails.idFrontUrl ||
            idDetails.idFrontImage ||
            idDetails.frontUrl ||
            '',

          idBackUrl:
            profile.idBackUrl ||
            idDetails.idBackUrl ||
            idDetails.idBackImage ||
            idDetails.backUrl ||
            '',

          portfolioImages,

          portfolioCount:
            portfolioImages.length,

          aiTrustScore:
            profile.aiTrustScore ?? null,

          registeredAt:
            profile.User?.createdAt || null,
        };
      });

    return res.json({
      success: true,
      count: result.length,
      data: result,
    });
  } catch (error) {
    console.error(
      'Error fetching pending artisans:',
      error,
    );

    return res.status(500).json({
      success: false,
      error: 'Failed to fetch pending artisans',
      details: error.message,
    });
  }
};

exports.reviewArtisan = async (req, res) => {
  try {
    const { artisanProfileId } =
      req.params;

    const { action } =
      req.body;

    if (
      !['approve', 'reject'].includes(
        action,
      )
    ) {
      return res.status(400).json({
        error:
          'action must be "approve" or "reject"',
      });
    }

    const profile =
      await ArtisanProfile.findByPk(
        artisanProfileId,
      );

    if (!profile) {
      return res.status(404).json({
        error:
          'Artisan profile not found',
      });
    }

    if (action === 'approve') {
      await profile.update({
        isVerified: true,
      });

      return res.json({
        success: true,
        message:
          'Artisan approved successfully',
        isVerified: true,
      });
    }

    await profile.update({
      isVerified: false,
    });

    return res.json({
      success: true,
      message:
        'Artisan rejected',
      isVerified: false,
    });
  } catch (error) {
    console.error(
      'Error reviewing artisan:',
      error,
    );

    res.status(500).json({
      error:
        'Failed to process verification review',
    });
  }
};

// ── GET /api/admin/users — fetch all registered platform users ─────────────────
exports.getUsers = async (req, res) => {
  try {
    const users = await User.findAll({
      include: [
        {
          model: Role,
          attributes: ['id', 'name'],
          through: { attributes: [] },
        },
        {
          model: ArtisanProfile,
          required: false,
        },
      ],
      order: [['createdAt', 'DESC']],
    });

    const formatted = users.map((u) => {
      const roles = (u.Roles || []).map((r) => r.name);
      if (u.role && !roles.includes(u.role)) {
        roles.push(u.role);
      }

      return {
        id: u.id,
        name: u.name,
        email: u.email,
        phone: u.phone || 'N/A',
        city: u.city || 'Nablus',
        profileImage: u.profileImage || '',
        roles: roles.length > 0 ? roles : ['customer'],
        adminStaffId: u.adminStaffId || (roles.includes('admin') ? ADMIN_STAFF_ID : null),
        isSuspended: u.isSuspended === true,
        isVerified: u.ArtisanProfile ? u.ArtisanProfile.isVerified : true,
        createdAt: u.createdAt,
      };
    });

    res.json({ success: true, count: formatted.length, users: formatted });
  } catch (error) {
    console.error('getUsers error:', error);
    res.status(500).json({ error: 'Failed to fetch users', details: error.message });
  }
};

// ── PATCH /api/admin/users/:id/status — toggle ban / suspend ───────────────
exports.toggleUserStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { isSuspended } = req.body;

    const user = await User.findByPk(id);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    user.isSuspended = isSuspended !== undefined ? isSuspended : !user.isSuspended;
    await user.save();

    res.json({
      success: true,
      message: `User ${user.name} status updated`,
      isSuspended: user.isSuspended,
    });
  } catch (error) {
    console.error('toggleUserStatus error:', error);
    res.status(500).json({ error: 'Failed to update user status', details: error.message });
  }
};

// ── POST /api/admin/users/:id/promote — promote user to admin & send code via email ──────
exports.promoteToAdmin = async (req, res) => {
  try {
    const { id } = req.params;

    const user = await User.findByPk(id, {
      include: [{ model: Role }],
    });

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Generate unique 4-digit numeric code for Admin Staff ID
    const randomDigits = Math.floor(1000 + Math.random() * 9000).toString();
    const adminStaffId = `AD-${randomDigits}`;

    // Attach admin role if not attached
    let adminRole = await Role.findOne({ where: { name: 'admin' } });
    if (!adminRole) {
      adminRole = await Role.create({ name: 'admin', description: 'Administrator' });
    }

    const UserRole = require('../models/UserRole');
    await UserRole.findOrCreate({
      where: { userId: user.id, roleId: adminRole.id },
    });

    user.role = 'admin';
    user.adminStaffId = adminStaffId;
    await user.save();

    // Send email to promoted user with their Admin Code
    try {
      await adminMailTransporter.sendMail({
        from: `"CraftGo Admin Portal" <${process.env.EMAIL_USER}>`,
        to: user.email,
        subject: '🎉 Congratulations! You have been promoted to Admin on CraftGo',
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 480px; margin: auto; padding: 24px; background: #0D1420; color: #ffffff; border-radius: 16px; border: 1px solid #D4A017;">
            <h2 style="color: #D4A017; text-align: center; margin-top: 0;">CraftGo Admin Portal Access</h2>
            <p>Hello <strong>${user.name}</strong>,</p>
            <p>You have been granted <strong>Administrator Privileges</strong> on CraftGo.</p>
            <p>Below is your confidential <strong>Admin Staff Code</strong> required for administrator login:</p>
            <div style="text-align: center; background: #1C2431; padding: 18px; border-radius: 12px; margin: 20px 0; border: 1px solid #D4A017;">
              <div style="font-size: 13px; color: #aab2c5;">YOUR CONFIDENTIAL ADMIN CODE</div>
              <div style="font-size: 32px; font-weight: bold; color: #D4A017; letter-spacing: 4px; margin-top: 6px;">${adminStaffId}</div>
            </div>
            <p style="font-size: 13px; color: #aab2c5;">Use your email (<strong>${user.email}</strong>), your password, and the Admin Staff Code (<strong>${adminStaffId}</strong>) to log in to the Admin Dashboard.</p>
            <p style="font-size: 12px; color: #7d8b9e; text-align: center; margin-top: 20px;">Keep this code confidential. CraftGo Security Team.</p>
          </div>
        `,
      });
    } catch (emailErr) {
      console.error('Failed to send admin promotion email:', emailErr.message || emailErr);
    }

    return res.json({
      success: true,
      message: `User ${user.name} has been promoted to Admin`,
      adminStaffId,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        adminStaffId,
      },
    });
  } catch (error) {
    console.error('promoteToAdmin error:', error);
    res.status(500).json({ error: 'Failed to promote user to admin', details: error.message });
  }
};

// ── Delete User & All Related Account Data ─────────────────────────────────
exports.deleteUser = async (req, res) => {
  try {
    const { id } = req.params;

    if (!id) {
      return res.status(400).json({ error: 'User ID is required' });
    }

    if (req.user && req.user.id === id) {
      return res.status(400).json({ error: 'You cannot delete your own admin account.' });
    }

    const user = await User.findByPk(id);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Safe delete helper that catches errors per model if a column schema differs
    const safeDelete = async (model, whereCondition) => {
      if (!model) return;
      try {
        await model.destroy({ where: whereCondition });
      } catch (err) {
        console.warn(`[deleteUser safeDelete warning]:`, err.message || err);
      }
    };

    // 1. User Roles
    await safeDelete(UserRole, { userId: id });

    // 2. Artisan Profile & Portfolio Items
    try {
      const artisanProfile = await ArtisanProfile.findOne({ where: { userId: id } });
      if (artisanProfile) {
        await safeDelete(PortfolioItem, { artisanProfileId: artisanProfile.id });
        await artisanProfile.destroy();
      }
    } catch (e) {
      console.warn('Error deleting artisan profile:', e.message);
    }

    // 3. Delivery Profile
    await safeDelete(DeliveryProfile, { userId: id });

    // 4. Products (column craftsmanId)
    await safeDelete(Product, { craftsmanId: id });

    // 5. Exhibitions & ExhibitionCraftsman
    await safeDelete(Exhibition, { ownerId: id });
    await safeDelete(ExhibitionCraftsman, { craftsmanId: id });

    // 6. Orders (columns customerId / craftsmanId)
    await safeDelete(Order, { [Op.or]: [{ customerId: id }, { craftsmanId: id }] });

    // 7. Custom Order Requests (columns customerId / artisanId)
    await safeDelete(CustomOrderRequest, { [Op.or]: [{ customerId: id }, { artisanId: id }] });

    // 8. Hire Requests (columns customerId / artisanId)
    await safeDelete(HireRequest, { [Op.or]: [{ customerId: id }, { artisanId: id }] });

    // 9. Order Disputes (columns reporterId / reportedUserId)
    await safeDelete(OrderDispute, { [Op.or]: [{ reporterId: id }, { reportedUserId: id }] });

    // 10. Delivery Orders
    await safeDelete(DeliveryOrder, { [Op.or]: [{ customerId: id }, { deliveryPersonId: id }] });

    // 11. Messages & Notifications
    await safeDelete(Message, { senderId: id });
    await safeDelete(Notification, { userId: id });

    // 12. Reviews (columns customerId / artisanId)
    await safeDelete(Review, { [Op.or]: [{ customerId: id }, { artisanId: id }] });

    // 13. Interactions, Stories, Favorites
    await safeDelete(UserInteraction, { userId: id });
    await safeDelete(Story, { artisanId: id });
    await safeDelete(FavoriteArtisan, { [Op.or]: [{ userId: id }, { artisanId: id }] });

    // 14. Finally, delete the User record itself
    await user.destroy();

    console.log(`[Admin] Successfully deleted user ${user.name} (${user.email}) and all related data`);

    return res.json({
      success: true,
      message: `User ${user.name} and all related account data were permanently deleted.`,
    });
  } catch (error) {
    console.error('deleteUser error:', error);
    return res.status(500).json({
      error: 'Failed to delete user and related data',
      details: error.message || error.toString(),
    });
  }
};



