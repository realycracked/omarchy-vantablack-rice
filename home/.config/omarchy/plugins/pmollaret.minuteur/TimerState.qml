import QtQuick
import Quickshell
import Quickshell.Io

// État partagé du minuteur : lit le fichier d'état écrit par bin/minuteur et
// lance ses commandes. La barre et le widget du bureau en ont chacun un ; le
// timer systemd reste la seule source de vérité.
Item {
  id: st
  visible: false

  readonly property string helper: {
    var url = Qt.resolvedUrl("bin/minuteur").toString()
    return url.indexOf("file://") === 0 ? decodeURIComponent(url.substring(7)) : url
  }
  readonly property string statePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/omarchy-minuteur.json"

  property double start: 0
  property double end: 0
  property string action: ""
  property double now: Date.now() / 1000

  readonly property bool active: end > 0 && end > now - 1
  readonly property int remaining: active ? Math.max(0, Math.round(end - now)) : 0
  readonly property real progress: active && end > start ? Math.min(1, Math.max(0, (now - start) / (end - start))) : 0

  readonly property string actionLabel: action === "shutdown" ? "Extinction" : action === "suspend" ? "Mise en veille" : "Fin"
  readonly property string actionGlyph: action === "shutdown" ? "󰐥" : action === "suspend" ? "󰤄" : "󰂞"
  readonly property string endClock: active ? Qt.formatTime(new Date(end * 1000), "HH:mm") : ""

  // 1:05:09 au-delà d'une heure, 04:59 en dessous.
  function clock(sec) {
    var h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60), s = sec % 60
    var mm = (m < 10 ? "0" : "") + m, ss = (s < 10 ? "0" : "") + s
    return h > 0 ? h + ":" + mm + ":" + ss : mm + ":" + ss
  }
  // Version courte pour la barre : 1h05, 12 min, 45 s.
  function short(sec) {
    if (sec >= 3600) { var m = Math.floor(sec % 3600 / 60); return Math.floor(sec / 3600) + "h" + (m < 10 ? "0" : "") + m }
    if (sec >= 60) return Math.ceil(sec / 60) + " min"
    return sec + " s"
  }

  function parse(text) {
    var d = {}
    try { d = JSON.parse(String(text || "{}")) } catch (e) { d = {} }
    var e = Number(d.end), s = Number(d.start)
    var ok = isFinite(e) && e > 0 && /^(notify|suspend|shutdown)$/.test(String(d.action || ""))
    st.end = ok ? e : 0
    st.start = ok && isFinite(s) ? s : 0
    st.action = ok ? String(d.action) : ""
  }

  // Commandes : arguments passés tels quels, jamais interprétés par un shell.
  property var queue: []
  function run(args) {
    queue = queue.concat([args])
    if (!proc.running) next()
  }
  function next() {
    if (queue.length === 0) return
    proc.command = ["bash", st.helper].concat(queue[0])
    queue = queue.slice(1)
    proc.running = true
  }
  function startMinutes(min, act) { run(["start", String(Math.round(min)), act]) }
  function startAt(hh, mm, act) {
    run(["start", (hh < 10 ? "0" : "") + hh + ":" + (mm < 10 ? "0" : "") + mm, act])
  }
  function extend(min) { run(["extend", String(min)]) }
  function cancel() { run(["cancel"]) }
  function refresh() { run(["status"]) }

  Process {
    id: proc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (proc.command[2] === "status") st.parse(text)
    }
    onExited: { st.refreshFile(); st.next() }
  }

  FileView {
    id: file
    path: st.statePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: st.parse(text())
    onLoadFailed: st.parse("{}")
  }
  function refreshFile() { file.reload() }

  // Le fichier peut être créé ou supprimé par le timer : on relit aussi régulièrement.
  Timer {
    interval: st.active ? 250 : 1000
    repeat: true
    running: true
    onTriggered: {
      st.now = Date.now() / 1000
      if (++st.ticks % (st.active ? 8 : 2) === 0) file.reload()
    }
  }
  property int ticks: 0

  Component.onCompleted: refresh()
}
