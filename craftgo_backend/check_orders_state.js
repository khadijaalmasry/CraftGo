(async () => {
  const baseUrl = "http://localhost:5000/api";
  
  // Login
  const loginRes = await fetch(`${baseUrl}/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email: "admin@craftgo.com", password: "123456" })
  });
  const { token } = await loginRes.json();
  const headers = { "Authorization": `Bearer ${token}`, "Content-Type": "application/json" };
  
  // Check current orders
  const ordersRes = await fetch(`${baseUrl}/orders/customer`, { headers });
  const ordersData = await ordersRes.json();
  console.log("\n=== Current Customer Orders (status", ordersRes.status, ")===");
  console.log("success:", ordersData.success, "count:", ordersData.orders?.length);
  ordersData.orders?.forEach(o => console.log(" -", o.id.substring(0,8), "| status:", o.status, "| product:", o.items?.[0]?.productName));
  
  // Check cart interactions
  const cartRes = await fetch(`${baseUrl}/interactions`, { headers });
  const cartData = await cartRes.json();
  const cartItems = (cartData.interactions || cartData.data || cartData || []).filter(i => i.interactionType === 'cart');
  console.log("\n=== Cart Items ===");
  console.log("count:", cartItems.length);
  cartItems.forEach(c => console.log(" -", c.id.substring(0,8), "| productId:", c.productId?.substring(0,8), "| qty:", c.quantity));
})();
