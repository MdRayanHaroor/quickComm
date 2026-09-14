import React from "react";
import { useCurrentFrame, interpolate } from "remotion";
import { FaShoppingBag, FaSyncAlt, FaMotorcycle, FaCheck } from "react-icons/fa";
import { COLORS, FONT, FONT_HEADING, SHADOW_SM } from "../design";
import { Sidebar } from "../components/Sidebar";
import { NarrationBox } from "../components/NarrationBox";
import { NARRATION } from "../data/mockData";

const PIPELINE_ORDERS = [
  {
    id: "#QC-8824",
    time: "10:45 AM",
    total: 1240,
    status: "New Order",
    statusColor: COLORS.brandPrimary,
    address: "Flat 402, Green Glen Layout, Bellandur, Bangalore",
    items: [
      { name: "Organic Whole Milk 1L", qty: 2, price: 136 },
      { name: "Basmati Rice 5kg", qty: 1, price: 299 },
      { name: "Fresh Eggs (12pk)", qty: 1, price: 120 },
    ],
    assignedRider: "Arjun K. (Available)",
    actionLabel: "Confirm & Assign",
  },
  {
    id: "#QC-8823",
    time: "10:31 AM",
    total: 2100,
    status: "Preparing",
    statusColor: "#CA8A04",
    address: "Villa 18, Palm Meadows, Whitefield, Bangalore",
    items: [
      { name: "Amul Butter 500g", qty: 2, price: 500 },
      { name: "Toor Dal 2kg", qty: 2, price: 440 },
      { name: "Organic Whole Milk 1L", qty: 4, price: 272 },
    ],
    assignedRider: "Dev M. (On way to store)",
    actionLabel: "Ready for Dispatch",
  },
  {
    id: "#QC-8822",
    time: "10:22 AM",
    total: 680,
    status: "Out for Delivery",
    statusColor: "#3B82F6",
    address: "B-204, Salarpuria Sattva, Marathahalli, Bangalore",
    items: [
      { name: "Farm Fresh Bread 400g", qty: 1, price: 45 },
      { name: "Amul Salted Butter 500g", qty: 1, price: 250 },
      { name: "Organic Whole Milk 1L", qty: 2, price: 136 },
    ],
    assignedRider: "Vikram S. (En Route · 6 mins away)",
    actionLabel: "Track on Live Map",
  },
];

