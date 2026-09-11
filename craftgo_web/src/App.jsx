import React from 'react';
import { Routes, Route, useLocation } from 'react-router-dom';
import { useAuth } from './context/AuthContext';

// Layout
import Navbar from './components/Navbar';

// Auth
import Onboarding from './pages/auth/Onboarding';
import RoleSelection from './pages/auth/RoleSelection';
import ArtisanRegister from './pages/auth/ArtisanRegister';
import Login from './pages/Login';

// Public Pages
import Home from './pages/Home';
import Shop from './pages/Shop';
import ProductDetails from './pages/ProductDetails';
import Exhibitions from './pages/Exhibitions';
import ExhibitionDetails from './pages/ExhibitionDetails';
import SearchResults from './pages/SearchResults';
import ArtisanProfile from './pages/ArtisanProfile';
import Stories from './pages/Stories';

// Customer Pages
import Cart from './pages/Cart';
import Checkout from './pages/Checkout';
import CustomerOrders from './pages/CustomerOrders';
import MyCustomOrders from './pages/customer/MyCustomOrders';
import CustomOrderForm from './pages/customer/CustomOrderForm';
import HireRequestForm from './pages/customer/HireRequestForm';
import MyHireRequests from './pages/customer/MyHireRequests';
import Favorites from './pages/customer/Favorites';
import CustomerProfile from './pages/customer/CustomerProfile';
import ReviewSubmission from './pages/customer/ReviewSubmission';
import GiftQuiz from './pages/customer/GiftQuiz';

// Chat
import Chat from './pages/Chat';

// Artisan Pages
import Dashboard from './pages/artisan/Dashboard';
import ArtisanOrders from './pages/artisan/ArtisanOrders';
import MyProducts from './pages/artisan/MyProducts';
import CustomOrderRequests from './pages/artisan/CustomOrderRequests';
import HireOrderRequests from './pages/artisan/HireOrderRequests';

// Admin Pages
import AdminDashboard from './pages/admin/AdminDashboard';
import PendingArtisans from './pages/admin/PendingArtisans';
import AdminGuard from './components/AdminGuard';

function App() {
  const { isAuthenticated, isArtisan, isAdmin } = useAuth();
  const location = useLocation();

  // Hide Navbar and Footer on these specific routes
  const hideLayout = ['/onboarding', '/role-selection', '/login'].includes(location.pathname) || (location.pathname === '/' && !isAuthenticated);

  const getDashboard = () => {
    if (isAdmin) return <AdminDashboard />;
    if (isArtisan) return <Dashboard />;
    return <Home />; // Customer dashboard/Home
  };

  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      {!hideLayout && <Navbar />}
      
      <main style={{ flex: 1 }}>
        <Routes>
          {/* ── Auth / Public ── */}
          <Route path="/" element={isAuthenticated ? getDashboard() : <Onboarding />} />
          <Route path="/onboarding" element={<Onboarding />} />
          <Route path="/role-selection" element={<RoleSelection />} />
          <Route path="/login" element={<Login />} />
          <Route path="/register/artisan" element={<ArtisanRegister />} />
          
          <Route path="/shop" element={<Shop />} />
          <Route path="/search" element={<SearchResults />} />
          <Route path="/product/:id" element={<ProductDetails />} />
          <Route path="/artisan/:id" element={<ArtisanProfile />} />
          <Route path="/stories" element={<Stories />} />
          <Route path="/exhibitions" element={<Exhibitions />} />
          <Route path="/exhibitions/:id" element={<ExhibitionDetails />} />

          {/* ── Customer ── */}
          <Route path="/cart" element={<Cart />} />
          <Route path="/checkout" element={<Checkout />} />
          <Route path="/customer/orders" element={<CustomerOrders />} />
          <Route path="/customer/custom-orders" element={<MyCustomOrders />} />
          <Route path="/custom-order/new" element={<CustomOrderForm />} />
          <Route path="/hire-request/new" element={<HireRequestForm />} />
          <Route path="/customer/hire-requests" element={<MyHireRequests />} />
          <Route path="/customer/favorites" element={<Favorites />} />
          <Route path="/customer/profile" element={<CustomerProfile />} />
          <Route path="/customer/review/:id" element={<ReviewSubmission />} />
          <Route path="/customer/gift-quiz" element={<GiftQuiz />} />

          {/* ── Chat ── */}
          <Route path="/chat" element={<Chat />} />

          {/* ── Artisan ── */}
          <Route path="/artisan/dashboard" element={<Dashboard />} />
          <Route path="/artisan/orders" element={<ArtisanOrders />} />
          <Route path="/artisan/products" element={<MyProducts />} />
          <Route path="/artisan/custom-orders" element={<CustomOrderRequests />} />
          <Route path="/artisan/hire-requests" element={<HireOrderRequests />} />

          {/* ── Admin ── */}
          <Route path="/admin/dashboard" element={<AdminGuard><AdminDashboard /></AdminGuard>} />
          <Route path="/admin/pending-artisans" element={<AdminGuard><PendingArtisans /></AdminGuard>} />
        </Routes>
      </main>

      {!hideLayout && (
        <footer style={{ backgroundColor: 'var(--surface-color)', padding: '2rem', textAlign: 'center', borderTop: '1px solid var(--border-color)', marginTop: '2rem' }}>
          <p style={{ color: 'var(--text-dim)' }}>© 2026 CraftGo. جميع الحقوق محفوظة.</p>
        </footer>
      )}
    </div>
  );
}

export default App;
