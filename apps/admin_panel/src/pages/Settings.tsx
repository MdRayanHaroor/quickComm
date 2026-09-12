import React, { useState, useEffect, useRef } from 'react';
import Sidebar from '../components/Sidebar';
import { supabase } from '../supabaseClient';
import { toast } from 'react-hot-toast';
import axios from 'axios';
import { MapContainer, TileLayer, Marker, Circle, useMap, useMapEvents } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';
import { renderToStaticMarkup } from 'react-dom/server';
import { useTheme } from '../components/ThemeContext';
import {
  FaStore, FaMapMarkerAlt, FaSearch, FaCheck, FaCreditCard,
  FaTruck, FaShieldAlt, FaCrosshairs, FaCheckCircle, FaBan
} from 'react-icons/fa';

// Custom Store Map Icon
const createStoreIcon = () => {
  const iconHtml = renderToStaticMarkup(
    <div style={{
      width: 36,
      height: 36,
      borderRadius: '50%',
      background: '#1BA672',
      border: '3px solid #ffffff',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      color: '#ffffff',
      fontSize: 16,
      boxShadow: '0 3px 8px rgba(0,0,0,0.35)'
    }}>
      <FaStore />
    </div>
  );

  return L.divIcon({
    html: iconHtml,
    className: 'custom-store-marker',
    iconSize: [36, 36],
    iconAnchor: [18, 18]
  });
};

// Map Pan Controller
const MapCenterUpdater: React.FC<{ center: [number, number] }> = ({ center }) => {
  const map = useMap();
  useEffect(() => {
    map.panTo(center, { animate: true });
  }, [center, map]);
  return null;
};

// Map Click & Drag Handler
const LocationSelector: React.FC<{
  position: [number, number];
  onSelect: (lat: number, lng: number) => void;
}> = ({ position, onSelect }) => {
  const markerRef = useRef<any>(null);

  useMapEvents({
    click(e) {
      onSelect(e.latlng.lat, e.latlng.lng);
    }
  });

  return (
    <Marker
      ref={markerRef}
      position={position}
      draggable={true}
      icon={createStoreIcon()}
      eventHandlers={{
        dragend() {
          const marker = markerRef.current;
          if (marker) {
            const { lat, lng } = marker.getLatLng();
            onSelect(lat, lng);
          }
        }
      }}
    />
  );
};

