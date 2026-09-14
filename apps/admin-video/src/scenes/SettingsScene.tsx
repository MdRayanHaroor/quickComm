import React from "react";
import { useCurrentFrame, interpolate } from "remotion";
import {
  FaStore, FaTruck, FaCheck, FaCrosshairs, FaCheckCircle, FaSearch, FaMapMarkerAlt
} from "react-icons/fa";
import { COLORS, FONT, FONT_HEADING, SHADOW_SM } from "../design";
import { Sidebar } from "../components/Sidebar";
import { NarrationBox } from "../components/NarrationBox";
import { NARRATION } from "../data/mockData";

export const SettingsScene: React.FC = () => {
  const frame = useCurrentFrame();

  const headerOpacity = interpolate(frame, [0, 15], [0, 1], { extrapolateRight: "clamp" });

  // Toggle animation for delivery radius toggle
  const toggleProgress = interpolate(frame, [40, 60], [0, 1], { extrapolateRight: "clamp" });

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
        <Sidebar activeItem="settings" width={220} />

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
        {/* Page Header matching Settings.tsx */}
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
              }}
            >
              Store Settings
            </h1>
            <p style={{ margin: "2px 0 0", color: COLORS.textMuted, fontSize: 12.5 }}>
              Configure supermarket operational hours, interactive map location, delivery radius, and pricing rules
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
            <FaCheck size={12} /> Save Changes
          </div>
        </div>

        {/* Settings Body matching Settings.tsx cards */}
        <div
          style={{
            padding: "16px 24px 24px",
            display: "grid",
            gridTemplateColumns: "1.2fr 1fr",
            gap: 16,
            flex: 1,
            overflowY: "hidden",
          }}
        >
          {/* Card 1: Store Location & Interactive Map */}
          <div
            style={{
              background: COLORS.bgSurface,
              borderRadius: 14,
              border: `1px solid ${COLORS.border}`,
              padding: "18px 22px",
              boxShadow: SHADOW_SM,
              display: "flex",
              flexDirection: "column",
              gap: 14,
            }}
          >
            {/* Header with Store Open Toggle */}
            <div
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                paddingBottom: 10,
                borderBottom: `1px solid ${COLORS.border}`,
              }}
            >
              <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                <div
                  style={{
                    width: 34,
                    height: 34,
                    borderRadius: 8,
                    background: COLORS.brandLight,
                    color: COLORS.brandPrimary,
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    fontSize: 16,
                  }}
                >
                  <FaStore />
                </div>
                <div>
                  <div style={{ fontSize: 14, fontWeight: 700, color: COLORS.textPrimary }}>
                    Store Profile &amp; Location
                  </div>
                  <div style={{ fontSize: 11, color: COLORS.textMuted }}>
                    Set exact store GPS coordinates &amp; address
                  </div>
                </div>
              </div>

              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <span
                  style={{
                    fontSize: 11,
                    fontWeight: 700,
                    color: COLORS.success,
                    display: "flex",
                    alignItems: "center",
                    gap: 5,
                  }}
                >
                  <span style={{ width: 7, height: 7, borderRadius: "50%", background: COLORS.success }} />
                  STORE OPEN
                </span>
                <div
                  style={{
                    width: 36,
                    height: 20,
                    borderRadius: 9999,
                    background: COLORS.brandPrimary,
                    position: "relative",
                  }}
                >
                  <div
                    style={{
                      position: "absolute",
                      top: 2,
                      right: 2,
                      width: 16,
                      height: 16,
                      borderRadius: "50%",
                      background: "#ffffff",
                    }}
                  />
                </div>
              </div>
            </div>

            {/* Form Inputs */}
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
              <div>
                <label style={{ fontSize: 12, fontWeight: 600, color: COLORS.textSecondary, display: "block", marginBottom: 4 }}>
                  Store Display Name
                </label>
                <div
                  style={{
                    background: COLORS.bgInput,
                    border: `1.5px solid ${COLORS.border}`,
                    borderRadius: 8,
                    padding: "7px 10px",
                    fontSize: 12.5,
                    color: COLORS.textPrimary,
                    fontWeight: 600,
                  }}
                >
                  QuickComm - Indiranagar
                </div>
              </div>

              <div>
                <label style={{ fontSize: 12, fontWeight: 600, color: COLORS.textSecondary, display: "block", marginBottom: 4 }}>
                  Landmark / Area
                </label>
                <div
                  style={{
                    background: COLORS.bgInput,
                    border: `1.5px solid ${COLORS.border}`,
                    borderRadius: 8,
                    padding: "7px 10px",
                    fontSize: 12.5,
                    color: COLORS.textPrimary,
                    display: "flex",
                    alignItems: "center",
                    gap: 6,
                  }}
                >
                  <FaSearch size={11} color={COLORS.textMuted} />
                  <span>100ft Road, Indiranagar</span>
                </div>
              </div>
            </div>

            {/* Interactive Map Container */}
            <div
              style={{
                flex: 1,
                borderRadius: 10,
                border: `1.5px solid ${COLORS.border}`,
                overflow: "hidden",
                position: "relative",
                background: "#E8EEF5",
                minHeight: 180,
              }}
            >
              <svg style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }} viewBox="0 0 100 100" preserveAspectRatio="none">
                <rect x="15" y="15" width="30" height="30" fill="#DFE6EE" rx="2" />
                <rect x="55" y="15" width="30" height="30" fill="#DFE6EE" rx="2" />
                <rect x="15" y="55" width="30" height="35" fill="#DFE6EE" rx="2" />
                <rect x="55" y="55" width="30" height="35" fill="#DFE6EE" rx="2" />
                <line x1="0" y1="50" x2="100" y2="50" stroke="#FFFFFF" strokeWidth="2.5" />
                <line x1="50" y1="0" x2="50" y2="100" stroke="#FFFFFF" strokeWidth="2.5" />
                {/* 5km Radius Circle */}
                <circle cx="50" cy="50" r="32" fill="rgba(27, 166, 114, 0.12)" stroke="#1BA672" strokeWidth="0.8" strokeDasharray="2 2" />
              </svg>

              {/* Store Marker Pin */}
              <div
                style={{
                  position: "absolute",
                  left: "50%",
                  top: "50%",
                  transform: "translate(-50%, -50%)",
                  width: 32,
                  height: 32,
                  borderRadius: "50%",
                  background: COLORS.brandPrimary,
                  border: "2.5px solid #ffffff",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  color: "#ffffff",
                  fontSize: 14,
                  boxShadow: "0 3px 10px rgba(0,0,0,0.25)",
                }}
              >
                <FaStore />
              </div>

              {/* Map guidance overlay */}
              <div
                style={{
                  position: "absolute",
                  bottom: 8,
                  left: 8,
                  background: "rgba(0, 0, 0, 0.75)",
                  color: "#ffffff",
                  padding: "4px 10px",
                  borderRadius: 6,
                  fontSize: 10.5,
                  display: "flex",
                  alignItems: "center",
                  gap: 6,
                }}
              >
                <FaMapMarkerAlt color="#1BA672" />
                <span>Store GPS: <strong>12.9716° N, 77.5946° E</strong> · 5 km Radius Zone</span>
              </div>
            </div>
          </div>

          {/* Card 2: Delivery & Pricing Rules */}
          <div
            style={{
              background: COLORS.bgSurface,
              borderRadius: 14,
              border: `1px solid ${COLORS.border}`,
              padding: "18px 22px",
              boxShadow: SHADOW_SM,
              display: "flex",
              flexDirection: "column",
              gap: 14,
            }}
          >
            {/* Header */}
            <div
              style={{
                display: "flex",
                alignItems: "center",
                gap: 10,
                paddingBottom: 10,
                borderBottom: `1px solid ${COLORS.border}`,
              }}
            >
              <div
                style={{
                  width: 34,
                  height: 34,
                  borderRadius: 8,
                  background: "rgba(59, 130, 246, 0.15)",
                  color: "#3B82F6",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  fontSize: 16,
                }}
              >
                <FaTruck />
              </div>
              <div>
                <div style={{ fontSize: 14, fontWeight: 700, color: COLORS.textPrimary }}>
                  Delivery Radius &amp; Pricing Rules
                </div>
                <div style={{ fontSize: 11, color: COLORS.textMuted }}>
                  Radial boundary enforcement &amp; fee waivers
                </div>
              </div>
            </div>

            {/* Rule 1: Delivery Radius Boundary */}
            <div
              style={{
                background: COLORS.bgSurfaceElevated,
                border: `1px solid ${COLORS.border}`,
                borderRadius: 10,
                padding: "12px 14px",
                display: "flex",
                flexDirection: "column",
                gap: 8,
              }}
            >
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <div>
                  <div style={{ fontSize: 13, fontWeight: 700, color: COLORS.textPrimary }}>
                    Enforce Delivery Radius Boundary
                  </div>
                  <div style={{ fontSize: 11, color: COLORS.textMuted }}>
                    Blocks checkout outside radial coverage
                  </div>
                </div>
                <div
                  style={{
                    width: 36,
                    height: 20,
                    borderRadius: 9999,
                    background: COLORS.brandPrimary,
                    position: "relative",
                  }}
                >
                  <div
                    style={{
                      position: "absolute",
                      top: 2,
                      right: 2,
                      width: 16,
                      height: 16,
                      borderRadius: "50%",
                      background: "#ffffff",
                    }}
                  />
                </div>
              </div>

              <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                <span style={{ fontSize: 12, color: COLORS.textSecondary, fontWeight: 600 }}>
                  Radial Limit:
                </span>
                <span
                  style={{
                    padding: "3px 10px",
                    borderRadius: 6,
                    background: COLORS.bgSurface,
                    border: `1px solid ${COLORS.border}`,
                    fontSize: 12,
                    fontWeight: 700,
                    color: COLORS.brandPrimary,
                  }}
                >
                  5.0 km
                </span>
                <span style={{ fontSize: 11, color: COLORS.brandPrimary, fontWeight: 600, display: "flex", alignItems: "center", gap: 4 }}>
                  <FaCheckCircle size={11} /> Coverage active
                </span>
              </div>
            </div>

            {/* Rule 2: Free Delivery Waiver */}
            <div
              style={{
                background: COLORS.bgSurfaceElevated,
                border: `1px solid ${COLORS.border}`,
                borderRadius: 10,
                padding: "12px 14px",
                display: "flex",
                flexDirection: "column",
                gap: 8,
              }}
            >
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <div>
                  <div style={{ fontSize: 13, fontWeight: 700, color: COLORS.textPrimary }}>
                    Free Delivery on Qualifying Orders
                  </div>
                  <div style={{ fontSize: 11, color: COLORS.textMuted }}>
                    Auto-waive fee on qualifying cart values
                  </div>
                </div>
                <div
                  style={{
                    width: 36,
                    height: 20,
                    borderRadius: 9999,
                    background: COLORS.brandPrimary,
                    position: "relative",
                  }}
                >
                  <div
                    style={{
                      position: "absolute",
                      top: 2,
                      right: 2,
                      width: 16,
                      height: 16,
                      borderRadius: "50%",
                      background: "#ffffff",
                    }}
                  />
                </div>
              </div>

              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <span style={{ fontSize: 12, color: COLORS.textSecondary }}>Free above:</span>
                <span
                  style={{
                    padding: "3px 10px",
                    borderRadius: 6,
                    background: COLORS.bgSurface,
                    border: `1px solid ${COLORS.border}`,
                    fontSize: 12,
                    fontWeight: 700,
                    color: COLORS.textPrimary,
                  }}
                >
                  ₹299
                </span>
              </div>
            </div>

            {/* Pricing Parameters */}
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
              <div
                style={{
                  background: COLORS.bgSurfaceElevated,
                  border: `1px solid ${COLORS.border}`,
                  borderRadius: 8,
                  padding: "10px 12px",
                }}
              >
                <div style={{ fontSize: 11, color: COLORS.textMuted, fontWeight: 600 }}>
                  Standard Delivery Fee
                </div>
                <div style={{ fontSize: 16, fontWeight: 800, color: COLORS.textPrimary, marginTop: 2 }}>
                  ₹20
                </div>
              </div>

              <div
                style={{
                  background: COLORS.bgSurfaceElevated,
                  border: `1px solid ${COLORS.border}`,
                  borderRadius: 8,
                  padding: "10px 12px",
                }}
              >
                <div style={{ fontSize: 11, color: COLORS.textMuted, fontWeight: 600 }}>
                  Minimum Order Amount
                </div>
                <div style={{ fontSize: 16, fontWeight: 800, color: COLORS.textPrimary, marginTop: 2 }}>
                  ₹99
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      </div>

      <NarrationBox text={NARRATION.settings} delay={10} />
    </div>
  );
};
