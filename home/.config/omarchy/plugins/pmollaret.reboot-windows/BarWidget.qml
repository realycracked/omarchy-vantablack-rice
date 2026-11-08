import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bouton de barre : un premier clic arme le redémarrage (l'icône passe en
// couleur d'alerte), un second clic dans les 4 secondes le lance. Clic droit :
// notification indiquant l'entrée Windows détectée. Clic du milieu : nouvelle
// détection.
BarWidget {
  id: root
  moduleName: "pmollaret.reboot-windows"

  readonly property string helperPath: {
    var url = Qt.resolvedUrl("bin/reboot-to-windows").toString()
    return url.indexOf("file://") === 0 ? decodeURIComponent(url.substring(7)) : url
  }
  readonly property bool confirmFirst: setting("confirm", true) !== false
  readonly property string entryOverride: String(setting("bootEntry", "") || "").trim()

  property bool armed: false
  property bool busy: false
  // État : "ok", "none" ou "error", d'après `reboot-to-windows --check`.
  property string detection: ""
  property string entryNumber: ""
  property string entryLabel: ""
  property string message: ""

  readonly property bool available: detection === "ok"

  function helperCommand(mode, extra) {
    var command = ["bash", root.helperPath, mode]
    if (extra) command.push(extra)
    if (root.entryOverride !== "") command.push("--entry", root.entryOverride)
    return command
  }

  function refresh() {
    if (checkProc.running) return
    checkProc.command = helperCommand("--check")
    checkProc.running = true
  }

  function explain() {
    if (explainProc.running) return
    explainProc.command = helperCommand("--check", "--notify")
    explainProc.running = true
  }

  function parseCheck(text) {
    var line = String(text || "").split("\n")[0]
    var parts = line.split("\t")
    root.detection = parts[0] || "error"
    root.entryNumber = parts[1] || ""
    root.entryLabel = parts.slice(2).join("\t")
    root.message = root.detection === "ok" ? "" : root.entryLabel
  }

  function disarm() {
    armTimer.stop()
    root.armed = false
  }

  function activate() {
    if (root.busy) return
    if (!root.available) {
      // Pas d'entrée Windows : on explique plutôt que d'échouer en silence.
      root.explain()
      root.refresh()
      return
    }
    if (root.confirmFirst && !root.armed) {
      root.armed = true
      armTimer.restart()
      return
    }
    root.disarm()
    root.busy = true
    rebootProc.command = helperCommand("--reboot")
    rebootProc.running = true
  }

  readonly property string tooltip: {
    if (root.busy) return "Préparation du redémarrage sous Windows…"
    if (root.armed) return "Cliquez encore pour redémarrer sous Windows"
    if (root.available) {
      return root.confirmFirst
        ? "Redémarrer sous Windows (double confirmation)"
        : "Redémarrer sous Windows"
    }
    if (root.detection === "") return "Recherche de Windows…"
    return "Windows introuvable : clic pour en savoir plus"
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onEntryOverrideChanged: refresh()
  Component.onCompleted: refresh()

  Timer {
    id: armTimer
    interval: 4000
    repeat: false
    onTriggered: root.armed = false
  }

  Process {
    id: checkProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseCheck(text)
    }
  }

  Process {
    id: explainProc
  }

  Process {
    id: rebootProc
    // En cas de succès la session se ferme ; sinon le script a déjà notifié.
    onExited: function(exitCode) {
      root.busy = false
      if (exitCode !== 0) root.refresh()
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // Logo Windows de la police Nerd Font utilisée par la barre.
    text: ""
    slotSize: Style.bar.statusSlot
    active: root.armed || root.busy
    dimmed: root.detection !== "" && !root.available
    tooltipText: root.tooltip

    onPressed: function(b) {
      if (b === Qt.RightButton) root.explain()
      else if (b === Qt.MiddleButton) { root.disarm(); root.refresh() }
      else root.activate()
    }
  }
}
