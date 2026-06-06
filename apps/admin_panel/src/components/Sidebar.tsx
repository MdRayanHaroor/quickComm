import { Link, useLocation } from 'react-router-dom';
import { FaChartPie, FaUtensils, FaMotorcycle, FaSignOutAlt } from 'react-icons/fa';
import { supabase } from '../supabaseClient';
import { useNavigate } from 'react-router-dom';
import ThemeToggle from './ThemeToggle';

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
      <div style={{ marginBottom: '40px', paddingLeft: '10px' }}>
        <h2 style={{ color: 'var(--accent-primary)', display: 'flex', alignItems: 'center', gap: '12px', fontSize: '1.5rem', letterSpacing: '1px' }}>
          <FaUtensils size={20} /> 
          Taj Biryani
        </h2>
        <p style={{ color: 'var(--text-muted)', fontSize: '0.8rem', margin: '5px 0 0 32px', fontFamily: 'Inter', letterSpacing: '0.5px', textTransform: 'uppercase' }}>Admin Portal</p>
      </div>
      
      <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
        <Link to="/dashboard" className={`nav-item ${isActive('/dashboard')}`}>
          <FaChartPie /> Dashboard
        </Link>
        
        <Link to="/menu" className={`nav-item ${isActive('/menu')}`}>
          <FaUtensils /> Menu Management
        </Link> 

        <Link to="/riders" className={`nav-item ${isActive('/riders')}`}>
          <FaMotorcycle /> Fleet & Map
        </Link>
      </div>

      <div style={{ marginTop: 'auto', display: 'flex', flexDirection: 'column', gap: '15px' }}>
        <ThemeToggle />
        <button onClick={handleLogout} className="nav-item" style={{ width: '100%', background: 'transparent', border: 'none', cursor: 'pointer', padding: '14px 18px', textAlign: 'left', color: 'var(--danger)' }}>
          <FaSignOutAlt style={{ color: 'var(--danger)' }} /> Logout
        </button>
      </div>
    </div>
  );
};

export default Sidebar;
