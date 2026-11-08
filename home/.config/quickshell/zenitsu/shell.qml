// Fond d'écran animé : Zenitsu sous la pluie.
// - effet de profondeur léger (style waydeeper) : profondeur calculée par l'IA
//   Depth Anything V2 Large, contours affinés par le détourage BiRefNet
// - pluie animée en deux couches
// - l'éclair du sabre crépite doucement
// Images : ~/.local/share/zenitsu-wall/   Lancé par ~/.config/hypr/autostart.lua : qs -c zenitsu
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Particles

ShellRoot {
  id: root

  // ---- Réglages -------------------------------------------------------------
  readonly property string dir: "file://" + Quickshell.env("HOME") + "/.local/share/zenitsu-wall/"
  readonly property real strength: 0.013    // force de l'effet de profondeur
  readonly property real focus: 0.30        // profondeur qui reste fixe (0 = fond, 1 = devant)
  readonly property real smoothing: 18.0    // plus grand = suit la souris plus vite
  readonly property int rainFar: 380        // gouttes fines par seconde
  readonly property int rainNear: 40        // grosses gouttes par seconde
  readonly property bool swordFlicker: true // crépitement de l'éclair du sabre
  // ---------------------------------------------------------------------------

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: win
      required property var modelData
      screen: modelData
      anchors { top: true; bottom: true; left: true; right: true }
      color: "black"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.namespace: "zenitsu-wall"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      property real targetX: 0
      property real targetY: 0
      property real curX: 0
      property real curY: 0
      readonly property real zoom: 1 + root.strength * 1.6

      // Position du curseur demandée à Hyprland
      Socket {
        id: hypr
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/hypr/" + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") + "/.socket.sock"
        onConnectedChanged: if (connected) { write("cursorpos"); flush() }
        parser: SplitParser {
          splitMarker: ""
          onRead: (data) => {
            const m = String(data).match(/(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)/)
            if (!m) return
            const sx = Number(m[1]) - win.screen.x, sy = Number(m[2]) - win.screen.y
            win.targetX = Math.max(-1, Math.min(1, sx / win.screen.width * 2 - 1))
            win.targetY = Math.max(-1, Math.min(1, sy / win.screen.height * 2 - 1))
          }
        }
      }
      Timer { interval: 16; repeat: true; running: true; onTriggered: if (!hypr.connected) hypr.connected = true }

      FrameAnimation {
        running: Math.abs(win.targetX - win.curX) > 0.0005 || Math.abs(win.targetY - win.curY) > 0.0005
        onTriggered: {
          const k = 1 - Math.exp(-frameTime * root.smoothing)
          win.curX += (win.targetX - win.curX) * k
          win.curY += (win.targetY - win.curY) * k
        }
      }

      Item {
        id: scene
        anchors.fill: parent

        Image {
          id: img
          source: root.dir + "clean.jpg"
          visible: false
          sourceSize.width: scene.width * win.zoom
          sourceSize.height: scene.height * win.zoom
          smooth: true
          mipmap: true
        }
        Image {
          id: depthImg
          source: root.dir + "depth.png"
          visible: false
          smooth: true
        }

        ShaderEffect {
          anchors.fill: parent
          property var src: img
          property var depth: depthImg
          property vector2d offset: Qt.vector2d(-win.curX * root.strength, -win.curY * root.strength * 0.6)
          property real zoom: win.zoom
          property real pivot: root.focus
          fragmentShader: Quickshell.shellDir + "/depth.frag.qsb"
        }

        // Lueur de l'éclair (suit la profondeur du sabre)
        Image {
          id: glow
          visible: root.swordFlicker
          source: root.dir + "glow.png"
          width: scene.width * win.zoom
          height: scene.height * win.zoom
          sourceSize.width: scene.width
          sourceSize.height: scene.height
          readonly property real d: 0.85 - root.focus
          x: (scene.width - width) / 2 - win.curX * root.strength * d * width
          y: (scene.height - height) / 2 - win.curY * root.strength * 0.6 * d * height
          opacity: 0.3
          smooth: true
        }

        // Pluie fine
        ParticleSystem { id: farSys }
        ImageParticle {
          system: farSys
          source: root.dir + "drop.png"
          color: "#a8b8cc"
          alpha: 0.22
          colorVariation: 0.05
        }
        Emitter {
          system: farSys
          x: -80; y: -60
          width: scene.width + 160; height: 1
          emitRate: root.rainFar
          lifeSpan: 1100
          size: 48; sizeVariation: 18
          velocity: AngleDirection { angle: 91; angleVariation: 1; magnitude: 1250; magnitudeVariation: 250 }
        }

        // Grosses gouttes au premier plan
        ParticleSystem { id: nearSys }
        ImageParticle {
          system: nearSys
          source: root.dir + "drop.png"
          color: "#c8d6e6"
          alpha: 0.28
        }
        Emitter {
          system: nearSys
          x: -120; y: -120
          width: scene.width + 240; height: 1
          emitRate: root.rainNear
          lifeSpan: 800
          size: 120; sizeVariation: 35
          velocity: AngleDirection { angle: 92; angleVariation: 1.5; magnitude: 2100; magnitudeVariation: 300 }
        }
      }

      // Crépitement doux de l'éclair
      Timer {
        interval: 90; repeat: true; running: root.swordFlicker
        onTriggered: {
          interval = 50 + Math.random() * 160
          glow.opacity = 0.2 + Math.random() * 0.25
        }
      }
    }
  }
}
