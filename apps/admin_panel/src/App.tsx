import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Products from './pages/Products';
import Categories from './pages/Categories';
import Brands from './pages/Brands';
import Riders from './pages/Riders';
import FleetManagement from './pages/FleetManagement';
import RiderAttendance from './pages/RiderAttendance';
import DeliveryHistory from './pages/DeliveryHistory';
import Inventory from './pages/Inventory';
import Orders from './pages/Orders';
import Settings from './pages/Settings';
import ProtectedRoute from './components/ProtectedRoute';
import { ThemeProvider } from './components/ThemeContext';
import { Toaster } from 'react-hot-toast';
import OrderNotificationListener from './components/OrderNotificationListener';

function App() {
  return (
    <ThemeProvider>
      <Toaster position="top-right" toastOptions={{ duration: 3000 }} />
      <Router>
        <OrderNotificationListener />
        <Routes>
          <Route path="/" element={<Login />} />

          {/* Overview */}
          <Route path="/dashboard" element={<ProtectedRoute><Dashboard /></ProtectedRoute>} />
          <Route path="/orders" element={<ProtectedRoute><Orders /></ProtectedRoute>} />

          {/* Catalogue */}
          <Route path="/products" element={<ProtectedRoute><Products /></ProtectedRoute>} />
          <Route path="/inventory" element={<ProtectedRoute><Inventory /></ProtectedRoute>} />
          <Route path="/categories" element={<ProtectedRoute><Categories /></ProtectedRoute>} />
          <Route path="/brands" element={<ProtectedRoute><Brands /></ProtectedRoute>} />

          {/* Operations */}
          <Route path="/riders" element={<ProtectedRoute><Riders /></ProtectedRoute>} />
          <Route path="/fleet-management" element={<ProtectedRoute><FleetManagement /></ProtectedRoute>} />
          <Route path="/rider-attendance" element={<ProtectedRoute><RiderAttendance /></ProtectedRoute>} />
          <Route path="/delivery-history" element={<ProtectedRoute><DeliveryHistory /></ProtectedRoute>} />

          {/* Configuration */}
          <Route path="/settings" element={<ProtectedRoute><Settings /></ProtectedRoute>} />

          {/* Legacy /menu → redirect to /products */}
          <Route path="/menu" element={<Navigate to="/products" replace />} />

          {/* Catch-all */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </Router>
    </ThemeProvider>
  );
}

export default App;
