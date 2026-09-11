import React from 'react';
import { useNavigate } from 'react-router-dom';
import { FaGlobe, FaSun, FaMoon, FaLightbulb, FaGavel, FaShieldAlt } from 'react-icons/fa';
import { useTheme } from '../../context/ThemeContext';

const content = {
  ar: {
    title: 'فن حقيقي بأيد موثوقة',
    desc: 'منصة تجمع الحرفيين المبدعين مع عشاق الفن اليدوي، لتجربة تسوق فريدة تجمع بين الأصالة والجودة.',
    startBtn: 'ابدأ رحلتك',
    chips: ['طلبات ذكية', 'عروض تنافسية', 'دفع آمن'],
    langBtn: 'EN',
  },
  en: {
    title: 'Real Craft, Trusted Hands',
    desc: 'A platform connecting creative artisans with handcraft lovers, for a unique shopping experience blending authenticity and quality.',
    startBtn: 'Start Your Journey',
    chips: ['AI Smart Orders', 'Competitive Bids', 'Secure Escrow'],
    langBtn: 'عربي',
  },
};

const Onboarding = () => {
  const navigate = useNavigate();
  const { isDark, isArabic, toggleTheme, toggleLanguage } = useTheme();
  const t = isArabic ? content.ar : content.en;

  return (
    <div style={{ ...styles.wrapper, background: isDark ? 'radial-gradient(ellipse at 60% 40%, #1C2431 0%, #0D1420 100%)' : 'radial-gradient(ellipse at 60% 40%, #e8e4dc 0%, #F5F5F0 100%)' }}>

      {/* ── Top Bar ─────────────────────────────────── */}
      <div style={styles.topBar}>
        <button style={styles.topBtn} onClick={toggleLanguage}>
          <FaGlobe size={14} /> {t.langBtn}
        </button>
        <button style={styles.topBtnIcon} onClick={toggleTheme} title="Toggle Theme">
          {isDark ? <FaSun size={16} color="#FFD700" /> : <FaMoon size={16} color="#1A1A2E" />}
        </button>
      </div>

      {/* ── Main Split Layout ──────────────────────── */}
      <div className="container" style={{ ...styles.container, direction: isArabic ? 'rtl' : 'ltr' }}>

        {/* Left: Text & Actions */}
        <div style={styles.leftSection} className="fade-in">
          {/* Logo */}
          <div style={styles.logoWrapper}>
            <img src="/images/logo.png" alt="CraftGo Logo" style={styles.logoImg} />
          </div>
          <h1 className="shimmer-text" style={styles.logoText}>CraftGo</h1>

          <h2 style={styles.title}>{t.title}</h2>
          <p style={styles.desc}>{t.desc}</p>

          {/* Feature Chips */}
          <div style={styles.chips}>
            {t.chips.map((chip, i) => (
              <span key={i} style={styles.chip}>
                {i === 0 && <FaLightbulb size={13} color="var(--accent-color)" />}
                {i === 1 && <FaGavel size={13} color="var(--accent-color)" />}
                {i === 2 && <FaShieldAlt size={13} color="var(--accent-color)" />}
                {chip}
              </span>
            ))}
          </div>

          {/* CTA Button */}
          <button
            className="btn-primary"
            style={styles.startBtn}
            onClick={() => navigate('/role-selection')}
          >
            {t.startBtn}
          </button>
        </div>

        {/* Right: Image Grid */}
        <div style={styles.rightSection} className="fade-in desktop-only">
          <div style={styles.imageGrid}>
            <div style={{ ...styles.imgCard, gridArea: 'a' }}>
              <img src="/images/plate.jpg" alt="Plate" style={styles.img} />
            </div>
            <div style={{ ...styles.imgCard, gridArea: 'b' }}>
              <img src="/images/basket.jpg" alt="Basket" style={styles.img} />
            </div>
            <div style={{ ...styles.imgCard, gridArea: 'c' }}>
              <img src="/images/jewelry.jpg" alt="Jewelry" style={styles.img} />
            </div>
          </div>
        </div>

      </div>

      <style>{`
        @media (max-width: 850px) {
          .desktop-only { display: none !important; }
        }
      `}</style>
    </div>
  );
};

const styles = {
  wrapper: {
    minHeight: '100vh',
    display: 'flex',
    flexDirection: 'column',
    overflowX: 'hidden',
    transition: 'background 0.3s ease',
  },
  topBar: {
    display: 'flex',
    justifyContent: 'flex-end',
    gap: '0.75rem',
    padding: '1.25rem 2rem',
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
  container: {
    flex: 1,
    display: 'flex',
    alignItems: 'center',
    gap: '5rem',
    paddingTop: '1rem',
    paddingBottom: '4rem',
  },
  leftSection: {
    flex: '1 1 500px',
    maxWidth: '600px',
  },
  logoWrapper: {
    marginBottom: '1rem',
  },
  logoImg: {
    width: '150px',
    height: '150px',
    objectFit: 'contain',
    filter:
      'drop-shadow(0 0 18px rgba(255,215,0,0.7)) drop-shadow(0 0 40px rgba(255,185,0,0.35))',
    transition: 'filter 0.3s ease',
  },
  logoText: {
    fontSize: '3.5rem',
    margin: 0,
    lineHeight: 1,
  },
  title: {
    fontSize: '2.8rem',
    color: 'var(--accent-color)',
    marginBottom: '1.25rem',
    lineHeight: 1.25,
  },
  desc: {
    color: 'var(--text-secondary)',
    fontSize: '1.1rem',
    lineHeight: 1.8,
    marginBottom: '2rem',
    maxWidth: '520px',
  },
  chips: {
    display: 'flex',
    flexWrap: 'wrap',
    gap: '0.75rem',
    marginBottom: '2.5rem',
  },
  chip: {
    background: 'rgba(128,128,128,0.1)',
    border: '1px solid rgba(128,128,128,0.2)',
    color: 'var(--text-secondary)',
    padding: '0.5rem 1.1rem',
    borderRadius: '25px',
    fontSize: '0.9rem',
    display: 'flex',
    alignItems: 'center',
    gap: '0.5rem',
  },
  startBtn: {
    padding: '1rem 3rem',
    fontSize: '1.15rem',
    minWidth: '220px',
  },
  rightSection: {
    flex: '1 1 400px',
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
  },
  imageGrid: {
    display: 'grid',
    gridTemplateColumns: '1fr 1fr',
    gridTemplateRows: '1fr 1fr',
    gap: '1.25rem',
    gridTemplateAreas: `"a b" "a c"`,
    width: '440px',
    height: '540px',
  },
  imgCard: {
    borderRadius: '18px',
    overflow: 'hidden',
    border: '2px solid rgba(255,215,0,0.12)',
    boxShadow: '0 16px 32px rgba(0,0,0,0.4)',
    transition: 'transform 0.4s ease',
  },
  img: {
    width: '100%',
    height: '100%',
    objectFit: 'cover',
  },
};

export default Onboarding;
