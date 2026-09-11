import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { FaUserAlt, FaTools, FaTruck, FaStore, FaShieldAlt, FaSearch, FaGlobe, FaSun, FaMoon } from 'react-icons/fa';
import { useTheme } from '../../context/ThemeContext';

// ... (roles and heading remain the same) ...

const roles = {
  ar: [
    {
      id: 'customer',
      title: 'أنا أبحث عن حرفي',
      desc: 'تصفح أمهر الحرفيين في منطقتك واطلب خدماتهم.',
      icon: FaSearch,
      path: '/login?role=customer',
    },
    {
      id: 'artisan',
      title: 'أنا حرفي',
      desc: 'سجّل لتقديم خدماتك، استقبل الطلبات، واعرض أعمالك.',
      icon: FaTools,
      path: '/register/artisan',
    },
    {
      id: 'admin',
      title: 'إدارة النظام',
      desc: 'ادخل بصلاحيات المشرف لإدارة التطبيق والمستخدمين.',
      icon: FaShieldAlt,
      path: '/login?role=admin',
    },
    {
      id: 'delivery',
      title: 'مندوب توصيل',
      desc: 'أدِر رحلات التوصيل الخاصة بك وسلّم طلبات الحرفيين.',
      icon: FaTruck,
      path: '/login?role=delivery',
    },
    {
      id: 'exhibition',
      title: 'صاحب معرض',
      desc: 'نظّم معارض الحرف، أضف حرفيين، وأدِر الفعاليات.',
      icon: FaStore,
      path: '/login?role=exhibition',
    },
  ],
  en: [
    {
      id: 'customer',
      title: 'I am looking for a Craftsman',
      desc: 'Browse the most skilled craftsmen in your area and request matching services.',
      icon: FaSearch,
      path: '/login?role=customer',
    },
    {
      id: 'artisan',
      title: 'I am a Craftsman',
      desc: 'Register to offer your services, receive orders, and showcase your work.',
      icon: FaTools,
      path: '/register/artisan',
    },
    {
      id: 'admin',
      title: 'System Administration',
      desc: 'Access with admin privileges to manage the application and users.',
      icon: FaShieldAlt,
      path: '/login?role=admin',
    },
    {
      id: 'delivery',
      title: 'Delivery Representative',
      desc: 'Manage your delivery trips and easily deliver artisans\' orders to customers.',
      icon: FaTruck,
      path: '/login?role=delivery',
    },
    {
      id: 'exhibition',
      title: 'Exhibition Owner',
      desc: 'Organize craft exhibitions, add artisans, and manage your events.',
      icon: FaStore,
      path: '/login?role=exhibition',
    },
  ],
};

const heading = {
  ar: { title: 'مرحباً بك في عالم الحرف', sub: 'اختر نوع حسابك للمتابعة' },
  en: { title: 'Welcome to the Craft World', sub: 'Select your account type to proceed' },
};

