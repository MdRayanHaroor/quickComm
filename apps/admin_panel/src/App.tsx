import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Menu from './pages/Menu';
import Riders from './pages/Riders';
import FleetManagement from './pages/FleetManagement';
import RiderAttendance from './pages/RiderAttendance';
import DeliveryHistory from './pages/DeliveryHistory';
import ProtectedRoute from './components/ProtectedRoute';
import { ThemeProvider } from './components/ThemeContext';

function App() {
  return (
    <ThemeProvider>
      <Router>
        <Routes>
          <Route path="/" element={<Login />} />
          <Route path="/dashboard" element={<ProtectedRoute><Dashboard /></ProtectedRoute>} />
          <Route path="/menu" element={<ProtectedRoute><Menu /></ProtectedRoute>} />
          <Route path="/riders" element={<ProtectedRoute><Riders /></ProtectedRoute>} />
          <Route path="/fleet-management" element={<ProtectedRoute><FleetManagement /></ProtectedRoute>} />
          <Route path="/rider-attendance" element={<ProtectedRoute><RiderAttendance /></ProtectedRoute>} />
          <Route path="/delivery-history" element={<ProtectedRoute><DeliveryHistory /></ProtectedRoute>} />
        </Routes>
      </Router>
    </ThemeProvider>
  );
}

export default App;
