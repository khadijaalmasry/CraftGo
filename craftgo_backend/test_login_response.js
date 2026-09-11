require('dotenv').config();
const { User, Role, ArtisanProfile } = require('./src/models');

async function testLoginData() {
  try {
    const email = 'MaramSalmeyeh1@gmail.com';
    const user = await User.findOne({
      where: { email },
      include: [
        { model: Role, attributes: ['name'] },
        { model: ArtisanProfile, attributes: ['isVerified'] },
      ],
    });

    if (!user) {
      console.log('User not found');
      return;
    }

    const userRoles = user.Roles.map(r => r.name);
    const isVerified = user.ArtisanProfile?.isVerified ?? false;

    const response = {
      message: 'Login successful',
      token: 'fake-jwt-token',
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        roles: userRoles,
        isVerified,
      },
    };

    console.log(JSON.stringify(response, null, 2));
  } catch (error) {
    console.error(error);
  }
}

testLoginData();
