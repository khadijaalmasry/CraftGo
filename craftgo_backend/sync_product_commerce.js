require('dotenv').config();
const sequelize = require('./src/config/database');
const ProductOffer = require('./src/models/ProductOffer');
const ReadyMadePayment = require('./src/models/ReadyMadePayment');

async function addColumn(table, column, sql) {
  const [rows] = await sequelize.query(`PRAGMA table_info(${table})`);
  if (!rows.some(row => row.name === column)) {
    console.log(`Adding ${table}.${column}`);
    await sequelize.query(`ALTER TABLE ${table} ADD COLUMN ${column} ${sql}`);
  }
}

async function main() {
  await addColumn('Orders', 'offerId', 'UUID NULL');
  await addColumn('Orders', 'agreedUnitPrice', 'DECIMAL(10,2) NULL');
  await addColumn('Orders', 'paymentStatus', "VARCHAR(32) NOT NULL DEFAULT 'unpaid'");
  await addColumn('Orders', 'escrowStatus', "VARCHAR(32) NOT NULL DEFAULT 'none'");
  await addColumn('Orders', 'stripeCheckoutSessionId', 'VARCHAR(255) NULL');
  await addColumn('Orders', 'paidAt', 'DATETIME NULL');
  await addColumn('Orders', 'escrowReleasedAt', 'DATETIME NULL');

  await ProductOffer.sync();
  await ReadyMadePayment.sync();
  console.log('Product commerce schema is ready.');
}

main().catch(error => { console.error(error); process.exitCode = 1; }).finally(() => sequelize.close());
