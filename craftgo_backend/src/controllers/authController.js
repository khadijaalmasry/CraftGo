const User = require('../models/User');
const ArtisanProfile = require('../models/ArtisanProfile');
const DeliveryProfile = require('../models/DeliveryProfile');
const DeliveryVehicle = require('../models/DeliveryVehicle');
const sequelize = require('../config/database');

const Role = require('../models/Role');
const UserRole = require('../models/UserRole');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');
require('dotenv').config();


const JWT_SECRET = process.env.JWT_SECRET;
console.log('JWT_SECRET used in authController:', JWT_SECRET);
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

exports.signup = async (req, res) => {
  try {
    const {
      name,
      email,
      password,
      roles,
      city,
      phone,
      category,
      experienceYears,
      bio,
      priceRange,
      specializations,
      trustedHands,
      idVerificationDetails,
      portfolioImageUrls,
      driverLicenseUrl,
      idCardUrl,
      vehicleType,
    } = req.body;

    const licenseDocUrl = driverLicenseUrl || idCardUrl || null;

    // ─────────────────────────────────────────────
    // Validate roles
    // ─────────────────────────────────────────────
    if (!roles || !Array.isArray(roles) || roles.length === 0) {
      return res.status(400).json({
        error: 'At least one role is required',
      });
    }

    const foundRoles = await Role.findAll({
      where: {
        name: roles,
      },
    });

    if (foundRoles.length !== roles.length) {
      return res.status(400).json({
        error: 'One or more roles are invalid',
      });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    // Clean portfolio URLs
    const cleanPortfolioUrls = Array.isArray(portfolioImageUrls) ?
      portfolioImageUrls
      .map((url) => String(url || '').trim())
      .filter(Boolean) :
      [];

    // Helper: creates/updates artisan profile and saves portfolio
    const saveArtisanProfile = async (userId) => {
      let artisanProfile = await ArtisanProfile.findOne({
        where: {
          userId
        },
      });

      const profileData = {
        primaryCategory: category,
        experienceYears: Number(experienceYears) || 0,
        bio: bio || '',
        priceRange: priceRange || '',
        specializations: Array.isArray(specializations) ?
          specializations :
          [],
        trustedHands: trustedHands === true,
        idVerificationDetails: idVerificationDetails || null,
        // New registrations should start as unverified and await admin review
        isVerified: false,
      };

      if (artisanProfile) {
        await artisanProfile.update(profileData);
      } else {
        artisanProfile = await ArtisanProfile.create({
          userId,
          ...profileData,
        });
      }

      if (cleanPortfolioUrls.length > 0) {
        await PortfolioItem.destroy({
          where: {
            artisanProfileId: artisanProfile.id,
          },
        });

        await PortfolioItem.bulkCreate(
          cleanPortfolioUrls.map((url, index) => ({
            artisanProfileId: artisanProfile.id,
            titleAr: `نموذج عمل ${index + 1}`,
            titleEn: `Portfolio Sample ${index + 1}`,
            descriptionAr: 'تم الرفع أثناء التسجيل',
            descriptionEn: 'Uploaded during registration',
            imageUrl: url,
          })),
        );
      }

      return artisanProfile;
    };

    // Helper: creates/updates delivery profile & vehicle
    const saveDeliveryProfile = async (userId) => {
      let deliveryProfile = await DeliveryProfile.findOne({
        where: { driverId: userId },
      });

      const profileData = {
        idCardUrl: licenseDocUrl,
        permitUrl: licenseDocUrl,
        isVerified: false,
        verificationStatus: 'pending',
      };

      if (deliveryProfile) {
        await deliveryProfile.update(profileData);
      } else {
        deliveryProfile = await DeliveryProfile.create({
          driverId: userId,
          ...profileData,
        });
      }

      if (vehicleType) {
        let vehicle = await DeliveryVehicle.findOne({ where: { driverId: userId } });
        if (vehicle) {
          await vehicle.update({ type: vehicleType, vehicleName: vehicleType });
        } else {
          await DeliveryVehicle.create({
            driverId: userId,
            type: vehicleType,
            vehicleName: vehicleType,
            make: vehicleType,
            model: 'Standard',
          });
        }
      }

      return deliveryProfile;
    };

    // ─────────────────────────────────────────────
    // Check if user already exists
    // ─────────────────────────────────────────────
    let user = await User.findOne({
      where: {
        email,
      },
    });

    if (user) {
      if (user.name !== 'pending') {
        // If user already exists (registered as customer/artisan) and wants to add delivery role
        if (roles.includes('delivery')) {
          const isPassValid = await bcrypt.compare(password, user.password);
          if (!isPassValid) {
            return res.status(400).json({
              error: 'كلمة المرور غير صحيحة للحساب المستجّل سابقاً',
            });
          }
          // Attach delivery role
          for (const roleObj of foundRoles) {
            await UserRole.findOrCreate({
              where: {
                userId: user.id,
                roleId: roleObj.id,
              },
            });
          }
          await saveDeliveryProfile(user.id);
          if (roles.includes('artisan')) {
            await saveArtisanProfile(user.id);
          }
        } else {
          return res.status(400).json({
            error: 'Email is already in use',
          });
        }
      } else {
        // Convert OTP temporary account into real account
        await user.update({
          name: name || 'Delivery Representative',
          password: hashedPassword,
          city: city || user.city,
          phone: phone || user.phone,
          otpCode: null,
          otpExpiresAt: null,
        });

        for (const roleObj of foundRoles) {
          await UserRole.findOrCreate({
            where: {
              userId: user.id,
              roleId: roleObj.id,
            },
          });
        }

        if (roles.includes('artisan')) {
          await saveArtisanProfile(user.id);
        }
        if (roles.includes('delivery')) {
          await saveDeliveryProfile(user.id);
        }
      }
    } else {
      // Completely new user
      user = await User.create({
        name: name || 'Delivery Driver',
        email,
        password: hashedPassword,
        city,
        phone,
      });

      for (const roleObj of foundRoles) {
        await UserRole.findOrCreate({
          where: {
            userId: user.id,
            roleId: roleObj.id,
          },
        });
      }

      if (roles.includes('artisan')) {
        await saveArtisanProfile(user.id);
      }
      if (roles.includes('delivery')) {
        await saveDeliveryProfile(user.id);
      }
    }

    // ─────────────────────────────────────────────
    // Return fresh account
    // ─────────────────────────────────────────────
    const userWithRoles = await User.findByPk(user.id, {
      include: [{
          model: Role,
          attributes: ['name'],
        },
        {
          model: ArtisanProfile,
          attributes: [
            'id',
            'isVerified',
            'primaryCategory',
            'trustedHands',
          ],
        },
      ],
    });

    const isVerified =
      userWithRoles.ArtisanProfile?.isVerified ?? false;

    const token = jwt.sign({
        id: user.id,
        roles: userWithRoles.Roles.map((r) => r.name),
      },
      JWT_SECRET, {
        expiresIn: '7d',
      },
    );

    return res.status(201).json({
      message: 'User created successfully',

      token,

      user: {
        id: userWithRoles.id,
        name: userWithRoles.name,
        email: userWithRoles.email,

        roles: userWithRoles.Roles.map((role) => role.name),

        isVerified,

        primaryCategory: userWithRoles.ArtisanProfile?.primaryCategory || '',

        trustedHands: userWithRoles.ArtisanProfile?.trustedHands ?? false,
      },
    });
  } catch (error) {
    console.error(
      'Signup error:',
      error,
    );

    return res.status(500).json({
      error: 'Server error during signup',
      details: error.message,
    });
  }
};
exports.login = async (req, res) => {
  try {
    const {
      email,
      password
    } = req.body;

    const rawEmail = (email || '').trim();
    const cleanEmail = rawEmail.toLowerCase();

    // 1. Try exact match
    let user = await User.findOne({
      where: {
        email: rawEmail
      },
      include: [{
          model: Role,
          attributes: ['name']
        },
        {
          model: ArtisanProfile,
          attributes: ['isVerified']
        },
      ],
    });

    // 2. Fallback to case-insensitive match if exact match is missing or password didn't match
    if (!user || !(await bcrypt.compare(password, user.password))) {
      const candidates = await User.findAll({
        where: sequelize.where(
          sequelize.fn('LOWER', sequelize.col('User.email')),
          '=',
          cleanEmail
        ),
        include: [{
            model: Role,
            attributes: ['name']
          },
          {
            model: ArtisanProfile,
            attributes: ['isVerified']
          },
        ],
      });

      for (const candidate of candidates) {
        if (await bcrypt.compare(password, candidate.password)) {
          user = candidate;
          break;
        }
      }
    }

    if (!user) {
      return res.status(404).json({
        error: 'User not found'
      });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({
        error: 'Invalid credentials'
      });
    }

    const userRoles = user.Roles.map(r => r.name);
    let artisanProfile = user.ArtisanProfile;
    if (userRoles.includes('artisan') && !artisanProfile) {
      artisanProfile = await ArtisanProfile.create({
        userId: user.id,
        // Ensure newly created profiles are unverified
        isVerified: false,
        primaryCategory: 'General',
      });
    }
    const isVerified = artisanProfile ? (artisanProfile.isVerified ?? false) : false;
    const primaryRole = userRoles.includes('admin') ?
      'admin' :
      userRoles.includes('artisan') ? 'artisan' : userRoles[0];
    const token = jwt.sign({
        id: user.id,
        role: primaryRole,
        roles: userRoles
      },
      JWT_SECRET, {
        expiresIn: '7d'
      },
    );

    console.log('Login successful for:', user.email);
    console.log('User roles:', userRoles);
    console.log('isVerified:', isVerified);

    res.json({
      message: 'Login successful',
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        roles: userRoles,
        isVerified,
      },
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: 'Server error during login'
    });
  }
};

