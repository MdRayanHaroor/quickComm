import { useState, useEffect } from 'react';
import api from '../api';
import Sidebar from '../components/Sidebar';
import { Toaster, toast } from 'react-hot-toast';
import { FaPlus, FaEdit, FaTrash } from 'react-icons/fa';
import { motion, AnimatePresence } from 'framer-motion';

interface Brand {
  id: number;
  name: string;
  logo_url?: string;
  is_active: boolean;
}

const Brands = () => {
  const [brands, setBrands] = useState<Brand[]>([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState<Brand | null>(null);
  const [name, setName] = useState('');
  const [isActive, setIsActive] = useState(true);
  const [saving, setSaving] = useState(false);

  const fetchBrands = async () => {
    setLoading(true);
    try {
      const res = await api.get('/brands/', { params: { active_only: false } });
      setBrands(res.data);
    } catch { toast.error('Failed to load brands'); }
    finally { setLoading(false); }
  };

  useEffect(() => { fetchBrands(); }, []);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && showModal) {
        setShowModal(false);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [showModal]);

  const openAdd = () => {
    setEditing(null);
    setName('');
    setIsActive(true);
    setShowModal(true);
  };

  const openEdit = (b: Brand) => {
    setEditing(b);
    setName(b.name);
    setIsActive(b.is_active ?? true);
    setShowModal(true);
  };

  const handleSave = async () => {
    if (!name.trim()) { toast.error('Brand name required'); return; }
    setSaving(true);
    try {
      if (editing) {
        await api.put(`/brands/${editing.id}`, { name: name.trim(), is_active: isActive });
        toast.success('Brand updated');
      } else {
        await api.post('/brands/', { name: name.trim(), is_active: isActive });
        toast.success('Brand created');
      }
      setShowModal(false);
      fetchBrands();
    } catch (e: any) {
      toast.error(e.response?.data?.detail || 'Failed to save brand');
    } finally { setSaving(false); }
  };

  const handleDelete = async (b: Brand) => {
    if (!confirm(`Delete "${b.name}"?`)) return;
    try {
      await api.delete(`/brands/${b.id}`);
      toast.success('Brand deleted');
      fetchBrands();
    } catch (e: any) {
      toast.error(e.response?.data?.detail || 'Failed to delete');
    }
  };

  return (
    <div className="layout">
      <Sidebar />
      <Toaster position="top-right" />

      <div className="main-content">
        <div className="page-header">
          <div>
            <h1 className="page-title">Brands</h1>
            <p style={{ color: 'var(--text-muted)', fontSize: 13, marginTop: 2 }}>
              {brands.length} brand{brands.length !== 1 ? 's' : ''} configured
            </p>
          </div>
          <button className="btn btn-primary" onClick={openAdd}>
            <FaPlus /> Add Brand
          </button>
        </div>

        <div className="page-body">
          <div className="table-container">
            {loading ? (
              <div style={{ padding: '48px 0', textAlign: 'center', color: 'var(--text-muted)' }}>Loading...</div>
            ) : (
              <table>
                <thead>
                  <tr>
                    <th>Brand Name</th>
                    <th>Status</th>
                    <th style={{ width: 100 }}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {brands.map((b, i) => (
                    <motion.tr key={b.id} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: i * 0.04 }}>
                      <td>
                        <span style={{ fontWeight: 600, fontSize: 13.5 }}>{b.name}</span>
                      </td>
                      <td>
                        <span className={`badge ${b.is_active ? 'badge-green' : 'badge-gray'}`}>
                          {b.is_active ? 'Active' : 'Inactive'}
                        </span>
                      </td>
                      <td>
                        <div style={{ display: 'flex', gap: 6 }}>
                          <button className="btn btn-ghost btn-sm btn-icon" onClick={() => openEdit(b)} title="Edit"><FaEdit /></button>
                          <button className="btn btn-ghost btn-sm btn-icon" style={{ color: 'var(--danger)' }} onClick={() => handleDelete(b)} title="Delete"><FaTrash /></button>
                        </div>
                      </td>
                    </motion.tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      </div>

      <AnimatePresence>
        {showModal && (
          <div className="modal-overlay" onClick={() => setShowModal(false)}>
            <motion.div
              className="modal-dialog"
              style={{ maxWidth: 420 }}
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.95, opacity: 0 }}
              transition={{ duration: 0.15 }}
              onClick={e => e.stopPropagation()}
            >
              <div className="drawer-header">
                <h2>{editing ? 'Edit Brand' : 'New Brand'}</h2>
              </div>
              <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 14 }}>
                <div className="form-group">
                  <label className="form-label required">Brand Name</label>
                  <input value={name} onChange={e => setName(e.target.value)} placeholder="e.g. Amul" autoFocus />
                </div>
                <div className="form-group">
                  <label className="form-label">Status</label>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 4 }}>
                    <label className="toggle">
                      <input
                        type="checkbox"
                        checked={isActive}
                        onChange={e => setIsActive(e.target.checked)}
                      />
                      <span className="toggle-slider" />
                    </label>
                    <span style={{ fontSize: 13, color: isActive ? 'var(--success)' : 'var(--text-muted)' }}>
                      {isActive ? 'Active in store' : 'Inactive'}
                    </span>
                  </div>
                </div>
              </div>
              <div className="drawer-footer">
                <button className="btn btn-ghost" onClick={() => setShowModal(false)}>Cancel</button>
                <button className="btn btn-primary" onClick={handleSave} disabled={saving}>
                  {saving ? 'Saving...' : editing ? 'Save' : 'Create'}
                </button>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
};

export default Brands;
