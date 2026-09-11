const { Sequelize, DataTypes } = require('sequelize');
const path = require('path');
const sequelize = new Sequelize({
  dialect: 'sqlite',
  storage: path.join(__dirname, 'craftgo.sqlite'),
  logging: false
});

const User = sequelize.define('User', {
  name: DataTypes.STRING,
  email: DataTypes.STRING
});

const ArtisanProfile = sequelize.define('ArtisanProfile', {
  isVerified: DataTypes.BOOLEAN
});

User.hasOne(ArtisanProfile, { foreignKey: 'userId' });
ArtisanProfile.belongsTo(User, { foreignKey: 'userId' });

async function test() {
  const users = await User.findAll({
    include: [{ model: ArtisanProfile }]
  });
  console.log(JSON.stringify(users, null, 2));
}

test();
