(async () => {
  const baseUrl = "http://localhost:5000/api";

  const post = async (url, body, token) => {
    const h = { "Content-Type": "application/json" };
    if (token) h["Authorization"] = `Bearer ${token}`;
    const r = await fetch(baseUrl + url, { method: "POST", headers: h, body: JSON.stringify(body) });
    return r.json();
  };
  const get = async (url, token) => {
    const r = await fetch(baseUrl + url, { headers: { Authorization: `Bearer ${token}` } });
    return { status: r.status, data: await r.json() };
  };

  // Try login for maram (artisan who has orders)
  const maramLogin = await post("/auth/login", { email: "MaramSalmeyeh1@gmail.com", password: "123456" });
  if (!maramLogin.token) {
    console.log("maram login failed:", maramLogin);
  } else {
    console.log("maram logged in, roles:", maramLogin.user?.roles);
    const artisanOrders = await get("/orders/artisan", maramLogin.token);
    console.log("\n[GET /orders/artisan] Status:", artisanOrders.status);
    console.log(JSON.stringify(artisanOrders.data, null, 2));
  }
})();