export const Settings: React.FC = () => {
  const { isDark } = useTheme();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  // Store Config State
  const [storeName, setStoreName] = useState('QuickComm Supermarket');
  const [storeAddress, setStoreAddress] = useState('');
  const [isOpen, setIsOpen] = useState(true);

  // Delivery Rules & Toggles
  const [useDeliveryRadius, setUseDeliveryRadius] = useState(true);
  const [deliveryRadius, setDeliveryRadius] = useState('5');
  const [minOrder, setMinOrder] = useState('99');
  const [deliveryFee, setDeliveryFee] = useState('20');
  const [useFreeDelivery, setUseFreeDelivery] = useState(true);
  const [freeDeliveryAbove, setFreeDeliveryAbove] = useState('299');

  // GPS Coordinates (Default: Bangalore centre)
  const [latitude, setLatitude] = useState<number>(12.9716);
  const [longitude, setLongitude] = useState<number>(77.5946);

  // Address Search State
  const [addressQuery, setAddressQuery] = useState('');
  const [searchingAddress, setSearchingAddress] = useState(false);
  const [addressResults, setAddressResults] = useState<any[]>([]);
  const debounceRef = useRef<any>(null);

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
          if (data.store_address) setStoreAddress(data.store_address);
          if (data.min_order_amount != null) setMinOrder(String(data.min_order_amount));
          if (data.delivery_fee_fixed != null) setDeliveryFee(String(data.delivery_fee_fixed));
          if (data.is_open != null) setIsOpen(Boolean(data.is_open));

          // Delivery radius toggle and value
          if (data.delivery_radius_km != null && Number(data.delivery_radius_km) > 0) {
            setUseDeliveryRadius(true);
            setDeliveryRadius(String(data.delivery_radius_km));
          } else {
            setUseDeliveryRadius(false);
            setDeliveryRadius('5');
          }

          // Free delivery toggle and value
          if (data.free_delivery_above != null && Number(data.free_delivery_above) > 0) {
            setUseFreeDelivery(true);
            setFreeDeliveryAbove(String(data.free_delivery_above));
          } else {
            setUseFreeDelivery(false);
            setFreeDeliveryAbove('299');
          }

          // Coordinates resolution
          const lat = data.lat ?? data.latitude;
          const lng = data.lng ?? data.longitude;
          if (lat != null && lng != null) {
            setLatitude(Number(lat));
            setLongitude(Number(lng));
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

  // Reverse geocode lat/lng to text address
  const reverseGeocode = async (lat: number, lng: number) => {
    try {
      const res = await axios.get(
        `https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lng}&zoom=18&addressdetails=1`,
        { headers: { 'User-Agent': 'QuickComm-Admin/1.0' } }
      );
      if (res.data && res.data.display_name) {
        setStoreAddress(res.data.display_name);
        setAddressQuery(res.data.display_name.split(',').slice(0, 3).join(','));
      }
    } catch {
      // silent fallback
    }
  };

  const handleMapLocationSelect = (lat: number, lng: number) => {
    setLatitude(lat);
    setLongitude(lng);
    reverseGeocode(lat, lng);
    toast.success(`Store location set to: ${lat.toFixed(4)}, ${lng.toFixed(4)}`);
  };

  // Browser GPS detection
  const handleDetectCurrentLocation = () => {
    if (!navigator.geolocation) {
      toast.error('Geolocation is not supported by your browser');
      return;
    }
    toast.loading('Detecting current GPS location...', { id: 'geo' });
    navigator.geolocation.getCurrentPosition(
      pos => {
        const lat = pos.coords.latitude;
        const lng = pos.coords.longitude;
        setLatitude(lat);
        setLongitude(lng);
        reverseGeocode(lat, lng);
        toast.success(`GPS coordinates detected: ${lat.toFixed(4)}, ${lng.toFixed(4)}`, { id: 'geo' });
      },
      err => {
        toast.error(`Could not detect location: ${err.message}`, { id: 'geo' });
      },
      { enableHighAccuracy: true, timeout: 8000 }
    );
  };

  // Search address via Nominatim
  const searchAddress = async (q: string) => {
    if (!q.trim()) {
      setAddressResults([]);
      return;
    }
    setSearchingAddress(true);
    try {
      const res = await axios.get(
        `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(q)}&accept-language=en&countrycodes=in`,
        { headers: { 'User-Agent': 'QuickComm-Admin/1.0' } }
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

  const handleSelectSearchResult = (result: any) => {
    const lat = parseFloat(result.lat);
    const lng = parseFloat(result.lon);
    setLatitude(lat);
    setLongitude(lng);
    setStoreAddress(result.display_name);
    setAddressResults([]);
    setAddressQuery(result.display_name.split(',')[0]);
    toast.success(`Store pinned to: ${result.display_name.split(',')[0]}`);
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      const payload: Record<string, any> = {
        store_name: storeName.trim(),
        store_address: storeAddress.trim() || addressQuery.trim(),
        lat: latitude,
        lng: longitude,
        min_order_amount: parseFloat(minOrder) || 99,
        delivery_fee_fixed: parseFloat(deliveryFee) || 20,
        is_open: isOpen,
        delivery_radius_km: useDeliveryRadius ? (parseFloat(deliveryRadius) || 5) : null,
        free_delivery_above: useFreeDelivery ? (parseFloat(freeDeliveryAbove) || 299) : null
      };

      const { error } = await supabase
        .from('store_settings')
        .update(payload)
        .eq('id', 1);

      if (error) throw error;
      toast.success('Store settings saved successfully!');
    } catch (err: any) {
      toast.error(err.message || 'Failed to save store settings');
    } finally {
      setSaving(false);
    }
  };

  const radiusKm = parseFloat(deliveryRadius) || 5;

  return (
    <div className="layout">
      <Sidebar />
      <div className="main-content" style={{ display: 'flex', flexDirection: 'column', height: '100vh', overflow: 'hidden' }}>
        {/* Header */}
        <div className="page-header" style={{ flexShrink: 0 }}>
          <div>
            <h1 className="page-title">Store Settings</h1>
            <p style={{ color: 'var(--text-muted)', fontSize: 13, marginTop: 2 }}>
              Configure supermarket operational hours, interactive map location, delivery radius, and payment rules.
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
          <form onSubmit={handleSave} style={{ width: '100%', display: 'flex', flexDirection: 'column', gap: 24 }}>
            
            {/* Card 1: Store Location & Interactive Map */}
            <div className="card" style={{ padding: 24 }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16, borderBottom: '1px solid var(--border)', paddingBottom: 12 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <div style={{ width: 36, height: 36, borderRadius: 8, background: 'var(--brand-light)', color: 'var(--brand-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <FaStore size={18} />
                  </div>
                  <div>
                    <h3 style={{ margin: 0, fontSize: 16, color: 'var(--text-primary)' }}>Store Profile &amp; Location</h3>
                    <span style={{ fontSize: 12, color: 'var(--text-muted)' }}>Click or drag the pin anywhere on the map to set the exact store coordinates</span>
                  </div>
                </div>

                {/* Open / Closed Status Toggle */}
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

              {/* Store Name & Search Bar */}
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 16, marginBottom: 16 }}>
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
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                    <label className="form-label">Search Area or Landmark</label>
                    <button
                      type="button"
                      onClick={handleDetectCurrentLocation}
                      className="btn btn-ghost"
                      style={{ padding: '2px 6px', fontSize: 11, display: 'flex', alignItems: 'center', gap: 4, color: 'var(--brand-primary)' }}
                      title="Center on your current GPS location"
                    >
                      <FaCrosshairs /> Use My Location
                    </button>
                  </div>
                  <div style={{ position: 'relative' }}>
                    <div style={{ display: 'flex', gap: 6 }}>
                      <input
                        value={addressQuery}
                        onChange={handleAddressInput}
                        placeholder="Search landmark, neighborhood, or city..."
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
                        zIndex: 1000,
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
                            onClick={() => handleSelectSearchResult(item)}
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

              {/* Interactive Map Picker */}
              <div style={{
                borderRadius: 'var(--radius-md)',
                overflow: 'hidden',
                border: '1.5px solid var(--border)',
                height: 320,
                position: 'relative'
              }}>
                <MapContainer
                  center={[latitude, longitude]}
                  zoom={14}
                  style={{ width: '100%', height: '100%' }}
                >
                  <TileLayer
                    url={isDark 
                      ? "https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png" 
                      : "https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png"
                    }
                    attribution='&copy; <a href="https://carto.com/">CARTO</a>'
                  />
                  <MapCenterUpdater center={[latitude, longitude]} />
                  <LocationSelector
                    position={[latitude, longitude]}
                    onSelect={handleMapLocationSelect}
                  />
                  {useDeliveryRadius && (
                    <Circle
                      center={[latitude, longitude]}
                      radius={radiusKm * 1000}
                      pathOptions={{
                        color: '#1BA672',
                        fillColor: '#1BA672',
                        fillOpacity: 0.12,
                        weight: 2,
                        dashArray: '6 6'
                      }}
                    />
                  )}
                </MapContainer>

                {/* Map Guidance Overlay */}
                <div style={{
                  position: 'absolute',
                  bottom: 12,
                  left: 12,
                  zIndex: 500,
                  background: 'rgba(0, 0, 0, 0.75)',
                  color: '#ffffff',
                  padding: '6px 12px',
                  borderRadius: 6,
                  fontSize: 11,
                  display: 'flex',
                  alignItems: 'center',
                  gap: 8,
                  backdropFilter: 'blur(4px)'
                }}>
                  <FaMapMarkerAlt color="#1BA672" />
                  <span>Click anywhere or drag the green pin to set store location</span>
                  <span style={{ opacity: 0.6 }}>|</span>
                  <span>Lat: <strong>{latitude.toFixed(4)}</strong>, Lng: <strong>{longitude.toFixed(4)}</strong></span>
                </div>
              </div>

              {storeAddress && (
                <div style={{ marginTop: 12, fontSize: 12, color: 'var(--text-secondary)' }}>
                  <strong>Selected Address:</strong> {storeAddress}
                </div>
              )}
            </div>

            {/* Card 2: Delivery & Checkout Rules (with Toggles) */}
            <div className="card" style={{ padding: 24 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 20, borderBottom: '1px solid var(--border)', paddingBottom: 12 }}>
                <div style={{ width: 36, height: 36, borderRadius: 8, background: 'rgba(59, 130, 246, 0.15)', color: '#3b82f6', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <FaTruck size={18} />
                </div>
                <div>
                  <h3 style={{ margin: 0, fontSize: 16, color: 'var(--text-primary)' }}>Delivery Radius &amp; Pricing Rules</h3>
                  <span style={{ fontSize: 12, color: 'var(--text-muted)' }}>Configure boundary enforcement, minimum order threshold, and delivery waivers</span>
                </div>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
                {/* 1. Delivery Radius Control + Toggle */}
                <div style={{
                  background: 'var(--bg-surface-elevated)',
                  border: '1px solid var(--border)',
                  borderRadius: 'var(--radius-md)',
                  padding: '16px 20px',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: 12
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                    <div>
                      <strong style={{ fontSize: 14, color: 'var(--text-primary)', display: 'block' }}>
                        Enforce Delivery Radius Boundary
                      </strong>
                      <span style={{ fontSize: 12, color: 'var(--text-muted)' }}>
                        When enabled, customers outside this radial distance will be blocked from placing orders.
                      </span>
                    </div>
                    <label className="toggle" title="Toggle delivery radius boundary enforcement">
                      <input
                        type="checkbox"
                        checked={useDeliveryRadius}
                        onChange={e => setUseDeliveryRadius(e.target.checked)}
                      />
                      <span className="toggle-slider" />
                    </label>
                  </div>

                  {useDeliveryRadius ? (
                    <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginTop: 4, flexWrap: 'wrap' }}>
                      <div className="form-group" style={{ width: 220 }}>
                        <label className="form-label required">Delivery Radius (km)</label>
                        <input
                          type="number"
                          value={deliveryRadius}
                          onChange={e => setDeliveryRadius(e.target.value)}
                          min={1}
                          max={50}
                          step={0.5}
                          required
                        />
                      </div>
                      <div style={{ fontSize: 12, color: 'var(--brand-primary)', fontWeight: 600, display: 'flex', alignItems: 'center', gap: 6, marginTop: 16 }}>
                        <FaCheckCircle /> Visual green circle on the map above shows the exact {radiusKm} km coverage zone.
                      </div>
                    </div>
                  ) : (
                    <div style={{ fontSize: 12, color: 'var(--text-muted)', display: 'flex', alignItems: 'center', gap: 6 }}>
                      <FaBan color="var(--warning)" /> Radius enforcement is OFF. Customers anywhere can place delivery orders.
                    </div>
                  )}
                </div>

                {/* 2. Free Delivery Above Threshold + Toggle */}
                <div style={{
                  background: 'var(--bg-surface-elevated)',
                  border: '1px solid var(--border)',
                  borderRadius: 'var(--radius-md)',
                  padding: '16px 20px',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: 12
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                    <div>
                      <strong style={{ fontSize: 14, color: 'var(--text-primary)', display: 'block' }}>
                        Free Delivery on Qualifying Orders
                      </strong>
                      <span style={{ fontSize: 12, color: 'var(--text-muted)' }}>
                        Waive the delivery fee if the cart item subtotal reaches a minimum amount.
                      </span>
                    </div>
                    <label className="toggle" title="Toggle free delivery threshold">
                      <input
                        type="checkbox"
                        checked={useFreeDelivery}
                        onChange={e => setUseFreeDelivery(e.target.checked)}
                      />
                      <span className="toggle-slider" />
                    </label>
                  </div>

                  {useFreeDelivery ? (
                    <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginTop: 4, flexWrap: 'wrap' }}>
                      <div className="form-group" style={{ width: 220 }}>
                        <label className="form-label required">Free Delivery Above (₹)</label>
                        <input
                          type="number"
                          value={freeDeliveryAbove}
                          onChange={e => setFreeDeliveryAbove(e.target.value)}
                          min={0}
                          required
                        />
                      </div>
                      <div style={{ fontSize: 12, color: 'var(--text-muted)', marginTop: 16 }}>
                        Orders with item total &ge; ₹{freeDeliveryAbove} will have ₹0 delivery fee applied automatically.
                      </div>
                    </div>
                  ) : (
                    <div style={{ fontSize: 12, color: 'var(--text-muted)', display: 'flex', alignItems: 'center', gap: 6 }}>
                      <FaBan color="var(--warning)" /> Free delivery waiver is OFF. The standard delivery fee will be applied to every order.
                    </div>
                  )}
                </div>

                {/* 3. Base Pricing Rules */}
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: 16 }}>
                  <div className="form-group">
                    <label className="form-label required">Standard Delivery Fee (₹)</label>
                    <input
                      type="number"
                      value={deliveryFee}
                      onChange={e => setDeliveryFee(e.target.value)}
                      min={0}
                      required
                    />
                    <span style={{ fontSize: 11, color: 'var(--text-muted)' }}>Base fee added to checkout</span>
                  </div>

                  <div className="form-group">
                    <label className="form-label required">Minimum Order Amount (₹)</label>
                    <input
                      type="number"
                      value={minOrder}
                      onChange={e => setMinOrder(e.target.value)}
                      min={0}
                      required
                    />
                    <span style={{ fontSize: 11, color: 'var(--text-muted)' }}>Minimum cart value required to place an order</span>
                  </div>
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
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 16, marginBottom: 16 }}>
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
                    Riders collect cash or UPI QR upon delivery. All orders currently default to COD.
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
