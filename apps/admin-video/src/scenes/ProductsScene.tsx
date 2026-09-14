import React from "react";
import { useCurrentFrame, interpolate } from "remotion";
import {
  FaPlus, FaFileUpload, FaSearch, FaEdit, FaTrash
} from "react-icons/fa";
import { COLORS, FONT, FONT_HEADING, SHADOW_SM } from "../design";
import { Sidebar } from "../components/Sidebar";
import { NarrationBox } from "../components/NarrationBox";
import { NARRATION } from "../data/mockData";

const PRODUCT_ROWS = [
  {
    id: 1,
    name: "Organic Whole Milk 1L",
    tags: "Dairy · Organic",
    category: "Dairy & Eggs",
    brand: "Amul",
    price: 68,
    stock: 84,
    stockStatus: "In Stock",
    stockType: "green",
    variants: "1 variant",
    emoji: "🥛",
  },
  {
    id: 2,
    name: "Basmati Rice 5kg",
    tags: "Grains · Premium",
    category: "Atta & Rice",
    brand: "India Gate",
    price: 299,
    stock: 32,
    stockStatus: "In Stock",
    stockType: "green",
    variants: "2 variants",
    emoji: "🌾",
  },
  {
    id: 3,
    name: "Fresh Eggs (12pk)",
    tags: "Poultry · Farm Fresh",
    category: "Dairy & Eggs",
    brand: "Eggoz",
    price: 120,
    stock: 12,
    stockStatus: "Low: 12",
    stockType: "amber",
    variants: "1 variant",
    emoji: "🥚",
  },
  {
    id: 4,
    name: "Amul Salted Butter 500g",
    tags: "Dairy · Breakfast",
    category: "Dairy & Eggs",
    brand: "Amul",
    price: 250,
    stock: 55,
    stockStatus: "In Stock",
    stockType: "green",
    variants: "3 variants",
    emoji: "🧈",
  },
  {
    id: 5,
    name: "Red Royal Delicious Apples 1kg",
    tags: "Fruits · Fresh",
    category: "Fruits & Vegetables",
    brand: "FarmDirect",
    price: 180,
    stock: 4,
    stockStatus: "Low: 4",
    stockType: "red",
    variants: "1 variant",
    emoji: "🍎",
  },
  {
    id: 6,
    name: "Fortune Sunlite Refined Oil 1L",
    tags: "Cooking · Edible Oil",
    category: "Oils & Masalas",
    brand: "Fortune",
    price: 145,
    stock: 45,
    stockStatus: "In Stock",
    stockType: "green",
    variants: "2 variants",
    emoji: "🌻",
  },
  {
    id: 7,
    name: "Aashirvaad Shudh Chakki Atta 5kg",
    tags: "Flour · Whole Wheat",
    category: "Atta & Rice",
    brand: "ITC",
    price: 260,
    stock: 28,
    stockStatus: "In Stock",
    stockType: "green",
    variants: "1 variant",
    emoji: "🌾",
  },
];

