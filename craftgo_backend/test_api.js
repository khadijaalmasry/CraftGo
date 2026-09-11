const http = require('http');

const data = JSON.stringify({ email: 'MaramSalmeyeh1@gmail.com' });

const options = {
  hostname: 'localhost',
  port: 5000,
  path: '/api/auth/send-otp',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length
  }
};

const req = http.request(options, res => {
  let body = '';
  res.on('data', d => body += d);
  res.on('end', () => console.log('Response:', body));
});

req.on('error', error => {
  console.error('Request error:', error);
});

req.write(data);
req.end();
