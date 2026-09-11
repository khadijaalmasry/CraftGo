const User = require('../models/User');

// GET /api/auth/me
// جلب بروفايل المستخدم الحالي
exports.getProfile = async (req, res) => {
  try {
    const user = await User.findByPk(req.user.id, {
      attributes: {
        exclude: ['password'],
      },
    });

    if (!user) {
      return res.status(404).json({
        error: 'User not found',
      });
    }

    return res.json(user);
  } catch (error) {
    console.error('getProfile error:', error);

    return res.status(500).json({
      error: 'Failed to fetch profile',
    });
  }
};

// GET /api/auth/user/:id
// جلب البيانات العامة لمستخدم آخر
exports.getPublicUserProfile = async (req, res) => {
  try {
    const { id } = req.params;

    if (!id || typeof id !== 'string') {
      return res.status(400).json({
        error: 'User id is required',
      });
    }

    const user = await User.findByPk(id, {
      attributes: [
'id',
'name',
'city',
'phone',
'profileImage'
],
    });

    if (!user) {
      return res.status(404).json({
        error: 'User not found',
      });
    }

    return res.json(user);
  } catch (error) {
    console.error('getPublicUserProfile error:', error);

    return res.status(500).json({
      error: 'Failed to fetch public user profile',
    });
  }
};

// PUT /api/auth/profile
// تعديل بيانات المستخدم الحالي
exports.updateProfile = async (req, res) => {
  try {
    const {
      name,
      city,
      location,
      phone,
      bio,
      bankName,
      accountTitle,
      iban,
      profileImage,
    } = req.body;

    const user = await User.findByPk(req.user.id);

    if (!user) {
      return res.status(404).json({
        error: 'User not found',
      });
    }

    if (typeof name === 'string' && name.trim().length > 0) {
      user.name = name.trim();
    }

    if (typeof city === 'string') {
      user.city = city.trim();
    }

    if (typeof location === 'string') {
      user.location = location.trim();
    }

    if (typeof phone === 'string') {
      user.phone = phone.trim();
    }

    if (typeof bio === 'string') {
      user.bio = bio.trim();
    }

    if (typeof bankName === 'string') {
      user.bankName = bankName.trim();
    }

    if (typeof accountTitle === 'string') {
      user.accountTitle = accountTitle.trim();
    }

    if (typeof iban === 'string') {
      user.iban = iban.trim();
    }

    if (typeof profileImage === 'string') {
      user.profileImage = profileImage.trim();
    }

    await user.save();

    const {
      password: _password,
      ...safeUser
    } = user.toJSON();

    return res.json({
      message: 'Profile updated successfully',
      user: safeUser,
    });
  } catch (error) {
    console.error('updateProfile error:', error);

    return res.status(500).json({
      error: 'Failed to update profile',
    });
  }
};