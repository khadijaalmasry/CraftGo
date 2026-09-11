const sequelize = require('./src/config/database');

async function addAiAnalysisColumn() {
  try {
    await sequelize.authenticate();
    console.log('✅ Database connected');

    const [columns] = await sequelize.query(`
      PRAGMA table_info(Products);
    `);

    const alreadyExists = columns.some(
      (column) => column.name === 'aiAnalysis'
    );

    if (alreadyExists) {
      console.log('✅ aiAnalysis column already exists');
      return;
    }

    await sequelize.query(`
      ALTER TABLE Products
      ADD COLUMN aiAnalysis JSON;
    `);

    console.log('✅ aiAnalysis column added successfully');
  } catch (error) {
    console.error('❌ Failed to add aiAnalysis column:', error);
  } finally {
    await sequelize.close();
  }
}

addAiAnalysisColumn();