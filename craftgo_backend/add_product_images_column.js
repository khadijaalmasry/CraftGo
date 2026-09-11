const { DataTypes } = require('sequelize');
const sequelize = require('./src/config/database');

async function addProductImagesColumn() {
  try {
    await sequelize.authenticate();

    console.log('Database connected ✅');

    const queryInterface =
      sequelize.getQueryInterface();

    const table =
      await queryInterface.describeTable('Products');

    if (table.images) {
      console.log(
        'Products.images already exists ✅'
      );
      return;
    }

    await queryInterface.addColumn(
      'Products',
      'images',
      {
        type: DataTypes.JSON,
        allowNull: true,
      },
    );

    console.log(
      'Products.images column added successfully ✅'
    );
  } catch (error) {
    console.error(
      'Failed to add images column ❌',
      error,
    );
  } finally {
    await sequelize.close();
  }
}

addProductImagesColumn();