export const ProductsScene: React.FC = () => {
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
        <Sidebar activeItem="products" width={220} />

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
          {/* Page Header matching Products.tsx */}
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
                  fontSize: 22,
                  fontWeight: 700,
                  color: COLORS.textPrimary,
                }}
              >
                Products
              </h1>
              <p style={{ margin: "2px 0 0", color: COLORS.textMuted, fontSize: 13 }}>
                142 total items in store catalogue
              </p>
            </div>

            <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 6,
                  padding: "9px 18px",
                  borderRadius: 8,
                  border: `1px solid ${COLORS.border}`,
                  background: COLORS.bgSurfaceElevated,
                  fontSize: 13,
                  color: COLORS.textPrimary,
                  fontWeight: 600,
                }}
              >
                <FaFileUpload /> Bulk Import
              </div>
              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 6,
                  padding: "9px 18px",
                  borderRadius: 8,
                  background: COLORS.brandPrimary,
                  color: "#ffffff",
                  fontSize: 13,
                  fontWeight: 600,
                  boxShadow: "0 2px 8px rgba(27, 166, 114, 0.35)",
                }}
              >
                <FaPlus /> Add Product
              </div>
            </div>
          </div>

          {/* Filter Bar */}
          <div
            style={{
              padding: "14px 24px 10px",
              display: "flex",
              gap: 10,
              alignItems: "center",
              flexShrink: 0,
            }}
          >
            {/* Search Box */}
            <div
              style={{
                flex: 1,
                display: "flex",
                alignItems: "center",
                gap: 8,
                background: COLORS.bgInput,
                border: `1.5px solid ${COLORS.border}`,
                borderRadius: 8,
                padding: "8px 12px",
                color: COLORS.textMuted,
                fontSize: 13,
              }}
            >
              <FaSearch size={13} />
              <span>Search products, brands, or barcodes...</span>
            </div>

            {/* Filter Dropdowns */}
            {["All Categories ▾", "All Brands ▾", "All Status ▾", "Newest First ▾"].map((f) => (
              <div
                key={f}
                style={{
                  padding: "8px 14px",
                  borderRadius: 8,
                  border: `1.5px solid ${COLORS.border}`,
                  background: COLORS.bgInput,
                  fontSize: 13,
                  color: COLORS.textSecondary,
                  fontWeight: 500,
                  whiteSpace: "nowrap",
                }}
              >
                {f}
              </div>
            ))}
          </div>

          {/* Products Table */}
          <div style={{ padding: "0 32px 24px", flex: 1, overflowY: "hidden" }}>
            <div
              style={{
                background: COLORS.bgSurface,
                borderRadius: 14,
                border: `1px solid ${COLORS.border}`,
                boxShadow: SHADOW_SM,
                overflow: "hidden",
              }}
            >
              {/* Table Header */}
              <div
                style={{
                  display: "grid",
                  gridTemplateColumns: "50px 2.2fr 1.2fr 1fr 1fr 1.1fr 1fr 1fr 60px",
                  background: COLORS.bgSurfaceElevated,
                  borderBottom: `1px solid ${COLORS.border}`,
                  padding: "11px 16px",
                  alignItems: "center",
                }}
              >
                {["", "PRODUCT", "CATEGORY", "BRAND", "PRICE", "STOCK", "VARIANTS", "STATUS", ""].map(
                  (col, cIdx) => (
                    <div
                      key={cIdx}
                      style={{
                        fontSize: 11,
                        fontWeight: 700,
                        textTransform: "uppercase",
                        letterSpacing: "0.6px",
                        color: COLORS.textMuted,
                      }}
                    >
                      {col}
                    </div>
                  )
                )}
              </div>

              {/* Table Rows */}
              {PRODUCT_ROWS.map((p, rIdx) => {
                const rowDelay = 8 + rIdx * 6;
                const rowOpacity = interpolate(Math.max(0, frame - rowDelay), [0, 10], [0, 1], {
                  extrapolateRight: "clamp",
                });

                return (
                  <div
                    key={p.id}
                    style={{
                      display: "grid",
                      gridTemplateColumns: "50px 2.2fr 1.2fr 1fr 1fr 1.1fr 1fr 1fr 60px",
                      padding: "10px 16px",
                      borderBottom: rIdx < PRODUCT_ROWS.length - 1 ? `1px solid ${COLORS.border}` : "none",
                      alignItems: "center",
                      opacity: rowOpacity,
                    }}
                  >
                    {/* Thumbnail */}
                    <div
                      style={{
                        width: 38,
                        height: 38,
                        borderRadius: 8,
                        background: COLORS.brandLight,
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "center",
                        fontSize: 20,
                        border: `1px solid ${COLORS.border}`,
                      }}
                    >
                      {p.emoji}
                    </div>

                    {/* Product Name */}
                    <div>
                      <div style={{ fontSize: 13.5, fontWeight: 600, color: COLORS.textPrimary }}>
                        {p.name}
                      </div>
                      <div style={{ fontSize: 11.5, color: COLORS.textMuted }}>{p.tags}</div>
                    </div>

                    {/* Category */}
                    <div style={{ fontSize: 13, color: COLORS.textSecondary }}>{p.category}</div>

                    {/* Brand */}
                    <div style={{ fontSize: 13, color: COLORS.textSecondary, fontWeight: 500 }}>
                      {p.brand}
                    </div>

                    {/* Price */}
                    <div style={{ fontSize: 14, fontWeight: 700, color: COLORS.textPrimary }}>
                      ₹{p.price}
                    </div>

                    {/* Stock Badge */}
                    <div>
                      <span
                        style={{
                          padding: "3px 10px",
                          borderRadius: 9999,
                          fontSize: 12,
                          fontWeight: 600,
                          background:
                            p.stockType === "green"
                              ? COLORS.successLight
                              : p.stockType === "amber"
                              ? COLORS.warningLight
                              : COLORS.dangerLight,
                          color:
                            p.stockType === "green"
                              ? "#047857"
                              : p.stockType === "amber"
                              ? "#92400E"
                              : "#DC2626",
                        }}
                      >
                        {p.stockStatus}
                      </span>
                    </div>

                    {/* Variants */}
                    <div style={{ fontSize: 13, color: COLORS.textSecondary }}>{p.variants}</div>

                    {/* Status Toggle */}
                    <div>
                      <div
                        style={{
                          width: 38,
                          height: 22,
                          borderRadius: 9999,
                          background: COLORS.brandPrimary,
                          position: "relative",
                        }}
                      >
                        <div
                          style={{
                            position: "absolute",
                            top: 3,
                            right: 3,
                            width: 16,
                            height: 16,
                            borderRadius: "50%",
                            background: "#ffffff",
                            boxShadow: "0 1px 3px rgba(0,0,0,0.2)",
                          }}
                        />
                      </div>
                    </div>

                    {/* Actions */}
                    <div style={{ display: "flex", gap: 8, color: COLORS.textMuted }}>
                      <FaEdit size={13} style={{ cursor: "pointer" }} />
                      <FaTrash size={12} style={{ cursor: "pointer" }} />
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </div>

      <NarrationBox text={NARRATION.products} delay={10} />
    </div>
  );
};
