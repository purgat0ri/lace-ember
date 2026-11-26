// Lace & Ember for Surfingkeys: dusk wine panels, bone text, crimson and ember accents,
// gold hairlines, Cinzel headings over Inter Tight (both free on Google Fonts; falls back
// to the system fonts if they're not installed).
// Paste below your own mappings in Surfingkeys → Settings (Advanced mode), then Save.

// ---- hints: wine tags with a crimson edge and an ember glow ------------------
Hints.style(`
  div {
    font: 700 11px/1.15 "Inter Tight", -apple-system, sans-serif !important;
    letter-spacing: 0.06em;
    color: #EDE3D1 !important;
    background: linear-gradient(#3A2632, #22161C) !important;
    border: 1px solid #D6454E !important;
    border-radius: 2px !important;
    padding: 1px 4px !important;
    box-shadow: 0 0 0 1px rgba(21,13,16,0.6), 0 0 7px rgba(255,122,61,0.45) !important;
    text-shadow: 0 1px 0 #0B0709;
  }
  div.begin { color: #FF7A3D !important; }
`);
Hints.style(`
  div {
    font: 700 11px/1.15 "Inter Tight", -apple-system, sans-serif !important;
    color: #EDE3D1 !important;
    background: linear-gradient(#2A1C25, #150D10) !important;
    border: 1px solid #C9A45C !important;
    border-radius: 2px !important;
    padding: 1px 4px !important;
    box-shadow: 0 0 6px rgba(201,164,92,0.4) !important;
  }
  div.begin { color: #FF7A3D !important; }
`, "text");

// ---- visual mode -------------------------------------------------------------
Visual.style("marks", "background-color: rgba(255,122,61,0.35); border-bottom: 1px solid #FF7A3D;");
Visual.style("cursor", "background-color: #FF7A3D; color: #150D10;");

// ---- omnibar, banner, status, help, tab overlay ------------------------------
settings.theme = `
  .sk_theme {
    font-family: "Inter Tight", -apple-system, "Helvetica Neue", sans-serif;
    font-size: 13px;
    background: linear-gradient(180deg, #2A1C25 0%, #1D1218 100%);
    color: #EDE3D1;
    border: 1px solid rgba(201,164,92,0.55);
    border-radius: 4px;
    box-shadow: 0 0 0 1px #0B0709, 0 18px 50px rgba(11,7,9,0.7), 0 0 24px rgba(214,69,78,0.25);
  }
  .sk_theme tbody { color: #EDE3D1; }
  .sk_theme input {
    color: #EDE3D1;
    caret-color: #FF7A3D;
    font-family: "Inter Tight", -apple-system, sans-serif;
  }
  .sk_theme input::placeholder { color: rgba(237,227,209,0.4); }
  .sk_theme .url { color: rgba(201,164,92,0.85); }
  .sk_theme .annotation { color: #A8998A; }
  .sk_theme kbd {
    background: #3A2632;
    color: #EDE3D1;
    border: 1px solid rgba(201,164,92,0.45);
    border-bottom-width: 2px;
    border-radius: 3px;
    box-shadow: none;
    font-family: "Inter Tight", -apple-system, sans-serif;
  }
  .sk_theme .frame { background: rgba(214,69,78,0.3); }
  .sk_theme .omnibar_highlight { color: #FF7A3D; text-shadow: 0 0 6px rgba(255,122,61,0.4); }
  .sk_theme .omnibar_folder { color: #D6454E; }
  .sk_theme .omnibar_timestamp { color: #B07A8C; }
  .sk_theme .omnibar_visitcount { color: #C9A45C; }
  .sk_theme .prompt, .sk_theme .resultPage {
    color: #C9A45C;
    font-family: "Cinzel", "Trajan Pro", Georgia, serif;
    font-weight: 700;
    letter-spacing: 0.08em;
  }
  .sk_theme .feature_name {
    color: #C9A45C;
    font-family: "Cinzel", "Trajan Pro", Georgia, serif;
    letter-spacing: 0.06em;
  }
  .sk_theme .separator { color: #D6454E; }
  .sk_theme #sk_omnibarSearchArea { border-bottom: 1px solid rgba(201,164,92,0.3); }
  .sk_theme #sk_omnibarSearchResult>ul>li { border-left: 2px solid transparent; }
  .sk_theme #sk_omnibarSearchResult>ul>li:nth-child(odd) { background: rgba(237,227,209,0.03); }
  .sk_theme #sk_omnibarSearchResult>ul>li.focused {
    background: linear-gradient(90deg, rgba(214,69,78,0.32), rgba(214,69,78,0.08));
    border-left-color: #FF7A3D;
  }
  .sk_theme #sk_omnibarSearchResult>ul>li.window { border: 1px solid rgba(201,164,92,0.3); }
  .sk_theme #sk_omnibarSearchResult>ul>li.window.focused { border: 1px solid #FF7A3D; }
  #sk_omnibarSearchResult li .icon {
    background: #3A2632; color: #EDE3D1; border: 1px solid #D6454E; box-shadow: none;
  }

  #sk_status, #sk_keystroke, #sk_banner {
    font-family: "Inter Tight", -apple-system, sans-serif;
    background: linear-gradient(180deg, #2A1C25, #1D1218);
    color: #EDE3D1;
    border: 1px solid rgba(201,164,92,0.55);
    box-shadow: 0 6px 24px rgba(11,7,9,0.6), 0 0 14px rgba(214,69,78,0.2);
  }
  #sk_status>span { border-left: 1px solid rgba(201,164,92,0.35); }
  #sk_banner { border-color: #D6454E; letter-spacing: 0.04em; }
  #sk_find { color: #EDE3D1; caret-color: #FF7A3D; }
  .expandRichHints kbd>.candidates { color: #FF7A3D; }
  .expandRichHints span.annotation { color: #A8998A; }

  #sk_usage, #sk_popup, #sk_editor {
    background: linear-gradient(180deg, #2A1C25, #150D10);
    color: #EDE3D1;
    border: 1px solid rgba(201,164,92,0.55);
    box-shadow: 0 18px 60px rgba(11,7,9,0.75), 0 0 30px rgba(214,69,78,0.2);
  }
  #sk_usage .feature_name { border-bottom: 1px solid rgba(201,164,92,0.35); }
  #sk_usage .feature_name>span {
    color: #C9A45C;
    font-family: "Cinzel", "Trajan Pro", Georgia, serif;
    text-transform: uppercase;
    letter-spacing: 0.12em;
  }
  #sk_usage span.annotation { color: #A8998A; }

  div.sk_tab {
    background: linear-gradient(180deg, #2A1C25, #1D1218);
    border: 1px solid rgba(201,164,92,0.45);
    box-shadow: 0 6px 20px rgba(11,7,9,0.6);
  }
  div.sk_tab_title { color: #EDE3D1; }
  div.sk_tab_url { color: rgba(201,164,92,0.85); }
  div.sk_tab_hint {
    background: linear-gradient(#3A2632, #22161C);
    color: #FF7A3D;
    border: 1px solid #D6454E;
    box-shadow: 0 0 7px rgba(255,122,61,0.45);
    font-family: "Inter Tight", -apple-system, sans-serif;
  }
  div.sk_tab_group_header>div { color: #C9A45C; font-family: "Cinzel", Georgia, serif; }
`;
