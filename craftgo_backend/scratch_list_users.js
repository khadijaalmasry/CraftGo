(async () => {
  const sequelize = require("./src/config/database");
  const User = require("./src/models/User");
  await sequelize.authenticate();

  // List all users with emails
  const users = await User.findAll({ attributes: ["id", "name", "email"] });
  console.log("All users:");
  users.forEach(u => console.log(" -", u.name, "|", u.email, "|", u.id));
  process.exit(0);
})();
