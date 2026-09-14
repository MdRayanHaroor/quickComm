import React from "react";
import { useCurrentFrame, interpolate, Easing } from "remotion";
import {
  FaShoppingBag, FaBoxes, FaExclamationTriangle, FaTimesCircle,
  FaRupeeSign, FaSyncAlt, FaClock, FaArrowRight, FaCheckCircle,
  FaWarehouse, FaPlus, FaMotorcycle
} from "react-icons/fa";
import { COLORS, FONT, FONT_HEADING, SHADOW_SM } from "../design";
import { AnimatedCard } from "../components/AnimatedCard";
import { SalesAreaChart } from "../components/SalesAreaChart";
import { Sidebar } from "../components/Sidebar";
import { NarrationBox } from "../components/NarrationBox";
import { NARRATION } from "../data/mockData";

const RECENT_ORDERS_DATA = [
  { id: "#24", address: "Flat 003, A H Manor Apts, 6th Cross, Kaggadasapura", amount: 100, status: "Delivered", statusType: "green" },
  { id: "#23", address: "Villa 12, Green Glen Layout, Bellandur, Bangalore", amount: 180, status: "Delivered", statusType: "green" },
  { id: "#22", address: "Flat 402, Salarpuria Sattva, Marathahalli", amount: 250, status: "Delivered", statusType: "green" },
  { id: "#21", address: "House 88, 100ft Road, Indiranagar, Bangalore", amount: 420, status: "Delivered", statusType: "green" },
  { id: "#20", address: "Tower 3, Palm Meadows, Whitefield, Bangalore", amount: 350, status: "Delivered", statusType: "green" },
  { id: "#19", address: "Flat 101, Prestige Tech Park, Outer Ring Road", amount: 200, status: "Delivered", statusType: "green" },
  { id: "#18", address: "42 B, Koramangala 4th Block, Bangalore", amount: 300, status: "Delivered", statusType: "green" },
];

