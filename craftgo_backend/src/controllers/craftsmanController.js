const {
    Op
} = require('sequelize');
const User = require('../models/User');
const ArtisanProfile = require('../models/ArtisanProfile');
const PortfolioItem = require('../models/PortfolioItem');
const Review = require('../models/Review');
const Order = require('../models/Order');
const Product = require('../models/Product');
const UserInteraction = require('../models/UserInteraction');

// ─── GET Profile + Stats ────────────────────────────────────────────────
exports.getProfile = async (req, res) => {
    try {
        const {
            id
        } = req.params; // artisan user ID

        // 1. Fetch user + artisan profile
        const user = await User.findByPk(id, {
            include: [{
                model: ArtisanProfile,
                as: 'ArtisanProfile'
            }, ],
        });

        if (!user) {
            return res.status(404).json({
                error: 'User not found'
            });
        }

        // 2. Compute stats
        const artisanId = user.id;

        // Completed orders count & total earnings
        const completedOrders = await Order.findAll({
            where: {
                craftsmanId: artisanId,
                status: 'completed'
            },
        });
        const totalCompleted = completedOrders.length;

const totalEarnings = completedOrders.reduce(
  (sum, order) => sum + Number(order.totalAmount || 0),
  0
);

        // Average rating
        const reviews = await Review.findAll({
            where: {
                artisanId: artisanId
            },
            attributes: ['rating'],
        });
        let avgRating = null;

if (reviews.length > 0) {
  const sum = reviews.reduce(
    (total, review) => total + Number(review.rating || 0),
    0
  );

  avgRating = Number((sum / reviews.length).toFixed(1));
}

        // Views: sum of scores from interactions on the artisan's products
        const products = await Product.findAll({
            where: {
                craftsmanId: artisanId
            },
            attributes: ['id'],
        });
        const productIds = products.map(p => p.id);
        let totalViews = 0;
        if (productIds.length > 0) {
            const interactions = await UserInteraction.findAll({
                where: {
                    productId: {
                        [Op.in]: productIds
                    },
                    interactionType: 'view',
                },
                attributes: ['score'],
            });
            totalViews = interactions.reduce(
  (sum, interaction) => sum + Number(interaction.score || 0),
  0
);
        }

        // 3. Build response
        const profile = user.ArtisanProfile || {};
        res.json({
            id: user.id,
            name: user.name,
            email: user.email,
            city: user.city,
            profileImage: user.profileImage,
bannerImage: profile.bannerImage || null,
            bio: profile.bio || '',
            experienceYears: profile.experienceYears || 0,
            primaryCategory: profile.primaryCategory || '',
            additionalCategories: profile.additionalCategories || [],
            isVerified: profile.isVerified || false,
            trustedHands: profile.trustedHands || false,
            priceRange: profile.priceRange || '',
            specializations: profile.specializations || [],
            stats: {
                earnings: totalEarnings,
                rating: avgRating,
                completedOrders: totalCompleted,
                views: totalViews,
            },
            artisanProfileId: profile.id,
        });
    } catch (error) {
        console.error('Error in getProfile:', error);
        res.status(500).json({
            error: 'Failed to fetch profile'
        });
    }
};

