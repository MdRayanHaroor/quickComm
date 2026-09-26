import React, { useEffect, useState, useRef, useCallback } from 'react';
import { MapContainer, TileLayer, Polyline, Marker, Popup, useMap, useMapEvents } from 'react-leaflet';
import { supabase } from '../supabaseClient';
import 'leaflet/dist/leaflet.css';
import RiderMarker from './RiderMarker';
import L from 'leaflet';
import { FaStore, FaMapMarkerAlt, FaRoute } from 'react-icons/fa';
import { renderToStaticMarkup } from 'react-dom/server';
import { useTheme } from './ThemeContext';

// --- Custom Leaflet Components ---

// 1. Component to handle map center updates
const MapController: React.FC<{ center: [number, number]; zoom?: number }> = ({ center, zoom }) => {
    const map = useMap();
    useEffect(() => {
        if (center) {
            map.flyTo(center, zoom || map.getZoom());
        }
    }, [center, map]);
    return null;
};

// 1.2 Component to automatically fit bounds to rider + destination
const MapBoundsController: React.FC<{ bounds: [number, number][] | null }> = ({ bounds }) => {
    const map = useMap();
    useEffect(() => {
        if (bounds && bounds.length >= 2) {
            map.fitBounds(bounds as L.LatLngBoundsExpression, {
                padding: [60, 60],
                maxZoom: 16,
            });
        }
    }, [bounds, map]);
    return null;
};

// 1.5. Component to handle map clicks
const MapEvents: React.FC<{ onClick?: () => void }> = ({ onClick }) => {
    useMapEvents({
        click() {
            if (onClick) onClick();
        }
    });
    return null;
};

// 2. Component to handle Store Marker
const StoreMarker: React.FC<{ position: [number, number]; onDragEnd: (lat: number, lng: number) => void }> = ({ position, onDragEnd }) => {
    const markerRef = useRef<any>(null);

    const iconHtml = renderToStaticMarkup(
        <div style={{ color: '#ec4899', fontSize: '24px', filter: 'drop-shadow(0 2px 3px rgba(0,0,0,0.5))' }}>
            <FaStore />
        </div>
    );

    const customIcon = L.divIcon({
        html: iconHtml,
        className: 'custom-store-icon',
        iconSize: [30, 30],
        iconAnchor: [15, 30],
    });

    const eventHandlers = {
        dragend() {
            const marker = markerRef.current;
            if (marker != null) {
                const { lat, lng } = marker.getLatLng();
                onDragEnd(lat, lng);
            }
        },
    };

    return (
        <Marker
            draggable={true}
            eventHandlers={eventHandlers}
            position={position}
            icon={customIcon}
            ref={markerRef}
        >
            <Popup>
                <div style={{ padding: '2px', fontWeight: 600 }}>Main Store Location</div>
            </Popup>
        </Marker>
    );
};

// 3. Component to handle Delivery Destination Marker
const DestinationMarker: React.FC<{
    position: [number, number];
    orderId: number;
    address?: string;
    distanceKm?: number;
    durationMins?: number;
}> = ({ position, orderId, address, distanceKm, durationMins }) => {
    const iconHtml = renderToStaticMarkup(
        <div style={{
            color: '#ef4444',
            fontSize: '28px',
            filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.5))',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
        }}>
            <FaMapMarkerAlt />
        </div>
    );

    const customIcon = L.divIcon({
        html: iconHtml,
        className: 'custom-destination-icon',
        iconSize: [30, 30],
        iconAnchor: [15, 28],
    });

    return (
        <Marker position={position} icon={customIcon}>
            <Popup>
                <div style={{ padding: '4px', minWidth: '170px' }}>
                    <div style={{ fontWeight: 700, fontSize: '13px', color: '#111827', marginBottom: '4px' }}>
                        Delivery Destination
                    </div>
                    <div style={{ fontSize: '12px', fontWeight: 600, color: '#3b82f6', marginBottom: '4px' }}>
                        Order #{orderId}
                    </div>
                    {address && (
                        <div style={{ fontSize: '11.5px', color: '#4b5563', marginBottom: '6px', lineHeight: 1.3 }}>
                            {address}
                        </div>
                    )}
                    {distanceKm !== undefined && durationMins !== undefined && (
                        <div style={{
                            fontSize: '11px',
                            color: '#059669',
                            fontWeight: 700,
                            background: '#ecfdf5',
                            padding: '3px 6px',
                            borderRadius: '4px',
                            display: 'inline-block'
                        }}>
                            {distanceKm} km away • ~{durationMins} min ETA
                        </div>
                    )}
                </div>
            </Popup>
        </Marker>
    );
};


