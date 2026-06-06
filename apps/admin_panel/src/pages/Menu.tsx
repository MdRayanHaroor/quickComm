import { useState, useEffect } from 'react';
import api from '../api';
import Sidebar from '../components/Sidebar';
import { FaPlus, FaTrash, FaEdit } from 'react-icons/fa';
import { motion, AnimatePresence } from 'framer-motion';

interface Product {
  id: number;
  name: string;
  price: number;
  size: string;
  category: string;
  is_available: boolean;
}

const Menu = () => {
  const [products, setProducts] = useState<Product[]>([]);
  const [showModal, setShowModal] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  
  // Form State
  const [name, setName] = useState('');
  const [price, setPrice] = useState('');
  const [size, setSize] = useState('Single');
  const [category, setCategory] = useState('Main Course');

  const fetchProducts = async () => {
    try {
      const res = await api.get('/products/');
      setProducts(res.data);
    } catch (e) {
      console.error(e);
    }
  };

  useEffect(() => {
    fetchProducts();

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setShowModal(false);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const payload = { 
      name, 
      price: parseFloat(price), 
      size, 
      category,
      is_available: true 
    };

    try {
      if (editingId) {
        await api.put(`/products/${editingId}`, payload);
      } else {
        await api.post('/products/', payload);
      }
      setShowModal(false);
      resetForm();
      fetchProducts();
    } catch (error) {
      alert('Error saving product');
    }
  };

  const handleDelete = async (id: number) => {
    if (confirm('Are you sure?')) {
      await api.delete(`/products/${id}`);
      fetchProducts();
    }
  };

  const handleEdit = (p: Product) => {
    setName(p.name);
    setPrice(p.price.toString());
    setSize(p.size);
    setCategory(p.category);
    setEditingId(p.id);
    setShowModal(true);
  };

  const resetForm = () => {
    setName('');
    setPrice('');
    setSize('Single');
    setCategory('Main Course');
    setEditingId(null);
  };

  return (
    <div className="layout">
      <Sidebar />
      <div className="content">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '30px' }}>
          <h1 style={{ color: 'var(--text-primary)', fontSize: '2rem' }}>Menu Management</h1>
          <button className="btn btn-primary" onClick={() => { resetForm(); setShowModal(true); }}>
            <FaPlus style={{ marginRight: '8px' }} /> Add Item
          </button>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: '24px' }}>
          {products.map((p, idx) => (
            <motion.div 
              initial={{ opacity: 0, y: 15 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: idx * 0.05 }}
              key={p.id} 
              className="card"
              style={{ padding: '24px', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}
            >
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '10px' }}>
                  <h3 style={{ fontSize: '1.2rem', color: 'var(--text-primary)', lineHeight: 1.2 }}>{p.name}</h3>
                  <span style={{ color: 'var(--accent-primary)', fontWeight: 'bold', fontSize: '1.2rem' }}>₹{p.price}</span>
                </div>
                <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem' }}>
                  <span style={{ 
                    padding: '4px 8px', 
                    background: 'var(--bg-surface-elevated)', 
                    borderRadius: '4px',
                    marginRight: '8px',
                    border: '1px solid var(--border-color)'
                  }}>
                    {p.category}
                  </span>
                  {p.size}
                </p>
              </div>
              <div style={{ marginTop: '20px', display: 'flex', gap: '10px' }}>
                <button 
                  className="btn" 
                  style={{ flex: 1, background: 'var(--bg-surface-elevated)', color: 'var(--text-primary)', border: '1px solid var(--border-color)' }} 
                  onClick={() => handleEdit(p)}
                >
                  <FaEdit />
                </button>
                <button 
                  className="btn btn-danger" 
                  style={{ flex: 1 }} 
                  onClick={() => handleDelete(p.id)}
                >
                  <FaTrash />
                </button>
              </div>
            </motion.div>
          ))}
        </div>

        {/* Modal Overlay */}
        <AnimatePresence>
          {showModal && (
            <motion.div 
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              style={{
                position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
                backgroundColor: 'rgba(0,0,0,0.8)', display: 'flex', alignItems: 'center', justifyContent: 'center',
                zIndex: 1000,
                backdropFilter: 'blur(4px)'
              }}
            >
              <motion.div 
                initial={{ scale: 0.95, y: 20 }}
                animate={{ scale: 1, y: 0 }}
                exit={{ scale: 0.95, y: 20 }}
                className="card" 
                style={{ width: '100%', maxWidth: '450px', margin: '20px', position: 'relative' }}
              >
                <h2 style={{ marginBottom: '25px', color: 'var(--accent-primary)', fontSize: '1.8rem' }}>{editingId ? 'Edit Item' : 'Add New Item'}</h2>
                <form onSubmit={handleSubmit}>
                  <div style={{ marginBottom: '15px' }}>
                    <label style={{ display: 'block', marginBottom: '8px', color: 'var(--text-muted)', fontSize: '0.9rem' }}>Item Name</label>
                    <input placeholder="e.g. Hyderabadi Chicken Dum Biryani" value={name} onChange={e => setName(e.target.value)} required />
                  </div>
                  
                  <div style={{ marginBottom: '15px' }}>
                    <label style={{ display: 'block', marginBottom: '8px', color: 'var(--text-muted)', fontSize: '0.9rem' }}>Price (₹)</label>
                    <input placeholder="0.00" type="number" value={price} onChange={e => setPrice(e.target.value)} required />
                  </div>
                  
                  <div style={{ display: 'flex', gap: '15px', marginBottom: '25px' }}>
                    <div style={{ flex: 1 }}>
                      <label style={{ display: 'block', marginBottom: '8px', color: 'var(--text-muted)', fontSize: '0.9rem' }}>Portion Size</label>
                      <select value={size} onChange={e => setSize(e.target.value)}>
                        <option>Single</option>
                        <option>Family</option>
                        <option>Jumbo</option>
                      </select>
                    </div>
                    <div style={{ flex: 1 }}>
                      <label style={{ display: 'block', marginBottom: '8px', color: 'var(--text-muted)', fontSize: '0.9rem' }}>Category</label>
                      <select value={category} onChange={e => setCategory(e.target.value)}>
                        <option>Main Course</option>
                        <option>Starters</option>
                        <option>Drinks</option>
                        <option>Dessert</option>
                      </select>
                    </div>
                  </div>

                  <div style={{ display: 'flex', gap: '15px' }}>
                    <button type="submit" className="btn btn-primary" style={{ flex: 1 }}>{editingId ? 'Save Changes' : 'Create Item'}</button>
                    <button type="button" className="btn" onClick={() => setShowModal(false)} style={{ flex: 1, background: 'transparent', border: '1px solid var(--border-color)', color: 'var(--text-primary)' }}>Cancel</button>
                  </div>
                </form>
              </motion.div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
};

export default Menu;
