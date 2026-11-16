// JXA: what's playing in Spotify or Apple Music, as JSON (or "null").
// Checks running() first so it never launches either app.
function run() {
  for (const name of ["Spotify", "Music"]) {
    let app;
    try { app = Application(name); if (!app.running()) continue; } catch (e) { continue; }
    try {
      const state = String(app.playerState());
      if (state !== "playing" && state !== "paused") continue;
      const t = app.currentTrack;
      let dur = Number(t.duration()) || 0;
      if (name === "Spotify") dur = dur / 1000;
      return JSON.stringify({
        app: name, state,
        title: t.name(), artist: t.artist(), album: t.album(),
        pos: Math.round(Number(app.playerPosition()) || 0), dur: Math.round(dur),
      });
    } catch (e) { continue; }
  }
  return "null";
}
