export type LangCode =
  | 'en' | 'zh-Hans' | 'zh-Hant' | 'ar' | 'es' | 'ug' | 'bo' | 'lo'
    | 'ru' | 'ja' | 'ko' | 'ms' | 'fr' | 'th' | 'vi' | 'pt'
    | 'id' | 'de' | 'tr' | 'it' | 'my' | 'pl';

export interface LanguageOption {
  code: LangCode;
  englishName: string;
  nativeName: string;
  rtl: boolean;
}

export const LANGUAGES: LanguageOption[] = [
  { code: 'en',      englishName: 'English',                nativeName: 'English',              rtl: false },
  { code: 'zh-Hans', englishName: 'Simplified Chinese',     nativeName: '简体中文',              rtl: false },
  { code: 'zh-Hant', englishName: 'Traditional Chinese',    nativeName: '繁體中文',              rtl: false },
  { code: 'ar',      englishName: 'Arabic',                 nativeName: 'العربية',               rtl: true  },
  { code: 'es',      englishName: 'Spanish',                nativeName: 'Español',              rtl: false },
  { code: 'ug',      englishName: 'Uyghur',                 nativeName: 'ئۇيغۇرچە',             rtl: true  },
  { code: 'bo',      englishName: 'Tibetan',                nativeName: 'བོད་སྐད་',              rtl: false },
  { code: 'lo',      englishName: 'Lao',                    nativeName: 'ພາສາລາວ',              rtl: false },
  { code: 'ru',      englishName: 'Russian',                nativeName: 'Русский',              rtl: false },
  { code: 'ja',      englishName: 'Japanese',               nativeName: '日本語',                rtl: false },
  { code: 'ko',      englishName: 'Korean',                 nativeName: '한국어',                rtl: false },
  { code: 'ms',      englishName: 'Malay',                  nativeName: 'Bahasa Melayu',        rtl: false },
  { code: 'fr',      englishName: 'French',                 nativeName: 'Français',             rtl: false },
  { code: 'th',      englishName: 'Thai',                   nativeName: 'ภาษาไทย',              rtl: false },
  { code: 'vi',      englishName: 'Vietnamese',             nativeName: 'Tiếng Việt',           rtl: false },
  { code: 'pt',      englishName: 'Portuguese (Portugal)',  nativeName: 'Português (Portugal)', rtl: false },
  { code: 'id',      englishName: 'Indonesian',             nativeName: 'Indonesia',            rtl: false },
  { code: 'de',      englishName: 'German',                 nativeName: 'Deutsch',              rtl: false },
  { code: 'tr',      englishName: 'Turkish',                nativeName: 'Türkçe',               rtl: false },
  { code: 'it',      englishName: 'Italian',                nativeName: 'Italiano',             rtl: false },
  { code: 'my',      englishName: 'Burmese',                nativeName: 'မြန်မာ',                rtl: false },
  { code: 'pl',      englishName: 'Polish',                 nativeName: 'Polski',               rtl: false }
];

export function languageByCode(code: string): LanguageOption {
  for (let i = 0; i < LANGUAGES.length; i++) {
    if (LANGUAGES[i].code === code) return LANGUAGES[i];
  }
  return LANGUAGES[0];
}