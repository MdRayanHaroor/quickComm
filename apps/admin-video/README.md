# QuickComm Admin Panel — Demo Video

A programmatic explainer video built with [Remotion](https://www.remotion.dev/) — 92 seconds, 1920×1080, 30fps.

## 🚀 Quick Start

```bash
cd apps/admin-video
npm install
npm run dev          # Opens Remotion Studio at http://localhost:3000
```

## 📹 Render to MP4

```bash
# Fast test render (first 30 frames / 1s preview)
npm run render:test

# Standard quality (full video, H.264)
npm run render

# High quality (for presentations, CRF 16)
npm run render:hq

# Custom frame range (e.g., render only Intro + Dashboard: frames 0 to 660)
npx remotion render src/index.tsx AdminPanelVideo out/preview.mp4 --frames=0-660
```

Output: `out/quickcomm-admin-demo.mp4` (or `out/test.mp4`)

## 🎬 Scene Breakdown

| Scene | Time | Content |
|---|---|---|
| Intro | 0–5s | Logo fly-in, tagline, feature badges |
| Dashboard | 5–22s | Stat cards count-up, bar chart, donut ring, activity feed |
| Orders | 22–37s | Order table stagger-in, status badges, In Transit highlight |
| Products | 37–52s | Product grid, stock bar animations, low-stock alerts |
| Fleet | 52–67s | Map with pulsing rider dots, route lines, rider list |
| Settings | 67–80s | Delivery zone toggles (Zone C animates ON), store hours |
| Outro | 80–92s | CTA, feature pills, "Manage everything from one place" |

## 🔊 Audio (TTS + Background Music)

The video uses karaoke-style caption overlays (`NarrationBox`) to simulate TTS.

### To add real TTS narration:
1. Generate MP3 files for each scene using a TTS service (ElevenLabs, Google TTS, etc.)
2. Place them in `src/audio/` as `intro.mp3`, `dashboard.mp3`, etc.
3. Add `<Audio src={staticFile("audio/intro.mp3")} />` inside each scene component

### To add background music:
Add to `AdminPanelVideo.tsx`:
```tsx
import { Audio, staticFile } from "remotion";
// Inside AdminPanelVideo:
<Audio src={staticFile("audio/bg-music.mp3")} volume={0.15} />
```

## 🏗️ Project Structure

```
src/
├── Root.tsx                    # Registers compositions
├── AdminPanelVideo.tsx         # Scene orchestration with <Sequence>
├── design.ts                   # Color tokens, fonts, shadows
├── data/mockData.ts            # All mock data + TTS scripts
├── components/
│   ├── AnimatedCard.tsx        # Stat card with count-up
│   ├── AnimatedBarChart.tsx    # Bar chart with staggered growth
│   ├── StatusBadge.tsx         # Order status pill
│   ├── MapDot.tsx              # Pulsing GPS dot
│   ├── Sidebar.tsx             # Navigation sidebar
│   └── NarrationBox.tsx        # Karaoke-style captions
└── scenes/
    ├── IntroScene.tsx
    ├── DashboardScene.tsx
    ├── OrdersScene.tsx
    ├── ProductsScene.tsx
    ├── FleetScene.tsx
    ├── SettingsScene.tsx
    └── OutroScene.tsx
```

## 📦 Tech Stack

- **Remotion 4** — React → Video
- **TypeScript** — Type-safe components
- **Remotion Studio** — Live preview browser UI
