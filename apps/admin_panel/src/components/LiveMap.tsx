import React, { useEffect, useState, useRef } from 'react';
import { MapContainer, TileLayer, Polyline, Marker, Popup, useMap } from 'react-leaflet';
import { supabase } from '../supabaseClient';
import 'leaflet/dist/leaflet.css';
import RiderMarker from './RiderMarker';
import L from 'leaflet';
import { FaStore } from 'react-icons/fa';
import { renderToStaticMarkup } from 'react-dom/server';

// --- Custom Components ---

// 1. Component to handle map center updates
const MapController: React.FC<{ center: [number, number], zoom?: number }> = ({ center, zoom }) => {
    const map = useMap();
    useEffect(() => {
        if (center) {
            map.flyTo(center, zoom || map.getZoom());
        }
    }, [center, map]);
    return null;
};

// 2. Component to handle "Click to Set Store" (if we enabled that mode, simplified here to just draggable marker)
const StoreMarker: React.FC<{ position: [number, number], onDragEnd: (lat: number, lng: number) => void }> = ({ position, onDragEnd }) => {
    const markerRef = useRef<any>(null);

    const iconHtml = renderToStaticMarkup(
        <div style={{ color: '#ec4899', fontSize: '24px', filter: 'drop-shadow(0 2px 2px rgba(0,0,0,0.5))' }}>
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
            <Popup>Main Store Location</Popup>
        </Marker>
    );
}


// --- Main LiveMap Component ---

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

interface LiveMapProps {
    storeLocation?: { lat: number, lng: number };
    onStoreLocationUpdate?: (lat: number, lng: number) => void;
    selectedRiderId?: string | null;
}

const LiveMap: React.FC<LiveMapProps> = ({ storeLocation, onStoreLocationUpdate, selectedRiderId }) => {
    const [riders, setRiders] = useState<Record<string, RiderState>>({});
    const [viewCenter, setViewCenter] = useState<[number, number]>([17.3850, 78.4867]); 
    const [hasLocated, setHasLocated] = useState(false);
    // const mapRef = useRef<any>(null);

    // Initial Geolocation
    useEffect(() => {
        if (!hasLocated) {
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    setViewCenter([position.coords.latitude, position.coords.longitude]);
                    setHasLocated(true);
                },
                (_error) => {
                    if (storeLocation) {
                        setViewCenter([storeLocation.lat, storeLocation.lng]);
                    }
                }
            );
        }
    }, [hasLocated]);

    // Focus offects
    useEffect(() => {
        if (storeLocation) {
            setViewCenter([storeLocation.lat, storeLocation.lng]);
        }
    }, [storeLocation]);

    useEffect(() => {
        // If selected rider changes and we have their location, fly to them
        if (selectedRiderId && riders[selectedRiderId]) {
            const r = riders[selectedRiderId].current;
            setViewCenter([r.lat, r.lng]);
        }
    }, [selectedRiderId, riders]);


    const handleResetLocation = () => {
        navigator.geolocation.getCurrentPosition(
            (position) => {
                setViewCenter([position.coords.latitude, position.coords.longitude]);
            },
            (_error) => alert("Could not fetch device location.")
        );
    };

    useEffect(() => {
        // 1. Fetch initial locations
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

        // 2. Subscribe to POSTGRES CHANGES (Correct way)
        const channel = supabase.channel('public:rider_locations:map') // Unique channel name
            .on('postgres_changes', { event: '*', schema: 'public', table: 'rider_locations' }, (payload) => {
                const newLoc = payload.new as RiderLocation;
                if (!newLoc) return;
                console.log("Map Update:", newLoc);

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

    // Filter displayed riders
    const displayedRiders = selectedRiderId 
        ? (riders[selectedRiderId] ? [riders[selectedRiderId]] : []) 
        : Object.values(riders);

    return (
        <MapContainer 
            center={viewCenter}
            zoom={13} 
            style={{ height: '100%', width: '100%' }}
            attributionControl={false}
        >
            <MapController center={viewCenter} />
            
            <TileLayer
                url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
            />

            {/* Store Marker */}
            {storeLocation && onStoreLocationUpdate && (
                <StoreMarker 
                    position={[storeLocation.lat, storeLocation.lng]} 
                    onDragEnd={onStoreLocationUpdate}
                />
            )}

            {/* Riders */}
            {displayedRiders.map((riderState) => (
                <React.Fragment key={riderState.current.rider_id}>
                    <Polyline 
                        positions={riderState.path} 
                        pathOptions={{ color: '#3b82f6', weight: 4, opacity: 0.7 }} 
                    />
                    <RiderMarker 
                        id={riderState.current.rider_id}
                        position={{ lat: riderState.current.lat, lng: riderState.current.lng }}
                        previousPosition={riderState.previous ? { lat: riderState.previous.lat, lng: riderState.previous.lng } : undefined}
                    />
                </React.Fragment>
            ))}

            {/* Reset Location Button Overlay */}
            <div style={{
                position: 'absolute',
                top: 100, // Below the "Live Tracking" box (20+height)
                right: 20,
                zIndex: 1000,
            }}>
                <button
                    onClick={handleResetLocation}
                    style={{
                        background: '#374151',
                        color: 'white',
                        border: '1px solid #4b5563',
                        padding: '8px 12px',
                        borderRadius: '8px',
                        cursor: 'pointer',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '5px',
                        boxShadow: '0 2px 4px rgba(0,0,0,0.3)'
                    }}
                >
                    <svg stroke="currentColor" fill="none" strokeWidth="2" viewBox="0 0 24 24" strokeLinecap="round" strokeLinejoin="round" height="1em" width="1em" xmlns="http://www.w3.org/2000/svg"><polygon points="3 11 22 2 13 21 11 13 3 11"></polygon></svg>
                    Locate Me
                </button>
            </div>
        </MapContainer>
    );
};

export default LiveMap;
