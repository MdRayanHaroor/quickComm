import { useState, useEffect } from 'react';
import api from '../api';
import Sidebar from '../components/Sidebar';
import { Toaster, toast } from 'react-hot-toast';
import { FaPlus, FaEdit, FaTrash, FaChevronRight, FaChevronDown, FaLayerGroup } from 'react-icons/fa';
import { motion, AnimatePresence } from 'framer-motion';

interface Category {
  id: number;
  name: string;
  slug: string;
  parent_id: number | null;
  image_url?: string;
  sort_order: number;
  is_active: boolean;
}

const Categories = () => {
  const [categories, setCategories] = useState<Category[]>([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState<Category | null>(null);
  const [name, setName] = useState('');
  const [slug, setSlug] = useState('');
  const [parentId, setParentId] = useState('');
  const [sortOrder, setSortOrder] = useState('0');
  const [isActive, setIsActive] = useState(true);
  const [saving, setSaving] = useState(false);
  const [expandedIds, setExpandedIds] = useState<Set<number>>(new Set());

  const fetchCategories = async () => {
    setLoading(true);
    try {
      const res = await api.get('/categories/', { params: { active_only: false } });
      setCategories(res.data);
    } catch { toast.error('Failed to load categories'); }
    finally { setLoading(false); }
  };

  useEffect(() => { fetchCategories(); }, []);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && showModal) {
        setShowModal(false);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [showModal]);

  const toggleExpand = (id: number) => {
    setExpandedIds(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const openAdd = () => {
    setEditing(null);
    setName(''); setSlug(''); setParentId(''); setSortOrder('0');
    setIsActive(true);
    setShowModal(true);
  };

  const openEdit = (c: Category) => {
    setEditing(c);
    setName(c.name); setSlug(c.slug);
    setParentId(c.parent_id?.toString() || '');
    setSortOrder(c.sort_order.toString());
    setIsActive(c.is_active ?? true);
    setShowModal(true);
  };

  const handleNameChange = (val: string) => {
    setName(val);
    setSlug(val.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, ''));
  };

  const handleSave = async () => {
    if (!name.trim()) { toast.error('Category name required'); return; }
    const finalSlug = (slug || name).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
    setSaving(true);
    const data = {
      name: name.trim(),
      slug: finalSlug,
      parent_id: parentId ? parseInt(parentId) : null,
      sort_order: parseInt(sortOrder) || 0,
      is_active: isActive,
    };
    try {
      if (editing) {
        await api.put(`/categories/${editing.id}`, data);
        toast.success('Category updated');
      } else {
        await api.post('/categories/', data);
        toast.success('Category created');
      }
      setShowModal(false);
      fetchCategories();
    } catch (e: any) {
      toast.error(e.response?.data?.detail || 'Failed to save category');
    } finally { setSaving(false); }
  };

  const handleDelete = async (c: Category) => {
    if (!confirm(`Delete "${c.name}"?`)) return;
    try {
      await api.delete(`/categories/${c.id}`);
      toast.success('Category deleted');
      fetchCategories();
    } catch (e: any) {
      toast.error(e.response?.data?.detail || 'Failed to delete (may have products)');
    }
  };

  // Group: top-level first, then sub-categories
  const topLevel = categories.filter(c => !c.parent_id);
  const childrenOf = (id: number) => categories.filter(c => c.parent_id === id);

  return (
    <div className="layout">
      <Sidebar />
      <Toaster position="top-right" />

      <div className="main-content">
        <div className="page-header">
          <div>
            <h1 className="page-title">Categories</h1>
            <p style={{ color: 'var(--text-muted)', fontSize: 13, marginTop: 2 }}>
              {topLevel.length} top-level · {categories.length - topLevel.length} sub-categories
            </p>
          </div>
          <button className="btn btn-primary" onClick={openAdd}>
            <FaPlus /> Add Category
          </button>
        </div>

        <div className="page-body">
          {loading ? (
            <div style={{ padding: '60px 0', textAlign: 'center', color: 'var(--text-muted)' }}>Loading...</div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {topLevel.map(parent => {
                const subCats = childrenOf(parent.id);
                const isExpanded = expandedIds.has(parent.id);

                return (
                  <div key={parent.id} className="card" style={{ padding: 0, overflow: 'hidden' }}>
                    {/* Parent row (clickable to toggle accordion) */}
                    <div
                      onClick={() => toggleExpand(parent.id)}
                      style={{
                        display: 'flex', alignItems: 'center', padding: '14px 20px',
                        background: 'var(--bg-surface)',
                        cursor: 'pointer',
                        borderBottom: isExpanded && subCats.length > 0 ? '1px solid var(--border)' : 'none',
                        userSelect: 'none'
                      }}
                    >
                      <div style={{ marginRight: 12, color: 'var(--text-muted)', display: 'flex', alignItems: 'center', fontSize: 12 }}>
                        {isExpanded ? <FaChevronDown /> : <FaChevronRight />}
                      </div>
                      <FaLayerGroup style={{ color: 'var(--brand-primary)', marginRight: 10, fontSize: 15 }} />
                      <div style={{ flex: 1 }}>
                        <div style={{ fontWeight: 600, fontSize: 14, display: 'flex', alignItems: 'center', gap: 8 }}>
                          {parent.name}
                          {!parent.is_active && (
                            <span className="badge badge-gray" style={{ fontSize: 10 }}>Inactive</span>
                          )}
                        </div>
                        <div style={{ fontSize: 12, color: 'var(--text-muted)', marginTop: 1 }}>
                          {subCats.length} sub-categories
                        </div>
                      </div>
                      <div style={{ display: 'flex', gap: 6 }} onClick={e => e.stopPropagation()}>
                        <button className="btn btn-ghost btn-sm btn-icon" onClick={() => openEdit(parent)} title="Edit">
                          <FaEdit />
                        </button>
                        <button className="btn btn-ghost btn-sm btn-icon" style={{ color: 'var(--danger)' }} onClick={() => handleDelete(parent)} title="Delete">
                          <FaTrash />
                        </button>
                      </div>
                    </div>

                    {/* Children (Only shown when expanded — no expand arrow on leaf subcategories) */}
                    {isExpanded && subCats.map((child, i) => (
                      <div
                        key={child.id}
                        style={{
                          display: 'flex', alignItems: 'center',
                          padding: '11px 20px 11px 48px',
                          borderBottom: i < subCats.length - 1 ? '1px solid var(--border)' : 'none',
                          background: 'var(--bg-surface-hover)',
                        }}
                      >
                        <div style={{ flex: 1 }}>
                          <div style={{ fontWeight: 500, fontSize: 13.5 }}>{child.name}</div>
                        </div>
                        {!child.is_active && (
                          <span className="badge badge-gray" style={{ marginRight: 12 }}>
                            Inactive
                          </span>
                        )}
                        <div style={{ display: 'flex', gap: 6 }}>
                          <button className="btn btn-ghost btn-sm btn-icon" onClick={() => openEdit(child)} title="Edit">
                            <FaEdit />
                          </button>
                          <button className="btn btn-ghost btn-sm btn-icon" style={{ color: 'var(--danger)' }} onClick={() => handleDelete(child)} title="Delete">
                            <FaTrash />
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>

      {/* Centered Modal */}
      <AnimatePresence>
        {showModal && (
          <div className="modal-overlay" onClick={() => setShowModal(false)}>
            <motion.div
              className="modal-dialog"
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.95, opacity: 0 }}
              transition={{ duration: 0.15 }}
              onClick={e => e.stopPropagation()}
            >
              <div className="drawer-header">
                <h2>{editing ? 'Edit Category' : 'New Category'}</h2>
              </div>
              <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 14 }}>
                <div className="form-group">
                  <label className="form-label required">Category Name</label>
                  <input value={name} onChange={e => handleNameChange(e.target.value)} placeholder="e.g. Dairy & Eggs" autoFocus />
                </div>

                {/* URL Slug commented out — auto-generated from name
                <div className="form-group">
                  <label className="form-label required">Slug</label>
                  <input value={slug} onChange={e => setSlug(e.target.value)} placeholder="dairy-eggs" />
                </div>
                */}

                <div className="grid-2">
                  <div className="form-group">
                    <label className="form-label">Parent Category</label>
                    <select value={parentId} onChange={e => setParentId(e.target.value)}>
                      <option value="">None (Top-level)</option>
                      {categories.filter(c => !c.parent_id && c.id !== editing?.id).map(c => (
                        <option key={c.id} value={c.id}>{c.name}</option>
                      ))}
                    </select>
                  </div>
                  <div className="form-group">
                    <label className="form-label">Sort Order</label>
                    <input type="number" value={sortOrder} onChange={e => setSortOrder(e.target.value)} min={0} />
                  </div>
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
                      {isActive ? 'Active (visible in store)' : 'Inactive (hidden from store)'}
                    </span>
                  </div>
                </div>
              </div>
              <div className="drawer-footer">
                <button className="btn btn-ghost" onClick={() => setShowModal(false)}>Cancel</button>
                <button className="btn btn-primary" onClick={handleSave} disabled={saving}>
                  {saving ? 'Saving...' : editing ? 'Save Changes' : 'Create'}
                </button>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
};

export default Categories;
