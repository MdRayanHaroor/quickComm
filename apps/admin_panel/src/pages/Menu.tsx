import { useState, useEffect } from 'react';
import api from '../api';
import Sidebar from '../components/Sidebar';
import { FaPlus, FaTrash, FaEdit } from 'react-icons/fa';

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
        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '20px' }}>
          <h1>Menu Management</h1>
          <button className="btn btn-primary" onClick={() => { resetForm(); setShowModal(true); }}>
            <FaPlus /> Add Item
          </button>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(250px, 1fr))', gap: '20px' }}>
          {products.map(p => (
            <div key={p.id} className="card">
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <h3>{p.name}</h3>
                <span style={{ color: 'var(--primary)', fontWeight: 'bold' }}>₹{p.price}</span>
              </div>
              <p style={{ color: 'var(--text-dim)' }}>{p.category} • {p.size}</p>
              <div style={{ marginTop: '15px', display: 'flex', gap: '10px' }}>
                <button className="btn" style={{ background: '#374151', color: 'white' }} onClick={() => handleEdit(p)}>
                  <FaEdit />
                </button>
                <button className="btn btn-danger" onClick={() => handleDelete(p.id)}>
                  <FaTrash />
                </button>
              </div>
            </div>
          ))}
        </div>

        {/* Modal Overlay */}
        {showModal && (
          <div style={{
            position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
            backgroundColor: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center'
          }}>
            <div className="card" style={{ width: '400px' }}>
              <h2>{editingId ? 'Edit Item' : 'Add New Item'}</h2>
              <form onSubmit={handleSubmit}>
                <input placeholder="Item Name" value={name} onChange={e => setName(e.target.value)} required />
                <input placeholder="Price" type="number" value={price} onChange={e => setPrice(e.target.value)} required />
                <select value={size} onChange={e => setSize(e.target.value)}>
                  <option>Single</option>
                  <option>Family</option>
                  <option>Jumbo</option>
                </select>
                <select value={category} onChange={e => setCategory(e.target.value)}>
                  <option>Main Course</option>
                  <option>Starters</option>
                  <option>Drinks</option>
                  <option>Dessert</option>
                </select>
                <div style={{ display: 'flex', gap: '10px', marginTop: '20px' }}>
                  <button type="submit" className="btn btn-primary" style={{ flex: 1 }}>Save</button>
                  <button type="button" className="btn" onClick={() => setShowModal(false)} style={{ background: '#4b5563' }}>Cancel</button>
                </div>
              </form>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default Menu;
