import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { FaTimes } from 'react-icons/fa';
import { toast } from 'react-hot-toast';
import api from '../../api';
import type { Product, Category, Brand, ProductVariant } from '../../pages/Products';
import ProductImageUpload from './ProductImageUpload';
import VariantEditor from './VariantEditor';

interface Props {
  product: Product | null;
  categories: Category[];
  brands: Brand[];
  onClose: () => void;
  onSaved: () => void;
}

const GST_RATES = [0, 5, 12, 18, 28];
const EMPTY_VARIANT: ProductVariant = {
  variant_name: '',
  mrp: 0,
  selling_price: 0,
  stock_quantity: 0,
  low_stock_alert: 10,
  is_available: true,
  sort_order: 0,
};

const ProductDrawer = ({ product, categories, brands, onClose, onSaved }: Props) => {
  const isEdit = !!product;

  // Form fields
  const [name, setName] = useState('');
  const [slug, setSlug] = useState('');
  const [description, setDescription] = useState('');
  const [parentCategoryId, setParentCategoryId] = useState('');
  const [subCategoryId, setSubCategoryId] = useState('');
  const [categoryId, setCategoryId] = useState('');
  const [brandId, setBrandId] = useState('');
  const [tags, setTags] = useState('');
  const [gstRate, setGstRate] = useState(0);
  const [isAvailable, setIsAvailable] = useState(true);
  const [images, setImages] = useState<string[]>([]);
  const [variants, setVariants] = useState<ProductVariant[]>([{ ...EMPTY_VARIANT }]);
  const [saving, setSaving] = useState(false);
  const [activeTab, setActiveTab] = useState<'basic' | 'variants' | 'images'>('basic');
  const [productId, setProductId] = useState<number | null>(null);

  // Close drawer on Escape key
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [onClose]);

  // Load product data when editing
  useEffect(() => {
    if (product) {
      setName(product.name);
      setSlug(product.slug || '');
      setDescription(product.description || '');
      setBrandId(product.brand_id?.toString() || '');
      setTags((product.tags || []).join(', '));
      setGstRate(product.gst_rate || 0);
      setIsAvailable(product.is_available);
      setImages(product.images || []);
      setProductId(product.id);

      if (product.category_id) {
        const cat = categories.find(c => c.id === product.category_id);
        if (cat?.parent_id) {
          setParentCategoryId(cat.parent_id.toString());
          setSubCategoryId(cat.id.toString());
          setCategoryId(cat.id.toString());
        } else if (cat) {
          setParentCategoryId(cat.id.toString());
          setSubCategoryId('');
          setCategoryId(cat.id.toString());
        }
      } else {
        setParentCategoryId('');
        setSubCategoryId('');
        setCategoryId('');
      }

      // Load variants
      api.get(`/products/${product.id}/variants`).then(res => {
        if (res.data?.length > 0) setVariants(res.data);
      });
    } else {
      resetForm();
    }
  }, [product, categories]);

  const resetForm = () => {
    setName(''); setSlug(''); setDescription('');
    setParentCategoryId(''); setSubCategoryId(''); setCategoryId('');
    setBrandId(''); setTags('');
    setGstRate(0); setIsAvailable(true); setImages([]);
    setVariants([{ ...EMPTY_VARIANT }]);
    setProductId(null);
  };

  // Auto-generate slug from name
  const handleNameChange = (val: string) => {
    setName(val);
    setSlug(val.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, ''));
  };

  const handleParentCategoryChange = (val: string) => {
    setParentCategoryId(val);
    setSubCategoryId('');
    setCategoryId(val);
  };

  const handleSubCategoryChange = (val: string) => {
    setSubCategoryId(val);
    setCategoryId(val || parentCategoryId);
  };

  const validateVariants = () => {
    for (const v of variants) {
      if (!v.variant_name.trim()) return 'All variants must have a name.';
      if (v.mrp <= 0) return 'MRP must be greater than 0.';
      if (v.selling_price <= 0) return 'Selling price must be greater than 0.';
      if (v.selling_price > v.mrp) return `Selling price cannot exceed MRP for "${v.variant_name}".`;
    }
    return null;
  };

  const handleSave = async () => {
    if (!name.trim()) { toast.error('Product name is required.'); return; }
    const variantError = validateVariants();
    if (variantError) { toast.error(variantError); setActiveTab('variants'); return; }

    setSaving(true);
    try {
      const finalSlug = (slug || name).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
      const productData = {
        name: name.trim(),
        slug: finalSlug,
        description: description.trim() || undefined,
        category_id: categoryId ? parseInt(categoryId) : undefined,
        brand_id: brandId ? parseInt(brandId) : undefined,
        tags: tags ? tags.split(',').map(t => t.trim()).filter(Boolean) : [],
        gst_rate: gstRate,
        is_available: isAvailable,
        images,
        price: variants[0]?.selling_price || 0,
        image_url: images[0] || undefined,
      };

      let pid = productId;

      if (isEdit && pid) {
        // Update product metadata
        await api.put(`/products/${pid}`, productData);

        // Sync variants: delete old ones and re-create, or update existing
        const existingResp = await api.get(`/products/${pid}/variants`);
        const existingIds = new Set(existingResp.data.map((v: any) => v.id));

        for (const v of variants) {
          if (v.id && existingIds.has(v.id)) {
            // Update existing
            await api.put(`/products/${pid}/variants/${v.id}`, v);
          } else {
            // Create new
            await api.post(`/products/${pid}/variants`, { ...v, product_id: pid });
          }
        }

      } else {
        // Create new product
        const prodResp = await api.post('/products/', productData);
        pid = prodResp.data.id;

        // Create all variants
        for (const v of variants) {
          await api.post(`/products/${pid}/variants`, { ...v, product_id: pid });
        }
      }

      toast.success(isEdit ? 'Product updated!' : 'Product created!');
      onSaved();

    } catch (e: any) {
      toast.error(e.response?.data?.detail || 'Failed to save product.');
    } finally {
      setSaving(false);
    }
  };

  const tabStyle = (tab: string) => ({
    padding: '8px 16px',
    border: 'none',
    background: 'none',
    cursor: 'pointer',
    fontSize: 13.5,
    fontWeight: 600,
    color: activeTab === tab ? 'var(--brand-primary)' : 'var(--text-muted)',
    borderBottom: activeTab === tab ? '2px solid var(--brand-primary)' : '2px solid transparent',
    transition: 'all 0.15s ease',
  });

  return (
    <>
      {/* Overlay */}
      <motion.div
        className="drawer-overlay"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        transition={{ duration: 0.15 }}
        onClick={onClose}
      />

      {/* Drawer */}
      <motion.div
        className="drawer"
        initial={{ x: '100%' }}
        animate={{ x: 0 }}
        exit={{ x: '100%' }}
        transition={{ duration: 0.22, ease: [0.16, 1, 0.3, 1] }}
        style={{ willChange: 'transform' }}
      >
        {/* Header */}
        <div className="drawer-header">
          <h2>{isEdit ? 'Edit Product' : 'Add New Product'}</h2>
          <button className="btn btn-ghost btn-sm btn-icon" onClick={onClose}>
            <FaTimes />
          </button>
        </div>

        {/* Tabs */}
        <div style={{
          display: 'flex',
          borderBottom: '1px solid var(--border)',
          padding: '0 24px',
          background: 'var(--bg-surface)',
        }}>
          <button style={tabStyle('basic')} onClick={() => setActiveTab('basic')}>Basic Info</button>
          <button style={tabStyle('variants')} onClick={() => setActiveTab('variants')}>
            Variants ({variants.length})
          </button>
          <button style={tabStyle('images')} onClick={() => setActiveTab('images')}>
            Images ({images.length})
          </button>
        </div>

        {/* Body */}
        <div className="drawer-body">
          {/* ---- BASIC INFO TAB ---- */}
          {activeTab === 'basic' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
              <div className="form-group">
                <label className="form-label required">Product Name</label>
                <input
                  value={name}
                  onChange={e => handleNameChange(e.target.value)}
                  placeholder="e.g. Amul Gold Full Cream Milk"
                />
              </div>

              {/* URL Slug commented out — auto-generated from name
              <div className="form-group">
                <label className="form-label">URL Slug</label>
                <input
                  value={slug}
                  onChange={e => setSlug(e.target.value)}
                  placeholder="amul-gold-full-cream-milk"
                />
                <span className="form-hint">Auto-generated from name. Used in URLs.</span>
              </div>
              */}

              <div className="form-group">
                <label className="form-label">Description</label>
                <textarea
                  value={description}
                  onChange={e => setDescription(e.target.value)}
                  placeholder="Product details, features, ingredients..."
                  rows={3}
                />
              </div>

              {/* Separate Category & Sub Category Dropdowns */}
              <div className="grid-2">
                <div className="form-group">
                  <label className="form-label">Category</label>
                  <select
                    value={parentCategoryId}
                    onChange={e => handleParentCategoryChange(e.target.value)}
                  >
                    <option value="">Select Category...</option>
                    {categories.filter(c => !c.parent_id).map(c => (
                      <option key={c.id} value={c.id}>{c.name}</option>
                    ))}
                  </select>
                </div>

                <div className="form-group">
                  <label className="form-label">Sub Category</label>
                  <select
                    value={subCategoryId}
                    onChange={e => handleSubCategoryChange(e.target.value)}
                    disabled={!parentCategoryId}
                  >
                    <option value="">
                      {!parentCategoryId ? 'Select Category first' : 'Select Sub Category (Optional)...'}
                    </option>
                    {categories
                      .filter(c => c.parent_id === parseInt(parentCategoryId))
                      .map(c => (
                        <option key={c.id} value={c.id}>{c.name}</option>
                      ))}
                  </select>
                </div>
              </div>

              <div className="grid-2">
                <div className="form-group">
                  <label className="form-label">Brand</label>
                  <select value={brandId} onChange={e => setBrandId(e.target.value)}>
                    <option value="">Select brand...</option>
                    {brands.map(b => (
                      <option key={b.id} value={b.id}>{b.name}</option>
                    ))}
                  </select>
                </div>

                <div className="form-group">
                  <label className="form-label">GST Rate</label>
                  <select value={gstRate} onChange={e => setGstRate(parseFloat(e.target.value))}>
                    {GST_RATES.map(r => (
                      <option key={r} value={r}>{r}%</option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">Status</label>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 6 }}>
                  <label className="toggle">
                    <input
                      type="checkbox"
                      checked={isAvailable}
                      onChange={e => setIsAvailable(e.target.checked)}
                    />
                    <span className="toggle-slider" />
                  </label>
                  <span style={{ fontSize: 13, color: isAvailable ? 'var(--success)' : 'var(--text-muted)' }}>
                    {isAvailable ? 'Active in store' : 'Hidden from store'}
                  </span>
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">Tags</label>
                <input
                  value={tags}
                  onChange={e => setTags(e.target.value)}
                  placeholder="organic, fresh, bestseller (comma-separated)"
                />
                <span className="form-hint">Used for search and filtering. Separate with commas.</span>
              </div>
            </div>
          )}

          {/* ---- VARIANTS TAB ---- */}
          {activeTab === 'variants' && (
            <VariantEditor
              variants={variants}
              onChange={setVariants}
            />
          )}

          {/* ---- IMAGES TAB ---- */}
          {activeTab === 'images' && (
            <ProductImageUpload
              productId={productId}
              images={images}
              onChange={setImages}
            />
          )}
        </div>

        {/* Footer */}
        <div className="drawer-footer">
          <button className="btn btn-ghost" onClick={onClose}>Cancel</button>
          <button className="btn btn-primary" onClick={handleSave} disabled={saving}>
            {saving ? 'Saving...' : isEdit ? 'Save Changes' : 'Create Product'}
          </button>
        </div>
      </motion.div>
    </>
  );
};

export default ProductDrawer;
