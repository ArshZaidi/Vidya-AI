export const LANGUAGES = [
  { code: 'en', label: 'EN',   name: 'English' },
  { code: 'hi', label: 'हिं',  name: 'हिन्दी' },
  { code: 'bn', label: 'বাং',  name: 'বাংলা' },
  { code: 'mr', label: 'मरा',  name: 'मराठी' },
  { code: 'ta', label: 'த',    name: 'தமிழ்' },
  { code: 'te', label: 'తె',   name: 'తెలుగు' },
  { code: 'kn', label: 'ಕ',    name: 'ಕನ್ನಡ' },
  { code: 'ml', label: 'മ',    name: 'മലയാളം' },
  { code: 'gu', label: 'ગુ',   name: 'ગુજરાતી' },
  { code: 'pa', label: 'ਪੰ',   name: 'ਪੰਜਾਬੀ' },
  { code: 'ur', label: 'اردو', name: 'اُردُو' },
  { code: 'or', label: 'ଓ',    name: 'ଓଡ଼ିଆ' },
];

export const getLang = (code) =>
  LANGUAGES.find((l) => l.code === code) || LANGUAGES[0];
