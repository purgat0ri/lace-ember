#!/bin/zsh
# Synthesise the mod's sounds with ffmpeg (no samples, nothing to license).
# Bells are A minor (A5 880, C6 1046.5, E6 1318.5); clicks are filtered
# noise; keys are a short muted thock; the music is two loops for GX's
# vertical remix: a storm bed (rain + distant thunder) and a low A-minor
# drone. Every sine and LFO fits a whole number of cycles in 64 s, so the
# loops join seamlessly.
#   sounds.sh <out-dir>
set -e
out=$1; mkdir -p $out/sound $out/keyboard $out/music
ff() { ffmpeg -nostdin -hide_banner -loglevel error -y "$@"; }
mp3() { ff -i $1 -codec:a libmp3lame -q:a 4 -ac 2 $2 && rm $1; }       # VBR ~165 kbps
src() { echo "aevalsrc=exprs='$1':s=44100:d=$2"; }
bell() { echo "exp(-t*$2)*(sin(2*PI*$1*t)+0.35*sin(2*PI*$1*2.003*t)*exp(-t*6)+0.12*sin(2*PI*$1*3.01*t)*exp(-t*12))"; }
# filtered noise shaped by an envelope (aevalsrc's random() doesn't keep state)
noisy() { ff -f lavfi -i "anoisesrc=r=44100:color=white:amplitude=1:d=${1}:seed=$RANDOM" -f lavfi -i "$(src "$2" $1)" \
  -filter_complex "[0][1]amultiply,$3" -t $1 $4; }

# browser sounds
noisy 0.05 "0.6*exp(-t*260)" "bandpass=f=2400:t=h:w=1800,volume=2.2" $out/sound/click.wav
noisy 0.03 "0.3*exp(-t*400)" "bandpass=f=3800:t=h:w=2000,volume=1.4" $out/sound/hover.wav
ff -f lavfi -i "$(src "0.22*$(bell 880 7)+0.12*$(bell 1318.5 9)" 0.6)" $out/sound/important_click.wav
ff -f lavfi -i "$(src "0.2*$(bell 880 10)+0.2*gt(t,0.07)*$(bell 1318.5 8 | sed 's/t/(t-0.07)/g')" 0.55)" $out/sound/new_tab.wav
ff -f lavfi -i "$(src "0.16*$(bell 1318.5 12)+0.16*gt(t,0.06)*$(bell 880 10 | sed 's/t/(t-0.06)/g')" 0.45)" $out/sound/close_tab.wav
noisy 0.22 "0.5*sin(PI*t/0.22)" "bandpass=f=1800:t=h:w=2600,volume=1.3" $out/sound/tab_slash.wav
ff -f lavfi -i "$(src "0.18*$(bell 1046.5 14)+0.18*gt(t,0.05)*$(bell 1318.5 12 | sed 's/t/(t-0.05)/g')" 0.35)" $out/sound/switch_on.wav
ff -f lavfi -i "$(src "0.18*$(bell 1318.5 14)+0.18*gt(t,0.05)*$(bell 1046.5 12 | sed 's/t/(t-0.05)/g')" 0.35)" $out/sound/switch_off.wav
ff -f lavfi -i "$(src "0.16*$(bell 1046.5 18)" 0.2)" $out/sound/switch.wav
ff -f lavfi -i "$(src "0.45*exp(-t*5)*sin(2*PI*55*t)*(1+0.5*sin(2*PI*7*t))" 0.6)" -af "lowpass=f=400" $out/sound/limiter_on.wav
ff -f lavfi -i "$(src "0.4*exp(-t*7)*sin(2*PI*41.2*t)" 0.45)" -af "lowpass=f=300" $out/sound/limiter_off.wav
ff -f lavfi -i "$(src "0.16*$(bell 880 6)+0.16*gt(t,0.09)*$(bell 1046.5 6 | sed 's/t/(t-0.09)/g')+0.16*gt(t,0.18)*$(bell 1318.5 6 | sed 's/t/(t-0.18)/g')+0.18*gt(t,0.27)*$(bell 1760 4 | sed 's/t/(t-0.27)/g')" 1.4)" $out/sound/level_upgrade.wav
for f in $out/sound/*.wav; do mp3 $f ${f:r}.mp3; done

# keyboard: a muted thock (body sine + filtered noise), varied per key
key() {  # name pitch noise-filter length
  ff -f lavfi -i "$(src "0.5*exp(-t*90)*sin(2*PI*$2*t)" $4)" -f lavfi -i "anoisesrc=r=44100:color=white:amplitude=0.35:d=${4}:seed=$RANDOM" \
     -f lavfi -i "$(src "exp(-t*160)" $4)" \
     -filter_complex "[1][2]amultiply,lowpass=f=$3[n];[0][n]amix=inputs=2:normalize=0" -t $4 $out/keyboard/$1.wav
}
key letter_1 190 1700 0.05; key letter_2 205 1900 0.05; key letter_3 178 1600 0.05
key space 120 1100 0.07; key enter 105 1000 0.09; key backspace 240 2200 0.045

# music (64 s loops)
ff -f lavfi -i "anoisesrc=r=44100:color=pink:amplitude=0.32:d=64:seed=7" \
   -f lavfi -i "anoisesrc=r=44100:color=brown:amplitude=1:d=64:seed=11" \
   -f lavfi -i "$(src "0.9*exp(-(t-19)*0.9)*gt(t,19)*(1-exp(-(t-19)*12))+0.6*exp(-(t-46.5)*1.1)*gt(t,46.5)*(1-exp(-(t-46.5)*9))" 64)" \
   -filter_complex "[0]highpass=f=300,lowpass=f=5200,volume=0.7[r];[1][2]amultiply,lowpass=f=110,volume=3.2[th];[r][th]amix=inputs=2:normalize=0,volume=0.55" -t 64 $out/music/storm.wav
ff -f lavfi -i "$(src "(0.30*sin(2*PI*110*t)+0.22*sin(2*PI*164.8125*t)*(0.75+0.25*sin(2*PI*t/16))+0.14*sin(2*PI*261.625*t)*(0.6+0.4*sin(2*PI*t/32))+0.06*sin(2*PI*220.015625*t))*(0.85+0.15*sin(2*PI*t/8))" 64)" -af "lowpass=f=900,volume=0.5" $out/music/drone.wav
for f in $out/music/*.wav; do mp3 $f ${f:r}.mp3; done
