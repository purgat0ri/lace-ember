#!/bin/zsh
# Build the Lace & Ember Opera GX mod into dist/Lace-Ember-GX (load it from
# opera://extensions → Developer mode → Load unpacked) and dist/Lace-Ember-GX.zip.
# Mod schema 2 (lists of named options, chosen in GX Control → Mods):
#   theme          Crimson, Ember and Gilt accents on dusk wine (dark) / bone (light)
#   wallpaper      the Naamah storm live loop as VP9 if it's on this Mac
#                  ($LACE_STORM_VIDEO, default ~/Pictures/Abednego Wallpapers), and the still storm
#   page_styles    the Stylus styles from ../firefox/stylus, compiled (pages.mjs)
#   shaders        Dusk, Embers, Embers · Storm, Embers · Bare (src/shaders)
#   sd_effects     speed-dial hover effects Kindle and Veil
#   cursors        the full Lace & Ember set (cursors.py)
#   image_overrides the sidebar and toolbar icons as Lottie, bone line-art with ember accents (icons.py)
#   app_icon       Naamah and Sigil (art.sh)
#   splash_screen  LACE & EMBER over the storm, with thunder and a bell (art.sh)
#   fonts          Cinzel headers, Inter Tight body, if installed (both OFL)
#   music, sounds  synthesised (sounds.sh)
# Needs node (npx fetches less@4.2.0), ffmpeg with libmp3lame/libvpx/libx264,
# ImageMagick, rsvg-convert and Python with Pillow.
set -e
here=${0:A:h}; cd $here
out=dist/Lace-Ember-GX
rm -rf $out; mkdir -p $out/wallpaper $out/shaders $out/fonts
cp src/license.txt $out/
cp src/shaders/dusk.txt src/shaders/embers.txt src/shaders/sd_*.txt $out/shaders/
sed -e 's/const half LIGHTNING = 0;/const half LIGHTNING = 1;/' src/shaders/embers.txt > $out/shaders/embers-storm.txt
sed -e 's/const half GRADE = 0.45;/const half GRADE = 0;/' -e 's/const half VIG = 0.5;/const half VIG = 0;/' src/shaders/embers.txt > $out/shaders/embers-bare.txt

pages=$(node pages.mjs $out "${LESSC:-npx --yes -p less@4.2.0 lessc}")
cursors=$(python3 cursors.py $out)
icons=$(python3 icons.py $out)
./sounds.sh $out

storm=$here/../zen/storm-clean.jpg
pics="$HOME/Pictures/Abednego Wallpapers"
video="${LACE_STORM_VIDEO:-$pics/Naamah — storm (live, 1080p loop).mp4}"
still="$pics/Naamah — storm (2688x1512).jpg"; [[ -f $still ]] || still=$storm
magick $storm -quality 88 $out/wallpaper/storm.jpg
if [[ -f $video ]]; then
  ffmpeg -nostdin -hide_banner -loglevel error -y -i $video -an -c:v libvpx-vp9 -b:v 0 -crf 36 -row-mt 1 -deadline good \
    -vf "scale=1920:1080,fps=30" $out/wallpaper/storm.webm
  ffmpeg -nostdin -hide_banner -loglevel error -y -i $video -frames:v 1 -q:v 3 $out/wallpaper/storm-first.jpg
  ./art.sh $out $still $video
else
  ./art.sh $out $still
fi

# the mod's own icon: Naamah square, bone hairline, gold corners
magick $still -gravity north -crop "%[fx:min(w,h)]x%[fx:min(w,h)]+0+0" +repage -resize 512x512 \
  \( -size 512x512 gradient:'rgba(42,28,37,0.1)-rgba(21,13,16,0.92)' \) -compose over -composite \
  -fill none -stroke 'rgba(237,227,209,0.55)' -strokewidth 3 -draw "rectangle 14,14 497,497" \
  -stroke '#C9A45C' -strokewidth 3 -draw "polyline 70,26 26,26 26,70" -draw "polyline 442,26 486,26 486,70" \
  -draw "polyline 70,486 26,486 26,442" -draw "polyline 442,486 486,486 486,442" \
  $out/icon_512.png

fonts=(~/Library/Fonts /Library/Fonts)
cinzel=(${^fonts}/Cinzel\[wght\].ttf(N)); inter=(${^fonts}/InterTight\[wght\].ttf(N))
[[ -n $cinzel[1] ]] && cp $cinzel[1] $out/fonts/cinzel.ttf
[[ -n $inter[1] ]] && cp $inter[1] $out/fonts/inter-tight.ttf

python3 - $out "$pages" "$cursors" "$icons" <<'PY'
import json, os, sys, time
out, pages, cursors, icons = sys.argv[1], *map(json.loads, sys.argv[2:5])
has = lambda p: os.path.exists(os.path.join(out, p))
hsl = lambda h, s, l: {"h": h, "s": s, "l": l}
snd = lambda *f: [f"sound/{x}.mp3" for x in f]
WINE, BONE = hsl(321, 22, 11), hsl(39, 44, 87)
def theme(id, name, dark, light):
    return {"id": id, "name": name, "dark": {"gx_accent": dark, "gx_secondary_base": WINE},
            "light": {"gx_accent": light, "gx_secondary_base": BONE}}
def wall(id, name, image, first=None):
    w = {"image": image, "text_color": "#EDE3D1", "text_shadow": "#0B0709"}
    if first: w["first_frame"] = first
    return {"id": id, "name": name, "dark": w, "light": w}
hover = {"args": ["__hover-shader-frame"], "animations": [{"name": "hover", "type": "hover", "duration": 400,
         "steps": 24, "reversible": True, "preserve_last_frame": True, "infinite": False}]}
