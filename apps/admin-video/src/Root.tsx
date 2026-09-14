import React from "react";
import { Composition } from "remotion";
import { AdminPanelVideo } from "./AdminPanelVideo";

// Total frames = 2880 @ 30fps = 96 seconds
const TOTAL_FRAMES = 2880;
const FPS = 30;
const WIDTH = 1920;
const HEIGHT = 1080;

export const RemotionRoot: React.FC = () => {
  return (
    <>
      {/* Full demo video — 1920×1080, 30fps, 92 seconds */}
      <Composition
        id="AdminPanelVideo"
        component={AdminPanelVideo}
        durationInFrames={TOTAL_FRAMES}
        fps={FPS}
        width={WIDTH}
        height={HEIGHT}
      />
    </>
  );
};
