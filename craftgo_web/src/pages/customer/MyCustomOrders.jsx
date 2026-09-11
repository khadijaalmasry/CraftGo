import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import api from '../../services/api';
import { useAuth } from '../../context/AuthContext';
import { FaPlus } from 'react-icons/fa';

const statusConfig = {
  pending:    { text: 'قيد الانتظار',  color: 'var(--accent-color)' },
  accepted:   { text: 'مقبول',         color: '#3B82F6' },
  rejected:   { text: 'مرفوض',         color: 'var(--danger-color)' },
  in_progress:{ text: 'قيد التنفيذ',   color: '#8B5CF6' },
  completed:  { text: 'مكتمل',          color: 'var(--success-color)' },
};

const MyCustomOrders = () => {
  const { user } = useAuth();
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!user?.id) return;
    api.get(`/custom-orders/requests/customer/${user.id}`)
      .then(res => {
        const data = res.data;
        setOrders(Array.isArray(data) ? data : (data.requests || data.data || []));
      })
      .catch(() => setError('تعذر جلب الطلبات.'))
      .finally(() => setLoading(false));
  }, [user]);

  if (loading) return <div className="container" style={{ padding: '4rem', textAlign: 'center' }}>جاري التحميل...</div>;

  return (
    <div className="container fade-in" style={{ padding: '2rem 1.5rem', minHeight: '80vh' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <h1 style={{ margin: 0 }}>طلباتي المخصصة</h1>
        <Link to="/custom-order/new" className="btn-primary" style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', textDecoration: 'none' }}>
          <FaPlus /> طلب جديد
        </Link>
      </div>

      {error && <p style={{ color: 'var(--danger-color)', marginBottom: '1rem' }}>{error}</p>}

      {orders.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '4rem', backgroundColor: 'var(--surface-color)', borderRadius: '12px' }}>
          <p style={{ color: 'var(--text-secondary)', marginBottom: '1.5rem' }}>لا توجد طلبات مخصصة بعد.</p>
          <Link to="/custom-order/new" className="btn-primary" style={{ textDecoration: 'none' }}>طلب منتج مخصص</Link>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
          {orders.map(order => {
            const sc = statusConfig[order.status] || { text: order.status, color: 'var(--text-dim)' };
            return (
              <div key={order.id} className="glass-card" style={{ padding: '1.5rem' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '1rem' }}>
                  <div>
                    <h3 style={{ margin: '0 0 0.25rem' }}>طلب مخصص #{order.id}</h3>
                    <p style={{ margin: 0, color: 'var(--text-dim)', fontSize: '0.85rem' }}>
                      {new Date(order.createdAt).toLocaleDateString('ar-EG')}
                    </p>
                  </div>
                  <span style={{ backgroundColor: sc.color + '20', color: sc.color, padding: '0.3rem 0.85rem', borderRadius: '20px', fontWeight: 'bold', fontSize: '0.85rem' }}>
                    {sc.text}
                  </span>
                </div>

                <p style={{ color: 'var(--text-secondary)', marginBottom: '1rem', lineHeight: 1.7 }}>
                  {order.description?.slice(0, 200)}{order.description?.length > 200 ? '...' : ''}
                </p>

                <div style={{ display: 'flex', gap: '2rem', flexWrap: 'wrap', color: 'var(--text-secondary)', fontSize: '0.9rem' }}>
                  <span>🎯 الحرفي: <strong style={{ color: 'var(--text-primary)' }}>{order.artisan?.name || order.Artisan?.name || '—'}</strong></span>
                  <span>💰 الميزانية: <strong style={{ color: 'var(--accent-color)' }}>{order.budget ? parseFloat(order.budget).toFixed(2) + ' د.أ' : '—'}</strong></span>
                  {order.offeredPrice && <span>🏷️ السعر المقترح: <strong style={{ color: '#3B82F6' }}>{parseFloat(order.offeredPrice).toFixed(2)} د.أ</strong></span>}
                </div>

                {order.artisanMessage && (
                  <div style={{ marginTop: '1rem', padding: '0.85rem', backgroundColor: 'var(--bg-color)', borderRadius: '8px', borderRight: '3px solid var(--accent-color)' }}>
                    <p style={{ margin: 0, color: 'var(--text-secondary)', fontSize: '0.9rem' }}>💬 رد الحرفي: {order.artisanMessage}</p>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

export default MyCustomOrders;
