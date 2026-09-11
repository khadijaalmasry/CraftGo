import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import api from '../../services/api';
import { FaUsers, FaHammer, FaClipboardList, FaMoneyBillWave, FaUserClock } from 'react-icons/fa';

const AdminDashboard = () => {
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const res = await api.get('/admin/stats');
        setStats(res.data.stats || res.data);
      } catch (err) {
        setError('تعذر جلب الإحصائيات. تأكد من أن حسابك لديه صلاحية الإدارة.');
      } finally {
        setLoading(false);
      }
    };
    fetchStats();
  }, []);

  if (loading) return <div className="container" style={{ padding: '4rem', textAlign: 'center' }}>جاري التحميل...</div>;

  return (
    <div className="container fade-in" style={{ padding: '2rem 1.5rem', minHeight: '80vh' }}>
      <h1 style={{ marginBottom: '0.5rem' }}>لوحة تحكم الإدارة</h1>
      <p style={{ color: 'var(--text-secondary)', marginBottom: '2.5rem' }}>مرحباً بك في لوحة تحكم CraftGo الإدارية.</p>

      {error && (
        <div style={{ backgroundColor: 'rgba(239,68,68,0.1)', color: 'var(--danger-color)', padding: '1rem', borderRadius: '8px', marginBottom: '2rem' }}>
          {error}
        </div>
      )}

      {/* Stats Grid */}
      {stats && (
        <div style={styles.statsGrid}>
          <div className="glass-card" style={{ ...styles.statCard, borderTop: '4px solid #3B82F6' }}>
            <div style={{ ...styles.statIcon, backgroundColor: 'rgba(59,130,246,0.1)' }}><FaUsers color="#3B82F6" size={22} /></div>
            <div>
              <p style={styles.statLabel}>إجمالي المستخدمين</p>
              <h2 style={styles.statValue}>{stats.totalUsers ?? stats.users ?? '—'}</h2>
            </div>
          </div>

          <div className="glass-card" style={{ ...styles.statCard, borderTop: '4px solid var(--accent-color)' }}>
            <div style={{ ...styles.statIcon, backgroundColor: 'rgba(212,160,23,0.1)' }}><FaHammer color="var(--accent-color)" size={22} /></div>
            <div>
              <p style={styles.statLabel}>الحرفيون</p>
              <h2 style={styles.statValue}>{stats.totalArtisans ?? stats.artisans ?? '—'}</h2>
            </div>
          </div>

          <div className="glass-card" style={{ ...styles.statCard, borderTop: '4px solid var(--success-color)' }}>
            <div style={{ ...styles.statIcon, backgroundColor: 'rgba(16,185,129,0.1)' }}><FaClipboardList color="var(--success-color)" size={22} /></div>
            <div>
              <p style={styles.statLabel}>إجمالي الطلبات</p>
              <h2 style={styles.statValue}>{stats.totalOrders ?? stats.orders ?? '—'}</h2>
            </div>
          </div>

          <div className="glass-card" style={{ ...styles.statCard, borderTop: '4px solid #8B5CF6' }}>
            <div style={{ ...styles.statIcon, backgroundColor: 'rgba(139,92,246,0.1)' }}><FaMoneyBillWave color="#8B5CF6" size={22} /></div>
            <div>
              <p style={styles.statLabel}>إجمالي الإيرادات</p>
              <h2 style={styles.statValue}>{(stats.totalRevenue ?? stats.revenue ?? 0).toFixed ? parseFloat(stats.totalRevenue ?? stats.revenue ?? 0).toFixed(2) : '—'} د.أ</h2>
            </div>
          </div>
        </div>
      )}

      {/* Quick Actions */}
      <div style={styles.actionsGrid}>
        <Link to="/admin/pending-artisans" className="glass-card" style={styles.actionCard}>
          <div style={{ ...styles.actionIcon, backgroundColor: 'rgba(212,160,23,0.1)' }}><FaUserClock color="var(--accent-color)" size={28} /></div>
          <h3 style={{ margin: '1rem 0 0.5rem' }}>الحرفيون قيد المراجعة</h3>
          <p style={{ color: 'var(--text-secondary)', margin: 0, fontSize: '0.9rem' }}>مراجعة وقبول أو رفض طلبات تسجيل الحرفيين الجدد.</p>
        </Link>

        <Link to="/admin/users" className="glass-card" style={styles.actionCard}>
          <div style={{ ...styles.actionIcon, backgroundColor: 'rgba(59,130,246,0.1)' }}><FaUsers color="#3B82F6" size={28} /></div>
          <h3 style={{ margin: '1rem 0 0.5rem' }}>إدارة المستخدمين</h3>
          <p style={{ color: 'var(--text-secondary)', margin: 0, fontSize: '0.9rem' }}>عرض جميع المستخدمين وإدارة حساباتهم.</p>
        </Link>
      </div>
    </div>
  );
};

const styles = {
  statsGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
    gap: '1.5rem',
    marginBottom: '2.5rem',
  },
  statCard: {
    display: 'flex',
    alignItems: 'center',
    gap: '1rem',
    padding: '1.5rem',
  },
  statIcon: {
    width: '52px',
    height: '52px',
    borderRadius: '12px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
  },
  statLabel: {
    color: 'var(--text-secondary)',
    margin: '0 0 0.25rem 0',
    fontSize: '0.85rem',
  },
  statValue: {
    margin: 0,
    fontSize: '1.6rem',
    color: 'var(--text-primary)',
  },
  actionsGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
    gap: '1.5rem',
  },
  actionCard: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'flex-start',
    textDecoration: 'none',
    color: 'inherit',
    padding: '2rem',
  },
  actionIcon: {
    width: '60px',
    height: '60px',
    borderRadius: '16px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
  }
};

export default AdminDashboard;
