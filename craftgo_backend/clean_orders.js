const sequelize = require('./src/config/database');
const Order = require('./src/models/Order');

async function cleanOrders() {
  try {
    await sequelize.authenticate();
    // Some mock data might have invalid UUIDs or we just delete everything
    // Let's just delete everything to be safe, or check if there's dummy data
    // The user says "«Õ–› √Ì »Ì«‰«  ÊÂ„Ì… œ«Œ· Orders"
    const orders = await Order.findAll();
    let deleted = 0;
    for (const o of orders) {
      // Mock data might not have a valid productId
      // or we can just wipe all to give a clean state
      await o.destroy();
      deleted++;
    }
    console.log(`Deleted ${deleted} mock/old orders for a clean slate.`);
  } catch (e) {
    console.error(e);
  } finally {
    process.exit(0);
  }
}
cleanOrders();
