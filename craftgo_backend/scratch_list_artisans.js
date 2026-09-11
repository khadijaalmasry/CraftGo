(async () => {
  const baseUrl = "http://localhost:5000/api";
  const sequelize = require("./src/config/database");
  const User = require("./src/models/User");
  const Role = require("./src/models/Role");
  await sequelize.authenticate();

  // List all artisans with their emails
  const artisans = await User.findAll({
    include: [{ model: Role, attributes: ["name"], where: { name: "artisan" } }],
    attributes: ["id", "name", "email"]
  });
  console.log("Artisans:");
  artisans.forEach(a => console.log(" -", a.name, a.email, a.id));
  process.exit(0);
})();
