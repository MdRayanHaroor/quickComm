import React from "react";
import { useCurrentFrame, interpolate } from "remotion";
import {
  FaMapMarkedAlt, FaMotorcycle, FaStore, FaPlus
} from "react-icons/fa";
import { COLORS, FONT, FONT_HEADING, SHADOW_SM } from "../design";
import { Sidebar } from "../components/Sidebar";
import { NarrationBox } from "../components/NarrationBox";
import { RIDERS, NARRATION } from "../data/mockData";

export const FleetScene: React.FC = () => {
  const frame = useCurrentFrame();

  const headerOpacity = interpolate(frame, [0, 15], [0, 1], { extrapolateRight: "clamp" });
  const routeProgress = interpolate(frame, [15, 55], [0, 1], { extrapolateRight: "clamp" });

  return (
    <div
      style={{
        width: 1920,
        height: 1080,
        background: COLORS.bgPage,
        overflow: "hidden",
        position: "relative",
      }}
    >
      {/* 1.50x scaling wrapper locked in */}
      <div
        style={{
          width: 1280,
          height: 720,
          transform: "scale(1.5)",
          transformOrigin: "top left",
          display: "flex",
          fontFamily: FONT,
          background: COLORS.bgPage,
          overflow: "hidden",
        }}
      >
        <Sidebar activeItem="fleet" width={220} />

        {/* Main content */}
        <div
          style={{
            flex: 1,
            display: "flex",
            flexDirection: "column",
            height: "100%",
            overflow: "hidden",
            boxSizing: "border-box",
          }}
        >
          {/* Page Header */}
          <div
            style={{
              background: COLORS.bgSurface,
              borderBottom: `1px solid ${COLORS.border}`,
              padding: "16px 24px",
              display: "flex",
              alignItems: "center",
              justifyContent: "space-between",
              flexShrink: 0,
              opacity: headerOpacity,
            }}
          >
            <div>
              <h1
                style={{
                  margin: 0,
                  fontFamily: FONT_HEADING,
                  fontSize: 20,
                  fontWeight: 700,
                  color: COLORS.textPrimary,
                  display: "flex",
                  alignItems: "center",
                  gap: 10,
                }}
              >
                <FaMapMarkedAlt color={COLORS.brandPrimary} /> Fleet &amp; Live Map
              </h1>
              <p style={{ margin: "2px 0 0", color: COLORS.textMuted, fontSize: 12.5 }}>
                6 active riders online · Real-time GPS location &amp; route dispatch
              </p>
            </div>

            <div
              style={{
                display: "flex",
                alignItems: "center",
                gap: 6,
                padding: "8px 16px",
                borderRadius: 8,
                background: COLORS.brandPrimary,
                color: "#ffffff",
                fontSize: 13,
                fontWeight: 600,
                boxShadow: "0 2px 8px rgba(27, 166, 114, 0.35)",
              }}
            >
              <FaPlus size={12} /> Add New Rider
            </div>
          </div>

          {/* Two-Column Body: Rider List Sidebar + Interactive Map */}
          <div style={{ flex: 1, display: "flex", overflow: "hidden" }}>
            {/* Left Rider List Sidebar matching Riders.tsx */}
            <div
              style={{
                width: 320,
                background: COLORS.bgSurface,
                borderRight: `1px solid ${COLORS.border}`,
                display: "flex",
                flexDirection: "column",
                overflowY: "hidden",
              }}
            >
              {/* Store Hub Location Section */}
              <div
                style={{
                  padding: "16px 20px",
                  borderBottom: `1px solid ${COLORS.border}`,
                  background: COLORS.bgSurfaceElevated,
                }}
              >
                <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 4 }}>
                  <FaStore color={COLORS.brandPrimary} />
                  <span style={{ fontSize: 14, fontWeight: 700, color: COLORS.textPrimary }}>
                    Indiranagar Store Hub
                  </span>
                  <span
                    style={{
                      marginLeft: "auto",
                      padding: "2px 6px",
                      borderRadius: 4,
                      background: COLORS.successLight,
                      color: "#047857",
                      fontSize: 10.5,
                      fontWeight: 700,
                    }}
                  >
                    ONLINE
                  </span>
                </div>
                <div style={{ fontSize: 12, color: COLORS.textMuted }}>
                  Lat: 12.9716, Lng: 77.5946 · Coverage: 5.0 km
                </div>
              </div>

              {/* Rider cards list */}
              <div style={{ padding: "12px 14px", display: "flex", flexDirection: "column", gap: 10, flex: 1 }}>
                {RIDERS.map((rider, i) => {
                  const cardDelay = 6 + i * 5;
                  const cardOpacity = interpolate(Math.max(0, frame - cardDelay), [0, 10], [0, 1], {
                    extrapolateRight: "clamp",
                  });
                  const isOnBreak = rider.status === "Break";

                  return (
                    <div
                      key={rider.id}
                      style={{
                        padding: "11px 14px",
                        borderRadius: 10,
                        background: i === 0 ? COLORS.brandLight : COLORS.bgSurface,
                        border: `1px solid ${i === 0 ? "rgba(27, 166, 114, 0.4)" : COLORS.border}`,
                        display: "flex",
                        alignItems: "center",
                        gap: 12,
                        opacity: cardOpacity,
                        boxShadow: SHADOW_SM,
                      }}
                    >
                      {/* Rider Avatar */}
                      <div
                        style={{
                          width: 38,
                          height: 38,
                          borderRadius: "50%",
                          background: isOnBreak ? COLORS.warningLight : "rgba(27, 166, 114, 0.15)",
                          color: isOnBreak ? COLORS.warning : COLORS.brandPrimary,
                          display: "flex",
                          alignItems: "center",
                          justifyContent: "center",
                          fontSize: 16,
                          flexShrink: 0,
                        }}
                      >
                        <FaMotorcycle />
                      </div>

                      <div style={{ flex: 1 }}>
                        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                          <span style={{ fontSize: 13.5, fontWeight: 700, color: COLORS.textPrimary }}>
                            {rider.name}
                          </span>
                          <span
                            style={{
                              padding: "2px 8px",
                              borderRadius: 9999,
                              fontSize: 10.5,
                              fontWeight: 700,
                              background: isOnBreak ? COLORS.warningLight : COLORS.successLight,
                              color: isOnBreak ? "#92400E" : "#047857",
                            }}
                          >
                            {rider.status}
                          </span>
                        </div>
                        <div style={{ fontSize: 12, color: COLORS.textMuted, marginTop: 2 }}>
                          {rider.deliveries} deliveries today · 98% on-time
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Right Map View matching Leaflet/Carto Light styling */}
            <div
              style={{
                flex: 1,
                position: "relative",
                background: "#EAF0F6",
                overflow: "hidden",
              }}
            >
              <svg
                style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }}
                viewBox="0 0 100 100"
                preserveAspectRatio="none"
              >
                {/* City Blocks Background */}
                <rect x="10" y="10" width="35" height="30" fill="#E2E9F0" rx="2" />
                <rect x="55" y="10" width="38" height="30" fill="#E2E9F0" rx="2" />
                <rect x="10" y="50" width="35" height="40" fill="#E2E9F0" rx="2" />
                <rect x="55" y="50" width="38" height="40" fill="#E2E9F0" rx="2" />

                {/* Parks / Green zones */}
                <rect x="15" y="15" width="12" height="10" fill="#D7ECD9" rx="2" opacity="0.8" />
                <rect x="65" y="60" width="18" height="15" fill="#D7ECD9" rx="2" opacity="0.8" />

                {/* Major Roads in Clean Light White with subtle border */}
                <line x1="0" y1="45" x2="100" y2="45" stroke="#FFFFFF" strokeWidth="3" />
                <line x1="0" y1="45" x2="100" y2="45" stroke="#CBD5E1" strokeWidth="3.6" opacity="0.5" />
                <line x1="50" y1="0" x2="50" y2="100" stroke="#FFFFFF" strokeWidth="3" />
                <line x1="50" y1="0" x2="50" y2="100" stroke="#CBD5E1" strokeWidth="3.6" opacity="0.5" />

                {/* Secondary avenues */}
                <line x1="0" y1="25" x2="100" y2="25" stroke="#FFFFFF" strokeWidth="1.6" />
                <line x1="0" y1="75" x2="100" y2="75" stroke="#FFFFFF" strokeWidth="1.6" />
                <line x1="28" y1="0" x2="28" y2="100" stroke="#FFFFFF" strokeWidth="1.6" />
                <line x1="75" y1="0" x2="75" y2="100" stroke="#FFFFFF" strokeWidth="1.6" />

                {/* Delivery Radius Circle from Settings (5km zone around Store Hub) */}
                <circle
                  cx="50"
                  cy="48"
                  r="38"
                  fill="rgba(27, 166, 114, 0.08)"
                  stroke="#1BA672"
                  strokeWidth="0.8"
                  strokeDasharray="2 2"
                />

                {/* Live Delivery Route */}
                <line
                  x1="50"
                  y1="48"
                  x2={50 + (75 - 50) * routeProgress}
                  y2={48 + (25 - 48) * routeProgress}
                  stroke="#1BA672"
                  strokeWidth="1.2"
                  strokeDasharray="2 2"
                />
              </svg>

              {/* Store Hub Marker */}
              <div
                style={{
                  position: "absolute",
                  left: "50%",
                  top: "48%",
                  transform: "translate(-50%, -50%)",
                  width: 38,
                  height: 38,
                  borderRadius: "50%",
                  background: COLORS.brandPrimary,
                  border: "3px solid #ffffff",
                  boxShadow: "0 3px 10px rgba(0,0,0,0.25)",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  color: "#ffffff",
                  fontSize: 16,
                  zIndex: 10,
                }}
              >
                <FaStore />
              </div>

              {/* Store Tag */}
              <div
                style={{
                  position: "absolute",
                  left: "50%",
                  top: "48%",
                  transform: "translate(-50%, 25px)",
                  background: "#ffffff",
                  padding: "3px 10px",
                  borderRadius: 6,
                  boxShadow: "0 2px 6px rgba(0,0,0,0.15)",
                  fontSize: 11.5,
                  fontWeight: 700,
                  color: COLORS.textPrimary,
                  border: `1px solid ${COLORS.border}`,
                  whiteSpace: "nowrap",
                  zIndex: 10,
                }}
              >
                🏬 Store Hub (Indiranagar)
              </div>

              {/* Customer Drop Location Pin */}
              <div
                style={{
                  position: "absolute",
                  left: "75%",
                  top: "25%",
                  transform: "translate(-50%, -50%)",
                  width: 30,
                  height: 30,
                  borderRadius: "50%",
                  background: COLORS.info,
                  border: "2px solid #ffffff",
                  boxShadow: "0 2px 8px rgba(0,0,0,0.2)",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  color: "#ffffff",
                  fontSize: 13,
                  zIndex: 9,
                }}
              >
                📍
              </div>

              {/* Rider GPS Markers */}
              {RIDERS.map((rider) => {
                const isOnBreak = rider.status === "Break";
                const pinBg = isOnBreak ? COLORS.warning : COLORS.brandPrimary;

                return (
                  <div
                    key={rider.id}
                    style={{
                      position: "absolute",
                      left: `${rider.x}%`,
                      top: `${rider.y}%`,
                      transform: "translate(-50%, -50%)",
                      display: "flex",
                      flexDirection: "column",
                      alignItems: "center",
                      zIndex: 8,
                    }}
                  >
                    <div
                      style={{
                        width: 30,
                        height: 30,
                        borderRadius: "50%",
                        background: pinBg,
                        border: "2.5px solid #ffffff",
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "center",
                        color: "#ffffff",
                        fontSize: 13.5,
                        boxShadow: "0 2px 8px rgba(0,0,0,0.25)",
                      }}
                    >
                      <FaMotorcycle />
                    </div>
                    <div
                      style={{
                        marginTop: 3,
                        background: "rgba(255, 255, 255, 0.95)",
                        border: `1px solid ${COLORS.border}`,
                        borderRadius: 4,
                        padding: "1px 7px",
                        fontSize: 11,
                        fontWeight: 700,
                        color: COLORS.textPrimary,
                        boxShadow: "0 1px 4px rgba(0,0,0,0.1)",
                        whiteSpace: "nowrap",
                      }}
                    >
                      {rider.name}
                    </div>
                  </div>
                );
              })}

              {/* Map Status Overlay */}
              <div
                style={{
                  position: "absolute",
                  bottom: 16,
                  left: 16,
                  background: "rgba(255, 255, 255, 0.92)",
                  border: `1px solid ${COLORS.border}`,
                  boxShadow: "0 2px 8px rgba(0,0,0,0.08)",
                  borderRadius: 8,
                  padding: "6px 14px",
                  display: "flex",
                  alignItems: "center",
                  gap: 10,
                  fontSize: 12.5,
                  color: COLORS.textSecondary,
                  zIndex: 10,
                }}
              >
                <span style={{ display: "flex", alignItems: "center", gap: 5, color: COLORS.brandPrimary, fontWeight: 700 }}>
                  <span style={{ width: 8, height: 8, borderRadius: "50%", background: COLORS.brandPrimary }} /> Live GPS
                </span>
                <span>|</span>
                <span>5.0 km delivery boundary active</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <NarrationBox text={NARRATION.fleet} delay={10} />
    </div>
  );
};