export const DashboardScene: React.FC = () => {
  const frame = useCurrentFrame();

  const contentOpacity = interpolate(frame, [0, 15], [0, 1], { extrapolateRight: "clamp" });

  // Silky-smooth cinematic camera pan to reveal lower dashboard components (Live Orders, Recent Orders, Inventory)
  const scrollY = interpolate(
    frame,
    [150, 260],
    [0, 350],
    {
      easing: Easing.inOut(Easing.cubic),
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    }
  );

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
        <Sidebar activeItem="dashboard" width={220} />

        {/* Main Content Pane */}
        <div
          style={{
            flex: 1,
            display: "flex",
            flexDirection: "column",
            height: "100%",
            overflow: "hidden",
            boxSizing: "border-box",
            opacity: contentOpacity,
          }}
        >
          {/* Top Page Header matching localhost:5173 */}
          <div
            style={{
              background: COLORS.bgSurface,
              borderBottom: `1px solid ${COLORS.border}`,
              padding: "16px 24px",
              display: "flex",
              alignItems: "center",
              justifyContent: "space-between",
              flexShrink: 0,
              zIndex: 10,
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
                Supermarket Dashboard
              </h1>
              <p style={{ margin: "2px 0 0", color: COLORS.textMuted, fontSize: 12.5 }}>
                Key performance indicators, catalog inventory health, and recent operations
              </p>
            </div>

            <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 8,
                  padding: "8px 16px",
                  borderRadius: 8,
                  background: COLORS.brandPrimary,
                  color: "#ffffff",
                  fontSize: 13,
                  fontWeight: 600,
                  boxShadow: "0 2px 8px rgba(27, 166, 114, 0.35)",
                }}
              >
                <FaShoppingBag size={13} /> Live Orders (4)
              </div>
              <div
                style={{
                  width: 34,
                  height: 34,
                  borderRadius: 8,
                  border: `1px solid ${COLORS.border}`,
                  background: COLORS.bgSurface,
                  color: COLORS.textSecondary,
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  fontSize: 12,
                }}
              >
                <FaSyncAlt />
              </div>
            </div>
          </div>

          {/* Page Body with animated vertical camera scroll */}
          <div
            style={{
              flex: 1,
              overflow: "hidden",
              position: "relative",
            }}
          >
            <div
              style={{
                padding: "20px 24px 30px",
                display: "flex",
                flexDirection: "column",
                gap: 20,
                transform: `translate3d(0, -${scrollY.toFixed(2)}px, 0)`,
                willChange: "transform",
              }}
            >
              {/* 1. Primary KPI Metrics Grid - 5 Cards with realistic supermarket metrics */}
              <div
                style={{
                  display: "grid",
                  gridTemplateColumns: "repeat(5, 1fr)",
                  gap: 14,
                }}
              >
                <AnimatedCard
                  label="Total GMV"
                  value={148500}
                  prefix="₹"
                  icon={<FaRupeeSign size={13} />}
                  iconBg={COLORS.brandLight}
                  iconColor={COLORS.brandPrimary}
                  subtext="+18.4% this week"
                  subtextColor={COLORS.brandPrimary}
                  delay={5}
                />
                <AnimatedCard
                  label="Total Orders"
                  value={186}
                  icon={<FaShoppingBag size={13} />}
                  iconBg="rgba(59, 130, 246, 0.15)"
                  iconColor="#3B82F6"
                  subtext="Pipeline active →"
                  subtextColor={COLORS.brandPrimary}
                  delay={8}
                />
                <AnimatedCard
                  label="Active SKUs"
                  value={142}
                  icon={<FaBoxes size={13} />}
                  iconBg="rgba(168, 85, 247, 0.15)"
                  iconColor="#A855F7"
                  subtext="Catalogue sync →"
                  subtextColor={COLORS.brandPrimary}
                  delay={11}
                />
                <AnimatedCard
                  label="Low Stock"
                  value={4}
                  icon={<FaExclamationTriangle size={13} />}
                  iconBg="rgba(234, 179, 8, 0.15)"
                  iconColor="#CA8A04"
                  subtext="Near threshold"
                  delay={14}
                />
                <AnimatedCard
                  label="Out of Stock"
                  value={1}
                  icon={<FaTimesCircle size={13} />}
                  iconBg="rgba(239, 68, 68, 0.15)"
                  iconColor={COLORS.danger}
                  subtext="Needs reorder"
                  delay={17}
                />
              </div>

              {/* 2. Sales Activity Trend Area Chart matching localhost:5173 */}
              <SalesAreaChart delay={20} />

              {/* 3. Live Orders Status Banner */}
              <div
                style={{
                  background: "linear-gradient(135deg, rgba(27, 166, 114, 0.1) 0%, rgba(59, 130, 246, 0.08) 100%)",
                  border: `1px solid ${COLORS.border}`,
                  borderRadius: 14,
                  padding: "18px 24px",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "space-between",
                  boxShadow: SHADOW_SM,
                }}
              >
                <div>
                  <div
                    style={{
                      fontWeight: 800,
                      color: COLORS.textPrimary,
                      fontSize: 15,
                      display: "flex",
                      alignItems: "center",
                      gap: 8,
                    }}
                  >
                    <FaClock color={COLORS.brandPrimary} /> Live Orders Status
                  </div>
                  <div
                    style={{
                      fontSize: 13,
                      color: COLORS.textSecondary,
                      marginTop: 4,
                      display: "flex",
                      gap: 18,
                    }}
                  >
                    <span>New Orders: <strong style={{ color: COLORS.brandPrimary }}>4</strong></span>
                    <span>Preparing: <strong style={{ color: "#ca8a04" }}>2</strong></span>
                    <span>Out for Delivery: <strong style={{ color: COLORS.info }}>3</strong></span>
                    <span>Completed Today: <strong style={{ color: COLORS.success }}>186</strong></span>
                  </div>
                </div>

                <div
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: 8,
                    padding: "8px 18px",
                    borderRadius: 8,
                    background: COLORS.brandPrimary,
                    color: "#ffffff",
                    fontSize: 13,
                    fontWeight: 600,
                    boxShadow: "0 2px 6px rgba(27, 166, 114, 0.3)",
                  }}
                >
                  Open Orders Page <FaArrowRight size={11} />
                </div>
              </div>

              {/* 4. Bottom Grid: Recent Orders Table (2fr) & Right Widgets (1fr) */}
              <div
                style={{
                  display: "grid",
                  gridTemplateColumns: "2fr 1fr",
                  gap: 20,
                  paddingBottom: 20,
                }}
              >
                {/* Recent Orders Table Card */}
                <div
                  style={{
                    background: COLORS.bgSurface,
                    borderRadius: 14,
                    border: `1px solid ${COLORS.border}`,
                    padding: "20px 24px",
                    boxShadow: SHADOW_SM,
                  }}
                >
                  <div
                    style={{
                      display: "flex",
                      justifyContent: "space-between",
                      alignItems: "center",
                      marginBottom: 16,
                    }}
                  >
                    <h3
                      style={{
                        margin: 0,
                        fontFamily: FONT_HEADING,
                        fontSize: 16,
                        fontWeight: 700,
                        color: COLORS.textPrimary,
                      }}
                    >
                      Recent Orders
                    </h3>
                    <span style={{ fontSize: 12, color: COLORS.brandPrimary, fontWeight: 600 }}>
                      View All →
                    </span>
                  </div>

                  <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
                    <thead>
                      <tr style={{ borderBottom: `1px solid ${COLORS.border}`, color: COLORS.textMuted }}>
                        <th style={{ textAlign: "left", padding: "8px 12px", fontSize: 11, textTransform: "uppercase" }}>Order</th>
                        <th style={{ textAlign: "left", padding: "8px 12px", fontSize: 11, textTransform: "uppercase" }}>Customer Address</th>
                        <th style={{ textAlign: "right", padding: "8px 12px", fontSize: 11, textTransform: "uppercase" }}>Amount</th>
                        <th style={{ textAlign: "center", padding: "8px 12px", fontSize: 11, textTransform: "uppercase" }}>Status</th>
                      </tr>
                    </thead>
                    <tbody>
                      {RECENT_ORDERS_DATA.map((ord) => (
                        <tr key={ord.id} style={{ borderBottom: `1px solid ${COLORS.border}` }}>
                          <td style={{ padding: "10px 12px", fontWeight: 700, color: COLORS.textPrimary }}>
                            {ord.id}
                          </td>
                          <td style={{ padding: "10px 12px", color: COLORS.textSecondary, maxWidth: 280, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                            {ord.address}
                          </td>
                          <td style={{ padding: "10px 12px", textAlign: "right", fontWeight: 700, color: COLORS.textPrimary }}>
                            ₹{ord.amount}
                          </td>
                          <td style={{ padding: "10px 12px", textAlign: "center" }}>
                            <span
                              style={{
                                padding: "2px 8px",
                                borderRadius: 9999,
                                fontSize: 11,
                                fontWeight: 700,
                                background: COLORS.successLight,
                                color: "#047857",
                              }}
                            >
                              {ord.status}
                            </span>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>

                {/* Right Widgets: Inventory Health & Quick Shortcuts */}
                <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
                  {/* Inventory Health Widget */}
                  <div
                    style={{
                      background: COLORS.bgSurface,
                      borderRadius: 14,
                      border: `1px solid ${COLORS.border}`,
                      padding: "20px 24px",
                      boxShadow: SHADOW_SM,
                    }}
                  >
                    <h3
                      style={{
                        margin: "0 0 14px",
                        fontFamily: FONT_HEADING,
                        fontSize: 16,
                        fontWeight: 700,
                        color: COLORS.textPrimary,
                      }}
                    >
                      Inventory Health
                    </h3>
                    <div style={{ display: "flex", flexDirection: "column", gap: 10, fontSize: 13 }}>
                      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                        <span style={{ color: COLORS.textSecondary, display: "flex", alignItems: "center", gap: 6 }}>
                          <FaCheckCircle color={COLORS.success} size={13} /> Healthy Stock
                        </span>
                        <strong style={{ color: COLORS.textPrimary }}>137 SKUs</strong>
                      </div>
                      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                        <span style={{ color: COLORS.textSecondary, display: "flex", alignItems: "center", gap: 6 }}>
                          <FaExclamationTriangle color="#ca8a04" size={13} /> Low Stock Alert
                        </span>
                        <strong style={{ color: "#ca8a04" }}>4 SKUs</strong>
                      </div>
                      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                        <span style={{ color: COLORS.textSecondary, display: "flex", alignItems: "center", gap: 6 }}>
                          <FaTimesCircle color={COLORS.danger} size={13} /> Out of Stock
                        </span>
                        <strong style={{ color: COLORS.danger }}>1 SKU</strong>
                      </div>
                    </div>

                    <div
                      style={{
                        marginTop: 16,
                        padding: "8px 12px",
                        borderRadius: 8,
                        border: `1px solid ${COLORS.border}`,
                        background: COLORS.bgSurfaceElevated,
                        color: COLORS.textPrimary,
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "center",
                        gap: 8,
                        fontSize: 13,
                        fontWeight: 600,
                      }}
                    >
                      <FaWarehouse size={13} /> Manage Stock
                    </div>
                  </div>

                  {/* Quick Action Shortcuts Widget */}
                  <div
                    style={{
                      background: COLORS.bgSurface,
                      borderRadius: 14,
                      border: `1px solid ${COLORS.border}`,
                      padding: "20px 24px",
                      boxShadow: SHADOW_SM,
                    }}
                  >
                    <h3
                      style={{
                        margin: "0 0 14px",
                        fontFamily: FONT_HEADING,
                        fontSize: 16,
                        fontWeight: 700,
                        color: COLORS.textPrimary,
                      }}
                    >
                      Quick Shortcuts
                    </h3>
                    <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                      <div
                        style={{
                          padding: "9px 12px",
                          borderRadius: 8,
                          border: `1px solid ${COLORS.border}`,
                          background: COLORS.bgSurfaceElevated,
                          color: COLORS.textPrimary,
                          display: "flex",
                          alignItems: "center",
                          gap: 8,
                          fontSize: 13,
                          fontWeight: 500,
                        }}
                      >
                        <FaPlus size={11} /> Add / Edit Products
                      </div>
                      <div
                        style={{
                          padding: "9px 12px",
                          borderRadius: 8,
                          border: `1px solid ${COLORS.border}`,
                          background: COLORS.bgSurfaceElevated,
                          color: COLORS.textPrimary,
                          display: "flex",
                          alignItems: "center",
                          gap: 8,
                          fontSize: 13,
                          fontWeight: 500,
                        }}
                      >
                        <FaMotorcycle size={13} /> Live Delivery Map (2 Riders)
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <NarrationBox text={NARRATION.dashboard} delay={10} />
    </div>
  );
};
