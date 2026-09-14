import React from "react";
import { AbsoluteFill, Sequence, useCurrentFrame, interpolate, Audio, staticFile } from "remotion";
import { IntroScene } from "./scenes/IntroScene";
import { DashboardScene } from "./scenes/DashboardScene";
import { OrdersScene } from "./scenes/OrdersScene";
import { ProductsScene } from "./scenes/ProductsScene";
import { FleetScene } from "./scenes/FleetScene";
import { SettingsScene } from "./scenes/SettingsScene";
import { OutroScene } from "./scenes/OutroScene";
import { COLORS } from "./design";

// ── Scene timing (at 30fps) ─────────────────────────────────
// Scene 1 – Intro       :   0s –  9s  (0   – 270 frames)
// Scene 2 – Dashboard   :   9s – 26s  (270 – 780 frames)
// Scene 3 – Orders      :  26s – 41s  (780 – 1230 frames)
// Scene 4 – Products    :  41s – 56s  (1230– 1680 frames)
// Scene 5 – Fleet       :  56s – 71s  (1680– 2130 frames)
// Scene 6 – Settings    :  71s – 84s  (2130– 2520 frames)
// Scene 7 – Outro       :  84s – 96s  (2520– 2880 frames)
// Total: 96 seconds / 2880 frames
// ─────────────────────────────────────────────────────────────

const TRANSITION_FRAMES = 12; // cross-fade duration between scenes

/**
 * Scene-level cross-fade wrapper.
 * Fades in from 0→1 over TRANSITION_FRAMES at the start of each sequence.
 */
const SceneFade: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [0, TRANSITION_FRAMES], [0, 1], {
    extrapolateRight: "clamp",
  });
  return (
    <AbsoluteFill style={{ opacity }}>
      {children}
    </AbsoluteFill>
  );
};

export const AdminPanelVideo: React.FC = () => {
  return (
    <AbsoluteFill style={{ backgroundColor: COLORS.bgPage }}>

      {/* ── Background Music Bed (Gentle warm ambient pad at 12% volume) ── */}
      <Audio
        src={staticFile("audio/bg_music.wav")}
        loop
        volume={(f) =>
          interpolate(f, [0, 30, 2800, 2880], [0, 0.12, 0.12, 0], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          })
        }
      />

      {/* ── Scene 1: Intro (0 – 270 frames / 9.0s) ── */}
      <Sequence from={0} durationInFrames={270}>
        <SceneFade>
          <IntroScene />
        </SceneFade>
        <Sequence from={15}>
          <Audio src={staticFile("audio/scene_1_intro.mp3")} volume={1.0} />
        </Sequence>
      </Sequence>

      {/* ── Scene 2: Dashboard (270 – 780 frames / 17.0s) ── */}
      <Sequence from={270} durationInFrames={510}>
        <SceneFade>
          <DashboardScene />
        </SceneFade>
        <Sequence from={15}>
          <Audio src={staticFile("audio/scene_2_dashboard.mp3")} volume={1.0} />
        </Sequence>
      </Sequence>

      {/* ── Scene 3: Orders (780 – 1230 frames / 15.0s) ── */}
      <Sequence from={780} durationInFrames={450}>
        <SceneFade>
          <OrdersScene />
        </SceneFade>
        <Sequence from={15}>
          <Audio src={staticFile("audio/scene_3_orders.mp3")} volume={1.0} />
        </Sequence>
      </Sequence>

      {/* ── Scene 4: Products & Inventory (1230 – 1680 frames / 15.0s) ── */}
      <Sequence from={1230} durationInFrames={450}>
        <SceneFade>
          <ProductsScene />
        </SceneFade>
        <Sequence from={15}>
          <Audio src={staticFile("audio/scene_4_products.mp3")} volume={1.0} />
        </Sequence>
      </Sequence>

      {/* ── Scene 5: Fleet Management (1680 – 2130 frames / 15.0s) ── */}
      <Sequence from={1680} durationInFrames={450}>
        <SceneFade>
          <FleetScene />
        </SceneFade>
        <Sequence from={15}>
          <Audio src={staticFile("audio/scene_5_fleet.mp3")} volume={1.0} />
        </Sequence>
      </Sequence>

      {/* ── Scene 6: Settings (2130 – 2520 frames / 13.0s) ── */}
      <Sequence from={2130} durationInFrames={390}>
        <SceneFade>
          <SettingsScene />
        </SceneFade>
        <Sequence from={15}>
          <Audio src={staticFile("audio/scene_6_settings.mp3")} volume={1.0} />
        </Sequence>
      </Sequence>

      {/* ── Scene 7: Outro (2520 – 2880 frames / 12.0s) ── */}
      <Sequence from={2520} durationInFrames={360}>
        <SceneFade>
          <OutroScene />
        </SceneFade>
        <Sequence from={15}>
          <Audio src={staticFile("audio/scene_7_outro.mp3")} volume={1.0} />
        </Sequence>
      </Sequence>

    </AbsoluteFill>
  );
};