// ─── UPDATE Profile ─────────────────────────────────────────────────────
exports.updateProfile = async (req, res) => {
    try {
        const {
            id
        } = req.params; // artisan user ID
        const {
    name,
    city,
    bio,
    experienceYears,
    primaryCategory,
    additionalCategories,
    priceRange,
    specializations,
    profileImage,
    bannerImage,
} = req.body;

        // Only allow the user themselves or admin
        if (req.user.id !== id && req.user.role !== 'admin') {
            return res.status(403).json({
                error: 'Forbidden: You can only update your own profile'
            });
        }

        // Update User
        const user = await User.findByPk(id);
        if (!user) {
            return res.status(404).json({
                error: 'User not found'
            });
        }
        if (name) user.name = name;
        if (city) user.city = city;
        if (profileImage) user.profileImage = profileImage;
        if (bannerImage !== undefined) {
    user.bannerImage = bannerImage;
}
        await user.save();

        // Find or create ArtisanProfile
        let profile = await ArtisanProfile.findOne({
            where: {
                userId: id
            }
        });
        if (!profile) {
            profile = await ArtisanProfile.create({
                userId: id
            });
        }

        // Update fields
        if (bio !== undefined) profile.bio = bio;
        if (experienceYears !== undefined) profile.experienceYears = experienceYears;
        if (primaryCategory !== undefined) profile.primaryCategory = primaryCategory;
        if (additionalCategories !== undefined) profile.additionalCategories = additionalCategories;
        if (priceRange !== undefined) profile.priceRange = priceRange;
        if (specializations !== undefined) profile.specializations = specializations;
        if (req.body.idVerificationDetails !== undefined) {
            profile.idVerificationDetails = req.body.idVerificationDetails;
        }
        if (req.body.trustedHands !== undefined) {
            profile.trustedHands = req.body.trustedHands;
        }
        await profile.save();

        // Fetch updated profile
        const updated = await User.findByPk(id, {
            include: [{
                model: ArtisanProfile,
                as: 'ArtisanProfile'
            }],
        });

        res.json({
    message: 'Profile updated successfully',
    profile: {
        id: updated.id,
        name: updated.name,
        city: updated.city,
        profileImage: updated.profileImage,
        bannerImage: updated.ArtisanProfile?.bannerImage || null,
        ...updated.ArtisanProfile.toJSON(),
    },
});
    } catch (error) {
        console.error('Error in updateProfile:', error);
        res.status(500).json({
            error: 'Failed to update profile'
        });
    }
};

// ─── GET Portfolio ──────────────────────────────────────────────────────
exports.getPortfolio = async (req, res) => {
    try {
        const {
            id
        } = req.params; // artisan user ID

        // Get the artisan profile
        const profile = await ArtisanProfile.findOne({
            where: {
                userId: id
            }
        });
        if (!profile) {
            return res.json([]); // no portfolio yet
        }

        const items = await PortfolioItem.findAll({
            where: {
                artisanProfileId: profile.id
            },
            order: [
                ['createdAt', 'DESC']
            ],
        });
        res.json(items);
    } catch (error) {
        console.error('Error in getPortfolio:', error);
        res.status(500).json({
            error: 'Failed to fetch portfolio'
        });
    }
};

// ─── ADD Portfolio Item ────────────────────────────────────────────────
exports.addPortfolioItem = async (req, res) => {
    console.log('✅ addPortfolioItem called');
    try {
        const {
            userId,
            titleAr,
            titleEn,
            descriptionAr,
            descriptionEn,
            imageUrl
        } = req.body; // change to userId
        console.log('📦 Received data:', {
            userId,
            titleAr,
            titleEn
        });

        if (!userId) {
            return res.status(400).json({
                error: 'userId is required'
            });
        }

        // Find the artisan profile by userId
        const profile = await ArtisanProfile.findOne({
            where: {
                userId
            }
        });
        if (!profile) {
            return res.status(404).json({
                error: 'Artisan profile not found for this user'
            });
        }
        if (profile.userId !== req.user.id && req.user.role !== 'admin') {
            return res.status(403).json({
                error: 'Forbidden'
            });
        }

        const item = await PortfolioItem.create({
            artisanProfileId: profile.id,
            titleAr,
            titleEn,
            descriptionAr,
            descriptionEn,
            imageUrl,
        });
        console.log('✅ Portfolio item created:', item.id);
        return res.status(201).json(item);
    } catch (error) {
        console.error('❌ Error in addPortfolioItem:', error);
        return res.status(500).json({
            error: 'Failed to add portfolio item',
            details: error.message
        });
    }
};
// ─── DELETE Portfolio Item ─────────────────────────────────────────────
exports.deletePortfolioItem = async (req, res) => {
    try {
        const {
            itemId
        } = req.params;

        const item = await PortfolioItem.findByPk(itemId, {
            include: [{
                model: ArtisanProfile,
                attributes: ['userId']
            }],
        });
        if (!item) {
            return res.status(404).json({
                error: 'Portfolio item not found'
            });
        }

        // Check ownership
        if (item.ArtisanProfile.userId !== req.user.id && req.user.role !== 'admin') {
            return res.status(403).json({
                error: 'Forbidden: You can only delete your own items'
            });
        }

        await item.destroy();
        res.json({
            message: 'Portfolio item deleted successfully'
        });
    } catch (error) {
        console.error('Error in deletePortfolioItem:', error);
        res.status(500).json({
            error: 'Failed to delete portfolio item'
        });
    }
};

