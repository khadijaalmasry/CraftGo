(async () => {
  try {
    const baseUrl = 'http://localhost:5000/api';
    
    // Login Admin
    const loginRes = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'admin@craftgo.com', password: '123456' })
    });
    const loginData = await loginRes.json();
    const token = loginData.token;

    const craftsmanId = 'ea47b473-0832-43c3-adcc-cc8377ba0e4d';

    console.log('\n--- ARTISAN ORDERS RESPONSE ---');
    const artisanOrdersRes = await fetch(`${baseUrl}/orders/craftsman/${craftsmanId}`, {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    const artisanOrdersData = await artisanOrdersRes.json();
    console.log(JSON.stringify(artisanOrdersData, null, 2));

  } catch(e) {
    console.error('Test Failed:', e.message);
  }
})();
