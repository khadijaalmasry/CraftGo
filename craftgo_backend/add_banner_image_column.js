const sequelize = require('./src/config/database');

async function migrate() {
  try {
    await sequelize.authenticate();

    console.log('✅ Database connected');

    const [columns] = await sequelize.query(
      'PRAGMA table_info(Users);'
    );

    const hasBannerImage = columns.some(
      (column) => column.name === 'bannerImage'
    );

    if (!hasBannerImage) {
      await sequelize.query(
        'ALTER TABLE Users ADD COLUMN bannerImage TEXT;'
      );

      console.log('✅ bannerImage column added to Users');
    } else {
      console.log('✅ bannerImage column already exists');
    }

    console.log('✅ Migration completed');
  } catch (error) {
    console.error('❌ Migration failed:', error);
  } finally {
    await sequelize.close();
  }
}

migrate();