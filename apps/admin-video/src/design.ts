// Shared design tokens matching actual apps/admin_panel/src/index.css (Blinkit-inspired light theme)
export const COLORS = {
  // Brand
  brandPrimary: "#1BA672",
  brandDark: "#158a5e",
  brandDarker: "#0f6e4a",
  brandLight: "#E8F8F2",
  brandLightHover: "#d4f3e8",

  // Compatibility aliases
  primary: "#1BA672",
  primaryLight: "#158a5e",
  primaryDark: "#0f6e4a",
  accent: "#1BA672",

  // Neutrals (Light theme source of truth)
  bgPage: "#F4F5F7",
  bgSurface: "#FFFFFF",
  bgSurfaceHover: "#F9FAFB",
  bgSurfaceElevated: "#F1F3F5",
  bgInput: "#F8F9FA",

  // Aliases
  bg: "#F4F5F7",
  surface: "#FFFFFF",
  surfaceAlt: "#F8F9FA",

  // Text
  textPrimary: "#1A1A2E",
  textSecondary: "#4A5568",
  textMuted: "#9CA3AF",
  textDisabled: "#C4C9D4",

  // Status
  danger: "#EF4444",
  dangerLight: "#FEF2F2",
  dangerDark: "#DC2626",
  warning: "#F59E0B",
  warningLight: "#FFFBEB",
  success: "#10B981",
  successLight: "#ECFDF5",
  info: "#3B82F6",
  infoLight: "#EFF6FF",
  purple: "#A855F7",
  purpleLight: "rgba(168, 85, 247, 0.15)",

  // Status aliases
  green: "#10B981",
  blue: "#3B82F6",
  amber: "#F59E0B",
  red: "#EF4444",
  slate: "#94A3B8",

  // Borders
  border: "#E2E8F0",
  borderStrong: "#CBD5E1",
  borderFocus: "#1BA672",
};

export const FONT = "'Inter', -apple-system, BlinkMacSystemFont, sans-serif";
export const FONT_HEADING = "'Plus Jakarta Sans', 'Inter', -apple-system, sans-serif";

export const SHADOW_SM = "0 1px 3px rgba(0, 0, 0, 0.08), 0 1px 2px rgba(0, 0, 0, 0.04)";
export const SHADOW_MD = "0 4px 12px rgba(0, 0, 0, 0.08), 0 2px 4px rgba(0, 0, 0, 0.04)";
export const SHADOW_LG = "0 10px 25px rgba(0, 0, 0, 0.10), 0 4px 10px rgba(0, 0, 0, 0.04)";
export const SHADOW = SHADOW_SM;
export const GLOW = "0 4px 20px rgba(27, 166, 114, 0.25)";
