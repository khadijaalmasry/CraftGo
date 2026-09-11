import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import api from '../../services/api';
import { FaChartLine, FaBoxOpen, FaClipboardList, FaMoneyBillWave } from 'react-icons/fa';

const Dashboard = () => {
  const [stats, setStats] = useState({
    totalOrders: 0,
    pendingOrders: 0,
    totalProducts: 0,
    revenue: 0,
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchDashboardData = async () => {
      try {
        // In a real app we might have a specific /api/artisan/stats endpoint
        // For now, let's fetch orders and products to compute basic stats
        const ordersRes = await api.get('/orders/artisan');
        const orders = ordersRes.data.orders || [];
        
        let revenue = 0;
        let pending = 0;
        
        orders.forEach(o => {
          if (o.status === 'completed') revenue += parseFloat(o.totalPrice || 0);
          if (o.status === 'pending') pending += 1;
        });
        
        setStats({
          totalOrders: orders.length,
          pendingOrders: pending,
          revenue: revenue,
          totalProducts: 12, // Mocked for now, will connect to real products later
        });
      } catch (err) {
        console.error('Failed to fetch artisan dashboard data', err);
      } finally {
        setLoading(false);
      }
    };
    
    fetchDashboardData();
  }, []);

  if (loading) return <div className="container" style={{ padding: '4rem', textAlign: 'center' }}>جاري التحميل...</div>;

  return (
    <div className="container fade-in" style={{ padding: '2rem 1.5rem', minHeight: '80vh' }}>
      <h1 style={{ color: 'var(--text-primary)', marginBottom: '2rem' }}>لوحة التحكم</h1>
      
      <div style={styles.grid}>
        <div className="glass-card" style={{ ...styles.statCard, borderTop: '4px solid #3B82F6' }}>
          <div style={styles.statIcon}><FaClipboardList color="#3B82F6" size={24} /></div>
          <div>
            <p style={styles.statLabel}>إجمالي الطلبات</p>
            <h3 style={styles.statValue}>{stats.totalOrders}</h3>
          </div>
        </div>
        
        <div className="glass-card" style={{ ...styles.statCard, borderTop: '4px solid var(--accent-color)' }}>
          <div style={styles.statIcon}><FaChartLine color="var(--accent-color)" size={24} /></div>
          <div>
            <p style={styles.statLabel}>طلبات قيد الانتظار</p>
            <h3 style={styles.statValue}>{stats.pendingOrders}</h3>
          </div>
        </div>
        
        <div className="glass-card" style={{ ...styles.statCard, borderTop: '4px solid var(--success-color)' }}>
          <div style={styles.statIcon}><FaMoneyBillWave color="var(--success-color)" size={24} /></div>
          <div>
            <p style={styles.statLabel}>إجمالي الأرباح</p>
            <h3 style={styles.statValue}>{stats.revenue.toFixed(2)} د.أ</h3>
          </div>
        </div>
        
        <div className="glass-card" style={{ ...styles.statCard, borderTop: '4px solid #8B5CF6' }}>
          <div style={styles.statIcon}><FaBoxOpen color="#8B5CF6" size={24} /></div>
          <div>
            <p style={styles.statLabel}>منتجاتي</p>
            <h3 style={styles.statValue}>{stats.totalProducts}</h3>
          </div>
        </div>
      </div>

      <div style={styles.quickActions}>
        <h2 style={{ marginBottom: '1.5rem' }}>إجراءات سريعة</h2>
        <div style={{ display: 'flex', gap: '1rem', flexWrap: 'wrap' }}>
          <Link to="/artisan/orders" className="btn-primary" style={styles.actionBtn}>
            <FaClipboardList /> إدارة الطلبات الواردة
          </Link>
          <Link to="/artisan/products" className="btn-primary" style={{ ...styles.actionBtn, backgroundColor: 'var(--surface-color)', color: 'var(--text-primary)', border: '1px solid var(--border-color)' }}>
            <FaBoxOpen /> إضافة منتج جديد
          </Link>
        </div>
      </div>
    </div>
  );
};

const styles = {
  grid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))',
    gap: '1.5rem',
    marginBottom: '3rem',
  },
  statCard: {
    display: 'flex',
    alignItems: 'center',
    gap: '1rem',
    padding: '1.5rem',
  },
  statIcon: {
    backgroundColor: 'var(--bg-color)',
    width: '50px',
    height: '50px',
    borderRadius: '50%',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
  },
  statLabel: {
    color: 'var(--text-secondary)',
    margin: '0 0 0.25rem 0',
    fontSize: '0.9rem',
  },
  statValue: {
    margin: 0,
    fontSize: '1.5rem',
    color: 'var(--text-primary)',
  },
  quickActions: {
    backgroundColor: 'var(--surface-color)',
    padding: '2rem',
    borderRadius: '16px',
    boxShadow: 'var(--shadow-sm)',
    border: '1px solid var(--border-color)',
  },
  actionBtn: {
    display: 'flex',
    alignItems: 'center',
    gap: '0.5rem',
    textDecoration: 'none',
  }
};

export default Dashboard;
