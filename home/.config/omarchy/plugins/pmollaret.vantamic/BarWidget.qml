import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// VantaMic dans la barre. L'appli écrit son état dans
// $XDG_RUNTIME_DIR/vantamic/status.json ; ce widget le lit et pilote l'appli
// avec `vantamic --command …`. Rien ne s'affiche en couleur sauf le direct.
BarWidget {
  id: root
  moduleName: "pmollaret.vantamic"

  readonly property string statusPath: Quickshell.env("XDG_RUNTIME_DIR") + "/vantamic/status.json"
  property var status: ({})

  readonly property bool running: status.pid !== undefined && status.state !== "off"
  readonly property bool live: running && status.state === "live"
  readonly property bool waiting: running && (status.state === "connecting" || status.state === "lost")

  function parse(text) {
    try {
      var s = JSON.parse(String(text || "{}"))
      // Only the fields this widget shows, bounded.
      root.status = {
        state: String(s.state || "off").slice(0, 16),
        phone: String(s.phone || "").slice(0, 64),
        muted: s.muted === true,
        cam: s.cam === true,
        recording: s.recording === true,
        pid: typeof s.pid === "number" ? s.pid : undefined
      }
    } catch (e) {
      root.status = {}
    }
  }

  FileView {
    id: file
    path: root.statusPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parse(text())
    onLoadFailed: root.status = {}
  }

  // The file is replaced, not edited; a slow poll catches what the watch misses.
  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: file.reload()
  }

  readonly property string glyph: {
    if (live && status.cam) return String.fromCodePoint(0xF0567)   // caméra
    if (live && status.muted) return String.fromCodePoint(0xF036D) // micro coupé
    return String.fromCodePoint(0xF036C)                            // micro
  }

  readonly property string tip: {
    if (!running) return "VantaMic : clic pour ouvrir"
    if (live) {
      var parts = ["En direct sur " + (status.phone || "le téléphone")]
      if (status.muted) parts.push("micro coupé")
      if (status.cam) parts.push("caméra allumée")
      if (status.recording) parts.push("enregistrement")
      return parts.join(" · ") + "\nClic droit : muet · Clic du milieu : caméra"
    }
    if (waiting) return "VantaMic : connexion à " + (status.phone || "un téléphone") + "…"
    return "VantaMic : en attente d'un téléphone"
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph
    slotSize: Style.bar.statusSlot
    // Lit while live; the recording shows in the tooltip and in VantaMic.
    active: root.live && !root.status.muted
    dimmed: !root.running || root.waiting
    tooltipText: root.tip

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton && root.running) root.bar.run("vantamic --command mute")
      else if (b === Qt.MiddleButton && root.running) root.bar.run("vantamic --command cam")
      else root.bar.run("vantamic --command show || vantamic")
    }
  }
}
