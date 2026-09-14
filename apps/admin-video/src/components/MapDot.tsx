import React from "react";
import { useCurrentFrame, interpolate } from "remotion";
import { COLORS } from "../design";

interface MapDotProps {
  x: number; // % position
  y: number; // % position
  delay?: number;
  color?: string;
  label?: string;
  size?: number;
}

export const MapDot: React.FC<MapDotProps> = ({
  x,
  y,
  delay = 0,
  color = COLORS.primary,
  label,
  size = 14,
}) => {
  const frame = useCurrentFrame();
  const adjustedFrame = Math.max(0, frame - delay);

  const appear = interpolate(adjustedFrame, [0, 15], [0, 1], {
    extrapolateRight: "clamp",
  });

  // Pulsing ring
  const pulseScale = interpolate(
    (adjustedFrame % 60),
    [0, 30, 60],
    [1, 2.5, 1],
    { extrapolateRight: "clamp" }
  );
  const pulseOpacity = interpolate(
    (adjustedFrame % 60),
    [0, 30, 60],
    [0.6, 0, 0.6],
    { extrapolateRight: "clamp" }
  );

  return (
    <div
      style={{
        position: "absolute",
        left: `${x}%`,
        top: `${y}%`,
        transform: "translate(-50%, -50%)",
        opacity: appear,
      }}
    >
      {/* Pulse ring */}
      <div
        style={{
          position: "absolute",
          width: size,
          height: size,
          borderRadius: "50%",
          border: `2px solid ${color}`,
          top: "50%",
          left: "50%",
          transform: `translate(-50%, -50%) scale(${pulseScale})`,
          opacity: pulseOpacity,
        }}
      />

      {/* Core dot */}
      <div
        style={{
          width: size,
          height: size,
          borderRadius: "50%",
          background: color,
          boxShadow: `0 0 10px ${color}`,
          border: "2px solid white",
          position: "relative",
          zIndex: 2,
        }}
      />

      {/* Label */}
      {label && (
        <div
          style={{
            position: "absolute",
            top: "100%",
            left: "50%",
            transform: "translateX(-50%)",
            marginTop: 4,
            fontSize: 9,
            fontWeight: 700,
            color: "white",
            background: "rgba(0,0,0,0.7)",
            padding: "2px 6px",
            borderRadius: 4,
            whiteSpace: "nowrap",
          }}
        >
          {label}
        </div>
      )}
    </div>
  );
};
