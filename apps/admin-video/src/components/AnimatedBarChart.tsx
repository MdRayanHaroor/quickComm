import React from "react";
import { useCurrentFrame, interpolate } from "remotion";
import { COLORS, FONT, FONT_HEADING, SHADOW_SM } from "../design";

interface BarChartProps {
  data: number[];
  labels: string[];
  delay?: number;
  height?: number;
}

export const AnimatedBarChart: React.FC<BarChartProps> = ({
  data,
  labels,
  delay = 0,
  height = 160,
}) => {
  const frame = useCurrentFrame();
  const adjustedFrame = Math.max(0, frame - delay);
  const maxValue = Math.max(...data);

  const chartOpacity = interpolate(adjustedFrame, [0, 15], [0, 1], {
    extrapolateRight: "clamp",
  });

  return (
    <div
      style={{
        fontFamily: FONT,
        opacity: chartOpacity,
        padding: "20px 24px",
        background: COLORS.bgSurface,
        borderRadius: 14,
        border: `1px solid ${COLORS.border}`,
        boxShadow: SHADOW_SM,
        boxSizing: "border-box",
      }}
    >
      <div
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          marginBottom: 16,
        }}
      >
        <div>
          <h3
            style={{
              margin: 0,
              fontFamily: FONT_HEADING,
              fontSize: 15,
              fontWeight: 700,
              color: COLORS.textPrimary,
            }}
          >
            Sales Activity Trend
          </h3>
          <p style={{ margin: "2px 0 0", fontSize: 12, color: COLORS.textMuted }}>
            Daily Gross Merchandise Value over the last 7 days
          </p>
        </div>
        <div style={{ display: "flex", gap: 16, fontSize: 12 }}>
          <span
            style={{
              display: "flex",
              alignItems: "center",
              gap: 6,
              color: COLORS.brandPrimary,
              fontWeight: 600,
            }}
          >
            <span
              style={{
                width: 10,
                height: 10,
                borderRadius: 2,
                background: COLORS.brandPrimary,
              }}
            />
            Sales (₹)
          </span>
        </div>
      </div>

      {/* Bars container */}
      <div
        style={{
          display: "flex",
          alignItems: "flex-end",
          gap: 14,
          height,
          borderBottom: `1px solid ${COLORS.border}`,
          paddingBottom: 4,
          position: "relative",
        }}
      >
        {/* Subtle horizontal grid guide */}
        <div
          style={{
            position: "absolute",
            top: "50%",
            left: 0,
            right: 0,
            borderTop: `1px dashed ${COLORS.border}`,
            pointerEvents: "none",
          }}
        />

        {data.map((val, i) => {
          const barDelay = i * 4;
          const barFrame = Math.max(0, adjustedFrame - 5 - barDelay);
          const barHeight = interpolate(
            barFrame,
            [0, 25],
            [0, (val / maxValue) * (height - 24)],
            { extrapolateRight: "clamp" }
          );

          const isHighest = val === maxValue;

          return (
            <div
              key={i}
              style={{
                flex: 1,
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                gap: 6,
                zIndex: 1,
              }}
            >
              {/* Value on top */}
              <div
                style={{
                  fontSize: 10,
                  color: isHighest ? COLORS.brandPrimary : COLORS.textMuted,
                  fontWeight: isHighest ? 700 : 500,
                  opacity: interpolate(barFrame, [18, 25], [0, 1], {
                    extrapolateRight: "clamp",
                  }),
                }}
              >
                ₹{(val / 1000).toFixed(0)}k
              </div>

              {/* Bar */}
              <div
                style={{
                  width: "100%",
                  height: barHeight,
                  background: isHighest
                    ? `linear-gradient(180deg, ${COLORS.brandPrimary}, ${COLORS.brandDark})`
                    : `linear-gradient(180deg, rgba(27, 166, 114, 0.4), rgba(27, 166, 114, 0.15))`,
                  borderRadius: "5px 5px 0 0",
                  alignSelf: "flex-end",
                }}
              />

              {/* Day Label */}
              <div
                style={{
                  fontSize: 11,
                  color: isHighest ? COLORS.textPrimary : COLORS.textMuted,
                  fontWeight: isHighest ? 700 : 500,
                  marginTop: 2,
                }}
              >
                {labels[i]}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};