walls = []
if has("wallpaper/storm.webm"):
    walls.append(wall("lace_ember_storm_live", "Naamah's Storm (live)", "wallpaper/storm.webm", "wallpaper/storm-first.jpg"))
walls.append(wall("lace_ember_storm_still", "The Storm (still)", "wallpaper/storm.jpg"))
payload = {
    "theme": [
        theme("lace_ember_crimson", "Lace & Ember · Crimson", hsl(357, 66, 56), hsl(351, 65, 43)),
        theme("lace_ember_ember", "Lace & Ember · Ember", hsl(19, 100, 62), hsl(16, 80, 45)),
        theme("lace_ember_gilt", "Lace & Ember · Gilt", hsl(40, 50, 57), hsl(38, 55, 38)),
    ],
    "wallpaper": walls,
    "page_styles": pages,
    "shaders": [
        {"id": "lace_ember_dusk", "name": "Lace & Ember · Dusk", "path": "shaders/dusk.txt"},
        {"id": "lace_ember_embers", "name": "Lace & Ember · Embers", "path": "shaders/embers.txt",
         "animation": {"duration": 60, "steps": 900}},
        {"id": "lace_ember_embers_storm", "name": "Lace & Ember · Embers · Storm", "path": "shaders/embers-storm.txt",
         "animation": {"duration": 60, "steps": 900}},
        {"id": "lace_ember_embers_bare", "name": "Lace & Ember · Embers · Bare", "path": "shaders/embers-bare.txt",
         "animation": {"duration": 60, "steps": 900}},
    ],
    "sd_effects": [
        {"id": "lace_ember_kindle", "name": "Kindle", "shader": {"path": "shaders/sd_kindle.txt", **hover}},
        {"id": "lace_ember_veil", "name": "Veil", "shader": {"path": "shaders/sd_veil.txt", **hover}},
    ],
    "cursors": [{"id": "lace_ember_cursors", "name": "Lace & Ember", "preview": "cursors/preview.jpg", "items": cursors}],
    "image_overrides": [{"id": "lace_ember_icons", "name": "Lace & Ember", "images": icons}],
    "app_icon": [
        {"id": "lace_ember_naamah_icon", "name": "Lace & Ember · Naamah", "path": "app_icon/naamah.png"},
        {"id": "lace_ember_sigil_icon", "name": "Lace & Ember · Sigil", "path": "app_icon/sigil.png"},
    ],
    "splash_screen": [{"id": "lace_ember_splash", "name": "Lace & Ember", "path": "splash/storm.mp4"}],
    # vertical remix: the storm bed always plays; the drone joins as you get busy
    "background_music": [{"id": "lace_ember_storm", "name": "Naamah's Storm", "author": "Lace & Ember",
                          "tracks": ["music/storm.mp3", "music/drone.mp3", "music/drone.mp3"]}],
    "browser_sounds": [{"id": "lace_ember_bells", "name": "Lace & Ember Bells", "author": "Lace & Ember", "sounds": {
        "CLICK": snd("click"), "HOVER": snd("hover"), "HOVER_UP": snd("hover"),
        "IMPORTANT_CLICK": snd("important_click"), "TAB_INSERT": snd("new_tab"),
        "TAB_CLOSE": snd("close_tab"), "TAB_SLASH": snd("tab_slash"),
        "SWITCH_TOGGLE": snd("switch"), "FEATURE_SWITCH_ON": snd("switch_on"),
        "FEATURE_SWITCH_OFF": snd("switch_off"), "LIMITER_ON": snd("limiter_on"),
        "LIMITER_OFF": snd("limiter_off"), "LEVEL_UPGRADE": snd("level_upgrade")}}],
    "keyboard_sounds": [{"id": "lace_ember_keys", "name": "Lace & Ember Keys", "author": "Lace & Ember", "sounds": {
        "TYPING_LETTER": [f"keyboard/letter_{i}.wav" for i in (1, 2, 3)],
        "TYPING_SPACE": ["keyboard/space.wav"], "TYPING_ENTER": ["keyboard/enter.wav"],
        "TYPING_BACKSPACE": ["keyboard/backspace.wav"]}}],
}
if has("fonts/cinzel.ttf") and has("fonts/inter-tight.ttf"):
    payload["fonts"] = [{"id": "lace_ember_fonts", "name": "Lace & Ember",
        "body": {"name": "Inter Tight", "variants": [{"path": "fonts/inter-tight.ttf"}]},
        "header": {"name": "Cinzel", "variants": [{"path": "fonts/cinzel.ttf"}]}}]
manifest = {
    "manifest_version": 3,
    "name": "Lace & Ember",
    "description": "Dusk wine and crimson under Naamah's storm: three themes, the live storm wallpaper, a full cursor set, sidebar and toolbar icons, app icons, a splash screen, Cinzel and Inter Tight, styled YouTube, Google, DuckDuckGo and Reddit, ember shaders, speed-dial effects, bell sounds and a storm soundtrack.",
    "version": time.strftime("%Y.%-m.%-d"),
    "developer": {"name": "Lace & Ember"},
    "icons": {"512": "icon_512.png"},
    "mod": {"schema_version": 2, "license": "license.txt", "payload": payload},
}
json.dump(manifest, open(f"{out}/manifest.json", "w"), indent=2, ensure_ascii=False)
PY
cp README.txt $out/ 2>/dev/null || true
(cd dist && rm -f Lace-Ember-GX.zip && zip -qr Lace-Ember-GX.zip Lace-Ember-GX)
echo "built $here/$out ($(du -sh $out | cut -f1)); zip: $here/dist/Lace-Ember-GX.zip"
