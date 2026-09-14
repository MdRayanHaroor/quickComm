import { useState, useEffect } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import {
  FaChartPie, FaBolt, FaSignOutAlt, FaCalendarAlt, FaClipboardList,
  FaUsersCog, FaMapMarkedAlt, FaBoxOpen, FaTrademark,
  FaLayerGroup, FaMoon, FaSun, FaChevronLeft, FaChevronRight, FaWarehouse,
  FaShoppingBag, FaCog
} from 'react-icons/fa';
import { supabase } from '../supabaseClient';
import api from '../api';
import { useTheme } from './ThemeContext';

const Sidebar = () => {
  const location = useLocation();
  const navigate = useNavigate();
  const { isDark, toggleTheme } = useTheme();
  const [isCollapsed, setIsCollapsed] = useState<boolean>(() => {
    return localStorage.getItem('qc-sidebar-collapsed') === 'true';
  });

  const [stockBadges, setStockBadges] = useState<{ low: number; out: number }>({ low: 0, out: 0 });
  const [orderBadges, setOrderBadges] = useState<{ newCount: number; preparingCount: number }>({ newCount: 0, preparingCount: 0 });

  useEffect(() => {
    document.body.classList.toggle('sidebar-collapsed', isCollapsed);
    localStorage.setItem('qc-sidebar-collapsed', String(isCollapsed));
  }, [isCollapsed]);

  // Fetch low stock, out of stock, and active order counts
  useEffect(() => {
    const fetchCounters = async () => {
      try {
        const [res, ordRes] = await Promise.all([
          api.get('/inventory/summary'),
          supabase.from('orders').select('status').in('status', ['pending', 'confirmed', 'preparing'])
        ]);
        if (res?.data) {
          setStockBadges({
            low: res.data.low_stock || 0,
            out: res.data.out_of_stock || 0,
          });
        }
        if (ordRes?.data) {
          const newOrders = ordRes.data.filter((o: any) => o.status === 'pending').length;
          const prepOrders = ordRes.data.filter((o: any) => o.status === 'confirmed' || o.status === 'preparing').length;
          setOrderBadges({
            newCount: newOrders,
            preparingCount: prepOrders,
          });
        }
      } catch {
        // silent fallback
      }
    };

    fetchCounters();
    const timer = setInterval(fetchCounters, 15000);

    // Realtime updates for orders
    const channel = supabase
      .channel('sidebar-orders-counter')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'orders' }, () => {
        fetchCounters();
      })
      .subscribe();

    return () => {
      clearInterval(timer);
      supabase.removeChannel(channel);
    };
  }, [location.pathname]);

  const handleLogout = async () => {
    await supabase.auth.signOut();
    navigate('/');
  };

  const isActive = (path: string) =>
    location.pathname === path || location.pathname.startsWith(path + '/')
      ? 'active'
      : '';

  return (
    <div className={`sidebar ${isCollapsed ? 'collapsed' : ''}`}>
      {/* Logo & Toggle */}
      <div className="sidebar-logo">
        <div className="sidebar-logo-icon" title="QuickComm">
          <FaBolt />
        </div>
        {!isCollapsed && (
          <div className="sidebar-logo-text">
            <span className="sidebar-logo-title">QuickComm</span>
            <span className="sidebar-logo-sub">Admin Portal</span>
          </div>
        )}
        <button
          className="sidebar-collapse-btn"
          onClick={() => setIsCollapsed(c => !c)}
          title={isCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}
          aria-label={isCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}
        >
          {isCollapsed ? <FaChevronRight size={11} /> : <FaChevronLeft size={11} />}
        </button>
      </div>

      {/* Nav */}
      <nav className="sidebar-nav">
        <div className="sidebar-section-label">Overview</div>

        <Link to="/dashboard" className={`nav-item ${isActive('/dashboard')}`} title="Dashboard">
          <FaChartPie className="nav-icon" />
          <span className="nav-label">Dashboard</span>
        </Link>

        <Link
          to="/orders"
          className={`nav-item ${isActive('/orders')}`}
          title={`Live Orders${orderBadges.newCount > 0 ? ` • ${orderBadges.newCount} New` : ''}${orderBadges.preparingCount > 0 ? ` • ${orderBadges.preparingCount} Preparing` : ''}`}
        >
          <FaShoppingBag className="nav-icon" />
          <span className="nav-label">Live Orders</span>
          {!isCollapsed && (orderBadges.newCount > 0 || orderBadges.preparingCount > 0) && (
            <div style={{ display: 'flex', gap: 4, marginLeft: 'auto', alignItems: 'center' }}>
              {orderBadges.newCount > 0 && (
                <span
                  title={`${orderBadges.newCount} New / Pending Orders`}
                  style={{
                    background: 'var(--danger)',
                    color: '#ffffff',
                    borderRadius: 10,
                    padding: '1px 6px',
                    fontSize: 10,
                    fontWeight: 700,
                    display: 'flex',
                    alignItems: 'center',
                    gap: 3,
                    boxShadow: '0 1px 3px rgba(239, 68, 68, 0.3)'
                  }}
                >
                  <span style={{ fontSize: 9, opacity: 0.9 }}>New</span>
                  {orderBadges.newCount}
                </span>
              )}
              {orderBadges.preparingCount > 0 && (
                <span
                  title={`${orderBadges.preparingCount} Preparing Orders`}
                  style={{
                    background: 'rgba(59, 130, 246, 0.15)',
                    color: '#3b82f6',
                    border: '1px solid rgba(59, 130, 246, 0.3)',
                    borderRadius: 10,
                    padding: '1px 6px',
                    fontSize: 10,
                    fontWeight: 700,
                    display: 'flex',
                    alignItems: 'center',
                    gap: 3
                  }}
                >
                  <span style={{ fontSize: 9, opacity: 0.9 }}>Prep</span>
                  {orderBadges.preparingCount}
                </span>
              )}
            </div>
          )}
        </Link>

        <div className="sidebar-section-label">Catalogue</div>

        <Link to="/products" className={`nav-item ${isActive('/products')}`} title="Products">
          <FaBoxOpen className="nav-icon" />
          <span className="nav-label">Products</span>
        </Link>

        <Link
          to="/inventory"
          className={`nav-item ${isActive('/inventory')}`}
          title={`Inventory${stockBadges.out > 0 ? ` • ${stockBadges.out} Out of Stock` : ''}${stockBadges.low > 0 ? ` • ${stockBadges.low} Low Stock` : ''}`}
        >
          <FaWarehouse className="nav-icon" />
          <span className="nav-label">Inventory</span>
          {!isCollapsed && (stockBadges.low > 0 || stockBadges.out > 0) && (
            <span style={{ marginLeft: 'auto', display: 'inline-flex', gap: 4, alignItems: 'center' }}>
              {stockBadges.low > 0 && (
                <span
                  title={`${stockBadges.low} Low Stock SKUs`}
                  style={{
                    background: 'rgba(234, 179, 8, 0.2)',
                    color: '#ca8a04',
                    border: '1px solid rgba(234, 179, 8, 0.45)',
                    fontSize: 10,
                    fontWeight: 800,
                    padding: '1px 5px',
                    borderRadius: 9999,
                    minWidth: 16,
                    textAlign: 'center',
                    lineHeight: '13px'
                  }}
                >
                  {stockBadges.low}
                </span>
              )}
              {stockBadges.out > 0 && (
                <span
                  title={`${stockBadges.out} Out of Stock SKUs`}
                  style={{
                    background: 'rgba(239, 68, 68, 0.2)',
                    color: '#dc2626',
                    border: '1px solid rgba(239, 68, 68, 0.45)',
                    fontSize: 10,
                    fontWeight: 800,
                    padding: '1px 5px',
                    borderRadius: 9999,
                    minWidth: 16,
                    textAlign: 'center',
                    lineHeight: '13px'
                  }}
                >
                  {stockBadges.out}
                </span>
              )}
            </span>
          )}
        </Link>

        <Link to="/categories" className={`nav-item ${isActive('/categories')}`} title="Categories">
          <FaLayerGroup className="nav-icon" />
          <span className="nav-label">Categories</span>
        </Link>

        <Link to="/brands" className={`nav-item ${isActive('/brands')}`} title="Brands">
          <FaTrademark className="nav-icon" />
          <span className="nav-label">Brands</span>
        </Link>

        <div className="sidebar-section-label">Operations</div>

        <Link to="/riders" className={`nav-item ${isActive('/riders')}`} title="Fleet & Map">
          <FaMapMarkedAlt className="nav-icon" />
          <span className="nav-label">Fleet &amp; Map</span>
        </Link>

        <Link to="/fleet-management" className={`nav-item ${isActive('/fleet-management')}`} title="Fleet Management">
          <FaUsersCog className="nav-icon" />
          <span className="nav-label">Fleet Management</span>
        </Link>

        <Link to="/rider-attendance" className={`nav-item ${isActive('/rider-attendance')}`} title="Rider Attendance">
          <FaCalendarAlt className="nav-icon" />
          <span className="nav-label">Rider Attendance</span>
        </Link>

        <Link to="/delivery-history" className={`nav-item ${isActive('/delivery-history')}`} title="Delivery History">
          <FaClipboardList className="nav-icon" />
          <span className="nav-label">Delivery History</span>
        </Link>

        <div className="sidebar-section-label">Configuration</div>

        <Link to="/settings" className={`nav-item ${isActive('/settings')}`} title="Store Settings">
          <FaCog className="nav-icon" />
          <span className="nav-label">Store Settings</span>
        </Link>
      </nav>

      {/* Footer */}
      <div className="sidebar-footer">
        <button
          className="nav-item"
          onClick={toggleTheme}
          style={{ marginBottom: 4 }}
          title={isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode'}
        >
          {isDark ? <FaSun className="nav-icon" /> : <FaMoon className="nav-icon" />}
          <span className="nav-label">{isDark ? 'Light Mode' : 'Dark Mode'}</span>
        </button>

        <button
          onClick={handleLogout}
          className="nav-item"
          style={{ color: 'var(--danger)' }}
          title="Logout"
        >
          <FaSignOutAlt className="nav-icon" style={{ color: 'var(--danger)' }} />
          <span className="nav-label">Logout</span>
        </button>
      </div>
    </div>
  );
};

export default Sidebar;
