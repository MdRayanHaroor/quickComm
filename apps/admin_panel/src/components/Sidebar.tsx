import { Link, useLocation } from 'react-router-dom';
import { FaChartPie, FaUtensils, FaMotorcycle, FaSignOutAlt } from 'react-icons/fa';
import { supabase } from '../supabaseClient';
import { useNavigate } from 'react-router-dom';

const Sidebar = () => {
  const location = useLocation();
  const navigate = useNavigate();

  const handleLogout = async () => {
    await supabase.auth.signOut();
    navigate('/');
  };

  const isActive = (path: string) => location.pathname === path ? 'active' : '';

  return (
    <div className="sidebar">
      <h2 style={{ color: 'white', marginBottom: '40px', display: 'flex', alignItems: 'center', gap: '10px' }}>
        <FaUtensils color="var(--primary)" /> BiryaniAdmin
      </h2>
      
      <Link to="/dashboard" className={`nav-item ${isActive('/dashboard')}`}>
        <FaChartPie style={{ marginRight: '10px' }} /> Dashboard
      </Link>
      
      <Link to="/menu" className={`nav-item ${isActive('/menu')}`}>
        <FaUtensils style={{ marginRight: '10px' }} /> Menu Management
      </Link> 

      <Link to="/riders" className={`nav-item ${isActive('/riders')}`}>
        <FaMotorcycle style={{ marginRight: '10px' }} /> Fleet & Map
      </Link>

      <div style={{ marginTop: 'auto' }}>
        <button onClick={handleLogout} className="nav-item" style={{ width: '100%', background: 'transparent', border: 'none', cursor: 'pointer' }}>
          <FaSignOutAlt style={{ marginRight: '10px' }} /> Logout
        </button>
      </div>
    </div>
  );
};

export default Sidebar;