export const OrdersScene: React.FC = () => {
  const frame = useCurrentFrame();

  const headerOpacity = interpolate(frame, [0, 15], [0, 1], { extrapolateRight: "clamp" });

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
        <Sidebar activeItem="orders" width={220} />

        {/* Main Content Area */}
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
          {/* Page Header matching Orders.tsx */}
          <div
            style={{
              padding: "16px 24px 12px",
              borderBottom: `1px solid ${COLORS.border}`,
              background: COLORS.bgSurface,
              flexShrink: 0,
              opacity: headerOpacity,
            }}
          >
            <div
              style={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "center",
                marginBottom: 14,
              }}
            >
              <div>
                <h1
                  style={{
                    margin: 0,
                    fontFamily: FONT_HEADING,
                    fontSize: 22,
                    fontWeight: 700,
                    color: COLORS.textPrimary,
                    display: "flex",
                    alignItems: "center",
                    gap: 10,
                  }}
                >
                  <FaShoppingBag color={COLORS.brandPrimary} /> Live Orders Pipeline
                </h1>
                <p style={{ margin: "3px 0 0", color: COLORS.textMuted, fontSize: 13 }}>
                  Manage incoming orders, preparation, and rider dispatches
                </p>
              </div>
              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 6,
                  padding: "7px 14px",
                  borderRadius: 8,
                  border: `1px solid ${COLORS.border}`,
                  background: COLORS.bgSurfaceElevated,
                  fontSize: 13,
                  color: COLORS.textSecondary,
                  fontWeight: 600,
                }}
              >
                <FaSyncAlt /> Refresh Orders
              </div>
            </div>

            {/* Status Filter Tabs */}
            <div style={{ display: "flex", gap: 8 }}>
              {[
                { label: "New Orders", count: 4, active: true },
                { label: "Preparing", count: 2, active: false },
                { label: "Out for Delivery", count: 3, active: false },
                { label: "Past Orders", count: 42, active: false },
              ].map((tab) => (
                <div
                  key={tab.label}
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: 8,
                    background: tab.active ? COLORS.brandPrimary : COLORS.bgSurfaceElevated,
                    color: tab.active ? "#FFFFFF" : COLORS.textSecondary,
                    border: `1px solid ${tab.active ? COLORS.brandPrimary : COLORS.border}`,
                    padding: "7px 16px",
                    borderRadius: 9999,
                    fontWeight: tab.active ? 700 : 500,
                    fontSize: 13,
                    boxShadow: tab.active ? "0 2px 8px rgba(27, 166, 114, 0.25)" : "none",
                  }}
                >
                  <span>{tab.label}</span>
                  <span
                    style={{
                      background: tab.active ? "rgba(255, 255, 255, 0.25)" : COLORS.bgSurface,
                      color: tab.active ? "#FFFFFF" : COLORS.textPrimary,
                      padding: "1px 7px",
                      borderRadius: 12,
                      fontSize: 12,
                      fontWeight: 800,
                    }}
                  >
                    {tab.count}
                  </span>
                </div>
              ))}
            </div>
          </div>

          {/* Orders Cards Feed */}
          <div
            style={{
              flex: 1,
              padding: "18px 24px 24px",
              display: "flex",
              flexDirection: "column",
              gap: 14,
              overflowY: "hidden",
            }}
          >
            {PIPELINE_ORDERS.map((order, idx) => {
              const cardDelay = 8 + idx * 10;
              const cardOpacity = interpolate(Math.max(0, frame - cardDelay), [0, 15], [0, 1], {
                extrapolateRight: "clamp",
              });
              const cardY = interpolate(Math.max(0, frame - cardDelay), [0, 15], [20, 0], {
                extrapolateRight: "clamp",
              });

              return (
                <div
                  key={order.id}
                  style={{
                    background: COLORS.bgSurface,
                    borderRadius: 14,
                    borderLeft: `4px solid ${order.statusColor}`,
                    border: `1px solid ${COLORS.border}`,
                    borderLeftWidth: 4,
                    padding: "16px 20px",
                    boxShadow: SHADOW_SM,
                    opacity: cardOpacity,
                    transform: `translateY(${cardY}px)`,
                    display: "flex",
                    flexDirection: "column",
                    gap: 12,
                  }}
                >
                  {/* Order Top Bar */}
                  <div
                    style={{
                      display: "flex",
                      justifyContent: "space-between",
                      alignItems: "center",
                    }}
                  >
                    <div>
                      <span
                        style={{
                          fontFamily: FONT_HEADING,
                          fontSize: 17,
                          fontWeight: 800,
                          color: COLORS.textPrimary,
                        }}
                      >
                        Order {order.id}
                      </span>
                      <span
                        style={{
                          marginLeft: 10,
                          fontSize: 13,
                          color: COLORS.textMuted,
                        }}
                      >
                        {order.time}
                      </span>
                    </div>

                    <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                      <span
                        style={{
                          fontFamily: FONT_HEADING,
                          fontSize: 18,
                          fontWeight: 800,
                          color: COLORS.textPrimary,
                        }}
                      >
                        ₹{order.total}
                      </span>
                      <span
                        style={{
                          padding: "3px 10px",
                          borderRadius: 9999,
                          fontSize: 11.5,
                          fontWeight: 700,
                          textTransform: "uppercase",
                          background: `${order.statusColor}18`,
                          color: order.statusColor,
                          border: `1px solid ${order.statusColor}33`,
                        }}
                      >
                        {order.status}
                      </span>
                    </div>
                  </div>

                  {/* Delivery Address */}
                  <div style={{ color: COLORS.textSecondary, fontSize: 13.5, display: "flex", alignItems: "center", gap: 6 }}>
                    📍 <span>{order.address}</span>
                  </div>

                  {/* Ordered Items Box */}
                  <div
                    style={{
                      background: COLORS.bgSurfaceElevated,
                      padding: "10px 16px",
                      borderRadius: 10,
                      border: `1px solid ${COLORS.border}`,
                    }}
                  >
                    <div
                      style={{
                        fontSize: 11.5,
                        fontWeight: 700,
                        color: COLORS.textMuted,
                        textTransform: "uppercase",
                        letterSpacing: "0.5px",
                        marginBottom: 6,
                      }}
                    >
                      Items ({order.items.length})
                    </div>
                    <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 10 }}>
                      {order.items.map((item, i) => (
                        <div
                          key={i}
                          style={{
                            display: "flex",
                            alignItems: "center",
                            gap: 8,
                            fontSize: 13,
                            color: COLORS.textPrimary,
                          }}
                        >
                          <span style={{ fontWeight: 700, color: COLORS.brandPrimary }}>
                            {item.qty}x
                          </span>
                          <span style={{ flex: 1, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
                            {item.name}
                          </span>
                          <span style={{ color: COLORS.textMuted, fontSize: 12 }}>₹{item.price}</span>
                        </div>
                      ))}
                    </div>
                  </div>

                  {/* Action Bar */}
                  <div
                    style={{
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "space-between",
                      paddingTop: 8,
                      borderTop: `1px solid ${COLORS.border}`,
                    }}
                  >
                    <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                      <span style={{ fontSize: 13, color: COLORS.textMuted, fontWeight: 600 }}>
                        Assigned Rider:
                      </span>
                      <div
                        style={{
                          display: "flex",
                          alignItems: "center",
                          gap: 6,
                          padding: "5px 12px",
                          background: COLORS.bgInput,
                          border: `1px solid ${COLORS.border}`,
                          borderRadius: 6,
                          fontSize: 12.5,
                          color: COLORS.textPrimary,
                          fontWeight: 500,
                        }}
                      >
                        <FaMotorcycle color={COLORS.brandPrimary} /> {order.assignedRider}
                      </div>
                    </div>

                    <div
                      style={{
                        display: "flex",
                        alignItems: "center",
                        gap: 6,
                        padding: "7px 18px",
                        borderRadius: 8,
                        background: COLORS.brandPrimary,
                        color: "#ffffff",
                        fontSize: 13,
                        fontWeight: 600,
                        boxShadow: "0 2px 6px rgba(27, 166, 114, 0.3)",
                      }}
                    >
                      <FaCheck size={11} /> {order.actionLabel}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      <NarrationBox text={NARRATION.orders} delay={10} />
    </div>
  );
};
