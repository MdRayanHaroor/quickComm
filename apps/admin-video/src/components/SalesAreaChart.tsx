import React from "react";
import { useCurrentFrame, interpolate } from "remotion";
import { COLORS, FONT, FONT_HEADING, SHADOW_SM } from "../design";

interface SalesAreaChartProps {
  delay?: number;
}

const DATA_POINTS = [
  { date: "Sep 7", value: 14200 },
  { date: "Sep 8", value: 18900 },
  { date: "Sep 9", value: 22400 },
  { date: "Sep 10", value: 20100 },
  { date: "Sep 11", value: 27500 },
  { date: "Sep 12", value: 41800 },
  { date: "Sep 13", value: 26300 },
];

export const SalesAreaChart: React.FC<SalesAreaChartProps> = ({ delay = 0 }) => {
  const frame = useCurrentFrame();
  const adjustedFrame = Math.max(0, frame - delay);

  const opacity = interpolate(adjustedFrame, [0, 15], [0, 1], { extrapolateRight: "clamp" });
  const progress = interpolate(adjustedFrame, [10, 45], [0, 1], { extrapolateRight: "clamp" });

  // 7 data coordinates mapped inside viewBox 0 0 1000 220
  // Left margin 50, right margin 960, top 35, bottom 190
  const points = [
    { x: 50, y: 135 },  // Sep 7 (~14k)
    { x: 200, y: 118 }, // Sep 8 (~19k)
    { x: 350, y: 104 }, // Sep 9 (~22k)
    { x: 500, y: 112 }, // Sep 10 (~20k)
    { x: 650, y: 84 },  // Sep 11 (~27k)
    { x: 800, y: 35 },  // Sep 12 (~42k)
    { x: 960, y: 89 },  // Sep 13 (~26k)
  ];

  // Animated path calculation - safe from undefined indices
  const currentMaxX = 50 + (960 - 50) * progress;
  const visiblePoints: { x: number; y: number }[] = [];

  for (let i = 0; i < points.length; i++) {
    if (points[i].x <= currentMaxX) {
      visiblePoints.push(points[i]);
    } else {
      if (i > 0) {
        const prev = points[i - 1];
        const curr = points[i];
        const span = curr.x - prev.x;
        if (span > 0) {
          const t = Math.max(0, Math.min(1, (currentMaxX - prev.x) / span));
          visiblePoints.push({
            x: currentMaxX,
            y: prev.y + (curr.y - prev.y) * t,
          });
        }
      }
      break;
    }
  }

  if (visiblePoints.length === 0) {
    visiblePoints.push(points[0]);
  }

  // Generate smooth SVG curve path
  const curvePath = visiblePoints.reduce((acc, pt, i, arr) => {
    if (i === 0) return `M ${pt.x},${pt.y}`;
    const prev = arr[i - 1];
    const cx = (prev.x + pt.x) / 2;
    return `${acc} C ${cx},${prev.y} ${cx},${pt.y} ${pt.x},${pt.y}`;
  }, "");

  const lastPoint = visiblePoints[visiblePoints.length - 1];
  const areaPath = `${curvePath} L ${lastPoint.x},190 L 50,190 Z`;

  return (
    <div
      style={{
        fontFamily: FONT,
        opacity,
        background: COLORS.bgSurface,
        borderRadius: 14,
        border: `1px solid ${COLORS.border}`,
        padding: "20px 24px 16px",
        boxShadow: SHADOW_SM,
        boxSizing: "border-box",
      }}
    >
      {/* Header */}
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

        <div style={{ display: "flex", alignItems: "center", gap: 6, fontSize: 12 }}>
          <span
            style={{
              width: 10,
              height: 10,
              borderRadius: 2,
              background: COLORS.brandPrimary,
            }}
          />
          <span style={{ color: COLORS.brandPrimary, fontWeight: 600 }}>Sales (₹)</span>
        </div>
      </div>

      {/* SVG Smooth Area Chart */}
      <div style={{ width: "100%", height: 180, position: "relative" }}>
        <svg
          viewBox="0 0 1000 220"
          style={{ width: "100%", height: "100%", overflow: "visible" }}
          preserveAspectRatio="none"
        >
          <defs>
            <linearGradient id="actualSalesTrendGrad" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor={COLORS.brandPrimary} stopOpacity={0.35} />
              <stop offset="95%" stopColor={COLORS.brandPrimary} stopOpacity={0.0} />
            </linearGradient>
          </defs>

          {/* Dotted Grid Lines matching actual Recharts */}
          <line x1="45" y1="35" x2="980" y2="35" stroke={COLORS.border} strokeDasharray="3 3" />
          <line x1="45" y1="74" x2="980" y2="74" stroke={COLORS.border} strokeDasharray="3 3" />
          <line x1="45" y1="113" x2="980" y2="113" stroke={COLORS.border} strokeDasharray="3 3" />
          <line x1="45" y1="151" x2="980" y2="151" stroke={COLORS.border} strokeDasharray="3 3" />
          <line x1="45" y1="190" x2="980" y2="190" stroke={COLORS.border} />

          {/* Y Axis Labels */}
          <text x="38" y="40" textAnchor="end" fill={COLORS.textMuted} fontSize="13" fontFamily={FONT}>40k</text>
          <text x="38" y="78" textAnchor="end" fill={COLORS.textMuted} fontSize="13" fontFamily={FONT}>30k</text>
          <text x="38" y="117" textAnchor="end" fill={COLORS.textMuted} fontSize="13" fontFamily={FONT}>20k</text>
          <text x="38" y="155" textAnchor="end" fill={COLORS.textMuted} fontSize="13" fontFamily={FONT}>10k</text>
          <text x="38" y="194" textAnchor="end" fill={COLORS.textMuted} fontSize="13" fontFamily={FONT}>0</text>

          {/* Area Fill */}
          <path d={areaPath} fill="url(#actualSalesTrendGrad)" />

          {/* Curved Line Stroke */}
          <path d={curvePath} fill="none" stroke={COLORS.brandPrimary} strokeWidth="3" strokeLinecap="round" />

          {/* X Axis Labels */}
          {DATA_POINTS.map((d, i) => (
            <text
              key={d.date}
              x={points[i].x}
              y="212"
              textAnchor="middle"
              fill={COLORS.textMuted}
              fontSize="13"
              fontFamily={FONT}
            >
              {d.date}
            </text>
          ))}
        </svg>
      </div>
    </div>
  );
};
