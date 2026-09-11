(async () => {
  try {
    const baseUrl = 'http://localhost:5000/api';
    
    // 1. Login Customer
    const loginRes = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'admin@craftgo.com', password: '123456' })
    });
    const loginData = await loginRes.json();
    const token = loginData.token;

    // 5. Get Customer Orders
    const customerOrdersRes = await fetch(`${baseUrl}/orders/customer`, { headers: { 'Authorization': `Bearer ${token}` }});
    const customerOrdersData = await customerOrdersRes.json();
    console.log('\n--- CUSTOMER ORDERS RESPONSE ---');
    console.log(JSON.stringify(customerOrdersData, null, 2));

    // Get the craftsmanId from the order we just created
    const firstOrder = customerOrdersData.orders[0];
    const craftsmanId = firstOrder.items[0].craftsmanName === 'maram' ? 'ea47b473-0832-43c3-adcc-cc8377ba0e4d' : null;

    // 6. Login Artisan
    const artisanLogin = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'maram@craftgo.com', password: '123456' })
    });
    const artisanLoginData = await artisanLogin.json();
    const artisanToken = artisanLoginData.token;
    
    if (craftsmanId) {
      console.log('\n--- ARTISAN ORDERS RESPONSE ---');
      const artisanOrdersRes = await fetch(`${baseUrl}/orders/craftsman/${craftsmanId}`, {
        headers: { 'Authorization': `Bearer ${artisanToken}` }
      });
      const artisanOrdersData = await artisanOrdersRes.json();
      console.log(JSON.stringify(artisanOrdersData, null, 2));
    }

  } catch(e) {
    console.error('Test Failed:', e.message);
  }
})();
