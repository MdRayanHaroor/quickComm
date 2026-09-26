import { useState, useEffect, useCallback } from 'react';
import api from '../api';
import Sidebar from '../components/Sidebar';
import { Toaster, toast } from 'react-hot-toast';
import {
  FaPlus, FaEdit, FaTrash, FaSearch,
  FaBoxOpen, FaImage, FaFileUpload
} from 'react-icons/fa';
import ProductDrawer from '../components/products/ProductDrawer';
import BulkImportModal from '../components/products/BulkImportModal';
import { motion, AnimatePresence } from 'framer-motion';

export interface Category {
  id: number;
  name: string;
  slug: string;
  parent_id: number | null;
}

export interface Brand {
  id: number;
  name: string;
  logo_url?: string;
}

export interface ProductVariant {
  id?: number;
  product_id?: number;
  variant_name: string;
  unit_value?: number;
  unit_type?: string;
  mrp: number;
  selling_price: number;
  stock_quantity: number;
  low_stock_alert: number;
  is_available: boolean;
  sku?: string;
  barcode?: string;
  sort_order: number;
}

export interface Product {
  id: number;
  name: string;
  slug?: string;
  description?: string;
  category_id?: number;
  brand_id?: number;
  images: string[];
  image_url?: string;
  tags: string[];
  gst_rate: number;
  is_available: boolean;
  created_at: string;
  updated_at?: string;
  // Aggregated
  min_price?: number;
  max_price?: number;
  variant_count?: number;
  total_stock?: number;
}

const SORT_OPTIONS = [
  { value: 'newest', label: 'Newest First' },
  { value: 'name_asc', label: 'Name A–Z' },
  { value: 'price_asc', label: 'Price: Low to High' },
  { value: 'price_desc', label: 'Price: High to Low' },
];

const StockBadge = ({ total }: { total?: number; variants?: number }) => {
  if (total === undefined) return <span className="badge badge-gray">No variants</span>;
  if (total === 0) return <span className="badge badge-red">Out of Stock</span>;
  if (total < 10) return <span className="badge badge-amber">Low: {total}</span>;
  return <span className="badge badge-green">In Stock</span>;
};