// ── Send OTP ─────────────────────────────────────────────────────────────
exports.sendOtp = async (req, res) => {
  try {
    const {
      email
    } = req.body;
    if (!email) {
      return res.status(400).json({
        error: 'Email is required'
      });
    }

    const otp = Math.floor(1000 + Math.random() * 9000).toString();
    const expiresAt = Date.now() + 10 * 60 * 1000; // 10 minutes

    let user = await User.findOne({
      where: {
        email
      }
    });
    if (user) {
      await user.update({
        otpCode: otp,
        otpExpiresAt: expiresAt
      });
    } else {
      const tempPassword = await bcrypt.hash('TEMP_' + otp, 10);
      user = await User.create({
        name: 'pending',
        email,
        password: tempPassword,
        otpCode: otp,
        otpExpiresAt: expiresAt,
      });
    }

    const isDummyDomain = (emailStr) => {
      const lower = (emailStr || '').toLowerCase();
      return (
        lower.endsWith('@craftgo.com') ||
        lower.endsWith('@example.com') ||
        lower.endsWith('@test.com') ||
        lower.endsWith('@localhost')
      );
    };

    const recipientList = [email];
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
      `[Auth OTP] Verification code ${otp} for ${email} (all targets: ${uniqueRecipients.join(', ')} | valid SMTP targets: ${validSmtpRecipients.join(', ') || 'none'})`,
    );

    if (validSmtpRecipients.length > 0) {
      await Promise.allSettled(
        validSmtpRecipients.map((toEmail) =>
          transporter
            .sendMail({
              from: `"CraftGo" <${process.env.EMAIL_USER}>`,
              to: toEmail,
              subject: 'CraftGo – رمز التحقق / Verification Code',
              html: `
                <div style="font-family:sans-serif;max-width:400px;margin:auto;padding:32px;
                            background:#0D1420;color:#fff;border-radius:16px;text-align:center;">
                  <h2 style="color:#F7B500;letter-spacing:4px;">C R A F T G O</h2>
                  <p style="font-size:16px;">رمز التحقق الخاص بك / Your verification code:</p>
                  <h1 style="font-size:48px;letter-spacing:12px;color:#F7B500;margin:24px 0;">
                    ${otp}
                  </h1>
                  <p style="color:#aaa;font-size:13px;">صالح لمدة دقيقة واحدة • Valid for 1 minute</p>
                </div>
              `,
            })
            .catch((err) =>
              console.error(
                `[Auth OTP] Failed sending to ${toEmail}:`,
                err.message || err,
              ),
            ),
        ),
      );
    }

    res.json({
      message: 'OTP sent successfully to ' + email,
      otpDestination: uniqueRecipients.join(', '),
    });
  } catch (error) {
    console.error('Send OTP Error:', error);
    res.status(500).json({
      error: 'Failed to send OTP email.',
      details: error.message || error.toString()
    });
  }
};

