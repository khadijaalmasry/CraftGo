(async () => {
  const sequelize = require('./src/config/database');
  const Order = require('./src/models/Order');
  const User = require('./src/models/User');
  const Product = require('./src/models/Product');
  
  try {
    await sequelize.authenticate();
    
    // Find customer admin
    const customer = await User.findOne({ where: { email: 'admin@craftgo.com' }});
    // Find product
    const product = await Product.findOne();
    const artisan = await User.findByPk(product.craftsmanId);

    // Create an order directly
    const newOrder = await Order.create({
      customerId: customer.id,
      craftsmanId: artisan.id,
      productId: product.id,
      quantity: 2,
      totalAmount: product.price * 2,
      shippingAddress: 'Nablus 123',
      paymentMethod: 'Cash',
      status: 'pending'
    });
    
    console.log("Order created:", newOrder.id);
  } catch (e) {
    console.error(e);
  } finally {
    process.exit(0);
  }
})();
