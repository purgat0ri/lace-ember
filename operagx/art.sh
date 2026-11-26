#!/bin/zsh
# App icons and the splash screen for the GX mod.
#   art.sh <out-dir> <storm-still> [storm-video]
# app_icon/naamah.png  Naamah from the storm in a macOS-shaped tile, bone hairline, gold corners
# app_icon/sigil.png   the gold sigil on dusk wine with an ember glow
# splash/storm.mp4     5 s, 1080²: the storm opens, LACE & EMBER rises in Cinzel Decorative, thunder and a bell
set -e
out=$1; still=$2; video=$3; here=${0:A:h}
mkdir -p $out/app_icon $out/splash
fonts=(~/Library/Fonts /Library/Fonts)
deco=(${^fonts}/CinzelDecorative-Bold.ttf(N)); deco=$deco[1]
cinzel=(${^fonts}/Cinzel\[wght\].ttf(N)); cinzel=$cinzel[1]
tile() {  # the macOS tile: 824² squircle-ish rounded square on a 1024 canvas
  magick -size 1024x1024 xc:none -fill white -draw "roundrectangle 100,100 923,923 185,185" $1
}
tile /tmp/lace-mask-$$.png
corners=(-stroke '#C9A45C' -strokewidth 10 -fill none
  -draw "polyline 270,180 180,180 180,270" -draw "polyline 754,180 844,180 844,270"
  -draw "polyline 270,844 180,844 180,754" -draw "polyline 754,844 844,844 844,754")

magick $still -gravity north -crop "%[fx:min(w,h)]x%[fx:min(w,h)]+0+0" +repage -resize 824x824 \
  \( -size 824x824 gradient:'rgba(42,28,37,0)-rgba(21,13,16,0.85)' \) -compose over -composite \
  -bordercolor none -border 100 /tmp/lace-a-$$.png
magick /tmp/lace-a-$$.png /tmp/lace-mask-$$.png -compose copy-opacity -composite \
  -fill none -stroke 'rgba(237,227,209,0.7)' -strokewidth 6 -draw "roundrectangle 128,128 895,895 160,160" \
  $corners -resize 512x512 $out/app_icon/naamah.png

rsvg-convert -w 520 -h 440 $here/../zen/extension/img/sigil.svg -o /tmp/lace-sigil-$$.png
magick -size 1024x1024 radial-gradient:'#5a1a28-#150D10' /tmp/lace-mask-$$.png -compose copy-opacity -composite \
  \( /tmp/lace-sigil-$$.png -bordercolor none -border 160 -channel A -blur 0x28 -evaluate multiply 1.4 +channel -fill '#FF7A3D' -colorize 100 \) -gravity center -geometry +0+30 -compose screen -composite \
  /tmp/lace-sigil-$$.png -gravity center -geometry +0+30 -compose over -composite \
  -fill none -stroke 'rgba(237,227,209,0.6)' -strokewidth 6 -draw "roundrectangle 128,128 895,895 160,160" \
  $corners -resize 512x512 $out/app_icon/sigil.png
rm -f /tmp/lace-*-$$.png

# splash: video if we have it, else the still. Titles are drawn by ImageMagick
# (Homebrew ffmpeg has no drawtext) and faded in as overlays.
t1=/tmp/lace-t1-$$.png; t2=/tmp/lace-t2-$$.png
magick -size 1080x1080 xc:none -font $deco -pointsize 104 -gravity north \
  \( -size 1080x1080 xc:none -font $deco -pointsize 104 -gravity north -fill '#B3263A' -annotate +0+770 'LACE & EMBER' -blur 0x14 \) -compose over -composite \
  -fill '#EDE3D1' -stroke '#0B0709' -strokewidth 2 -annotate +0+770 'LACE & EMBER' $t1
magick -size 1080x1080 xc:none -fill '#C9A45C' -draw "rectangle 360,905 720,907" \
  -font $cinzel -pointsize 30 -gravity north -fill '#C9A45C' -annotate +0+925 'NAAMAH · STORM' $t2
if [[ -f $video ]]; then src=(-stream_loop 1 -i $video); else src=(-loop 1 -framerate 30 -i $still); fi
ffmpeg -nostdin -hide_banner -loglevel error -y $src -loop 1 -framerate 30 -i $t1 -loop 1 -framerate 30 -i $t2 \
  -f lavfi -i "anoisesrc=r=44100:color=brown:amplitude=1:d=5:seed=3" \
  -f lavfi -i "aevalsrc=exprs='0.9*exp(-(t-0.4)*1.4)*gt(t,0.4)*(1-exp(-(t-0.4)*10))':s=44100:d=5" \
  -f lavfi -i "aevalsrc=exprs='0.22*gt(t,1.6)*exp(-(t-1.6)*2.2)*(sin(2*PI*440*(t-1.6))+0.4*sin(2*PI*880.6*(t-1.6))+0.2*sin(2*PI*1320*(t-1.6)))':s=44100:d=5" \
  -filter_complex "[0:v]scale=-2:1080,crop=1080:1080,fps=30,eq=brightness=-0.06:saturation=1.05,fade=t=in:st=0:d=0.8[bg];\
[1:v]format=rgba,fade=t=in:st=1.3:d=0.8:alpha=1[ti];[2:v]format=rgba,fade=t=in:st=2.0:d=0.6:alpha=1[st];\
[bg][ti]overlay=shortest=1[b1];[b1][st]overlay=shortest=1,fade=t=out:st=4.4:d=0.6,format=yuv420p[v];\
[3][4]amultiply,lowpass=f=140,volume=2.6[th];[th][5]amix=inputs=2:normalize=0,afade=t=out:st=4.2:d=0.8,volume=0.9[a]" \
  -map "[v]" -map "[a]" -t 5 -c:v libx264 -crf 22 -preset slow -c:a aac -b:a 128k -movflags +faststart $out/splash/storm.mp4
rm -f $t1 $t2
