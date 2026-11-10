import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Processeur et mémoire, lus dans /proc toutes les quelques secondes. Le
// chiffre s'allume seulement quand la machine force (au-dessus de 80 %).
BarWidget {
  id: root
  moduleName: "pmollaret.sysmon"

  readonly property int seconds: Math.max(1, Math.min(30, Number(setting("interval", 2)) || 2))
  property int cpu: 0
  property int mem: 0
  property var lastTotal: 0
  property var lastIdle: 0

  function readCpu(text) {
    var line = String(text || "").split("\n")[0].trim().split(/\s+/)
    if (line[0] !== "cpu") return
    var total = 0
    for (var i = 1; i < line.length; i++) total += Number(line[i]) || 0
    var idle = (Number(line[4]) || 0) + (Number(line[5]) || 0)
    if (root.lastTotal > 0 && total > root.lastTotal)
      root.cpu = Math.round(100 * (1 - (idle - root.lastIdle) / (total - root.lastTotal)))
    root.lastTotal = total
    root.lastIdle = idle
  }

  function readMem(text) {
    var total = 0, available = 0
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^(MemTotal|MemAvailable):\s+(\d+)/)
      if (!m) continue
      if (m[1] === "MemTotal") total = Number(m[2])
      else available = Number(m[2])
    }
    if (total > 0) root.mem = Math.round(100 * (total - available) / total)
  }

  FileView { id: stat; path: "/proc/stat"; printErrors: false; onLoaded: root.readCpu(text()) }
  FileView { id: meminfo; path: "/proc/meminfo"; printErrors: false; onLoaded: root.readMem(text()) }

  Timer {
    interval: root.seconds * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: { stat.reload(); meminfo.reload() }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // A text button sizes itself to its label, glyph included.
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // Starts with a letter: the bar treats a label opening on a glyph as a
    // lone icon and gives it an icon's width.
    text: "CPU " + root.cpu + "%  RAM " + root.mem + "%"
    active: root.cpu >= 80 || root.mem >= 80
    tooltipText: "Processeur " + root.cpu + " % · Mémoire " + root.mem + " %\nClic : ouvre btop"

    onPressed: function(b) {
      if (root.bar) root.bar.run("omarchy launch or focus tui btop")
    }
  }
}
