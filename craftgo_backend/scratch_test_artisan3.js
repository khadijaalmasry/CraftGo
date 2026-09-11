(async () => {
  const baseUrl = "http://localhost:5000/api";
  const sequelize = require("./src/config/database");
  const Order = require("./src/models/Order");
  const User = require("./src/models/User");
  await sequelize.authenticate();

  // Generate a fresh token for maram directly
  const jwt = require("jsonwebtoken");
  const JWT_SECRET = process.env.CRAFTGO_JWT_SECRET || require("dotenv").config() && process.env.JWT_SECRET;
  console.log("JWT_SECRET:", JWT_SECRET ? JWT_SECRET.substring(0, 10) + "..." : "NOT FOUND");

  const maramId = "ea47b473-0832-43c3-adcc-cc8377ba0e4d";
  const maramToken = jwt.sign({ id: maramId }, "craftgo_super_secret_jwt_key_2024", { expiresIn: "1d" });
  
  const r = await fetch(`${baseUrl}/orders/artisan`, { headers: { Authorization: `Bearer ${maramToken}` } });
  const data = await r.json();
  console.log("\n[GET /orders/artisan] Status:", r.status);
  console.log(JSON.stringify(data, null, 2));
  process.exit(0);
})();
