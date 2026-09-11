import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { FaShoppingCart, FaUser, FaBars, FaTimes, FaComments, FaTachometerAlt, FaGlobe, FaSun, FaMoon } from 'react-icons/fa';
import { useAuth } from '../context/AuthContext';
import { useCart } from '../context/CartContext';
import { useTheme } from '../context/ThemeContext';
import NotificationBell from './NotificationBell';

const Navbar = () => {
  const { isAuthenticated, isArtisan, isAdmin, user, logout } = useAuth();
  const { cartCount } = useCart();
  const { isDark, isArabic, toggleTheme, toggleLanguage } = useTheme();
  const navigate = useNavigate();
  const [isMenuOpen, setIsMenuOpen] = useState(false);

  const handleLogout = () => {
    logout();
    setIsMenuOpen(false);
    navigate('/login');
  };

  const closeMenu = () => setIsMenuOpen(false);

  // Build nav links based on role
  const publicLinks = [
    { name: 'الرئيسية', path: '/' },
    { name: 'المتجر', path: '/shop' },
    { name: 'بحث', path: '/search' },
    { name: 'المعارض', path: '/exhibitions' },
    { name: 'يوميات', path: '/stories' },
  ];

  const customerLinks = isAuthenticated && !isArtisan && !isAdmin ? [
    { name: 'المفضلة', path: '/customer/favorites' },
    { name: 'هدايا الذكاء', path: '/customer/gift-quiz' },
    { name: 'طلباتي', path: '/customer/orders' },
    { name: 'مخصص', path: '/customer/custom-orders' },
    { name: 'استئجار', path: '/customer/hire-requests' },
  ] : [];

  const artisanLinks = isArtisan ? [
    { name: 'لوحة التحكم', path: '/artisan/dashboard' },
    { name: 'منتجاتي', path: '/artisan/products' },
    { name: 'الطلبات', path: '/artisan/orders' },
    { name: 'طلبات مخصصة', path: '/artisan/custom-orders' },
    { name: 'استئجاري', path: '/artisan/hire-requests' },
  ] : [];

  const adminLinks = isAdmin ? [
    { name: 'الإدارة', path: '/admin/dashboard' },
    { name: 'مراجعة الحرفيين', path: '/admin/pending-artisans' },
  ] : [];

  const allLinks = [...publicLinks, ...customerLinks, ...artisanLinks, ...adminLinks];

  return (
    <nav style={styles.nav}>
      <div className="container" style={styles.navContainer}>
        {/* Logo */}
        <Link to="/" style={styles.logo} onClick={closeMenu}>
          Craft<span style={{ color: 'var(--accent-color)' }}>Go</span>
        </Link>

        {/* Desktop Links */}
        <div className="desktop-nav-links" style={styles.desktopMenu}>
          {allLinks.map(link => (
            <Link key={link.path} to={link.path} style={styles.link}>{link.name}</Link>
          ))}
        </div>

        {/* Icon Section */}
        <div style={styles.iconContainer}>
          {/* Language & Theme Toggles */}
          <button onClick={toggleLanguage} style={{ ...styles.iconBtn, padding: '0.3rem 0.6rem', border: '1px solid var(--border-color)', borderRadius: '20px', fontSize: '0.75rem', color: 'var(--text-secondary)', gap: '0.3rem' }}>
            <FaGlobe size={12} /> {isArabic ? 'EN' : 'عربي'}
          </button>
          <button onClick={toggleTheme} style={styles.iconBtn} title={isDark ? 'Light Mode' : 'Dark Mode'}>
            {isDark ? <FaSun size={18} color="var(--accent-color)" /> : <FaMoon size={18} color="var(--text-primary)" />}
          </button>

          {isAuthenticated && <NotificationBell />}

          {isAuthenticated && (
            <Link to="/chat" style={styles.iconBtn} title="الدردشة">
              <FaComments size={22} color="var(--text-primary)" />
            </Link>
          )}

          {isAuthenticated && !isArtisan && !isAdmin && (
            <Link to="/cart" style={{ ...styles.iconBtn, position: 'relative' }}>
              <FaShoppingCart size={22} color="var(--text-primary)" />
              {cartCount > 0 && (
                <span style={styles.badge}>{cartCount}</span>
              )}
            </Link>
          )}

          {isAdmin && (
            <Link to="/admin/dashboard" style={styles.iconBtn} title="لوحة الإدارة">
              <FaTachometerAlt size={20} color="var(--accent-color)" />
            </Link>
          )}

          {isAuthenticated ? (
            <div style={styles.profileSection}>
              <Link to="/customer/profile" style={styles.userName}>
                {isAdmin ? '👑 ' : isArtisan ? '🔨 ' : ''}
                {user?.name?.split(' ')[0]}
              </Link>
              <button onClick={handleLogout} style={styles.logoutBtn}>خروج</button>
            </div>
          ) : (
            <Link to="/login" style={styles.iconBtn}>
              <FaUser size={20} color="var(--text-primary)" />
            </Link>
          )}

          {/* Mobile Menu Toggle */}
          <button style={styles.mobileMenuBtn} onClick={() => setIsMenuOpen(!isMenuOpen)}>
            {isMenuOpen ? <FaTimes size={22} color="var(--text-primary)" /> : <FaBars size={22} color="var(--text-primary)" />}
          </button>
        </div>
      </div>

      {/* Mobile Menu */}
      {isMenuOpen && (
        <div style={styles.mobileMenu}>
          {allLinks.map(link => (
            <Link key={link.path} to={link.path} style={styles.mobileLink} onClick={closeMenu}>
              {link.name}
            </Link>
          ))}
          {isAuthenticated && (
            <button onClick={handleLogout} style={{ ...styles.mobileLink, border: 'none', background: 'none', color: 'var(--danger-color)', cursor: 'pointer', textAlign: 'right', width: '100%' }}>
              تسجيل الخروج
            </button>
          )}
        </div>
      )}

      <style>{`
        @media (max-width: 768px) {
          .desktop-nav-links { display: none !important; }
          .mobile-menu-btn { display: flex !important; }
        }
        @media (min-width: 769px) {
          .mobile-menu-btn { display: none !important; }
        }
      `}</style>
    </nav>
  );
};

