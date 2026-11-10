import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Widget de bureau : posé sous les fenêtres (calque « bottom »), au-dessus du
// fond d'écran (ordre réglé dans ~/.config/hypr/layers.lua).
// Au repos, le grand affichage se règle : molette sur les heures ou les minutes,
// ou clic en haut (+) / en bas (−) d'un chiffre. Mode « Dans » (durée) ou « À » (heure).
Item {
  id: root
  property var shell: null
  property var manifest: null
  property string omarchyPath: ""

  // ---- réglages
  readonly property int marginLeft: 28
  readonly property int marginTop: 44

  property string action: "shutdown"
  property string mode: "dur"     // "dur" | "at"
  property int durH: 0
  property int durM: 30
  property int atH: 23
  property int atM: 0

  readonly property int h: mode === "dur" ? durH : atH
  readonly property int m: mode === "dur" ? durM : atM
  function two(n) { return (n < 10 ? "0" : "") + n }
  function setH(v) {
    if (mode === "dur") durH = Math.max(0, Math.min(23, v))
    else atH = ((v % 24) + 24) % 24
  }
  function setM(v) {
    if (mode === "dur") {
      var total = Math.max(1, Math.min(23 * 60 + 59, durH * 60 + v))
      durH = Math.floor(total / 60); durM = total % 60
    } else {
      var t = ((atH * 60 + v) % 1440 + 1440) % 1440
      atH = Math.floor(t / 60); atM = t % 60
    }
  }
  function launch() {
    if (mode === "dur") st.startMinutes(Math.max(1, durH * 60 + durM), action)
    else st.startAt(atH, atM, action)
  }
  // Fin prévue, affichée sous le réglage.
  readonly property string preview: {
    var now = new Date(st.now * 1000)
    if (mode === "dur") return "à " + Qt.formatTime(new Date(now.getTime() + (durH * 60 + durM) * 60000), "HH:mm")
    var target = new Date(now); target.setHours(atH, atM, 0, 0)
    if (target <= now) target.setDate(target.getDate() + 1)
    var mins = Math.round((target - now) / 60000)
    return "dans " + (mins >= 60 ? Math.floor(mins / 60) + " h " + two(mins % 60) : mins + " min")
  }

  TimerState { id: st }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: win
      required property var modelData
      screen: modelData
      anchors { top: true; left: true }
      margins { top: root.marginTop; left: root.marginLeft }
      implicitWidth: card.width
      implicitHeight: card.height
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.namespace: "omarchy-minuteur-desk"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      readonly property color fg: Commons.Color.foreground
      readonly property color bg: Commons.Color.background
      readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.45)
      readonly property string family: Style.font.family

      component Caps: Text {
        textFormat: Text.PlainText
        color: win.dim
        font.family: win.family
        font.pixelSize: 11
        font.letterSpacing: 2.2
        font.capitalization: Font.AllUppercase
      }

      component Chip: Rectangle {
        id: chip
        property string label: ""
        property bool selected: false
        property bool strong: false
        signal activated()
        implicitWidth: Math.max(42, t.implicitWidth + 18)
        implicitHeight: 28
        color: selected || strong ? win.fg : (ma.containsMouse ? Qt.rgba(win.fg.r, win.fg.g, win.fg.b, 0.10) : "transparent")
        border.width: 1
        border.color: selected || strong ? win.fg : Qt.rgba(win.fg.r, win.fg.g, win.fg.b, ma.containsMouse ? 0.6 : 0.25)
        Behavior on color { ColorAnimation { duration: Style.duration(120) } }
        Text {
          id: t
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: chip.label
          color: chip.selected || chip.strong ? win.bg : win.fg
          font.family: win.family
          font.pixelSize: 12
        }
        MouseArea {
          id: ma
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: chip.activated()
        }
      }

      // Un nombre réglable : molette, ou clic en haut (+) / en bas (−).
      component Spin: Item {
        id: spin
        property int value: 0
        property int step: 1
        signal changed(int delta)
        implicitWidth: num.implicitWidth
        implicitHeight: num.implicitHeight
        baselineOffset: num.baselineOffset
        Text {
          id: num
          textFormat: Text.PlainText
          text: root.two(spin.value)
          color: area.containsMouse ? win.fg : Qt.rgba(win.fg.r, win.fg.g, win.fg.b, 0.85)
          font.family: win.family
          font.pixelSize: 58
          font.weight: Font.Light
        }
        Text { // flèches au survol
          visible: area.containsMouse
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.top; anchors.topMargin: -6
          textFormat: Text.PlainText; text: "▴"; color: win.dim; font.pixelSize: 12
        }
        Text {
          visible: area.containsMouse
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom; anchors.bottomMargin: -4
          textFormat: Text.PlainText; text: "▾"; color: win.dim; font.pixelSize: 12
        }
        MouseArea {
          id: area
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.SizeVerCursor
          onClicked: function(e) { spin.changed(e.y < height / 2 ? spin.step : -spin.step) }
          onWheel: function(w) { spin.changed(w.angleDelta.y > 0 ? spin.step : -spin.step) }
        }
      }

      Rectangle {
        id: card
        width: 340
        height: content.implicitHeight + 36
        color: Qt.rgba(win.bg.r, win.bg.g, win.bg.b, 0.80)
        border.width: 1
        border.color: Qt.rgba(win.fg.r, win.fg.g, win.fg.b, st.active && st.remaining <= 60 ? 0.9 : 0.22)

        Column {
          id: content
          x: 18; y: 18
          width: card.width - 36
          spacing: 10

          // ---- en-tête : titre, heure actuelle, action finale
          Item {
            width: parent.width; height: 18
            Caps { id: head; text: "Minuteur  ·  " + Qt.formatTime(new Date(st.now * 1000), "HH:mm") }
            Row {
              anchors.right: parent.right
              spacing: 8
              Repeater {
                model: [{ v: "notify", g: "󰂞" }, { v: "suspend", g: "󰤄" }, { v: "shutdown", g: "󰐥" }]
                Text {
                  required property var modelData
                  readonly property bool on: (st.active ? st.action : root.action) === modelData.v
                  textFormat: Text.PlainText
                  text: modelData.g
                  color: on ? win.fg : win.dim
                  opacity: st.active && !on ? 0.4 : 1
                  font.family: win.family
                  font.pixelSize: 15
                  MouseArea {
                    anchors.fill: parent; anchors.margins: -4
                    enabled: !st.active
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.action = parent.modelData.v
                  }
                }
              }
            }
          }

          // ---- minuteur en cours
          Text {
            visible: st.active
            textFormat: Text.PlainText
            text: st.clock(st.remaining)
            color: win.fg
            font.family: win.family
            font.pixelSize: 58
            font.weight: Font.Light
          }
          Caps { visible: st.active; text: st.actionLabel + " à " + st.endClock }
          Rectangle {
            visible: st.active
            width: parent.width; height: 2
            color: Qt.rgba(win.fg.r, win.fg.g, win.fg.b, 0.12)
            Rectangle { width: parent.width * st.progress; height: parent.height; color: win.fg }
          }
          Row {
            visible: st.active
            spacing: 6
            Chip { label: "+5 min"; onActivated: st.extend(5) }
            Chip { label: "+15 min"; onActivated: st.extend(15) }
            Chip { label: "+1 h"; onActivated: st.extend(60) }
            Chip { label: "Annuler"; onActivated: st.cancel() }
          }

          // ---- réglage
          Row {
            visible: !st.active
            spacing: 6
            Chip { label: "Dans"; selected: root.mode === "dur"; onActivated: root.mode = "dur" }
            Chip { label: "À"; selected: root.mode === "at"; onActivated: root.mode = "at" }
          }
          Row {
            visible: !st.active
            spacing: 2
            Spin { id: spinH; value: root.h; onChanged: function(d) { root.setH(root.h + d) } }
            Text {
              textFormat: Text.PlainText
              text: root.mode === "dur" ? "h" : ":"
              color: win.dim
              font.family: win.family
              font.pixelSize: root.mode === "dur" ? 30 : 58
              font.weight: Font.Light
              anchors.baseline: spinH.baseline
            }
            Spin { value: root.m; step: 1; onChanged: function(d) { root.setM(root.m + d) } }
            Text {
              visible: root.mode === "dur"
              textFormat: Text.PlainText
              text: "min"
              color: win.dim
              font.family: win.family
              font.pixelSize: 18
              anchors.baseline: spinH.baseline
            }
          }
          Caps {
            visible: !st.active
            text: (root.action === "shutdown" ? "Éteindre " : root.action === "suspend" ? "Veille " : "Notifier ") + root.preview
          }
          Flow {
            visible: !st.active
            width: parent.width
            spacing: 6
            Repeater {
              model: root.mode === "dur"
                ? [{ l: "15 min", h: 0, m: 15 }, { l: "30 min", h: 0, m: 30 }, { l: "1 h", h: 1, m: 0 }, { l: "2 h", h: 2, m: 0 }]
                : [{ l: "22:00", h: 22, m: 0 }, { l: "23:00", h: 23, m: 0 }, { l: "00:00", h: 0, m: 0 }, { l: "01:00", h: 1, m: 0 }]
              Chip {
                required property var modelData
                label: modelData.l
                selected: root.h === modelData.h && root.m === modelData.m
                onActivated: {
                  if (root.mode === "dur") { root.durH = modelData.h; root.durM = modelData.m }
                  else { root.atH = modelData.h; root.atM = modelData.m }
                }
              }
            }
            Chip { label: "Lancer"; strong: true; onActivated: root.launch() }
          }
        }
      }
    }
  }
}