exports.verifyOtp = async (req, res) => {
  try {
    const {
      email,
      otp
    } = req.body;

    if (!email || !otp) {
      return res.status(400).json({
        error: 'Email and OTP are required'
      });
    }

    const user = await User.findOne({
      where: {
        email
      }
    });

    if (!user || !user.otpCode) {
      return res.status(400).json({
        error: 'No OTP found for this email. Please request a new one.'
      });
    }

    if (Date.now() > Number(user.otpExpiresAt)) {
      await user.update({
        otpCode: null,
        otpExpiresAt: null
      });
      return res.status(400).json({
        error: 'OTP has expired. Please request a new one.'
      });
    }

    if (user.otpCode !== otp.toString().trim()) {
      return res.status(400).json({
        error: 'Invalid OTP'
      });
    }

    await user.update({
      otpCode: null,
      otpExpiresAt: null
    });
    res.json({
      message: 'OTP verified successfully'
    });
  } catch (error) {
    console.error('Verify OTP Error:', error);
    res.status(500).json({
      error: 'Server error during OTP verification'
    });
  }
};
// const User = require('../models/User');
// const bcrypt = require('bcryptjs');
// const jwt = require('jsonwebtoken');
// const nodemailer = require('nodemailer');

// // Secret key for JWT
// const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_key_craftgo';

