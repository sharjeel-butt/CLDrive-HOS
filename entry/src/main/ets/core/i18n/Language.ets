export type LangCode =
  | 'en' | 'zh-Hans' | 'zh-Hant' | 'ar' | 'es' | 'ug' | 'bo' | 'lo'
    | 'ru' | 'ja' | 'ko' | 'ms' | 'fr' | 'th' | 'vi' | 'pt'
    | 'id' | 'de' | 'tr' | 'it' | 'my' | 'pl';

export interface LanguageOption {
  code: LangCode;
  englishName: string;
  nativeName: string;
  rtl: boolean;
  /**
   * True when the language has a translated Privacy Policy page
   * online. Unavailable languages are hidden from the picker so
   * the user is never routed to a policy they cannot read.
   */
  available: boolean;
}

export const LANGUAGES: LanguageOption[] = [
  { code: 'en',      englishName: 'English',                nativeName: 'English',              rtl: false, available: true  },
  { code: 'zh-Hans', englishName: 'Simplified Chinese',     nativeName: '简体中文',              rtl: false, available: true  },
  { code: 'zh-Hant', englishName: 'Traditional Chinese',    nativeName: '繁體中文',              rtl: false, available: false },
  { code: 'ar',      englishName: 'Arabic',                 nativeName: 'العربية',               rtl: true,  available: true  },
  { code: 'es',      englishName: 'Spanish',                nativeName: 'Español',              rtl: false, available: true  },
  { code: 'ug',      englishName: 'Uyghur',                 nativeName: 'ئۇيغۇرچە',             rtl: true,  available: false },
  { code: 'bo',      englishName: 'Tibetan',                nativeName: 'བོད་སྐད་',              rtl: false, available: false },
  { code: 'lo',      englishName: 'Lao',                    nativeName: 'ພາສາລາວ',              rtl: false, available: false },
  { code: 'ru',      englishName: 'Russian',                nativeName: 'Русский',              rtl: false, available: true  },
  { code: 'ja',      englishName: 'Japanese',               nativeName: '日本語',                rtl: false, available: false },
  { code: 'ko',      englishName: 'Korean',                 nativeName: '한국어',                rtl: false, available: false },
  { code: 'ms',      englishName: 'Malay',                  nativeName: 'Bahasa Melayu',        rtl: false, available: false },
  { code: 'fr',      englishName: 'French',                 nativeName: 'Français',             rtl: false, available: false },
  { code: 'th',      englishName: 'Thai',                   nativeName: 'ภาษาไทย',              rtl: false, available: false },
  { code: 'vi',      englishName: 'Vietnamese',             nativeName: 'Tiếng Việt',           rtl: false, available: false },
  { code: 'pt',      englishName: 'Portuguese (Portugal)',  nativeName: 'Português (Portugal)', rtl: false, available: false },
  { code: 'id',      englishName: 'Indonesian',             nativeName: 'Indonesia',            rtl: false, available: false },
  { code: 'de',      englishName: 'German',                 nativeName: 'Deutsch',              rtl: false, available: false },
  { code: 'tr',      englishName: 'Turkish',                nativeName: 'Türkçe',               rtl: false, available: false },
  { code: 'it',      englishName: 'Italian',                nativeName: 'Italiano',             rtl: false, available: false },
  { code: 'my',      englishName: 'Burmese',                nativeName: 'မြန်မာ',                rtl: false, available: false },
  { code: 'pl',      englishName: 'Polish',                 nativeName: 'Polski',               rtl: false, available: false }
];

/**
 * Return only the languages that have a translated Privacy Policy
 * page. This is what the pickers should render.
 */
export function availableLanguages(): LanguageOption[] {
  const out: LanguageOption[] = [];
  for (let i = 0; i < LANGUAGES.length; i++) {
    if (LANGUAGES[i].available) out.push(LANGUAGES[i]);
  }
  return out;
}

/**
 * Look up a language by code. Returns the English entry if the code
 * isn't found, so callers never receive null.
 */
export function languageByCode(code: string): LanguageOption {
  for (let i = 0; i < LANGUAGES.length; i++) {
    if (LANGUAGES[i].code === code) return LANGUAGES[i];
  }
  return LANGUAGES[0];
}