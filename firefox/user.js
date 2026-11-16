// Lace & Ember — Firefox prefs. Symlinked into the profile; Firefox reapplies
// these at every launch, so change them here rather than in Settings.

// read chrome/userChrome.css
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// horizontal tabs, no sidebar
user_pref("sidebar.verticalTabs", false);
user_pref("sidebar.revamp", false);

// dark built-in theme underneath, so anything the CSS misses stays dark
user_pref("extensions.activeThemeID", "firefox-compact-dark@mozilla.org");

// allow the unsigned Lace & Ember Start extension. Only Developer Edition,
// Nightly and ESR honour this; release Firefox ignores it.
user_pref("xpinstall.signatures.required", false);
// the extension is dropped into the profile's extensions/ folder by
// install.sh; enable it without the "another program added an add-on" prompt
user_pref("extensions.autoDisableScopes", 0);
// and look in that folder at every launch (by default Firefox only rescans it
// after an update), so a rebuilt start page is picked up on the next restart
user_pref("extensions.startupScanScopes", 1);

// The home page is set by the extension (chrome_settings_overrides), not here.