// --- Types ---

interface RiderLocation {
  rider_id: string;
  lat: number;
  lng: number;
}

interface RiderState {
    current: RiderLocation;
    previous?: RiderLocation;
    path: [number, number][]; // Array of [lat, lng]
}

interface ActiveOrderRoute {
    riderId: string;
    orderId: number;
    status: string;
    deliveryAddress?: string;
    deliveryPos: [number, number]; // [lat, lng]
    routePoints: [number, number][]; // street-following road coordinates from OSRM
    distanceKm?: number;
    durationMins?: number;
}

interface LiveMapProps {
    storeLocation?: { lat: number; lng: number };
    onStoreLocationUpdate?: (lat: number, lng: number) => void;
    selectedRiderId?: string | null;
    onMapClick?: () => void;
}

// --- Main LiveMap Component ---

const LiveMap: React.FC<LiveMapProps> = ({ storeLocation, onStoreLocationUpdate, selectedRiderId, onMapClick }) => {
    const { isDark } = useTheme();
    const [riders, setRiders] = useState<Record<string, RiderState>>({});
    const [activeRoute, setActiveRoute] = useState<ActiveOrderRoute | null>(null);
    const [fitBounds, setFitBounds] = useState<[number, number][] | null>(null);
    const [viewCenter, setViewCenter] = useState<[number, number]>(() => {
        if (storeLocation) return [storeLocation.lat, storeLocation.lng];
        return [17.3850, 78.4867];
    });

    // Sync store center
    useEffect(() => {
        if (storeLocation) {
            setViewCenter([storeLocation.lat, storeLocation.lng]);
        }
    }, [storeLocation]);

    // OSRM road-following route fetcher
    const fetchOSRMRoute = useCallback(async (
        riderId: string,
        riderLat: number,
        riderLng: number,
        destLat: number,
        destLng: number,
        orderInfo: { id: number; status: string; delivery_address?: string }
    ) => {
        try {
            // OSRM expects coordinates in {longitude},{latitude} order
            const url = `https://router.project-osrm.org/route/v1/driving/${riderLng},${riderLat};${destLng},${destLat}?overview=full&geometries=geojson`;
            const resp = await fetch(url);
            if (!resp.ok) throw new Error(`OSRM HTTP ${resp.status}`);
            const data = await resp.json();

            if (data.code === 'Ok' && data.routes && data.routes.length > 0) {
                const route = data.routes[0];
                // Convert GeoJSON [lng, lat] to Leaflet [lat, lng]
                const points: [number, number][] = route.geometry.coordinates.map(
                    ([lng, lat]: [number, number]) => [lat, lng]
                );

                const distKm = parseFloat((route.distance / 1000).toFixed(1));
                const durMin = Math.ceil(route.duration / 60);

                setActiveRoute({
                    riderId,
                    orderId: orderInfo.id,
                    status: orderInfo.status,
                    deliveryAddress: orderInfo.delivery_address,
                    deliveryPos: [destLat, destLng],
                    routePoints: points,
                    distanceKm: distKm,
                    durationMins: durMin,
                });

                // Auto-fit bounds so dispatcher sees entire route
                setFitBounds([[riderLat, riderLng], [destLat, destLng]]);
            }
        } catch (e) {
            console.warn('OSRM route fetch failed, falling back to direct line:', e);
            setActiveRoute({
                riderId,
                orderId: orderInfo.id,
                status: orderInfo.status,
                deliveryAddress: orderInfo.delivery_address,
                deliveryPos: [destLat, destLng],
                routePoints: [[riderLat, riderLng], [destLat, destLng]],
            });
            setFitBounds([[riderLat, riderLng], [destLat, destLng]]);
        }
    }, []);

    // Fetch active order and route when a rider is selected
    useEffect(() => {
        // Instantly clear any previously selected rider's active route to avoid stale display
        setActiveRoute(null);
        setFitBounds(null);

        if (!selectedRiderId) {
            return;
        }

        const currentRiderId = selectedRiderId;
        let isMounted = true;

        const loadActiveOrder = async () => {
            try {
                // Fetch the rider's currently assigned active order
                const { data: order, error } = await supabase
                    .from('orders')
                    .select('id, status, delivery_lat, delivery_lng, delivery_address')
                    .eq('rider_id', currentRiderId)
                    .neq('status', 'delivered')
                    .neq('status', 'cancelled')
                    .order('created_at', { ascending: false })
                    .limit(1)
                    .maybeSingle();

                if (!isMounted) return;

                if (error || !order || !order.delivery_lat || !order.delivery_lng) {
                    // No active delivery for this rider — ensure route HUD stays hidden
                    setActiveRoute(null);
                    setFitBounds(null);
                    const r = riders[currentRiderId]?.current;
                    if (r) setViewCenter([r.lat, r.lng]);
                    return;
                }

                const riderCurrent = riders[currentRiderId]?.current;
                if (riderCurrent) {
                    await fetchOSRMRoute(
                        currentRiderId,
                        riderCurrent.lat,
                        riderCurrent.lng,
                        order.delivery_lat,
                        order.delivery_lng,
                        order
                    );
                } else {
                    setActiveRoute({
                        riderId: currentRiderId,
                        orderId: order.id,
                        status: order.status,
                        deliveryAddress: order.delivery_address,
                        deliveryPos: [order.delivery_lat, order.delivery_lng],
                        routePoints: [],
                    });
                }
            } catch (err) {
                console.error('Error fetching active rider order:', err);
                if (isMounted) setActiveRoute(null);
            }
        };

        loadActiveOrder();

        return () => {
            isMounted = false;
        };
    }, [selectedRiderId, fetchOSRMRoute]);

    // Update route dynamically as the selected rider moves (only if this rider owns the route)
    useEffect(() => {
        if (!selectedRiderId || !activeRoute || activeRoute.riderId !== selectedRiderId) return;
        const riderPos = riders[selectedRiderId]?.current;
        if (!riderPos) return;

        fetchOSRMRoute(
            selectedRiderId,
            riderPos.lat,
            riderPos.lng,
            activeRoute.deliveryPos[0],
            activeRoute.deliveryPos[1],
            { id: activeRoute.orderId, status: activeRoute.status, delivery_address: activeRoute.deliveryAddress }
        );
    }, [
        selectedRiderId,
        activeRoute?.riderId,
        riders[selectedRiderId || '']?.current?.lat,
        riders[selectedRiderId || '']?.current?.lng,
    ]);

    // Initial rider locations fetch & realtime subscription
    useEffect(() => {
        const fetchInitialLocations = async () => {
            const { data } = await supabase.from('rider_locations').select('*');
            if (data) {
                setRiders(prev => {
                    const next = { ...prev };
                    data.forEach((loc: any) => {
                        next[loc.rider_id] = { 
                            current: loc, 
                            path: [[loc.lat, loc.lng]] 
                        };
                    });
                    return next;
                });
            }
        };

        fetchInitialLocations();

        const channel = supabase.channel('public:rider_locations:map')
            .on('postgres_changes', { event: '*', schema: 'public', table: 'rider_locations' }, (payload) => {
                const newLoc = payload.new as RiderLocation;
                if (!newLoc) return;

                setRiders(prev => {
                    const riderState = prev[newLoc.rider_id];
                    const newPoint: [number, number] = [newLoc.lat, newLoc.lng];
                    
                    const currentPath = riderState ? riderState.path : [];
                    const newPath = [...currentPath, newPoint].slice(-50);

                    return {
                        ...prev,
                        [newLoc.rider_id]: {
                            current: newLoc,
                            previous: riderState ? riderState.current : undefined,
                            path: newPath
                        }
                    };
                });
            })
            .subscribe();

        return () => {
            supabase.removeChannel(channel);
        };
    }, []);

    const handleResetLocation = () => {
        if (storeLocation) {
            setViewCenter([storeLocation.lat, storeLocation.lng]);
        }
    };

    const handleFitActiveRoute = () => {
        if (activeRoute && selectedRiderId && riders[selectedRiderId]?.current) {
            const r = riders[selectedRiderId].current;
            setFitBounds([[r.lat, r.lng], activeRoute.deliveryPos]);
        }
    };

    const displayedRiders = Object.values(riders);
    const hasActiveRouteForSelected = !!(activeRoute && selectedRiderId && activeRoute.riderId === selectedRiderId);

    return (
        <MapContainer 
            center={viewCenter}
            zoom={13} 
            style={{ height: '100%', width: '100%' }}
            attributionControl={false}
        >
            <MapController center={viewCenter} />
            <MapBoundsController bounds={fitBounds} />
            <MapEvents onClick={onMapClick} />
            
            <TileLayer
                key={isDark ? 'dark-tiles' : 'light-tiles'}
                url={
                    isDark
                        ? "https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
                        : "https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png"
                }
            />

            {/* Store Marker */}
            {storeLocation && onStoreLocationUpdate && (
                <StoreMarker 
                    position={[storeLocation.lat, storeLocation.lng]} 
                    onDragEnd={onStoreLocationUpdate}
                />
            )}

            {/* Active Delivery Route & Destination (Strictly for the selected rider with an active delivery) */}
            {hasActiveRouteForSelected && activeRoute.routePoints.length > 0 && (
                <>
                    {/* Road-following glow polyline */}
                    <Polyline 
                        positions={activeRoute.routePoints} 
                        pathOptions={{ 
                            color: '#10b981', 
                            weight: 6, 
                            opacity: 0.85,
                            lineCap: 'round',
                            lineJoin: 'round',
                        }} 
                    />
                    {/* Inner dash accent */}
                    <Polyline 
                        positions={activeRoute.routePoints} 
                        pathOptions={{ 
                            color: '#ffffff', 
                            weight: 2, 
                            dashArray: '6, 8',
                            opacity: 0.9,
                        }} 
                    />
                    {/* Destination Marker */}
                    <DestinationMarker 
                        position={activeRoute.deliveryPos}
                        orderId={activeRoute.orderId}
                        address={activeRoute.deliveryAddress}
                        distanceKm={activeRoute.distanceKm}
                        durationMins={activeRoute.durationMins}
                    />
                </>
            )}

            {/* All Riders & their historical trails */}
            {displayedRiders.map((riderState) => {
                const isSelected = selectedRiderId === riderState.current.rider_id;
                return (
                    <React.Fragment key={riderState.current.rider_id}>
                        {/* Historical Trail */}
                        <Polyline 
                            positions={riderState.path} 
                            pathOptions={{ 
                                color: isSelected ? '#2563eb' : '#3b82f6', 
                                weight: isSelected ? 4 : 3, 
                                opacity: isSelected ? 0.8 : 0.4,
                                dashArray: isSelected ? undefined : '4, 6',
                            }} 
                        />
                        {/* Current Rider Marker */}
                        <RiderMarker 
                            id={riderState.current.rider_id}
                            position={{ lat: riderState.current.lat, lng: riderState.current.lng }}
                            previousPosition={riderState.previous ? { lat: riderState.previous.lat, lng: riderState.previous.lng } : undefined}
                        />
                    </React.Fragment>
                );
            })}

            {/* Active Route HUD Overlay (Increased width and strict active rider ownership check) */}
            {hasActiveRouteForSelected && (
                <div style={{
                    position: 'absolute',
                    top: 20,
                    left: 20,
                    zIndex: 1000,
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border)',
                    borderRadius: 'var(--radius-lg)',
                    padding: '12px 18px',
                    boxShadow: 'var(--shadow-lg)',
                    display: 'flex',
                    flexDirection: 'column',
                    gap: '6px',
                    width: '380px',
                    maxWidth: 'calc(100vw - 40px)',
                    backdropFilter: 'blur(10px)',
                }}>
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '8px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '13.5px', fontWeight: 700, color: 'var(--text-primary)' }}>
                            <FaRoute color="#10b981" size={15} />
                            <span>Active Route (Order #{activeRoute.orderId})</span>
                        </div>
                        <span style={{
                            fontSize: '10.5px',
                            fontWeight: 700,
                            textTransform: 'uppercase',
                            background: '#dcfce7',
                            color: '#15803d',
                            padding: '3px 8px',
                            borderRadius: '999px',
                            letterSpacing: '0.3px',
                        }}>
                            {activeRoute.status.replace(/_/g, ' ')}
                        </span>
                    </div>

                    {activeRoute.distanceKm !== undefined && activeRoute.durationMins !== undefined && (
                        <div style={{ fontSize: '12.5px', color: '#059669', fontWeight: 600 }}>
                            {activeRoute.distanceKm} km remaining • ~{activeRoute.durationMins} mins ETA
                        </div>
                    )}

                    {activeRoute.deliveryAddress && (
                        <div style={{
                            fontSize: '11.5px',
                            color: 'var(--text-muted)',
                            overflow: 'hidden',
                            textOverflow: 'ellipsis',
                            whiteSpace: 'nowrap',
                            lineHeight: 1.4,
                        }}>
                            📍 {activeRoute.deliveryAddress}
                        </div>
                    )}

                    <div style={{ display: 'flex', gap: '8px', marginTop: '4px' }}>
                        <button
                            onClick={handleFitActiveRoute}
                            style={{
                                background: '#10b981',
                                color: '#ffffff',
                                border: 'none',
                                borderRadius: 'var(--radius-sm)',
                                padding: '5px 10px',
                                fontSize: '11.5px',
                                fontWeight: 600,
                                cursor: 'pointer',
                                display: 'flex',
                                alignItems: 'center',
                                gap: '5px',
                            }}
                        >
                            Fit Route View
                        </button>
                    </div>
                </div>
            )}

            {/* Map Action Buttons Overlay */}
            <div style={{
                position: 'absolute',
                top: 20,
                right: 20,
                zIndex: 1000,
                display: 'flex',
                flexDirection: 'column',
                gap: '8px',
            }}>
                <button
                    onClick={handleResetLocation}
                    title="Center on Store"
                    style={{
                        background: 'var(--bg-surface)',
                        color: 'var(--text-primary)',
                        border: '1px solid var(--border)',
                        padding: '8px 14px',
                        borderRadius: 'var(--radius-md)',
                        cursor: 'pointer',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '6px',
                        fontSize: '12px',
                        fontWeight: 600,
                        boxShadow: 'var(--shadow-md)',
                    }}
                >
                    <svg stroke="currentColor" fill="none" strokeWidth="2" viewBox="0 0 24 24" strokeLinecap="round" strokeLinejoin="round" height="1em" width="1em" xmlns="http://www.w3.org/2000/svg"><polygon points="3 11 22 2 13 21 11 13 3 11"></polygon></svg>
                    Locate Store
                </button>
            </div>
        </MapContainer>
    );
};

export default LiveMap;
