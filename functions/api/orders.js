export async function onRequestPost({ request, env }) {
  try {
    const body = await request.json();
    const customer = body.customer || {};
    const items = body.items || [];
    if (!customer.full_name || !/^[6-9]\d{9}$/.test(String(customer.mobile || "")) ||
        !customer.house_name || !customer.street || !customer.city || !customer.district ||
        !customer.state || !/^\d{6}$/.test(String(customer.pincode || "")) || !Array.isArray(items) || !items.length) {
      return Response.json({ error: "Please complete all required delivery details." }, { status: 400 });
    }
    if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) return Response.json({ error: "Server database is not configured." }, { status: 503 });
    const base = env.SUPABASE_URL.replace(/\/$/, "");
    const headers = { apikey: env.SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`, "Content-Type": "application/json", Prefer: "return=representation" };
    const ids = [...new Set(items.map(x => String(x.product_id)))];
    const productsRes = await fetch(`${base}/rest/v1/products?id=in.(${ids.map(encodeURIComponent).join(",")})&published=eq.true&select=id,name,price,mrp,stock,quantity_prices`, { headers });
    if (!productsRes.ok) throw new Error("Could not verify products.");
    const products = await productsRes.json();
    if (products.length !== ids.length) return Response.json({ error: "One or more products are unavailable." }, { status: 409 });
    let total = 0; const rows = [];
    for (const item of items) {
      const p = products.find(x => x.id === item.product_id); const qty = Number(item.quantity);
      if (!p || !Number.isInteger(qty) || qty < 1 || qty > Number(p.stock)) return Response.json({ error: `Insufficient stock for ${p?.name || "a product"}.` }, { status: 409 });
      const slab = (p.quantity_prices || []).find(s => Number(s.qty) === qty);
      const line = slab ? Number(slab.total) : Number(p.price) * qty;
      total += line; rows.push({ product_id: p.id, product_name: p.name, quantity: qty, unit_price: Number(p.price), line_total: line });
    }
    const customerRes = await fetch(`${base}/rest/v1/customers?on_conflict=mobile`, { method:"POST", headers:{...headers,Prefer:"resolution=merge-duplicates,return=representation"}, body:JSON.stringify({full_name:customer.full_name,mobile:customer.mobile,email:customer.email||null,house_name:customer.house_name,street:customer.street,city:customer.city,district:customer.district,state:customer.state,pincode:customer.pincode}) });
    if (!customerRes.ok) throw new Error("Could not save customer details.");
    const customerRows = await customerRes.json(); const savedCustomer = customerRows[0];
    const orderRes = await fetch(`${base}/rest/v1/orders`, { method:"POST", headers, body:JSON.stringify({customer_id:savedCustomer.id,customer_name:customer.full_name,mobile:customer.mobile,total,status:"Pending",payment_method:"COD",delivery_address:{...customer}}) });
    if (!orderRes.ok) throw new Error("Could not create order.");
    const orderRows = await orderRes.json(); const order = orderRows[0];
    const itemRes = await fetch(`${base}/rest/v1/order_items`, { method:"POST", headers, body:JSON.stringify(rows.map(r=>({...r,order_id:order.id}))) });
    if (!itemRes.ok) throw new Error("Order saved but items could not be saved.");
    // Stock is decremented with a conditional PATCH to avoid overselling.
    for (const row of rows) {
      const stockRes = await fetch(`${base}/rest/v1/products?id=eq.${encodeURIComponent(row.product_id)}&stock=gte.${row.quantity}`, { method:"PATCH", headers:{...headers,Prefer:"return=minimal"}, body:JSON.stringify({stock: products.find(p=>p.id===row.product_id).stock-row.quantity}) });
      if (!stockRes.ok) throw new Error("Order created; stock update needs owner review.");
    }
    return Response.json({ order: { id: order.id, order_code: order.order_code, total: order.total, status: order.status } }, { status: 201 });
  } catch (e) { return Response.json({ error: e.message || "Unexpected server error." }, { status: 500 }); }
}
