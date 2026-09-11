/**
 * migrate_user_columns.js
 * One-time migration: adds new columns to the Users table in the
 * existing SQLite database WITHOUT dropping or recreating any data.
 * Run once with: node migrate_user_columns.js
 */
const sequelize = require('./src/config/database');

async function migrate() {
  const newColumns = [
    ['location',     'VARCHAR(255)'],
    ['bio',          'TEXT'],
    ['bankName',     'VARCHAR(255)'],
    ['accountTitle', 'VARCHAR(255)'],
    ['iban',         'VARCHAR(255)'],
  ];

  const [existingCols] = await sequelize.query(`PRAGMA table_info(Users);`);
  const existingNames = new Set(existingCols.map(c => c.name));

  for (const [colName, colType] of newColumns) {
    if (existingNames.has(colName)) {
      console.log(`  ✓ Column "${colName}" already exists – skipping`);
      continue;
    }
    await sequelize.query(`ALTER TABLE "Users" ADD COLUMN "${colName}" ${colType};`);
    console.log(`  + Added column "${colName}" (${colType})`);
  }

  console.log('\nMigration complete. You can now restart the server.');
  process.exit(0);
}

migrate().catch(err => {
  console.error('Migration failed:', err.message);
  process.exit(1);
});
