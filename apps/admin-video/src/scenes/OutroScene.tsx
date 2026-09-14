import React from "react";
import { useCurrentFrame, interpolate, spring, useVideoConfig } from "remotion";
import {
  FaBolt, FaChartPie, FaShoppingBag, FaBoxOpen,
  FaMapMarkedAlt, FaWarehouse, FaCog
} from "react-icons/fa";
import { COLORS, FONT, FONT_HEADING } from "../design";
import { NarrationBox } from "../components/NarrationBox";
import { NARRATION } from "../data/mockData";

const FEATURES = [
  { icon: <FaChartPie size={13} />, label: "Real-time Dashboard" },
  { icon: <FaShoppingBag size={13} />, label: "Live Order Pipeline" },
  { icon: <FaBoxOpen size={13} />, label: "Product Catalogue" },
  { icon: <FaMapMarkedAlt size={13} />, label: "Fleet & Map Tracking" },
  { icon: <FaWarehouse size={13} />, label: "Inventory Health" },
  { icon: <FaCog size={13} />, label: "Store Delivery Zones" },
];

export const OutroScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Logo pops in
  const logoScale = spring({
    frame,
    fps,
    from: 0.7,
    to: 1,
    config: { damping: 14, stiffness: 120 },
    durationInFrames: 28,
  });
  const logoOpacity = interpolate(frame, [0, 18], [0, 1], { extrapolateRight: "clamp" });

  // Main headline
  const headlineOpacity = interpolate(frame, [20, 40], [0, 1], { extrapolateRight: "clamp" });
  const headlineY = interpolate(frame, [20, 40], [20, 0], { extrapolateRight: "clamp" });

  // CTA button
  const ctaOpacity = interpolate(frame, [45, 65], [0, 1], { extrapolateRight: "clamp" });
  const ctaScale = spring({
    frame: Math.max(0, frame - 45),
    fps,
    from: 0.85,
    to: 1,
    config: { damping: 14, stiffness: 140 },
    durationInFrames: 25,
  });

  const pulseLine = interpolate(frame, [50, 80], [0, 1], { extrapolateRight: "clamp" });

  return (
    <div
      style={{
        width: "100%",
        height: "100%",
        background: COLORS.bgPage,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        fontFamily: FONT,
        position: "relative",
        overflow: "hidden",
      }}
    >
      {/* Background glow in soft brand green */}
      <div
        style={{
          position: "absolute",
          width: 800,
          height: 800,
          borderRadius: "50%",
          background: `radial-gradient(circle, rgba(27, 166, 114, 0.14) 0%, rgba(27, 166, 114, 0.03) 45%, transparent 70%)`,
          pointerEvents: "none",
        }}
      />

      {/* Grid */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          backgroundImage: `linear-gradient(${COLORS.border} 1px, transparent 1px), linear-gradient(90deg, ${COLORS.border} 1px, transparent 1px)`,
          backgroundSize: "48px 48px",
          opacity: 0.6,
        }}
      />

      {/* Logo */}
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 16,
          marginBottom: 20,
          opacity: logoOpacity,
          transform: `scale(${logoScale})`,
        }}
      >
        <div
          style={{
            width: 68,
            height: 68,
            borderRadius: 18,
            background: COLORS.brandPrimary,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            color: "#ffffff",
            fontSize: 34,
            boxShadow: "0 8px 24px rgba(27, 166, 114, 0.35)",
          }}
        >
          <FaBolt />
        </div>
        <div
          style={{
            fontFamily: FONT_HEADING,
            fontSize: 54,
            fontWeight: 800,
            color: COLORS.textPrimary,
            letterSpacing: "-1.5px",
          }}
        >
          QuickComm
        </div>
      </div>

      {/* Headline */}
      <div
        style={{
          opacity: headlineOpacity,
          transform: `translateY(${headlineY}px)`,
          textAlign: "center",
          marginBottom: 10,
        }}
      >
        <div
          style={{
            fontFamily: FONT_HEADING,
            fontSize: 32,
            fontWeight: 600,
            color: COLORS.textPrimary,
            lineHeight: 1.3,
          }}
        >
          Manage everything from{" "}
          <span
            style={{
              fontWeight: 800,
              color: COLORS.brandPrimary,
            }}
          >
            one place.
          </span>
        </div>
        <div
          style={{
            fontSize: 16,
            color: COLORS.textSecondary,
            marginTop: 8,
            fontWeight: 500,
          }}
        >
          Deliver faster. Grow smarter.
        </div>
      </div>

      {/* Animated divider */}
      <div
        style={{
          width: `${pulseLine * 400}px`,
          height: 2,
          background: `linear-gradient(90deg, transparent, ${COLORS.brandPrimary}, transparent)`,
          marginBottom: 26,
        }}
      />

      {/* Feature pills */}
      <div
        style={{
          display: "flex",
          flexWrap: "wrap",
          gap: 10,
          justifyContent: "center",
          maxWidth: 640,
          marginBottom: 32,
        }}
      >
        {FEATURES.map((f, i) => {
          const pillOpacity = interpolate(Math.max(0, frame - 50 - i * 4), [0, 12], [0, 1], {
            extrapolateRight: "clamp",
          });
          const pillY = interpolate(Math.max(0, frame - 50 - i * 4), [0, 12], [10, 0], {
            extrapolateRight: "clamp",
          });
          return (
            <div
              key={f.label}
              style={{
                display: "flex",
                alignItems: "center",
                gap: 7,
                padding: "8px 16px",
                borderRadius: 9999,
                background: COLORS.brandLight,
                border: `1px solid rgba(27, 166, 114, 0.3)`,
                opacity: pillOpacity,
                transform: `translateY(${pillY}px)`,
                boxShadow: "0 2px 6px rgba(0, 0, 0, 0.03)",
              }}
            >
              <span style={{ color: COLORS.brandPrimary, display: "flex", alignItems: "center" }}>
                {f.icon}
              </span>
              <span style={{ fontSize: 12.5, fontWeight: 600, color: COLORS.brandDark }}>
                {f.label}
              </span>
            </div>
          );
        })}
      </div>

      {/* CTA button */}
      <div
        style={{
          opacity: ctaOpacity,
          transform: `scale(${ctaScale})`,
          padding: "14px 38px",
          borderRadius: 9999,
          background: COLORS.brandPrimary,
          fontSize: 16,
          fontWeight: 700,
          color: "white",
          letterSpacing: "0.02em",
          boxShadow: "0 8px 25px rgba(27, 166, 114, 0.4)",
        }}
      >
        Get Started with QuickComm →
      </div>

      <NarrationBox text={NARRATION.outro} delay={15} />
    </div>
  );
};
