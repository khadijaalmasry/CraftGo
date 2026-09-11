const sequelize = require('./src/config/database');

const User = require('./src/models/User');
const ArtisanProfile = require('./src/models/ArtisanProfile');
const PortfolioItem = require('./src/models/PortfolioItem');

async function repairKhadijaPortfolio() {
  try {
    await sequelize.authenticate();

    console.log('Database connected ✅');

    const email =
      'MaramSalmeyeh+Jewelry@gmail.com';

    const imageUrl =
      'http://localhost:3000/uploads/image-1786544843006-283045069.webp';

    // 1. Find Khadija
    const user = await User.findOne({
      where: { email },
    });

    if (!user) {
      throw new Error(
        `User not found: ${email}`,
      );
    }

    console.log(
      'User found:',
      user.id,
      user.name,
    );

    // 2. Find artisan profile
    const profile =
      await ArtisanProfile.findOne({
        where: {
          userId: user.id,
        },
      });

    if (!profile) {
      throw new Error(
        'ArtisanProfile not found',
      );
    }

    console.log(
      'Artisan profile found:',
      profile.id,
    );

    // 3. Check if this exact image is already connected
    const existing =
      await PortfolioItem.findOne({
        where: {
          artisanProfileId: profile.id,
          imageUrl,
        },
      });

    if (existing) {
      console.log(
        'Portfolio image is already linked ✅',
      );

      return;
    }

    // 4. Add the missing portfolio item
    const item =
      await PortfolioItem.create({
        artisanProfileId: profile.id,

        titleAr:
          'نموذج أعمال المجوهرات',

        titleEn:
          'Jewelry Portfolio Sample',

        descriptionAr:
          'نموذج عمل تم رفعه أثناء التسجيل',

        descriptionEn:
          'Portfolio sample uploaded during registration',

        imageUrl,
      });

    console.log(
      'Portfolio repaired successfully ✅',
    );

    console.log(
      'PortfolioItem ID:',
      item.id,
    );

    console.log(
      'Image URL:',
      item.imageUrl,
    );
  } catch (error) {
    console.error(
      'Repair failed ❌',
      error,
    );
  } finally {
    await sequelize.close();
  }
}

repairKhadijaPortfolio();