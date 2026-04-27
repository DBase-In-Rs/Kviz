const String premierModeKey = 'premier';

bool usesStandardDailyQuota(String modeKey) {
  return modeKey.trim() != premierModeKey;
}
