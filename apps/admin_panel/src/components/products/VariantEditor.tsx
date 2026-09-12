import { useState } from 'react';
import { FaPlus, FaTrash, FaBarcode } from 'react-icons/fa';
import BarcodeScannerModal from './BarcodeScannerModal';
import type { ProductVariant } from '../../pages/Products';

interface Props {
  variants: ProductVariant[];
  onChange: (variants: ProductVariant[]) => void;
}

const UNIT_TYPES = ['ml', 'l', 'g', 'kg', 'pcs', 'pack', 'dozen'];

const VariantEditor = ({ variants, onChange }: Props) => {
  const [scanningIdx, setScanningIdx] = useState<number | null>(null);

  const add = () => {
    onChange([...variants, {
      variant_name: '',
      mrp: 0,
      selling_price: 0,
      stock_quantity: 0,
      low_stock_alert: 10,
      is_available: true,
      sort_order: variants.length,
    }]);
  };

  const remove = (idx: number) => {
    if (variants.length <= 1) return;
    onChange(variants.filter((_, i) => i !== idx));
  };

  const update = (idx: number, field: keyof ProductVariant, value: any) => {
    const updated = [...variants];
    updated[idx] = { ...updated[idx], [field]: value };
    onChange(updated);
  };

  const discountPct = (mrp: number, sp: number) => {
    if (!mrp || mrp <= 0) return 0;
    return Math.round(((mrp - sp) / mrp) * 100);
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontWeight: 600, fontSize: 14 }}>Product Variants</div>
          <div style={{ fontSize: 12, color: 'var(--text-muted)', marginTop: 2 }}>
            Each variant is a separate SKU (size, weight, pack size)
          </div>
        </div>
        <button className="btn btn-secondary btn-sm" onClick={add} type="button">
          <FaPlus /> Add Variant
        </button>
      </div>

      {variants.map((v, idx) => (
        <div
          key={idx}
          className="card"
          style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 12 }}
        >
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <span style={{ fontWeight: 600, fontSize: 13, color: 'var(--text-secondary)' }}>
              Variant #{idx + 1}
            </span>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <label className="toggle" title="Available">
                <input
                  type="checkbox"
                  checked={v.is_available}
                  onChange={e => update(idx, 'is_available', e.target.checked)}
                />
                <span className="toggle-slider" />
              </label>
              <button
                className="btn btn-ghost btn-sm btn-icon"
                style={{ color: 'var(--danger)' }}
                onClick={() => remove(idx)}
                disabled={variants.length <= 1}
                title="Remove variant"
                type="button"
              >
                <FaTrash />
              </button>
            </div>
          </div>

          {/* Row 1: Name + Unit */}
          <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr 1fr', gap: 10 }}>
            <div className="form-group">
              <label className="form-label required">Variant Name</label>
              <input
                value={v.variant_name}
                onChange={e => update(idx, 'variant_name', e.target.value)}
                placeholder="e.g. 500 ml, 1 kg, Pack of 6"
              />
            </div>
            <div className="form-group">
              <label className="form-label">Unit Value</label>
              <input
                type="number"
                value={v.unit_value || ''}
                onChange={e => update(idx, 'unit_value', parseFloat(e.target.value) || null)}
                placeholder="500"
              />
            </div>
            <div className="form-group">
              <label className="form-label">Unit Type</label>
              <select value={v.unit_type || ''} onChange={e => update(idx, 'unit_type', e.target.value)}>
                <option value="">— select —</option>
                {UNIT_TYPES.map(u => <option key={u} value={u}>{u}</option>)}
              </select>
            </div>
          </div>

          {/* Row 2: Pricing */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr auto', gap: 10, alignItems: 'end' }}>
            <div className="form-group">
              <label className="form-label required">MRP (₹)</label>
              <input
                type="number"
                value={v.mrp || ''}
                onChange={e => update(idx, 'mrp', parseFloat(e.target.value) || 0)}
                placeholder="0.00"
                min={0}
              />
            </div>
            <div className="form-group">
              <label className="form-label required">Selling Price (₹)</label>
              <input
                type="number"
                value={v.selling_price || ''}
                onChange={e => update(idx, 'selling_price', parseFloat(e.target.value) || 0)}
                placeholder="0.00"
                min={0}
                className={v.selling_price > v.mrp ? 'input-error' : ''}
              />
              {v.selling_price > v.mrp && (
                <span className="form-error">Cannot exceed MRP</span>
              )}
            </div>
            <div style={{ paddingBottom: 2 }}>
              {v.mrp > 0 && v.selling_price > 0 && v.selling_price <= v.mrp && (
                <span className="discount-badge">
                  {discountPct(v.mrp, v.selling_price)}% off
                </span>
              )}
            </div>
          </div>

          {/* Row 3: Stock */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 10 }}>
            <div className="form-group">
              <label className="form-label">Stock Quantity</label>
              <input
                type="number"
                value={v.stock_quantity}
                onChange={e => update(idx, 'stock_quantity', parseInt(e.target.value) || 0)}
                min={0}
              />
            </div>
            <div className="form-group">
              <label className="form-label">Low Stock Alert</label>
              <input
                type="number"
                value={v.low_stock_alert}
                onChange={e => update(idx, 'low_stock_alert', parseInt(e.target.value) || 10)}
                min={1}
              />
            </div>
            <div className="form-group">
              <label className="form-label">SKU / Barcode</label>
              <div style={{ display: 'flex', gap: 6 }}>
                <input
                  value={v.sku || ''}
                  onChange={e => update(idx, 'sku', e.target.value)}
                  placeholder="e.g. 890123456789"
                  style={{ flex: 1 }}
                />
                <button
                  type="button"
                  className="btn btn-secondary btn-sm"
                  title="Scan barcode with camera or reader"
                  onClick={() => setScanningIdx(idx)}
                  style={{ flexShrink: 0, padding: '0 10px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
                >
                  <FaBarcode />
                </button>
              </div>
            </div>
          </div>
        </div>
      ))}

      {/* Barcode Scanner Camera Modal */}
      <BarcodeScannerModal
        isOpen={scanningIdx !== null}
        onClose={() => setScanningIdx(null)}
        onScan={(code) => {
          if (scanningIdx !== null) {
            update(scanningIdx, 'sku', code);
          }
        }}
      />
    </div>
  );
};

export default VariantEditor;
