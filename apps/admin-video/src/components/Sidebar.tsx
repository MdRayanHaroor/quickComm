import React from "react";
import { useCurrentFrame, interpolate, spring, useVideoConfig } from "remotion";
import {
  FaChartPie, FaBolt, FaShoppingBag, FaBoxOpen, FaWarehouse,
  FaLayerGroup, FaTrademark, FaMapMarkedAlt, FaUsersCog,
  FaCalendarAlt, FaClipboardList, FaCog, FaMoon, FaSignOutAlt, FaChevronLeft
} from "react-icons/fa";
import { COLORS, FONT, FONT_HEADING } from "../design";

interface SidebarProps {
  activeItem?:
    | "dashboard"
    | "orders"
    | "products"
    | "inventory"
    | "categories"
    | "brands"
    | "fleet"
    | "fleet-management"
    | "rider-attendance"
    | "delivery-history"
    | "settings";
  width?: number;
}

interface NavSection {
  label: string;
  items: {
    key: string;
    label: string;
    icon: React.ReactNode;
    badge?: React.ReactNode;
  }[];
}

export const Sidebar: React.FC<SidebarProps> = ({ activeItem = "dashboard", width = 220 }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const slideX = spring({
    frame,
    fps,
    from: -60,
    to: 0,
    config: { damping: 16, stiffness: 100 },
    durationInFrames: 25,
  });

  const opacity = interpolate(frame, [0, 15], [0, 1], { extrapolateRight: "clamp" });

  const SECTIONS: NavSection[] = [
    {
      label: "Overview",
      items: [
        { key: "dashboard", label: "Dashboard", icon: <FaChartPie size={16} /> },
        {
          key: "orders",
          label: "Live Orders",
          icon: <FaShoppingBag size={16} />,
          badge: (
            <div style={{ display: "flex", gap: 4, marginLeft: "auto", alignItems: "center" }}>
              <span
                title="4 New Orders"
                style={{
                  background: COLORS.danger,
                  color: "#ffffff",
                  borderRadius: 10,
                  padding: "1px 6px",
                  fontSize: 10,
                  fontWeight: 700,
                  boxShadow: "0 1px 3px rgba(239, 68, 68, 0.3)",
                }}
              >
                4
              </span>
              <span
                title="2 Preparing Orders"
                style={{
                  background: "rgba(59, 130, 246, 0.15)",
                  color: "#3b82f6",
                  border: "1px solid rgba(59, 130, 246, 0.3)",
                  borderRadius: 10,
                  padding: "1px 6px",
                  fontSize: 10,
                  fontWeight: 700,
                }}
              >
                2
              </span>
            </div>
          ),
        },
      ],
    },
    {
      label: "Catalogue",
      items: [
        { key: "products", label: "Products", icon: <FaBoxOpen size={16} /> },
        {
          key: "inventory",
          label: "Inventory",
          icon: <FaWarehouse size={16} />,
          badge: (
            <span
              style={{
                marginLeft: "auto",
                background: "rgba(234, 179, 8, 0.2)",
                color: "#ca8a04",
                border: "1px solid rgba(234, 179, 8, 0.45)",
                fontSize: 10,
                fontWeight: 800,
                padding: "1px 6px",
                borderRadius: 9999,
              }}
            >
              2 Low
            </span>
          ),
        },
        { key: "categories", label: "Categories", icon: <FaLayerGroup size={16} /> },
        { key: "brands", label: "Brands", icon: <FaTrademark size={16} /> },
      ],
    },
    {
      label: "Operations",
      items: [
        { key: "fleet", label: "Fleet & Map", icon: <FaMapMarkedAlt size={16} /> },
        { key: "fleet-management", label: "Fleet Management", icon: <FaUsersCog size={16} /> },
        { key: "rider-attendance", label: "Rider Attendance", icon: <FaCalendarAlt size={16} /> },
        { key: "delivery-history", label: "Delivery History", icon: <FaClipboardList size={16} /> },
      ],
    },
    {
      label: "Configuration",
      items: [
        { key: "settings", label: "Store Settings", icon: <FaCog size={16} /> },
      ],
    },
  ];

  return (
    <div
      style={{
        fontFamily: FONT,
        width,
        height: "100%",
        background: COLORS.bgSurface,
        borderRight: `1px solid ${COLORS.border}`,
        display: "flex",
        flexDirection: "column",
        transform: `translateX(${slideX}px)`,
        opacity,
        flexShrink: 0,
        boxSizing: "border-box",
      }}
    >
      {/* Sidebar Logo Header */}
      <div
        style={{
          padding: "16px 16px 12px",
          borderBottom: `1px solid ${COLORS.border}`,
          display: "flex",
          alignItems: "center",
          gap: 10,
        }}
      >
        <div
          style={{
            width: 34,
            height: 34,
            background: COLORS.brandPrimary,
            borderRadius: 10,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            color: "#ffffff",
            fontSize: 16,
            flexShrink: 0,
            boxShadow: "0 2px 8px rgba(27, 166, 114, 0.35)",
          }}
        >
          <FaBolt />
        </div>
        <div style={{ display: "flex", flexDirection: "column" }}>
          <span
            style={{
              fontFamily: FONT_HEADING,
              fontSize: 15,
              fontWeight: 700,
              color: COLORS.textPrimary,
              lineHeight: 1.2,
            }}
          >
            QuickComm
          </span>
          <span
            style={{
              fontSize: 11,
              color: COLORS.textMuted,
              textTransform: "uppercase",
              letterSpacing: "0.5px",
              fontWeight: 600,
            }}
          >
            Admin Portal
          </span>
        </div>
        <div
          style={{
            marginLeft: "auto",
            width: 24,
            height: 24,
            borderRadius: 6,
            border: `1px solid ${COLORS.border}`,
            background: COLORS.bgSurfaceElevated,
            color: COLORS.textMuted,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            fontSize: 11,
          }}
        >
          <FaChevronLeft size={11} />
        </div>
      </div>

      {/* Nav List */}
      <div
        style={{
          padding: "8px 10px",
          flex: 1,
          display: "flex",
          flexDirection: "column",
          gap: 1,
          overflowY: "hidden",
        }}
      >
        {SECTIONS.map((section, sIdx) => (
          <div key={section.label} style={{ marginBottom: 4 }}>
            <div
              style={{
                fontSize: 10,
                fontWeight: 600,
                textTransform: "uppercase",
                letterSpacing: "0.8px",
                color: COLORS.textMuted,
                padding: "6px 10px 2px",
              }}
            >
              {section.label}
            </div>

            {section.items.map((item, iIdx) => {
              const isActive = item.key === activeItem;
              const delay = sIdx * 4 + iIdx * 2;
              const itemOpacity = interpolate(Math.max(0, frame - 5 - delay), [0, 10], [0, 1], {
                extrapolateRight: "clamp",
              });

              return (
                <div
                  key={item.key}
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: 9,
                    padding: "7px 10px",
                    borderRadius: 10,
                    marginBottom: 1,
                    background: isActive ? COLORS.brandLight : "transparent",
                    color: isActive ? COLORS.brandPrimary : COLORS.textSecondary,
                    fontSize: 13,
                    fontWeight: isActive ? 600 : 500,
                    opacity: itemOpacity,
                  }}
                >
                  <span
                    style={{
                      color: isActive ? COLORS.brandPrimary : COLORS.textMuted,
                      display: "flex",
                      alignItems: "center",
                      width: 18,
                    }}
                  >
                    {item.icon}
                  </span>
                  <span style={{ whiteSpace: "nowrap" }}>{item.label}</span>
                  {item.badge}
                </div>
              );
            })}
          </div>
        ))}
      </div>

      {/* Footer */}
      <div
        style={{
          padding: "8px 10px",
          borderTop: `1px solid ${COLORS.border}`,
          display: "flex",
          flexDirection: "column",
          gap: 2,
        }}
      >
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 9,
            padding: "7px 10px",
            borderRadius: 10,
            color: COLORS.textSecondary,
            fontSize: 13,
            fontWeight: 500,
          }}
        >
          <FaMoon size={15} style={{ color: COLORS.textMuted }} />
          <span>Dark Mode</span>
        </div>
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 9,
            padding: "7px 10px",
            borderRadius: 10,
            color: COLORS.danger,
            fontSize: 13,
            fontWeight: 600,
          }}
        >
          <FaSignOutAlt size={15} />
          <span>Logout</span>
        </div>
      </div>
    </div>
  );
};
