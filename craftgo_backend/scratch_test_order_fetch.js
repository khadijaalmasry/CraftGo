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

    const productId = 'f5dc5bf6-3b85-4c42-934e-e58593ee1e61'; // Colorful cups
    const craftsmanId = 'ce5e93f0-4018-4e59-a687-3d0d3e0d49f1'; // Obada

    // 3. Add to cart (UserInteraction)
    const addCartRes = await fetch(`${baseUrl}/interactions/products/${productId}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
      body: JSON.stringify({ interactionType: 'cart' })
    });
    const addCartData = await addCartRes.json();
    if (!addCartData.interaction) {
        console.log("Add cart failed:", addCartData);
        process.exit(1);
    }
    const interactionId = addCartData.interaction.id;
    console.log('Added to cart, Interaction ID:', interactionId);

    // 4. Checkout
    const checkoutBody = {
      items: [{ productId: productId, quantity: 1, interactionId }],
      deliveryAddress: 'Test Address 123',
      paymentMethod: 'Online Payment (Escrow)'
    };
    const checkoutRes = await fetch(`${baseUrl}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
      body: JSON.stringify(checkoutBody)
    });
    const checkoutData = await checkoutRes.json();
    console.log('Checkout Response:', checkoutRes.status, checkoutData.success);

    // 5. Get Customer Orders
    const customerOrdersRes = await fetch(`${baseUrl}/orders/customer`, { headers: { 'Authorization': `Bearer ${token}` }});
    const customerOrdersData = await customerOrdersRes.json();
    console.log('\n--- CUSTOMER ORDERS RESPONSE ---');
    console.log(JSON.stringify(customerOrdersData, null, 2));

    // 6. Login Artisan
    const artisanLogin = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'obada@craftgo.com', password: '123456' })
    });
    const artisanLoginData = await artisanLogin.json();
    if(!artisanLoginData.token) {
        console.log("Artisan login failed:", artisanLoginData);
    }
    const artisanToken = artisanLoginData.token;
    
    console.log('\n--- ARTISAN ORDERS RESPONSE ---');
    const artisanOrdersRes = await fetch(`${baseUrl}/orders/craftsman/${craftsmanId}`, {
      headers: { 'Authorization': `Bearer ${artisanToken}` }
    });
    const artisanOrdersData = await artisanOrdersRes.json();
    console.log(JSON.stringify(artisanOrdersData, null, 2));

  } catch(e) {
    console.error('Test Failed:', e.message);
  }
})();