const RoleSelection = () => {
  const navigate = useNavigate();
  const { isDark, isArabic, toggleTheme, toggleLanguage } = useTheme();
  const [hovered, setHovered] = useState(null);
  const lang = isArabic ? 'ar' : 'en';
  const t = heading[lang];
  const roleList = roles[lang];

  return (
    <div style={{ ...styles.wrapper, direction: isArabic ? 'rtl' : 'ltr' }} className="fade-in">
      {/* ── Top Bar ─────────────────────────────────── */}
      <div style={styles.topBar}>
        <button style={styles.topBtn} onClick={toggleLanguage}>
          <FaGlobe size={14} /> {isArabic ? 'EN' : 'عربي'}
        </button>
        <button style={styles.topBtnIcon} onClick={toggleTheme} title="Toggle Theme">
          {isDark ? <FaSun size={16} color="#FFD700" /> : <FaMoon size={16} color="#1A1A2E" />}
        </button>
      </div>

      {/* Header */}
      <div style={styles.header}>
        <h1 style={styles.title}>{t.title}</h1>
        <p style={styles.sub}>{t.sub}</p>
      </div>

      {/* Role Cards — 2 column grid on web */}
      <div style={styles.grid}>
        {roleList.map(role => {
          const Icon = role.icon;
          const isHov = hovered === role.id;
          return (
            <div
              key={role.id}
              style={{
                ...styles.card,
                border: isHov
                  ? '1.5px solid var(--accent-color)'
                  : '1.5px solid rgba(255,215,0,0.08)',
                transform: isHov ? 'translateY(-4px)' : 'none',
                boxShadow: isHov
                  ? '0 12px 32px rgba(0,0,0,0.5)'
                  : '0 4px 16px rgba(0,0,0,0.3)',
              }}
              onClick={() => navigate(role.path)}
              onMouseEnter={() => setHovered(role.id)}
              onMouseLeave={() => setHovered(null)}
            >
              {/* Icon Box */}
              <div style={{
                ...styles.iconBox,
                background: isHov
                  ? 'linear-gradient(135deg, #B8860B, #FFD700)'
                  : 'linear-gradient(135deg, #8B6508, #B8860B)',
              }}>
                <Icon size={26} color="#0D1420" />
              </div>

              {/* Text */}
              <div style={styles.cardText}>
                <h3 style={styles.cardTitle}>{role.title}</h3>
                <p style={styles.cardDesc}>{role.desc}</p>
              </div>

              {/* Arrow */}
              <div style={{ ...styles.arrow, opacity: isHov ? 1 : 0.3 }}>
                {isArabic ? '←' : '→'}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

const styles = {
  wrapper: {
    minHeight: '100vh',
    backgroundColor: 'var(--bg-color)',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    padding: '1rem 1.5rem 4rem 1.5rem',
  },
  topBar: {
    width: '100%',
    display: 'flex',
    justifyContent: 'flex-end',
    gap: '0.75rem',
    marginBottom: '2rem',
  },
  topBtn: {
    background: 'rgba(128,128,128,0.12)',
    border: '1px solid rgba(128,128,128,0.2)',
    color: 'var(--text-secondary)',
    borderRadius: '20px',
    padding: '0.45rem 1rem',
    display: 'flex',
    alignItems: 'center',
    gap: '0.45rem',
    fontSize: '0.85rem',
    fontFamily: 'var(--font-primary)',
    cursor: 'pointer',
  },
  topBtnIcon: {
    background: 'rgba(128,128,128,0.12)',
    border: '1px solid rgba(128,128,128,0.2)',
    borderRadius: '50%',
    width: '38px',
    height: '38px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    cursor: 'pointer',
  },
  header: {
    textAlign: 'center',
    marginBottom: '3rem',
    maxWidth: '600px',
  },
  title: {
    fontSize: '2.5rem',
    color: 'var(--accent-color)',
    fontFamily: 'var(--font-heading)',
    marginBottom: '0.75rem',
    lineHeight: 1.3,
  },
  sub: {
    color: 'var(--text-secondary)',
    fontSize: '1.05rem',
  },
  grid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(380px, 1fr))',
    gap: '1.25rem',
    width: '100%',
    maxWidth: '900px',
  },
  card: {
    display: 'flex',
    alignItems: 'center',
    gap: '1.25rem',
    padding: '1.4rem 1.5rem',
    borderRadius: '16px',
    backgroundColor: 'var(--surface-color)',
    cursor: 'pointer',
    transition: 'transform 0.25s ease, box-shadow 0.25s ease, border 0.2s ease',
  },
  iconBox: {
    width: '60px',
    height: '60px',
    borderRadius: '14px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
    transition: 'background 0.25s ease',
  },
  cardText: {
    flex: 1,
  },
  cardTitle: {
    fontSize: '1.05rem',
    fontWeight: '700',
    color: 'var(--text-primary)',
    fontFamily: 'var(--font-primary)',
    marginBottom: '0.3rem',
  },
  cardDesc: {
    fontSize: '0.88rem',
    color: 'var(--text-secondary)',
    lineHeight: 1.5,
    margin: 0,
  },
  arrow: {
    fontSize: '1.4rem',
    color: 'var(--accent-color)',
    fontWeight: 'bold',
    transition: 'opacity 0.2s ease',
    flexShrink: 0,
  },
};

export default RoleSelection;