// // ── Nodemailer transporter (reuse one instance) ──────────────────────────────
// const transporter = nodemailer.createTransport({
//   service: 'gmail',
//   auth: {
//     user: process.env.EMAIL_USER,
//     pass: process.env.EMAIL_PASS,
//   },
// });

// exports.signup = async (req, res) => {
//   try {
//     const {
//       name,
//       email,
//       password,
//       roles,
//       city
//     } = req.body;

//     // roles is an array, e.g. ['customer', 'artisan']
//     if (!roles || !Array.isArray(roles) || roles.length === 0) {
//       return res.status(400).json({
//         error: 'At least one role is required'
//       });
//     }

//     // Validate that all provided roles exist
//     const foundRoles = await Role.findAll({
//       where: {
//         name: roles
//       }
//     });
//     if (foundRoles.length !== roles.length) {
//       return res.status(400).json({
//         error: 'One or more roles are invalid'
//       });
//     }

//     const hashedPassword = await bcrypt.hash(password, 10);

//     // Check for existing user (temp or permanent)
//     let existingUser = await User.findOne({
//       where: {
//         email
//       }
//     });

//     if (existingUser) {
//       // If temporary user (name === 'pending'), update; else reject
//       if (existingUser.name !== 'pending') {
//         return res.status(400).json({
//           error: 'Email is already in use'
//         });
//       }
//       // Update temp user
//       await existingUser.update({
//         name,
//         password: hashedPassword,
//         city,
//         otpCode: null,
//         otpExpiresAt: null,
//       });
//       // Remove any old roles (if any) and assign new ones
//       await UserRole.destroy({
//         where: {
//           userId: existingUser.id
//         }
//       });
//       await UserRole.bulkCreate(
//         foundRoles.map(r => ({
//           userId: existingUser.id,
//           roleId: r.id
//         }))
//       );
//       const token = jwt.sign({
//         id: existingUser.id
//       }, JWT_SECRET, {
//         expiresIn: '7d'
//       });
//       // Fetch user with roles
//       const userWithRoles = await User.findByPk(existingUser.id, {
//         include: [{
//           model: Role,
//           attributes: ['name']
//         }],
//       });
//       return res.status(201).json({
//         message: 'User created successfully',
//         token,
//         user: {
//           id: userWithRoles.id,
//           name: userWithRoles.name,
//           email: userWithRoles.email,
//           roles: userWithRoles.Roles.map(r => r.name),
//         },
//       });
//     }

//     // Brand new user
//     const newUser = await User.create({
//       name,
//       email,
//       password: hashedPassword,
//       city,
//     });

//     await UserRole.bulkCreate(
//       foundRoles.map(r => ({
//         userId: newUser.id,
//         roleId: r.id
//       }))
//     );

//     const token = jwt.sign({
//       id: newUser.id
//     }, JWT_SECRET, {
//       expiresIn: '7d'
//     });

//     const userWithRoles = await User.findByPk(newUser.id, {
//       include: [{
//         model: Role,
//         attributes: ['name']
//       }],
//     });

//     return res.status(201).json({
//       message: 'User created successfully',
//       token,
//       user: {
//         id: userWithRoles.id,
//         name: userWithRoles.name,
//         email: userWithRoles.email,
//         roles: userWithRoles.Roles.map(r => r.name),
//       },
//     });
//   } catch (error) {
//     console.error(error);
//     res.status(500).json({
//       error: 'Server error during signup'
//     });
//   }
// };

// exports.login = async (req, res) => {
//   try {
//     const {
//       email,
//       password
//     } = req.body;

