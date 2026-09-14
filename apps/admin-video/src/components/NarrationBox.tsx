import React from "react";
import { useCurrentFrame, interpolate, spring, useVideoConfig } from "remotion";
import { COLORS, FONT } from "../design";

interface NarrationBoxProps {
  text: string;
  delay?: number;
}

export const NarrationBox: React.FC<NarrationBoxProps> = ({ text, delay = 0 }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const adjustedFrame = Math.max(0, frame - delay);

  const words = text.split(" ");
  const visibleWords = Math.floor(adjustedFrame / 3);

  const slideY = spring({
    frame: adjustedFrame,
    fps,
    from: 25,
    to: 0,
    config: { damping: 18, stiffness: 120 },
    durationInFrames: 20,
  });

  const opacity = interpolate(adjustedFrame, [0, 15], [0, 1], { extrapolateRight: "clamp" });

  return (
    <div
      style={{
        fontFamily: FONT,
        position: "absolute",
        bottom: 24,
        left: "50%",
        transform: `translate(-50%, ${slideY}px)`,
        opacity,
        background: "rgba(255, 255, 255, 0.94)",
        backdropFilter: "blur(12px)",
        border: `1.5px solid ${COLORS.borderStrong}`,
        boxShadow: "0 8px 30px rgba(0, 0, 0, 0.08), 0 2px 8px rgba(0, 0, 0, 0.04)",
        borderRadius: 12,
        padding: "10px 24px",
        maxWidth: 820,
        textAlign: "center",
        zIndex: 100,
      }}
    >
      <div style={{ fontSize: 14, color: COLORS.textPrimary, lineHeight: 1.5, fontWeight: 500 }}>
        {words.map((word, i) => (
          <span
            key={i}
            style={{
              color: i < visibleWords ? COLORS.textPrimary : COLORS.textDisabled,
              fontWeight: i < visibleWords ? 600 : 400,
              marginRight: 5,
            }}
          >
            {word}
          </span>
        ))}
      </div>
      {/* Live Voice Indicator */}
      <div
        style={{
          position: "absolute",
          top: 8,
          right: 10,
          display: "flex",
          alignItems: "center",
          gap: 4,
        }}
      >
        <div
          style={{
            width: 6,
            height: 6,
            borderRadius: "50%",
            background: COLORS.brandPrimary,
            boxShadow: "0 0 6px rgba(27, 166, 114, 0.6)",
          }}
        />
      </div>
    </div>
  );
};
