import { useState, useEffect, useCallback } from 'react';
import api from '../api';
import Sidebar from '../components/Sidebar';
import { Toaster, toast } from 'react-hot-toast';
import {
  FaBoxes, FaExclamationTriangle, FaTimesCircle, FaCheckCircle,
  FaSearch, FaSyncAlt, FaPlus, FaMinus, FaEdit
} from 'react-icons/fa';
import { motion, AnimatePresence } from 'framer-motion';

interface InventoryItem {
  variant_id: number;
  product_id: number;
  product_name: string;
  category_name: string;
  variant_name: string;
  stock_quantity: number;
  low_stock_alert: number;
  mrp: number;
  selling_price: number;
  is_available: boolean;
  sku?: string;
}

interface Summary {
  total_variants: number;
  out_of_stock: number;
  low_stock: number;
  healthy_stock: number;
}

const Inventory = () => {
  const [items, setItems] = useState<InventoryItem[]>([]);
  const [summary, setSummary] = useState<Summary | null>(null);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'all' | 'low' | 'out'>('all');
  const [search, setSearch] = useState('');

  // Quick adjust modal
  const [adjustItem, setAdjustItem] = useState<InventoryItem | null>(null);
  const [adjustQty, setAdjustQty] = useState<string>('');
  const [adjustMode, setAdjustMode] = useState<'add' | 'set'>('add');
  const [savingAdjust, setSavingAdjust] = useState(false);

  const fetchInventory = useCallback(async () => {
    setLoading(true);
    try {
      const [invRes, sumRes] = await Promise.all([
        api.get('/inventory/all', { params: { search: search || undefined } }),
        api.get('/inventory/summary')
      ]);
      setItems(invRes.data);
      setSummary(sumRes.data);
    } catch {
      toast.error('Failed to load inventory data');
    } finally {
      setLoading(false);
    }
  }, [search]);

  useEffect(() => {
    fetchInventory();
  }, [fetchInventory]);

  // Escape key closes modal
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setAdjustItem(null);
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  const handleQuickAdjust = async (item: InventoryItem, delta: number) => {
    try {
      await api.patch(`/products/${item.product_id}/variants/${item.variant_id}/stock`, {
        quantity: delta,
        variant_id: item.variant_id
      });
      toast.success(`Updated stock for ${item.product_name} (${item.variant_name})`);
      fetchInventory();
    } catch {
      toast.error('Failed to update stock');
    }
  };

  const handleSaveAdjust = async () => {
    if (!adjustItem) return;
    const val = parseInt(adjustQty, 10);
    if (isNaN(val)) {
      toast.error('Please enter a valid number');
      return;
    }

    const delta = adjustMode === 'set' ? val - adjustItem.stock_quantity : val;
    setSavingAdjust(true);
    try {
      await api.patch(`/products/${adjustItem.product_id}/variants/${adjustItem.variant_id}/stock`, {
        quantity: delta,
        variant_id: adjustItem.variant_id
      });
      toast.success(`Stock updated to ${Math.max(0, adjustItem.stock_quantity + delta)}`);
      setAdjustItem(null);
      setAdjustQty('');
      fetchInventory();
    } catch {
      toast.error('Failed to update stock');
    } finally {
      setSavingAdjust(false);
    }
  };

  const displayedItems = items.filter(item => {
    if (activeTab === 'low') {
      return item.stock_quantity > 0 && item.stock_quantity <= item.low_stock_alert;
    }
    if (activeTab === 'out') {
      return item.stock_quantity === 0;
    }
    return true;
  });

  return (
    <div className="layout">
      <Sidebar />
      <Toaster position="top-right" />

      <div className="main-content" style={{ display: 'flex', flexDirection: 'column', height: '100vh', overflow: 'hidden' }}>
        {/* Page Header */}
        <div style={{ padding: '24px 32px 16px', flexShrink: 0, borderBottom: '1px solid var(--border-color)', background: 'var(--bg-surface)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
            <div>
              <h1 style={{ margin: 0, color: 'var(--text-primary)', fontSize: '1.6rem', display: 'flex', alignItems: 'center', gap: 12 }}>
                <FaBoxes color="var(--brand-primary)" /> Inventory &amp; Stock
              </h1>
              <p style={{ margin: '4px 0 0', color: 'var(--text-muted)', fontSize: '0.9em' }}>
                Track and adjust SKU inventory across your catalog
              </p>
            </div>
            <button
              onClick={fetchInventory}
              disabled={loading}
              className="btn btn-ghost"
              style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: '0.88em' }}
            >
              <FaSyncAlt className={loading ? 'animate-spin' : ''} /> Refresh
            </button>
          </div>

          {/* Metric Cards */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 14 }}>
            <div
              onClick={() => setActiveTab('all')}
              style={{
                background: activeTab === 'all' ? 'var(--brand-light)' : 'var(--bg-surface-elevated)',
                border: `1px solid ${activeTab === 'all' ? 'var(--brand-primary)' : 'var(--border)'}`,
                padding: '12px 16px', borderRadius: 'var(--radius-md)', cursor: 'pointer', transition: 'all var(--transition-fast)'
              }}
            >
              <div style={{ fontSize: '0.78em', color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase' }}>Total SKUs</div>
              <div style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)', marginTop: 2 }}>
                {summary?.total_variants ?? items.length}
              </div>
            </div>

            <div
              onClick={() => setActiveTab('all')}
              style={{
                background: 'var(--bg-surface-elevated)',
                border: '1px solid var(--border)',
                padding: '12px 16px', borderRadius: 'var(--radius-md)', cursor: 'pointer'
              }}
            >
              <div style={{ fontSize: '0.78em', color: 'var(--success)', fontWeight: 600, textTransform: 'uppercase', display: 'flex', alignItems: 'center', gap: 5 }}>
                <FaCheckCircle size={11} /> Healthy
              </div>
              <div style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)', marginTop: 2 }}>
                {summary?.healthy_stock ?? 0}
              </div>
            </div>

            <div
              onClick={() => setActiveTab('low')}
              style={{
                background: activeTab === 'low' ? 'rgba(234, 179, 8, 0.15)' : 'var(--bg-surface-elevated)',
                border: `1px solid ${activeTab === 'low' ? '#eab308' : 'var(--border)'}`,
                padding: '12px 16px', borderRadius: 'var(--radius-md)', cursor: 'pointer', transition: 'all var(--transition-fast)'
              }}
            >
              <div style={{ fontSize: '0.78em', color: '#eab308', fontWeight: 600, textTransform: 'uppercase', display: 'flex', alignItems: 'center', gap: 5 }}>
                <FaExclamationTriangle size={11} /> Low Stock
              </div>
              <div style={{ fontSize: '1.4rem', fontWeight: 800, color: '#eab308', marginTop: 2 }}>
                {summary?.low_stock ?? 0}
              </div>
            </div>

            <div
              onClick={() => setActiveTab('out')}
              style={{
                background: activeTab === 'out' ? 'rgba(239, 68, 68, 0.15)' : 'var(--bg-surface-elevated)',
                border: `1px solid ${activeTab === 'out' ? 'var(--danger)' : 'var(--border)'}`,
                padding: '12px 16px', borderRadius: 'var(--radius-md)', cursor: 'pointer', transition: 'all var(--transition-fast)'
              }}
            >
              <div style={{ fontSize: '0.78em', color: 'var(--danger)', fontWeight: 600, textTransform: 'uppercase', display: 'flex', alignItems: 'center', gap: 5 }}>
                <FaTimesCircle size={11} /> Out of Stock
              </div>
              <div style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--danger)', marginTop: 2 }}>
                {summary?.out_of_stock ?? 0}
              </div>
            </div>
          </div>
        </div>

        {/* Filter bar & Tab selector */}
        <div style={{ padding: '14px 32px', display: 'flex', alignItems: 'center', gap: 12, borderBottom: '1px solid var(--border)', background: 'var(--bg-surface)' }}>
          <div style={{ display: 'flex', background: 'var(--bg-input)', borderRadius: 'var(--radius-md)', padding: 3 }}>
            <button
              onClick={() => setActiveTab('all')}
              style={{
                padding: '6px 14px', border: 'none', borderRadius: 'var(--radius-sm)',
                background: activeTab === 'all' ? 'var(--bg-surface)' : 'transparent',
                color: activeTab === 'all' ? 'var(--text-primary)' : 'var(--text-muted)',
                fontWeight: activeTab === 'all' ? 700 : 500, fontSize: '0.85em', cursor: 'pointer',
                boxShadow: activeTab === 'all' ? 'var(--shadow-xs)' : 'none'
              }}
            >
              All Items ({items.length})
            </button>
            <button
              onClick={() => setActiveTab('low')}
              style={{
                padding: '6px 14px', border: 'none', borderRadius: 'var(--radius-sm)',
                background: activeTab === 'low' ? 'var(--bg-surface)' : 'transparent',
                color: activeTab === 'low' ? '#eab308' : 'var(--text-muted)',
                fontWeight: activeTab === 'low' ? 700 : 500, fontSize: '0.85em', cursor: 'pointer',
                boxShadow: activeTab === 'low' ? 'var(--shadow-xs)' : 'none'
              }}
            >
              Low Stock ({summary?.low_stock ?? 0})
            </button>
            <button
              onClick={() => setActiveTab('out')}
              style={{
                padding: '6px 14px', border: 'none', borderRadius: 'var(--radius-sm)',
                background: activeTab === 'out' ? 'var(--bg-surface)' : 'transparent',
                color: activeTab === 'out' ? 'var(--danger)' : 'var(--text-muted)',
                fontWeight: activeTab === 'out' ? 700 : 500, fontSize: '0.85em', cursor: 'pointer',
                boxShadow: activeTab === 'out' ? 'var(--shadow-xs)' : 'none'
              }}
            >
              Out of Stock ({summary?.out_of_stock ?? 0})
            </button>
          </div>

          <div style={{ position: 'relative', width: 280, marginLeft: 'auto' }}>
            <FaSearch style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)', fontSize: 13 }} />
            <input
              value={search}
              onChange={e => setSearch(e.target.value)}
              placeholder="Search product, variant, SKU..."
              style={{
                width: '100%', padding: '7px 12px 7px 34px', borderRadius: 'var(--radius-md)',
                border: '1px solid var(--border)', background: 'var(--bg-input)', color: 'var(--text-primary)',
                fontSize: '0.85em'
              }}
            />
          </div>
        </div>

        {/* Table Content */}
        <div style={{ flex: 1, overflowY: 'auto', padding: '20px 32px 32px' }}>
          {loading ? (
            <div style={{ display: 'flex', height: 200, alignItems: 'center', justifyContent: 'center', color: 'var(--text-muted)' }}>
              Loading inventory...
            </div>
          ) : displayedItems.length === 0 ? (
            <div className="empty-state">
              <FaBoxes style={{ fontSize: 40, color: 'var(--text-muted)', marginBottom: 12 }} />
              <h3>No inventory records found</h3>
              <p>Try clearing your search or filter</p>
            </div>
          ) : (
            <div style={{ background: 'var(--bg-surface)', borderRadius: 'var(--radius-lg)', border: '1px solid var(--border)', overflow: 'hidden' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.88em' }}>
                <thead>
                  <tr style={{ background: 'var(--bg-surface-elevated)', borderBottom: '1px solid var(--border)' }}>
                    <th style={{ textAlign: 'left', padding: '12px 16px', color: 'var(--text-muted)', fontWeight: 600 }}>Product &amp; Variant</th>
                    <th style={{ textAlign: 'left', padding: '12px 16px', color: 'var(--text-muted)', fontWeight: 600 }}>Category</th>
                    <th style={{ textAlign: 'left', padding: '12px 16px', color: 'var(--text-muted)', fontWeight: 600 }}>SKU</th>
                    <th style={{ textAlign: 'right', padding: '12px 16px', color: 'var(--text-muted)', fontWeight: 600 }}>Selling Price</th>
                    <th style={{ textAlign: 'center', padding: '12px 16px', color: 'var(--text-muted)', fontWeight: 600 }}>Status</th>
                    <th style={{ textAlign: 'center', padding: '12px 16px', color: 'var(--text-muted)', fontWeight: 600 }}>Stock Qty</th>
                    <th style={{ textAlign: 'right', padding: '12px 16px', color: 'var(--text-muted)', fontWeight: 600 }}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {displayedItems.map((item) => {
                    const isOut = item.stock_quantity === 0;
                    const isLow = !isOut && item.stock_quantity <= item.low_stock_alert;

                    return (
                      <tr
                        key={item.variant_id}
                        style={{ borderBottom: '1px solid var(--border)', transition: 'background var(--transition-fast)' }}
                        className="table-row-hover"
                      >
                        <td style={{ padding: '12px 16px' }}>
                          <div style={{ fontWeight: 600, color: 'var(--text-primary)' }}>{item.product_name}</div>
                          <div style={{ fontSize: '0.85em', color: 'var(--text-muted)' }}>{item.variant_name}</div>
                        </td>
                        <td style={{ padding: '12px 16px', color: 'var(--text-secondary)' }}>
                          {item.category_name}
                        </td>
                        <td style={{ padding: '12px 16px', color: 'var(--text-muted)', fontFamily: 'monospace', fontSize: '0.9em' }}>
                          {item.sku || '—'}
                        </td>
                        <td style={{ padding: '12px 16px', textAlign: 'right', fontWeight: 600, color: 'var(--text-primary)' }}>
                          ₹{item.selling_price}
                        </td>
                        <td style={{ padding: '12px 16px', textAlign: 'center' }}>
                          {isOut ? (
                            <span className="badge badge-danger">Out of Stock</span>
                          ) : isLow ? (
                            <span className="badge badge-warning">Low ({item.stock_quantity})</span>
                          ) : (
                            <span className="badge badge-success">In Stock</span>
                          )}
                        </td>
                        <td style={{ padding: '12px 16px', textAlign: 'center' }}>
                          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                            <button
                              onClick={() => handleQuickAdjust(item, -1)}
                              disabled={item.stock_quantity <= 0}
                              title="Decrease stock by 1"
                              style={{
                                width: 24, height: 24, borderRadius: 'var(--radius-xs)', border: '1px solid var(--border)',
                                background: 'var(--bg-surface-elevated)', color: 'var(--text-primary)', cursor: 'pointer',
                                display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 10
                              }}
                            >
                              <FaMinus />
                            </button>
                            <span style={{ fontWeight: 700, minWidth: 36, textAlign: 'center', color: isOut ? 'var(--danger)' : isLow ? '#eab308' : 'var(--text-primary)' }}>
                              {item.stock_quantity}
                            </span>
                            <button
                              onClick={() => handleQuickAdjust(item, 1)}
                              title="Increase stock by 1"
                              style={{
                                width: 24, height: 24, borderRadius: 'var(--radius-xs)', border: '1px solid var(--border)',
                                background: 'var(--bg-surface-elevated)', color: 'var(--text-primary)', cursor: 'pointer',
                                display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 10
                              }}
                            >
                              <FaPlus />
                            </button>
                          </div>
                        </td>
                        <td style={{ padding: '12px 16px', textAlign: 'right' }}>
                          <button
                            onClick={() => {
                              setAdjustItem(item);
                              setAdjustQty(String(item.stock_quantity));
                              setAdjustMode('set');
                            }}
                            className="btn btn-ghost"
                            style={{ padding: '5px 10px', fontSize: '0.82em', display: 'inline-flex', alignItems: 'center', gap: 5 }}
                          >
                            <FaEdit size={12} /> Adjust
                          </button>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>

      {/* Adjust Stock Modal */}
      <AnimatePresence>
        {adjustItem && (
          <div className="modal-overlay" onClick={() => setAdjustItem(null)}>
            <motion.div
              className="modal-dialog"
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.95, opacity: 0 }}
              transition={{ duration: 0.15 }}
              onClick={e => e.stopPropagation()}
              style={{ maxWidth: 420 }}
            >
              <div className="drawer-header">
                <h2>Adjust Stock</h2>
              </div>
              <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 14 }}>
                <div>
                  <div style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: '1.05rem' }}>
                    {adjustItem.product_name}
                  </div>
                  <div style={{ color: 'var(--text-muted)', fontSize: '0.85em' }}>
                    Variant: {adjustItem.variant_name} &bull; Current Stock: <strong style={{ color: 'var(--text-primary)' }}>{adjustItem.stock_quantity}</strong>
                  </div>
                </div>

                <div style={{ display: 'flex', gap: 8, background: 'var(--bg-input)', padding: 3, borderRadius: 'var(--radius-md)' }}>
                  <button
                    type="button"
                    onClick={() => setAdjustMode('set')}
                    style={{
                      flex: 1, padding: '7px 0', border: 'none', borderRadius: 'var(--radius-sm)',
                      background: adjustMode === 'set' ? 'var(--bg-surface)' : 'transparent',
                      color: adjustMode === 'set' ? 'var(--text-primary)' : 'var(--text-muted)',
                      fontWeight: adjustMode === 'set' ? 700 : 500, fontSize: '0.85em', cursor: 'pointer'
                    }}
                  >
                    Set Exact Qty
                  </button>
                  <button
                    type="button"
                    onClick={() => { setAdjustMode('add'); setAdjustQty('10'); }}
                    style={{
                      flex: 1, padding: '7px 0', border: 'none', borderRadius: 'var(--radius-sm)',
                      background: adjustMode === 'add' ? 'var(--bg-surface)' : 'transparent',
                      color: adjustMode === 'add' ? 'var(--text-primary)' : 'var(--text-muted)',
                      fontWeight: adjustMode === 'add' ? 700 : 500, fontSize: '0.85em', cursor: 'pointer'
                    }}
                  >
                    Add / Restock Qty
                  </button>
                </div>

                <div className="form-group">
                  <label className="form-label required">
                    {adjustMode === 'set' ? 'New Total Stock Quantity' : 'Quantity to Add'}
                  </label>
                  <input
                    type="number"
                    value={adjustQty}
                    onChange={e => setAdjustQty(e.target.value)}
                    min={adjustMode === 'set' ? 0 : 1}
                    placeholder={adjustMode === 'set' ? String(adjustItem.stock_quantity) : '10'}
                    autoFocus
                  />
                  <span style={{ fontSize: '0.8em', color: 'var(--text-muted)', marginTop: 4 }}>
                    Alert threshold is set at {adjustItem.low_stock_alert} units.
                  </span>
                </div>
              </div>

              <div className="drawer-footer">
                <button className="btn btn-ghost" onClick={() => setAdjustItem(null)}>Cancel</button>
                <button className="btn btn-primary" onClick={handleSaveAdjust} disabled={savingAdjust}>
                  {savingAdjust ? 'Saving...' : 'Update Stock'}
                </button>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
};

export default Inventory;
