import React, { useState, useEffect } from 'react';
import Sidebar from '../components/Sidebar';
import { supabase } from '../supabaseClient';
import { toast } from 'react-hot-toast';
import axios from 'axios';
import {
  FaStore, FaMapMarkerAlt, FaSearch, FaCheck, FaCreditCard,
  FaTruck, FaShieldAlt
} from 'react-icons/fa';

export const Settings: React.FC = () => {
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  // Store Config State
  const [storeName, setStoreName] = useState('QuickComm Supermarket');
  const [deliveryRadius, setDeliveryRadius] = useState('5');
  const [minOrder, setMinOrder] = useState('99');
  const [deliveryFee, setDeliveryFee] = useState('20');
  const [freeDeliveryAbove, setFreeDeliveryAbove] = useState('299');
  const [isOpen, setIsOpen] = useState(true);
  const [latitude, setLatitude] = useState<number | null>(null);
  const [longitude, setLongitude] = useState<number | null>(null);

  // Address Search State
  const [addressQuery, setAddressQuery] = useState('');
  const [searchingAddress, setSearchingAddress] = useState(false);
  const [addressResults, setAddressResults] = useState<any[]>([]);
  const debounceRef = React.useRef<any>(null);

  useEffect(() => {
    const fetchSettings = async () => {
      setLoading(true);
      try {
        const { data, error } = await supabase
          .from('store_settings')
          .select('*')
          .eq('id', 1)
          .maybeSingle();

        if (error) throw error;
        if (data) {
          if (data.store_name) setStoreName(data.store_name);
          if (data.delivery_radius_km != null) setDeliveryRadius(String(data.delivery_radius_km));
          if (data.min_order_amount != null) setMinOrder(String(data.min_order_amount));
          if (data.delivery_fee_fixed != null) setDeliveryFee(String(data.delivery_fee_fixed));
          if (data.free_delivery_above != null) setFreeDeliveryAbove(String(data.free_delivery_above));
          if (data.is_open != null) setIsOpen(Boolean(data.is_open));
          if (data.location?.coordinates) {
            setLongitude(data.location.coordinates[0]);
            setLatitude(data.location.coordinates[1]);
          } else if (data.latitude && data.longitude) {
            setLatitude(data.latitude);
            setLongitude(data.longitude);
          }
        }
      } catch (err: any) {
        console.error('Failed to load store settings:', err);
        toast.error('Failed to load store settings');
      } finally {
        setLoading(false);
      }
    };

    fetchSettings();
  }, []);

  const searchAddress = async (q: string) => {
    if (!q) {
      setAddressResults([]);
      return;
    }
    setSearchingAddress(true);
    try {
      const res = await axios.get(
        `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(q)}&accept-language=en&countrycodes=in`
      );
      setAddressResults(res.data || []);
    } catch {
      // ignore
    } finally {
      setSearchingAddress(false);
    }
  };

  const handleAddressInput = (e: React.ChangeEvent<HTMLInputElement>) => {
    const val = e.target.value;
    setAddressQuery(val);
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => {
      searchAddress(val);
    }, 450);
  };

  const handleSelectLocation = (result: any) => {
    const lat = parseFloat(result.lat);
    const lng = parseFloat(result.lon);
    setLatitude(lat);
    setLongitude(lng);
    setAddressResults([]);
    setAddressQuery(result.display_name.split(',')[0]);
    toast.success(`Store coordinates set to: ${lat.toFixed(4)}, ${lng.toFixed(4)}`);
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      const payload: Record<string, any> = {
        store_name: storeName.trim(),
        delivery_radius_km: parseFloat(deliveryRadius) || 5,
        min_order_amount: parseFloat(minOrder) || 99,
        delivery_fee_fixed: parseFloat(deliveryFee) || 20,
        free_delivery_above: parseFloat(freeDeliveryAbove) || 299,
        is_open: isOpen,
      };

      if (latitude != null && longitude != null) {
        payload.location = `POINT(${longitude} ${latitude})`;
      }

      const { error } = await supabase
        .from('store_settings')
        .update(payload)
        .eq('id', 1);

      if (error) throw error;
      toast.success('Store configuration saved successfully!');
    } catch (err: any) {
      toast.error(err.message || 'Failed to save store settings');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="layout">
      <Sidebar />
      <div className="main-content" style={{ display: 'flex', flexDirection: 'column', height: '100vh', overflow: 'hidden' }}>
        {/* Header */}
        <div className="page-header" style={{ flexShrink: 0 }}>
          <div>
            <h1 className="page-title">Store Settings</h1>
            <p style={{ color: 'var(--text-muted)', fontSize: 13, marginTop: 2 }}>
              Configure supermarket operational hours, delivery radius, pricing rules, and payment gateways.
            </p>
          </div>
          <button
            onClick={handleSave}
            className="btn btn-primary"
            disabled={saving || loading}
            style={{ display: 'flex', alignItems: 'center', gap: 6 }}
          >
            <FaCheck /> {saving ? 'Saving...' : 'Save Changes'}
          </button>
        </div>

        {/* Body */}
        <div className="page-body" style={{ flex: 1, overflowY: 'auto', padding: '24px 32px 32px' }}>
          <form onSubmit={handleSave} style={{ maxWidth: 840, display: 'flex', flexDirection: 'column', gap: 24 }}>
            {/* Card 1: Store Operational Profile */}
            <div className="card" style={{ padding: 24 }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20, borderBottom: '1px solid var(--border)', paddingBottom: 12 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <div style={{ width: 36, height: 36, borderRadius: 8, background: 'var(--brand-light)', color: 'var(--brand-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <FaStore size={18} />
                  </div>
                  <div>
                    <h3 style={{ margin: 0, fontSize: 16, color: 'var(--text-primary)' }}>Store Operational Profile</h3>
                    <span style={{ fontSize: 12, color: 'var(--text-muted)' }}>Store branding and live operating switch</span>
                  </div>
                </div>

                {/* Open / Closed Status Badge & Toggle */}
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <span style={{
                    fontSize: 12,
                    fontWeight: 700,
                    color: isOpen ? 'var(--success)' : 'var(--danger)',
                    display: 'flex',
                    alignItems: 'center',
                    gap: 6
                  }}>
                    <span style={{ width: 8, height: 8, borderRadius: '50%', background: isOpen ? 'var(--success)' : 'var(--danger)' }} />
                    {isOpen ? 'STORE OPEN' : 'STORE CLOSED'}
                  </span>
                  <label className="toggle" title="Toggle Store Open/Closed">
                    <input
                      type="checkbox"
                      checked={isOpen}
                      onChange={e => setIsOpen(e.target.checked)}
                    />
                    <span className="toggle-slider" />
                  </label>
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
                <div className="form-group">
                  <label className="form-label required">Store Display Name</label>
                  <input
                    value={storeName}
                    onChange={e => setStoreName(e.target.value)}
                    placeholder="e.g. QuickComm Supermarket - Indiranagar"
                    required
                  />
                </div>

                <div className="form-group">
                  <label className="form-label">Store Location (Search Area)</label>
                  <div style={{ position: 'relative' }}>
                    <div style={{ display: 'flex', gap: 6 }}>
                      <input
                        value={addressQuery}
                        onChange={handleAddressInput}
                        placeholder="Search landmark / locality (e.g. Koramangala)"
                      />
                      <button
                        type="button"
                        onClick={() => searchAddress(addressQuery)}
                        className="btn btn-secondary"
                        disabled={searchingAddress}
                      >
                        <FaSearch />
                      </button>
                    </div>

                    {addressResults.length > 0 && (
                      <ul style={{
                        position: 'absolute',
                        top: '100%',
                        left: 0,
                        right: 0,
                        zIndex: 20,
                        background: 'var(--bg-surface-elevated)',
                        border: '1px solid var(--border)',
                        borderRadius: 'var(--radius-md)',
                        listStyle: 'none',
                        margin: '4px 0 0',
                        padding: 0,
                        maxHeight: 180,
                        overflowY: 'auto',
                        boxShadow: 'var(--shadow-md)'
                      }}>
                        {addressResults.map((item: any) => (
                          <li
                            key={item.place_id}
                            onClick={() => handleSelectLocation(item)}
                            style={{
                              padding: '8px 12px',
                              fontSize: 12,
                              cursor: 'pointer',
                              borderBottom: '1px solid var(--border)',
                              color: 'var(--text-primary)'
                            }}
                            onMouseEnter={e => (e.currentTarget.style.background = 'var(--brand-light)')}
                            onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}
                          >
                            {item.display_name}
                          </li>
                        ))}
                      </ul>
                    )}
                  </div>
                </div>
              </div>

              {latitude != null && longitude != null && (
                <div style={{ marginTop: 14, fontSize: 12, color: 'var(--text-muted)', display: 'flex', alignItems: 'center', gap: 6 }}>
                  <FaMapMarkerAlt color="var(--brand-primary)" />
                  Registered GPS Center: <strong>{latitude.toFixed(4)}, {longitude.toFixed(4)}</strong> (Rider distance calculations are based on this point)
                </div>
              )}
            </div>

            {/* Card 2: Delivery & Checkout Rules */}
            <div className="card" style={{ padding: 24 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 20, borderBottom: '1px solid var(--border)', paddingBottom: 12 }}>
                <div style={{ width: 36, height: 36, borderRadius: 8, background: 'rgba(59, 130, 246, 0.15)', color: '#3b82f6', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <FaTruck size={18} />
                </div>
                <div>
                  <h3 style={{ margin: 0, fontSize: 16, color: 'var(--text-primary)' }}>Delivery &amp; Checkout Rules</h3>
                  <span style={{ fontSize: 12, color: 'var(--text-muted)' }}>Radius boundaries and cart delivery charges</span>
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 16 }}>
                <div className="form-group">
                  <label className="form-label required">Delivery Radius (km)</label>
                  <input
                    type="number"
                    value={deliveryRadius}
                    onChange={e => setDeliveryRadius(e.target.value)}
                    min={1}
                    max={50}
                    required
                  />
                  <span style={{ fontSize: 11, color: 'var(--text-muted)' }}>Max customer distance</span>
                </div>

                <div className="form-group">
                  <label className="form-label required">Min Order Amount (₹)</label>
                  <input
                    type="number"
                    value={minOrder}
                    onChange={e => setMinOrder(e.target.value)}
                    min={0}
                    required
                  />
                  <span style={{ fontSize: 11, color: 'var(--text-muted)' }}>Required for checkout</span>
                </div>

                <div className="form-group">
                  <label className="form-label required">Standard Delivery Fee (₹)</label>
                  <input
                    type="number"
                    value={deliveryFee}
                    onChange={e => setDeliveryFee(e.target.value)}
                    min={0}
                    required
                  />
                  <span style={{ fontSize: 11, color: 'var(--text-muted)' }}>Applied to standard orders</span>
                </div>

                <div className="form-group">
                  <label className="form-label required">Free Delivery Above (₹)</label>
                  <input
                    type="number"
                    value={freeDeliveryAbove}
                    onChange={e => setFreeDeliveryAbove(e.target.value)}
                    min={0}
                    required
                  />
                  <span style={{ fontSize: 11, color: 'var(--text-muted)' }}>Delivery fee waived above</span>
                </div>
              </div>
            </div>

            {/* Card 3: Payment Gateway Configuration */}
            <div className="card" style={{ padding: 24 }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16, borderBottom: '1px solid var(--border)', paddingBottom: 12 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <div style={{ width: 36, height: 36, borderRadius: 8, background: 'rgba(234, 179, 8, 0.15)', color: '#eab308', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <FaCreditCard size={18} />
                  </div>
                  <div>
                    <h3 style={{ margin: 0, fontSize: 16, color: 'var(--text-primary)' }}>Payment Gateways</h3>
                    <span style={{ fontSize: 12, color: 'var(--text-muted)' }}>Digital payments, UPI, and Cash on Delivery</span>
                  </div>
                </div>

                <span style={{
                  background: 'rgba(59, 130, 246, 0.15)',
                  color: '#3b82f6',
                  padding: '3px 10px',
                  borderRadius: 12,
                  fontSize: 11,
                  fontWeight: 700
                }}>
                  Razorpay: Coming Soon (Phase 5)
                </span>
              </div>

              {/* Active Payment Methods */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 16 }}>
                {/* Cash on Delivery */}
                <div style={{
                  border: '1px solid var(--border)',
                  borderRadius: 'var(--radius-md)',
                  padding: '16px',
                  background: 'var(--bg-surface-elevated)'
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
                    <strong style={{ fontSize: 14, color: 'var(--text-primary)' }}>Cash on Delivery (COD)</strong>
                    <span style={{ color: 'var(--success)', fontWeight: 700, fontSize: 12 }}>● Active</span>
                  </div>
                  <p style={{ margin: 0, fontSize: 12, color: 'var(--text-secondary)' }}>
                    Riders collect cash or UPI upon delivery. All orders currently default to COD.
                  </p>
                </div>

                {/* Razorpay Online */}
                <div style={{
                  border: '1px solid var(--border)',
                  borderRadius: 'var(--radius-md)',
                  padding: '16px',
                  background: 'var(--bg-surface-elevated)',
                  opacity: 0.85
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
                    <strong style={{ fontSize: 14, color: 'var(--text-primary)' }}>Razorpay (UPI / Cards / Netbanking)</strong>
                    <span style={{ color: '#3b82f6', fontWeight: 700, fontSize: 11 }}>Coming Soon</span>
                  </div>
                  <p style={{ margin: 0, fontSize: 12, color: 'var(--text-secondary)' }}>
                    Pre-payment webhook integration scheduled for deployment with the Customer App.
                  </p>
                </div>
              </div>

              {/* Credentials Preview */}
              <div style={{
                background: 'var(--bg-input)',
                border: '1px dashed var(--border)',
                borderRadius: 'var(--radius-md)',
                padding: '14px 16px',
                display: 'flex',
                alignItems: 'center',
                gap: 12
              }}>
                <FaShieldAlt color="var(--text-muted)" size={20} />
                <div style={{ fontSize: 12, color: 'var(--text-secondary)' }}>
                  <strong>Gateway Webhook Key &amp; Secret:</strong> Configured via backend environment variables (<code>RAZORPAY_KEY_ID</code> and <code>RAZORPAY_KEY_SECRET</code>) for PCI-DSS compliance.
                </div>
              </div>
            </div>

            {/* Bottom Actions */}
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 12 }}>
              <button
                type="submit"
                className="btn btn-primary"
                disabled={saving || loading}
                style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '10px 24px' }}
              >
                <FaCheck /> {saving ? 'Saving...' : 'Save Settings'}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
};

export default Settings;
