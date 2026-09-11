// migrate-custom-orders.js
const {
    sequelize
} = require('./config/database'); // adjust if needed

async function migrate() {
    try {
        await sequelize.query(`ALTER TABLE CustomOrderRequests ADD COLUMN stripePaymentIntentId TEXT;`);
        await sequelize.query(`ALTER TABLE CustomOrderRequests ADD COLUMN paymentStatus TEXT DEFAULT 'unpaid';`);
        await sequelize.query(`ALTER TABLE CustomOrderRequests ADD COLUMN paidAt DATETIME;`);
        console.log('✅ Migration successful');
    } catch (error) {
        console.error('❌ Migration failed:', error.message);
    }
    migrate();
}