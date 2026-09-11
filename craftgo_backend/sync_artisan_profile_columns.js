require('dotenv').config();

const sequelize = require('./src/config/database');
const ArtisanProfile = require('./src/models/ArtisanProfile');

async function syncArtisanProfileColumns() {
  try {
    await sequelize.authenticate();

    const queryInterface = sequelize.getQueryInterface();
    const tableName = ArtisanProfile.getTableName();

    const existingColumns =
      await queryInterface.describeTable(tableName);

    const attributes = ArtisanProfile.getAttributes();

    const missingColumns = Object.entries(attributes).filter(
      ([name]) => !existingColumns[name]
    );

    if (missingColumns.length === 0) {
      console.log(
        'ArtisanProfiles is already up to date.'
      );
      return;
    }

    for (const [name, attribute] of missingColumns) {
      console.log(
        `Adding ArtisanProfiles.${name} ...`
      );

      await queryInterface.addColumn(
        tableName,
        name,
        {
          type: attribute.type,
          allowNull: true,
        }
      );
    }

    console.log(
      `Done. Added ${missingColumns.length} missing column(s).`
    );
  } catch (error) {
    console.error(
      'Artisan profile migration failed:',
      error
    );

    process.exitCode = 1;
  } finally {
    await sequelize.close();
  }
}

syncArtisanProfileColumns();