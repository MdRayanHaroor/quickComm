import React from "react";
import { useCurrentFrame, interpolate, spring, useVideoConfig } from "remotion";
import { FaBolt } from "react-icons/fa";
import { COLORS, FONT, FONT_HEADING } from "../design";
import { NarrationBox } from "../components/NarrationBox";
import { NARRATION } from "../data/mockData";

export const IntroScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Background radial glow breathes in
  const glowScale = interpolate(frame, [0, 90], [0.6, 1.2]);
  const glowOpacity = interpolate(frame, [0, 30], [0, 0.8], { extrapolateRight: "clamp" });

  // Logo flies in from below with spring
  const logoY = spring({
    frame,
    fps,
    from: 60,
    to: 0,
    config: { damping: 13, stiffness: 100 },
    durationInFrames: 35,
  });
  const logoOpacity = interpolate(frame, [0, 20], [0, 1], { extrapolateRight: "clamp" });

  // Tagline fades in after logo
  const tagOpacity = interpolate(frame, [25, 45], [0, 1], { extrapolateRight: "clamp" });
  const tagY = interpolate(frame, [25, 45], [16, 0], { extrapolateRight: "clamp" });

  // Subtitle line
  const subOpacity = interpolate(frame, [45, 65], [0, 1], { extrapolateRight: "clamp" });

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
      {/* Animated radial background glow in brand green */}
      <div
        style={{
          position: "absolute",
          width: 800,
          height: 800,
          borderRadius: "50%",
          background: `radial-gradient(circle, rgba(27, 166, 114, 0.16) 0%, rgba(27, 166, 114, 0.04) 40%, transparent 70%)`,
          transform: `scale(${glowScale})`,
          opacity: glowOpacity,
          pointerEvents: "none",
        }}
      />

      {/* Grid lines subtle background */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          backgroundImage: `linear-gradient(${COLORS.border} 1px, transparent 1px), linear-gradient(90deg, ${COLORS.border} 1px, transparent 1px)`,
          backgroundSize: "48px 48px",
          opacity: 0.7,
        }}
      />

      {/* Logo container */}
      <div
        style={{
          transform: `translateY(${logoY}px)`,
          opacity: logoOpacity,
          display: "flex",
          alignItems: "center",
          gap: 20,
          marginBottom: 24,
        }}
      >
        {/* Brand Icon */}
        <div
          style={{
            width: 76,
            height: 76,
            borderRadius: 20,
            background: COLORS.brandPrimary,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            color: "#ffffff",
            fontSize: 38,
            boxShadow: "0 10px 30px rgba(27, 166, 114, 0.35)",
          }}
        >
          <FaBolt />
        </div>

        {/* Brand name */}
        <div>
          <div
            style={{
              fontFamily: FONT_HEADING,
              fontSize: 62,
              fontWeight: 800,
              color: COLORS.textPrimary,
              letterSpacing: "-1.5px",
              lineHeight: 1,
            }}
          >
            QuickComm
          </div>
          <div
            style={{
              fontSize: 14,
              fontWeight: 700,
              color: COLORS.brandPrimary,
              letterSpacing: "0.22em",
              textTransform: "uppercase",
              marginTop: 6,
            }}
          >
            Admin Portal
          </div>
        </div>
      </div>

      {/* Divider */}
      <div
        style={{
          width: interpolate(frame, [35, 60], [0, 420], { extrapolateRight: "clamp" }),
          height: 2,
          background: `linear-gradient(90deg, transparent, ${COLORS.brandPrimary}, transparent)`,
          marginBottom: 24,
        }}
      />

      {/* Tagline */}
      <div
        style={{
          opacity: tagOpacity,
          transform: `translateY(${tagY}px)`,
          fontFamily: FONT_HEADING,
          fontSize: 26,
          fontWeight: 600,
          color: COLORS.textSecondary,
          letterSpacing: "-0.3px",
          textAlign: "center",
        }}
      >
        Supermarket at Your Speed
      </div>

      {/* Subtitle badges */}
      <div
        style={{
          opacity: subOpacity,
          display: "flex",
          gap: 12,
          marginTop: 24,
        }}
      >
        {["Live Orders Pipeline", "Fleet & Live Map", "Smart Inventory", "Store Delivery Zones"].map((tag) => (
          <div
            key={tag}
            style={{
              padding: "7px 18px",
              borderRadius: 9999,
              background: COLORS.brandLight,
              border: `1px solid rgba(27, 166, 114, 0.35)`,
              fontSize: 12.5,
              fontWeight: 600,
              color: COLORS.brandDark,
              boxShadow: "0 2px 6px rgba(0, 0, 0, 0.04)",
            }}
          >
            {tag}
          </div>
        ))}
      </div>

      <NarrationBox text={NARRATION.intro} delay={15} />
    </div>
  );
};
