// Lace & Ember — Zen prefs. Symlinked into the profile; Zen reapplies these at
// every launch, so change them here rather than in Settings.

// read chrome/userChrome.css
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// allow the unsigned Lace & Ember Start extension (Zen is built without forced
// signing, so this pref is honoured; stock Firefox would ignore it)
user_pref("xpinstall.signatures.required", false);

// new tabs open the start page instead of Zen's floating URL bar
user_pref("zen.urlbar.replace-newtab", false);

// The home page is set by the extension (chrome_settings_overrides), not here.