const styles = {
  nav: {
    backgroundColor: 'var(--surface-color)',
    borderBottom: '1px solid var(--border-color)',
    position: 'sticky',
    top: 0,
    zIndex: 1000,
    boxShadow: 'var(--shadow-sm)',
  },
  navContainer: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    height: '68px',
  },
  logo: {
    fontSize: '1.5rem',
    fontWeight: 'bold',
    fontFamily: 'var(--font-heading)',
    color: 'var(--text-primary)',
    textDecoration: 'none',
  },
  desktopMenu: {
    display: 'flex',
    gap: '1.5rem',
  },
  link: {
    color: 'var(--text-secondary)',
    fontWeight: '600',
    fontSize: '0.9rem',
    textDecoration: 'none',
    transition: 'color 0.2s',
  },
  iconContainer: {
    display: 'flex',
    alignItems: 'center',
    gap: '1rem',
  },
  iconBtn: {
    position: 'relative',
    display: 'flex',
    alignItems: 'center',
    textDecoration: 'none',
    background: 'none',
    border: 'none',
    cursor: 'pointer',
  },
  badge: {
    position: 'absolute',
    top: '-7px',
    right: '-7px',
    backgroundColor: 'var(--danger-color)',
    color: '#fff',
    fontSize: '0.65rem',
    fontWeight: 'bold',
    borderRadius: '50%',
    width: '17px',
    height: '17px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
  },
  profileSection: {
    display: 'flex',
    alignItems: 'center',
    gap: '0.75rem',
  },
  userName: {
    fontWeight: '600',
    color: 'var(--text-primary)',
    fontSize: '0.9rem',
  },
  logoutBtn: {
    backgroundColor: 'transparent',
    color: 'var(--danger-color)',
    fontWeight: '600',
    fontSize: '0.85rem',
    fontFamily: 'var(--font-primary)',
    cursor: 'pointer',
  },
  mobileMenuBtn: {
    display: 'none',
    background: 'none',
    border: 'none',
    cursor: 'pointer',
    padding: '0.25rem',
    alignItems: 'center',
  },
  mobileMenu: {
    display: 'flex',
    flexDirection: 'column',
    backgroundColor: 'var(--surface-color)',
    padding: '0.5rem 1.5rem',
    borderTop: '1px solid var(--border-color)',
  },
  mobileLink: {
    padding: '0.85rem 0',
    color: 'var(--text-primary)',
    fontWeight: '600',
    borderBottom: '1px solid var(--border-color)',
    textDecoration: 'none',
    display: 'block',
  }
};

export default Navbar;
