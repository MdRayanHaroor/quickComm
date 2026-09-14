import React from "react";
import { useCurrentFrame, interpolate, spring, useVideoConfig } from "remotion";
import { COLORS, FONT, FONT_HEADING, SHADOW_SM } from "../design";

interface AnimatedCardProps {
  label: string;
  value: number;
  prefix?: string;
  suffix?: string;
  icon: React.ReactNode;
  iconBg?: string;
  iconColor?: string;
  subtext?: string;
  subtextColor?: string;
  delay?: number;
}

export const AnimatedCard: React.FC<AnimatedCardProps> = ({
  label,
  value,
  prefix = "",
  suffix = "",
  icon,
  iconBg = COLORS.brandLight,
  iconColor = COLORS.brandPrimary,
  subtext = "",
  subtextColor = COLORS.textMuted,
  delay = 0,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const adjustedFrame = Math.max(0, frame - delay);

  const slideY = spring({
    frame: adjustedFrame,
    fps,
    from: 30,
    to: 0,
    config: { damping: 15, stiffness: 120 },
    durationInFrames: 22,
  });

  const opacity = interpolate(adjustedFrame, [0, 15], [0, 1], {
    extrapolateRight: "clamp",
  });

  const countedValue = interpolate(adjustedFrame, [5, 50], [0, value], {
    extrapolateRight: "clamp",
  });

  const formattedValue =
    value > 999
      ? Math.floor(countedValue).toLocaleString("en-IN")
      : value % 1 !== 0
      ? countedValue.toFixed(1)
      : Math.floor(countedValue).toString();

  return (
    <div
      style={{
        fontFamily: FONT,
        transform: `translateY(${slideY}px)`,
        opacity,
        background: COLORS.bgSurface,
        borderRadius: 14,
        padding: "13px 14px",
        border: `1px solid ${COLORS.border}`,
        boxShadow: SHADOW_SM,
        flex: 1,
        minWidth: 0,
        display: "flex",
        flexDirection: "column",
        justifyContent: "space-between",
        minHeight: 102,
        boxSizing: "border-box",
      }}
    >
      <div
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          marginBottom: 8,
          gap: 6,
        }}
      >
        <span
          style={{
            fontSize: 11,
            fontWeight: 600,
            color: COLORS.textSecondary,
            whiteSpace: "nowrap",
            overflow: "hidden",
            textOverflow: "ellipsis",
          }}
        >
          {label}
        </span>
        <div
          style={{
            width: 26,
            height: 26,
            borderRadius: 6,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            background: iconBg,
            color: iconColor,
            fontSize: 12,
            flexShrink: 0,
          }}
        >
          {icon}
        </div>
      </div>

      <div>
        <div
          style={{
            fontFamily: FONT_HEADING,
            fontSize: 22,
            fontWeight: 800,
            color: COLORS.textPrimary,
            lineHeight: 1.15,
          }}
        >
          {prefix}
          {formattedValue}
          {suffix}
        </div>
        {subtext && (
          <div
            style={{
              fontSize: 11,
              color: subtextColor,
              marginTop: 4,
              fontWeight: 500,
              whiteSpace: "nowrap",
              overflow: "hidden",
              textOverflow: "ellipsis",
            }}
          >
            {subtext}
          </div>
        )}
      </div>
    </div>
  );
};
