(async () => {
  const baseUrl = "http://localhost:5000/api";

  const post = async (url, body, token) => {
    const h = { "Content-Type": "application/json" };
    if (token) h["Authorization"] = `Bearer ${token}`;
    const r = await fetch(baseUrl + url, { method: "POST", headers: h, body: JSON.stringify(body) });
    return r.json();
  };
  const get = async (url, token) => {
    const r = await fetch(baseUrl + url, { headers: { Authorization: `Bearer ${token}` } });
    const data = await r.json();
    return { status: r.status, data };
  };

  // 1. Login customer (admin has customer role)
  const cLogin = await post("/auth/login", { email: "admin@craftgo.com", password: "123456" });
  const cToken = cLogin.token;
  const customerId = cLogin.user.id;
  console.log("Customer ID:", customerId);

  // 2. Empty cart orders
  const emptyOrders = await get("/orders/customer", cToken);
  console.log("\n[GET /orders/customer] Status:", emptyOrders.status);
  console.log("Success:", emptyOrders.data.success, "Orders count:", emptyOrders.data.orders?.length ?? "N/A");

  // 3. Create a test order via DB node script so we can test properly
  const sequelize = require("./src/config/database");
  const Order = require("./src/models/Order");
  const Product = require("./src/models/Product");
  const User = require("./src/models/User");
  await sequelize.authenticate();
  const product = await Product.findOne();
  const artisan = await User.findByPk(product.craftsmanId);
  const newOrder = await Order.create({
    customerId,
    craftsmanId: artisan.id,
    productId: product.id,
    quantity: 1,
    totalAmount: product.price * 1,
    shippingAddress: "Test Street 5, Nablus",
    paymentMethod: "Cash on Delivery",
    status: "pending"
  });
  console.log("\nTest order created:", newOrder.id);

  // 4. Customer orders
  const custOrders = await get("/orders/customer", cToken);
  console.log("\n[GET /orders/customer] Status:", custOrders.status);
  console.log(JSON.stringify(custOrders.data, null, 2));

  // 5. Artisan orders (login as artisan)
  const aLogin = await post("/auth/login", { email: artisan.email, password: "123456" });
  const aToken = aLogin.token;
  console.log("\nArtisan login:", aLogin.user ? aLogin.user.email : "FAILED");

  const artisanOrders = await get("/orders/artisan", aToken);
  console.log("\n[GET /orders/artisan] Status:", artisanOrders.status);
  console.log(JSON.stringify(artisanOrders.data, null, 2));

  process.exit(0);
})();
