export interface ThemeColors {
  // Backgrounds
  background: string;
  surface: string;
  surfaceElevated: string;
  surfaceSubtle: string;

  // Text
  textPrimary: string;
  textSecondary: string;
  textTertiary: string;
  textInverse: string;

  // Accent
  primary: string;
  primaryDark: string;
  primarySoft: string;
  primaryContrast: string;

  // Semantic
  success: string;
  successSoft: string;
  error: string;
  errorSoft: string;
  warning: string;
  warningSoft: string;

  // Lines
  divider: string;
  border: string;
  borderSubtle: string;

  // Overlays
  overlay: string;
  overlayHeavy: string;

  // Chips / subtle fills
  chipBg: string;
  chipSelectedBg: string;

  // Misc
  isDark: boolean;
}

export const LIGHT_THEME: ThemeColors = {
  background: '#F8F9FB',
  surface: '#FFFFFF',
  surfaceElevated: '#FFFFFF',
  surfaceSubtle: '#F1F4F8',

  textPrimary: '#0B1221',
  textSecondary: '#5F6B7C',
  textTertiary: '#8A94A6',
  textInverse: '#FFFFFF',

  primary: '#0A5BD3',
  primaryDark: '#084AB3',
  primarySoft: '#E6F0FD',
  primaryContrast: '#FFFFFF',

  success: '#1E8E3E',
  successSoft: '#E6F4EA',
  error: '#D93025',
  errorSoft: '#FCE8E6',
  warning: '#F29900',
  warningSoft: '#FEF7E0',

  divider: '#E8ECF1',
  border: '#D9DFE7',
  borderSubtle: '#EEF1F5',

  overlay: '#66000000',
  overlayHeavy: '#99000000',

  chipBg: '#F1F4F8',
  chipSelectedBg: '#E6F0FD',

  isDark: false
};

export const DARK_THEME: ThemeColors = {
  background: '#0E1420',
  surface: '#1A2130',
  surfaceElevated: '#232B3D',
  surfaceSubtle: '#151B28',

  textPrimary: '#E8ECF2',
  textSecondary: '#A0A9B8',
  textTertiary: '#6B7688',
  textInverse: '#0B1221',

  primary: '#4A9EFF',
  primaryDark: '#2B7FDD',
  primarySoft: '#1B2B44',
  primaryContrast: '#FFFFFF',

  success: '#5BB974',
  successSoft: '#1B3324',
  error: '#F28B82',
  errorSoft: '#3A1F1D',
  warning: '#FDD663',
  warningSoft: '#3A2E10',

  divider: '#2A3444',
  border: '#323C4D',
  borderSubtle: '#232B3D',

  overlay: '#99000000',
  overlayHeavy: '#CC000000',

  chipBg: '#232B3D',
  chipSelectedBg: '#1B2B44',

  isDark: true
};