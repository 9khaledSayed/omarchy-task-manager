.pragma library

var SYSTEM_USERS = [
  "root", "systemd-network", "systemd-resolve", "systemd-timesync",
  "systemd-coredump", "systemd-journal-remote", "nobody", "daemon",
  "bin", "sys", "sync", "games", "man", "lp", "mail", "news",
  "uucp", "proxy", "www-data", "backup", "list", "irc", "gnats",
  "messagebus", "polkitd", "avahi", "colord", "rtkit", "geoclue"
];

var PROTECTED = [
  "systemd", "Hyprland", "quickshell", "waybar", "wireplumber",
  "pipewire", "pipewire-pulse", "dbus-broker", "dbus-broker-lau",
  "dbus-daemon", "login", "init", "uwsm", "Xwayland",
  "foot", "kitty", "alacritty", "ghostty"
];

function isSystemProcess(pid, user, comm, currentUser) {
  if (pid <= 2) return true;
  if (SYSTEM_USERS.indexOf(user) !== -1) return true;
  if (currentUser && user !== currentUser) return true;
  if (PROTECTED.indexOf(comm) !== -1) return true;
  return false;
}

function parseProcesses(raw, currentUser) {
  var lines = String(raw || "").trim().split("\n");
  var list = [];
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim();
    if (!line) continue;
    var parts = line.split(/\s+/);
    if (parts.length < 5) continue;
    var pid = parseInt(parts[0], 10);
    var user = parts[1];
    var cpu = parseFloat(parts[2]) || 0;
    var mem = parseFloat(parts[3]) || 0;
    var comm = parts.slice(4).join(" ");
    list.push({
      pid: pid,
      user: user,
      cpu: cpu,
      mem: mem,
      name: comm,
      isSystem: isSystemProcess(pid, user, comm, currentUser)
    });
  }
  return list;
}

function filterAndSort(processes, filterText, sortBy, onlyUser) {
  var list = (processes || []).slice();
  if (onlyUser) {
    list = list.filter(function(p) { return !p.isSystem; });
  }
  if (filterText && filterText.trim().length > 0) {
    var query = filterText.trim().toLowerCase();
    list = list.filter(function(p) {
      return p.name.toLowerCase().indexOf(query) !== -1 || String(p.pid).indexOf(query) !== -1;
    });
  }
  var sortKey = sortBy || "cpu";
  list.sort(function(a, b) {
    if (sortKey === "mem") return b.mem - a.mem;
    if (sortKey === "name") return a.name.localeCompare(b.name);
    return b.cpu - a.cpu;
  });
  return list;
}
