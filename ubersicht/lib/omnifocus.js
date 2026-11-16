// JXA: the next three available actions in the OmniFocus project "Abednego",
// as a JSON array of names. Uses Omni Automation for OmniFocus's own
// availability rules (defer dates, sequential projects). Never launches OmniFocus.
function run() {
  const of = Application("OmniFocus");
  if (!of.running()) return "null";
  const code = `(() => {
    const p = flattenedProjects.byName("Abednego");
    if (!p) return "[]";
    const ok = [Task.Status.Available, Task.Status.Next, Task.Status.DueSoon, Task.Status.Overdue];
    return JSON.stringify(p.flattenedTasks
      .filter(t => ok.includes(t.taskStatus) && !t.hasChildren)
      .slice(0, 3).map(t => t.name));
  })()`;
  return of.evaluateJavascript(code);
}
