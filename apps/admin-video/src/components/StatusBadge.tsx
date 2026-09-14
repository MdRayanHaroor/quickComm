import React from "react";
import { useCurrentFrame, interpolate } from "remotion";
import { FONT } from "../design";

interface StatusBadgeProps {
  status: string;
  delay?: number;
  animate?: boolean;
}

interface BadgeStyle {
  bg: string;
  color: string;
  dotColor: string;
}

const BADGE_STYLES: Record<string, BadgeStyle> = {
  Delivered: { bg: "#ECFDF5", color: "#047857", dotColor: "#10B981" },
  "In Transit": { bg: "#EFF6FF", color: "#1D4ED8", dotColor: "#3B82F6" },
  Preparing: { bg: "#FFFBEB", color: "#92400E", dotColor: "#F59E0B" },
  Pending: { bg: "#F1F3F5", color: "#4A5568", dotColor: "#9CA3AF" },
  Confirmed: { bg: "#E8F8F2", color: "#158a5e", dotColor: "#1BA672" },
  Active: { bg: "#ECFDF5", color: "#047857", dotColor: "#10B981" },
  Break: { bg: "#FFFBEB", color: "#92400E", dotColor: "#F59E0B" },
  Cancelled: { bg: "#FEF2F2", color: "#DC2626", dotColor: "#EF4444" },
};

export const StatusBadge: React.FC<StatusBadgeProps> = ({
  status,
  delay = 0,
  animate = false,
}) => {
  const frame = useCurrentFrame();
  const adjustedFrame = Math.max(0, frame - delay);

  const STATUSES = ["Pending", "Preparing", "In Transit", "Delivered"];
  let displayStatus = status;

  if (animate) {
    const idx = Math.floor(adjustedFrame / 30) % STATUSES.length;
    displayStatus = STATUSES[idx];
  }

  const opacity = interpolate(adjustedFrame, [0, 10], [0, 1], {
    extrapolateRight: "clamp",
  });

  const style = BADGE_STYLES[displayStatus] || {
    bg: "#F1F3F5",
    color: "#4A5568",
    dotColor: "#9CA3AF",
  };

  return (
    <div
      style={{
        fontFamily: FONT,
        display: "inline-flex",
        alignItems: "center",
        gap: 6,
        padding: "3px 10px",
        borderRadius: 9999,
        background: style.bg,
        color: style.color,
        fontSize: 12,
        fontWeight: 600,
        opacity,
        whiteSpace: "nowrap",
      }}
    >
      <div
        style={{
          width: 6,
          height: 6,
          borderRadius: "50%",
          background: style.dotColor,
        }}
      />
      <span>{displayStatus}</span>
    </div>
  );
};