// ─── GET Reviews (with pagination) ────────────────────────────────────
exports.getReviews = async (req, res) => {
    try {
        const {
            id
        } = req.params; // artisan user ID
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 10;
        const offset = (page - 1) * limit;

        const {
            count,
            rows
        } = await Review.findAndCountAll({
            where: {
                artisanId: id
            },
            include: [{
                model: User,
                as: 'customer',
                attributes: ['id', 'name']
            }, ],
            order: [
                ['createdAt', 'DESC']
            ],
            limit,
            offset,
        });

        res.json({
            reviews: rows,
            total: count,
            page,
            totalPages: Math.ceil(count / limit),
        });
    } catch (error) {
        console.error('Error in getReviews:', error);
        res.status(500).json({
            error: 'Failed to fetch reviews'
        });
    }
};

// ─── GET All Craftsmen ────────────────────────────────────────────────
exports.getAllCraftsmen = async (req, res) => {
    try {
        const craftsmen = await User.findAll({
            include: [{
                model: ArtisanProfile,
                as: 'ArtisanProfile',
                required: false
            }],
        });

        // Filter users who have an ArtisanProfile OR have role 'artisan'/'craftsman'
        const verifiedArtisans = craftsmen.filter(c => 
            c.ArtisanProfile != null || c.role === 'artisan' || c.role === 'craftsman'
        );
        const artisanIds = verifiedArtisans.map(c => c.id);

        // Batch load reviews and completed orders for all artisans
        const [reviews, completedOrders] = await Promise.all([
            Review.findAll({
                where: { artisanId: { [Op.in]: artisanIds } },
                attributes: ['artisanId', 'rating'],
            }),
            Order.findAll({
                where: { craftsmanId: { [Op.in]: artisanIds }, status: 'completed' },
                attributes: ['craftsmanId'],
            }),
        ]);

        // Build maps
        const ratingMap = {}; // artisanId -> { sum, count }
        reviews.forEach(r => {
            if (!ratingMap[r.artisanId]) ratingMap[r.artisanId] = { sum: 0, count: 0 };
            ratingMap[r.artisanId].sum += Number(r.rating || 0);
            ratingMap[r.artisanId].count += 1;
        });

        const ordersMap = {}; // artisanId -> count
        completedOrders.forEach(o => {
            ordersMap[o.craftsmanId] = (ordersMap[o.craftsmanId] || 0) + 1;
        });

        const result = verifiedArtisans.map(c => {
            const plainUser = c.toJSON();
            const profile = plainUser.ArtisanProfile || {};
            const artisanRating = ratingMap[c.id];
            const avgRating = artisanRating && artisanRating.count > 0
                ? Number((artisanRating.sum / artisanRating.count).toFixed(1))
                : null;

            return {
                id: plainUser.id,
                name: plainUser.name,
                city: plainUser.city,
                profileImage: plainUser.profileImage,
                primaryCategory: profile.primaryCategory || '',
                bio: profile.bio || '',
                experienceYears: profile.experienceYears || 0,
                isVerified: profile.isVerified || false,
                trustedHands: profile.trustedHands || false,
                averageRating: avgRating,
                completedOrders: ordersMap[c.id] || 0,
                ArtisanProfile: profile,
            };
        });

        res.json(result);
    } catch (error) {
        console.error('Error fetching craftsmen:', error);
        res.status(500).json({ error: 'Failed to fetch craftsmen' });
    }
};