const authController = require('./src/controllers/authController');

const req = {
  body: { email: 'MaramSalmeyeh1@gmail.com' }
};

const res = {
  status: function(code) {
    this.statusCode = code;
    return this;
  },
  json: function(data) {
    console.log('Status:', this.statusCode);
    console.log('JSON Response:', JSON.stringify(data, null, 2));
  }
};

authController.sendOtp(req, res).catch(console.error);
