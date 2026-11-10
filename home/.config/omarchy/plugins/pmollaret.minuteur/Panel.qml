import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Minuteur dans la barre : l'icône affiche le temps restant ; le panneau règle
// une durée ou une heure précise, et ce qui se passe à la fin.
Panel {
  id: root
  moduleName: "pmollaret.minuteur"
  ipcTarget: "minuteur"

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.7)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Réglages du panneau (gardés tant que le shell tourne).
  property string mode: "dur"          // "dur" | "at"
  property int durH: 0
  property int durM: 30
  property int atHour: 23
  property int atMinute: 0
  property string action: "shutdown"

  readonly property int minutes: Math.max(1, durH * 60 + durM)
  readonly property var presets: [15, 30, 45, 60, 90, 120]
  readonly property var atPresets: [[21, 0], [22, 0], [23, 0], [0, 0], [1, 0], [2, 0]]
  function two(n) { return (n < 10 ? "0" : "") + n }
  function presetLabel(m) { return m < 60 ? m + " min" : (m % 60 ? Math.floor(m / 60) + " h " + two(m % 60) : (m / 60) + " h") }

  function launch() {
    if (root.mode === "dur") st.startMinutes(root.minutes, root.action)
    else st.startAt(root.atHour, root.atMinute, root.action)
  }

  onOpenedChanged: if (opened) {
    var d = new Date(Date.now() + 60 * 60000)   // proposer « dans une heure », arrondi au quart d'heure
    if (!st.active) { root.atHour = d.getHours(); root.atMinute = Math.floor(d.getMinutes() / 15) * 15 }
    Qt.callLater(function() { keys.forceActiveFocus() })
  }

  TimerState { id: st }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  TextMetrics {
    id: labelMetrics
    font.family: root.fontFamily
    font.pixelSize: Style.bar.iconFont
    text: button.labelText
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: st.active ? "󰔟" : "󰔛"
    labelText: st.active ? st.short(st.remaining) : ""
    slotSize: Style.bar.statusSlot
    // La largeur d'une icône seule ne compte pas le texte : on l'ajoute.
    fixedWidth: root.bar && root.bar.vertical ? -1
      : Style.bar.statusSlot + (labelText !== "" ? labelMetrics.advanceWidth + Style.space(6) : 0)
    active: st.active && st.remaining <= 60
    dimmed: !st.active
    tooltipText: st.active ? st.actionLabel + " à " + st.endClock + " (" + st.clock(st.remaining) + ")" : "Minuteur"
    onPressed: function(b) {
      if (b === Qt.MiddleButton && st.active) st.cancel()
      else root.toggle()
    }
  }

  component Label: Text {
    textFormat: Text.PlainText
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.letterSpacing: Style.spaceReal(1.6)
    font.capitalization: Font.AllUppercase
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keys
    contentWidth: Style.space(330)
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      onCloseRequested: root.close()
      onActivateRequested: root.launch()
      onReturnRequested: root.launch()

      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

        // ---- état
        Column {
          width: parent.width
          spacing: Style.space(2)
          Label { text: "Minuteur" }
          Text {
            textFormat: Text.PlainText
            text: st.active ? st.clock(st.remaining) : "--:--"
            color: st.active ? root.foreground : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.space(46)
            font.weight: Font.Light
          }
          Text {
            textFormat: Text.PlainText
            text: st.active ? st.actionLabel + " à " + st.endClock : "Aucun minuteur en cours"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
        }
        Rectangle {   // progression
          width: parent.width; height: Math.max(1, Style.space(2))
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
          Rectangle { width: parent.width * st.progress; height: parent.height; color: root.foreground }
        }
        Row {
          visible: st.active
          spacing: Style.space(6)
          Button { text: "+5 min"; bordered: true; foreground: root.foreground; onClicked: st.extend(5) }
          Button { text: "+15 min"; bordered: true; foreground: root.foreground; onClicked: st.extend(15) }
          Button { text: "Annuler"; iconText: "󰜺"; bordered: true; foreground: root.foreground; onClicked: st.cancel() }
        }

        PanelSeparator { foreground: root.foreground }

        // ---- quand
        Label { text: "Quand" }
        ButtonGroup {
          width: parent.width
          foreground: root.foreground
          options: [{ label: "Dans…", value: "dur", icon: "󰔛" }, { label: "À une heure", value: "at", icon: "󰥔" }]
          value: root.mode
          onChanged: function(v) { root.mode = v }
        }
        Grid {
          visible: root.mode === "dur"
          width: parent.width
          columns: 3
          spacing: Style.space(6)
          Repeater {
            model: root.presets
            Button {
              required property var modelData
              width: (column.width - Style.space(12)) / 3
              text: root.presetLabel(modelData)
              bordered: true
              selected: root.minutes === modelData
              foreground: root.foreground
              onClicked: { root.durH = Math.floor(modelData / 60); root.durM = modelData % 60 }
            }
          }
        }
        Row {
          visible: root.mode === "dur"
          width: parent.width
          spacing: Style.space(10)
          NumberField {
            width: (parent.width - Style.space(10)) / 2
            label: "Heures"
            from: 0; to: 23
            value: root.durH
            foreground: root.foreground
            onModified: function(v) { root.durH = v; if (v === 0 && root.durM === 0) root.durM = 1 }
          }
          NumberField {
            width: (parent.width - Style.space(10)) / 2
            label: "Min"
            from: 0; to: 59
            value: root.durM
            foreground: root.foreground
            onModified: function(v) { root.durM = (v === 0 && root.durH === 0) ? 1 : v }
          }
        }
        Grid {
          visible: root.mode === "at"
          width: parent.width
          columns: 3
          spacing: Style.space(6)
          Repeater {
            model: root.atPresets
            Button {
              required property var modelData
              width: (column.width - Style.space(12)) / 3
              text: root.two(modelData[0]) + ":" + root.two(modelData[1])
              bordered: true
              selected: root.atHour === modelData[0] && root.atMinute === modelData[1]
              foreground: root.foreground
              onClicked: { root.atHour = modelData[0]; root.atMinute = modelData[1] }
            }
          }
        }
        Row {
          visible: root.mode === "at"
          width: parent.width
          spacing: Style.space(10)
          NumberField {
            width: (parent.width - Style.space(10)) / 2
            label: "Heure"
            from: 0; to: 23
            value: root.atHour
            foreground: root.foreground
            onModified: function(v) { root.atHour = v }
          }
          NumberField {
            width: (parent.width - Style.space(10)) / 2
            label: "Min"
            from: 0; to: 59
            value: root.atMinute
            foreground: root.foreground
            onModified: function(v) { root.atMinute = v }
          }
        }

        // ---- puis
        Label { text: "Ensuite" }
        ButtonGroup {
          width: parent.width
          foreground: root.foreground
          options: [{ label: "Notifier", value: "notify", icon: "󰂞" },
                    { label: "Veille", value: "suspend", icon: "󰤄" },
                    { label: "Éteindre", value: "shutdown", icon: "󰐥" }]
          value: root.action
          onChanged: function(v) { root.action = v }
        }

        Button {
          width: parent.width
          text: (st.active ? "Remplacer : " : "Lancer : ") + (root.mode === "dur"
            ? root.presetLabel(root.minutes)
            : (root.atHour < 10 ? "0" : "") + root.atHour + ":" + (root.atMinute < 10 ? "0" : "") + root.atMinute)
          iconText: "󰐊"
          bordered: true
          foreground: root.foreground
          onClicked: root.launch()
        }
      }
    }
  }
}