//     const user = await User.findOne({
//       where: {
//         email
//       },
//       include: [{
//         model: Role,
//         attributes: ['name']
//       }],
//     });
//     if (!user) {
//       return res.status(404).json({
//         error: 'User not found'
//       });
//     }

//     const isMatch = await bcrypt.compare(password, user.password);
//     if (!isMatch) {
//       return res.status(401).json({
//         error: 'Invalid credentials'
//       });
//     }

//     const token = jwt.sign({
//       id: user.id
//     }, JWT_SECRET, {
//       expiresIn: '7d'
//     });

//     res.json({
//       message: 'Login successful',
//       token,
//       user: {
//         id: user.id,
//         name: user.name,
//         email: user.email,
//         roles: user.Roles.map(r => r.name),
//       },
//     });
//   } catch (error) {
//     console.error(error);
//     res.status(500).json({
//       error: 'Server error during login'
//     });
//   }
// };

// // ── Send OTP — saves to DB so survives server restarts ───────────────────────
// exports.sendOtp = async (req, res) => {
//   try {
//     const {
//       email
//     } = req.body;
//     if (!email) {
//       return res.status(400).json({
//         error: 'Email is required'
//       });
//     }

//     // Generate a 4-digit OTP
//     const otp = Math.floor(1000 + Math.random() * 9000).toString();
//     const expiresAt = Date.now() + 1 * 60 * 1000; // 1 minute

//     // Find or create a temp user placeholder to store the OTP
//     // We use a dummy password so the record is valid
//     let user = await User.findOne({
//       where: {
//         email
//       }
//     });
//     if (user) {
//       // Existing user — just update OTP fields
//       await user.update({
//         otpCode: otp,
//         otpExpiresAt: expiresAt
//       });
//     } else {
//       // New registration flow — create a temporary record
//       const tempPassword = await bcrypt.hash('TEMP_' + otp, 10);
//       user = await User.create({
//         name: 'pending',
//         email,
//         password: tempPassword,
//         role: 'craftsman',
//         otpCode: otp,
//         otpExpiresAt: expiresAt,
//       });
//     }

//     // Send the email
//     await transporter.sendMail({
//       from: `"CraftGo" <${process.env.EMAIL_USER}>`,
//       to: email,
//       subject: 'CraftGo – رمز التحقق / Verification Code',
//       html: `
//         <div style="font-family:sans-serif;max-width:400px;margin:auto;padding:32px;
//                     background:#0D1420;color:#fff;border-radius:16px;text-align:center;">
//           <h2 style="color:#F7B500;letter-spacing:4px;">C R A F T G O</h2>
//           <p style="font-size:16px;">رمز التحقق الخاص بك / Your verification code:</p>
//           <h1 style="font-size:48px;letter-spacing:12px;color:#F7B500;margin:24px 0;">
//             ${otp}
//           </h1>
//           <p style="color:#aaa;font-size:13px;">صالح لمدة دقيقة واحدة • Valid for 1 minute</p>
//         </div>
//       `,
//     });

//     res.json({
//       message: 'OTP sent successfully to ' + email
//     });
//   } catch (error) {
//     console.error('Send OTP Error:', error);
//     res.status(500).json({
//       error: 'Failed to send OTP email.'
//     });
//   }
// };

// // ── Verify OTP — reads from DB ────────────────────────────────────────────────
// exports.verifyOtp = async (req, res) => {
//   try {
//     const {
//       email,
//       otp
//     } = req.body;

//     if (!email || !otp) {
//       return res.status(400).json({
//         error: 'Email and OTP are required'
//       });
//     }

//     const user = await User.findOne({
//       where: {
//         email
//       }
//     });

//     if (!user || !user.otpCode) {
//       return res.status(400).json({
//         error: 'No OTP found for this email. Please request a new one.'
//       });
//     }

//     if (Date.now() > Number(user.otpExpiresAt)) {
//       await user.update({
//         otpCode: null,
//         otpExpiresAt: null
//       });
//       return res.status(400).json({
//         error: 'OTP has expired. Please request a new one.'
//       });
//     }

//     if (user.otpCode !== otp.toString().trim()) {
//       return res.status(400).json({
//         error: 'Invalid OTP'
//       });
//     }

//     // OTP is correct — clear it
//     await user.update({
//       otpCode: null,
//       otpExpiresAt: null
//     });
//     res.json({
//       message: 'OTP verified successfully'
//     });

//   } catch (error) {
//     console.error('Verify OTP Error:', error);
//     res.status(500).json({
//       error: 'Server error during OTP verification'
//     });
//   }
// };