const Products = () => {
  const [products, setProducts] = useState<Product[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [brands, setBrands] = useState<Brand[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('');
  const [brandFilter, setBrandFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [sort, setSort] = useState('newest');
  const [page, setPage] = useState(1);
  const [showDrawer, setShowDrawer] = useState(false);
  const [showBulkImport, setShowBulkImport] = useState(false);
  const [editingProduct, setEditingProduct] = useState<Product | null>(null);

  // Debounce search input (350ms) so typing doesn't spam the API on every keystroke
  useEffect(() => {
    const t = setTimeout(() => {
      setDebouncedSearch(search);
      setPage(1);
    }, 350);
    return () => clearTimeout(t);
  }, [search]);

  // Load categories and brands once on initial mount
  useEffect(() => {
    Promise.all([
      api.get('/categories/'),
      api.get('/brands/'),
    ]).then(([catRes, brandRes]) => {
      setCategories(catRes.data);
      setBrands(brandRes.data);
    }).catch(() => {});
  }, []);

  const fetchProducts = useCallback(async () => {
    setLoading(true);
    try {
      const params: Record<string, string | number | boolean> = { page, sort };
      if (debouncedSearch.trim()) params.search = debouncedSearch.trim();
      if (categoryFilter) params.category_id = parseInt(categoryFilter);
      if (brandFilter) params.brand_id = parseInt(brandFilter);
      if (statusFilter !== '') params.is_available = statusFilter === 'true';

      const prodRes = await api.get('/products/', { params });
      setProducts(prodRes.data);
    } catch (e) {
      toast.error('Failed to load products');
    } finally {
      setLoading(false);
    }
  }, [page, debouncedSearch, categoryFilter, brandFilter, statusFilter, sort]);

  useEffect(() => { fetchProducts(); }, [fetchProducts]);
  const fetchAll = fetchProducts;

  const handleDelete = async (id: number, name: string) => {
    if (!confirm(`Delete "${name}"? This also removes all its variants.`)) return;
    try {
      await api.delete(`/products/${id}`);
      toast.success('Product deleted');
      fetchAll();
    } catch {
      toast.error('Failed to delete product');
    }
  };

  const handleToggleAvailable = async (product: Product) => {
    try {
      await api.put(`/products/${product.id}`, { is_available: !product.is_available });
      toast.success(product.is_available ? 'Product hidden' : 'Product made available');
      fetchAll();
    } catch {
      toast.error('Failed to update product');
    }
  };

  const getCategoryName = (id?: number) =>
    categories.find(c => c.id === id)?.name || '—';
  const getBrandName = (id?: number) =>
    brands.find(b => b.id === id)?.name || '—';

  const openAdd = () => { setEditingProduct(null); setShowDrawer(true); };
  const openEdit = (p: Product) => { setEditingProduct(p); setShowDrawer(true); };

  return (
    <div className="layout">
      <Sidebar />
      <Toaster position="top-right" />

      <div className="main-content">
        {/* Page Header */}
        <div className="page-header">
          <div>
            <h1 className="page-title">Products</h1>
            <p style={{ color: 'var(--text-muted)', fontSize: 13, marginTop: 2 }}>
              {products.length} items
            </p>
          </div>
          <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
            <button
              className="btn btn-secondary"
              onClick={() => setShowBulkImport(true)}
              style={{ display: 'flex', alignItems: 'center', gap: 6 }}
            >
              <FaFileUpload /> Bulk Import
            </button>
            <button className="btn btn-primary" onClick={openAdd} style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <FaPlus /> Add Product
            </button>
          </div>
        </div>

        <div className="page-body">
          {/* Filter Bar */}
          <div style={{ display: 'flex', gap: 10, marginBottom: 20, flexWrap: 'wrap', alignItems: 'center' }}>
            <div className="search-input-wrap">
              <FaSearch />
              <input
                type="search"
                placeholder="Search products..."
                value={search}
                onChange={e => setSearch(e.target.value)}
                style={{ width: '100%' }}
              />
            </div>

            <select
              value={categoryFilter}
              onChange={e => { setCategoryFilter(e.target.value); setPage(1); }}
              style={{ width: 170 }}
            >
              <option value="">All Categories</option>
              {categories.map(c => (
                <option key={c.id} value={c.id}>{c.name}</option>
              ))}
            </select>

            <select
              value={brandFilter}
              onChange={e => { setBrandFilter(e.target.value); setPage(1); }}
              style={{ width: 150 }}
            >
              <option value="">All Brands</option>
              {brands.map(b => (
                <option key={b.id} value={b.id}>{b.name}</option>
              ))}
            </select>

            <select
              value={statusFilter}
              onChange={e => { setStatusFilter(e.target.value); setPage(1); }}
              style={{ width: 140 }}
            >
              <option value="">All Status</option>
              <option value="true">Active</option>
              <option value="false">Inactive</option>
            </select>

            <select
              value={sort}
              onChange={e => setSort(e.target.value)}
              style={{ width: 170, marginLeft: 'auto' }}
            >
              {SORT_OPTIONS.map(o => (
                <option key={o.value} value={o.value}>{o.label}</option>
              ))}
            </select>
          </div>

          {/* Products Table */}
          <div className="table-container">
            {loading ? (
              <div style={{ padding: '60px 0', textAlign: 'center', color: 'var(--text-muted)' }}>
                <div style={{ fontSize: 32, marginBottom: 12 }}>⏳</div>
                Loading products...
              </div>
            ) : products.length === 0 ? (
              <div style={{ padding: '60px 0', textAlign: 'center', color: 'var(--text-muted)' }}>
                <FaBoxOpen style={{ fontSize: 48, marginBottom: 12, opacity: 0.3 }} />
                <div style={{ fontSize: 16, fontWeight: 600, color: 'var(--text-secondary)' }}>No products found</div>
                <div style={{ marginTop: 4, fontSize: 13 }}>Try adjusting your filters or add a new product</div>
                <button className="btn btn-primary" style={{ marginTop: 16 }} onClick={openAdd}>
                  <FaPlus /> Add First Product
                </button>
              </div>
            ) : (
              <table>
                <thead>
                  <tr>
                    <th style={{ width: 52 }}></th>
                    <th>Product</th>
                    <th>Category</th>
                    <th>Brand</th>
                    <th>Price</th>
                    <th>Stock</th>
                    <th>Variants</th>
                    <th>Status</th>
                    <th style={{ width: 60 }}></th>
                  </tr>
                </thead>
                <tbody>
                  <AnimatePresence>
                    {products.map((p, i) => (
                      <motion.tr
                        key={p.id}
                        initial={{ opacity: 0, y: 6 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{ delay: i * 0.03 }}
                      >
                        {/* Thumbnail */}
                        <td>
                          <div className="product-thumbnail">
                            {p.images?.[0] || p.image_url ? (
                              <img src={p.images?.[0] || p.image_url} alt={p.name} />
                            ) : (
                              <FaImage style={{ color: 'var(--text-muted)', fontSize: 18 }} />
                            )}
                          </div>
                        </td>

                        {/* Name */}
                        <td>
                          <div style={{ fontWeight: 600, fontSize: 13.5 }}>{p.name}</div>
                          {p.tags?.length > 0 && (
                            <div style={{ marginTop: 3, display: 'flex', gap: 4, flexWrap: 'wrap' }}>
                              {p.tags.slice(0, 3).map(tag => (
                                <span key={tag} className="badge badge-gray" style={{ fontSize: 10 }}>{tag}</span>
                              ))}
                            </div>
                          )}
                        </td>

                        <td style={{ color: 'var(--text-secondary)', fontSize: 13 }}>
                          {getCategoryName(p.category_id)}
                        </td>

                        <td style={{ color: 'var(--text-secondary)', fontSize: 13 }}>
                          {getBrandName(p.brand_id)}
                        </td>

                        {/* Price */}
                        <td>
                          {p.min_price !== undefined ? (
                            <span style={{ fontWeight: 600 }}>
                              ₹{p.min_price}
                              {p.max_price !== p.min_price && (
                                <span style={{ color: 'var(--text-muted)', fontWeight: 400 }}>
                                  {' '}– ₹{p.max_price}
                                </span>
                              )}
                            </span>
                          ) : (
                            <span className="text-muted">—</span>
                          )}
                        </td>

                        <td>
                          <StockBadge total={p.total_stock} variants={p.variant_count} />
                        </td>

                        <td style={{ color: 'var(--text-secondary)', fontSize: 13 }}>
                          {p.variant_count ?? 0} variant{(p.variant_count ?? 0) !== 1 ? 's' : ''}
                        </td>

                        {/* Status Toggle */}
                        <td>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                            <label className="toggle" title={p.is_available ? 'Active in store — click to hide' : 'Hidden from store — click to make active'}>
                              <input
                                type="checkbox"
                                checked={p.is_available}
                                onChange={() => handleToggleAvailable(p)}
                              />
                              <span className="toggle-slider" />
                            </label>
                            <span style={{ fontSize: 12, fontWeight: 500, color: p.is_available ? 'var(--success)' : 'var(--text-muted)' }}>
                              {p.is_available ? 'Active' : 'Hidden'}
                            </span>
                          </div>
                        </td>

                        {/* Actions */}
                        <td>
                          <div style={{ display: 'flex', gap: 4 }}>
                            <button
                              className="btn btn-ghost btn-sm btn-icon"
                              onClick={() => openEdit(p)}
                              title="Edit product"
                            >
                              <FaEdit />
                            </button>
                            <button
                              className="btn btn-ghost btn-sm btn-icon"
                              style={{ color: 'var(--danger)' }}
                              onClick={() => handleDelete(p.id, p.name)}
                              title="Delete product"
                            >
                              <FaTrash />
                            </button>
                          </div>
                        </td>
                      </motion.tr>
                    ))}
                  </AnimatePresence>
                </tbody>
              </table>
            )}
          </div>

          {/* Pagination */}
          {!loading && products.length > 0 && (
            <div style={{ display: 'flex', justifyContent: 'center', gap: 8, marginTop: 20 }}>
              <button
                className="btn btn-ghost btn-sm"
                disabled={page === 1}
                onClick={() => setPage(p => p - 1)}
              >
                ← Previous
              </button>
              <span style={{ display: 'flex', alignItems: 'center', fontSize: 13, color: 'var(--text-muted)' }}>
                Page {page}
              </span>
              <button
                className="btn btn-ghost btn-sm"
                disabled={products.length < 20}
                onClick={() => setPage(p => p + 1)}
              >
                Next →
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Product Add/Edit Drawer */}
      <AnimatePresence>
        {showDrawer && (
          <ProductDrawer
            product={editingProduct}
            categories={categories}
            brands={brands}
            onClose={() => setShowDrawer(false)}
            onSaved={() => { setShowDrawer(false); fetchAll(); }}
          />
        )}
      </AnimatePresence>

      {/* Bulk Product Import Modal */}
      <BulkImportModal
        isOpen={showBulkImport}
        onClose={() => setShowBulkImport(false)}
        onSuccess={() => fetchAll()}
      />
    </div>
  );
};

export default Products;
