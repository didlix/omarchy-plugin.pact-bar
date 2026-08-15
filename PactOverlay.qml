import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// Full-screen overlay hosting the fun PACT windows: "status" (live system
// readouts styled like the Relic Database), "counter" (the pregnancy
// opportunity screen), "emergency" (a flashing alert). Which one shows is
// the bar root's pactOverlayKey; empty string means hidden. Click anywhere
// to dismiss.
PanelWindow {
  id: overlay

  required property QtObject bar
  readonly property string key: bar ? bar.pactOverlayKey : ""

  visible: key !== ""
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "pact-overlay"
  WlrLayershell.layer: WlrLayer.Overlay
  // The overlay owns its keyboard: OnDemand + a focus grab means Esc lands
  // here directly, and the grab can always clear (never Exclusive — that
  // deadlocks input routing and eats mouse clicks desktop-wide).
  WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

  HyprlandFocusGrab {
    active: overlay.visible
    windows: [overlay]
  }

  Item {
    anchors.fill: parent
    focus: true
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return
          || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
        overlay.bar.pactCloseWindow()
        event.accepted = true
      }
    }
  }

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  readonly property color frame: Color.pick("pact.frame", "#4fb8d8")
  readonly property color text: Color.pick("pact.text", "#6ac8e8")
  readonly property color mint: Color.pick("pact.titlebar", "#9fd6c6")
  readonly property color amber: Color.pick("pact.amber", "#e8942e")
  readonly property color yellow: Color.pick("pact.selected", "#c8da7c")
  readonly property color paleYellow: "#ece5a4"

  // ---- live stats (status window)
  property string statUptime: "—"
  property real statRamUsed: 0
  property real statRamTotal: 1
  property string statDiskPct: "—"
  property real statDiskFree: 0
  property string statLoad: "—"

  function refreshStats() { statProc.running = true }

  Process {
    id: statProc
    command: ["sh", "-c",
      "echo \"UPTIME $(uptime -p | sed 's/^up //')\"; " +
      "free -b | awk 'NR==2{printf \"RAM %d %d\\n\",$3,$2}'; " +
      "df -B1 --output=pcent,avail / | awk 'NR==2{printf \"DISK %s %d\\n\",$1,$2}'; " +
      "echo \"LOAD $(cut -d' ' -f1-3 /proc/loadavg)\""]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
          var parts = lines[i].split(" ")
          if (parts[0] === "UPTIME") overlay.statUptime = lines[i].substring(7).toUpperCase()
          else if (parts[0] === "RAM") { overlay.statRamUsed = Number(parts[1]); overlay.statRamTotal = Math.max(1, Number(parts[2])) }
          else if (parts[0] === "DISK") { overlay.statDiskPct = parts[1]; overlay.statDiskFree = Number(parts[2]) }
          else if (parts[0] === "LOAD") overlay.statLoad = lines[i].substring(5)
        }
      }
    }
  }

  Timer {
    interval: 2000
    repeat: true
    running: overlay.key === "status"
    triggeredOnStart: true
    onTriggered: overlay.refreshStats()
  }

  // ---- countdown (counter window). Label and target date come from the
  // user config's [counter] section; defaults to end of the current year.
  readonly property var counterConfig: bar && bar.pactConfig && bar.pactConfig.counter ? bar.pactConfig.counter : ({})
  readonly property string counterLabel: typeof counterConfig.label === "string" && counterConfig.label
    ? counterConfig.label : "PREGNANCY OPPORTUNITY TIME"
  property int cdDays: 0
  property int cdHours: 0
  property int cdMins: 0

  function counterTarget(now) {
    var raw = typeof counterConfig.date === "string" ? counterConfig.date : ""
    var m = raw.match(/^(\d{4})-(\d{2})-(\d{2})$/)
    if (m) {
      var t = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]))
      if (t > now) return t
    }
    return new Date(now.getFullYear() + 1, 0, 1)
  }

  Timer {
    interval: 1000
    repeat: true
    running: overlay.key === "counter"
    triggeredOnStart: true
    onTriggered: {
      var now = new Date()
      var ms = overlay.counterTarget(now) - now
      overlay.cdDays = Math.floor(ms / 86400000)
      overlay.cdHours = Math.floor(ms % 86400000 / 3600000)
      overlay.cdMins = Math.floor(ms % 3600000 / 60000)
    }
  }

  // Scrim; click anywhere closes.
  Rectangle {
    anchors.fill: parent
    color: Util.alpha("#040807", 0.6)

    MouseArea {
      anchors.fill: parent
      onPressed: overlay.bar.pactCloseWindow()
    }

    // Card
    Rectangle {
      anchors.centerIn: parent
      width: content.implicitWidth + Style.space(48)
      height: content.implicitHeight + Style.space(48) + titlebar.height
      color: "#040807"
      border.width: 1
      border.color: overlay.key === "emergency" ? overlay.amber : overlay.frame

      // Mint filled titlebar, like the Relic Database windows.
      Rectangle {
        id: titlebar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 1
        height: Style.space(26)
        color: overlay.key === "emergency" ? overlay.amber : overlay.mint

        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          text: overlay.key === "status" ? "SILO SYSTEMS STATUS"
            : overlay.key === "counter" ? "PACT MEDICAL"
            : "EMERGENCY BROADCAST"
          color: "#0a1110"
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }
        Text {
          anchors.right: parent.right
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          text: "X"
          color: "#0a1110"
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }
      }

      Item {
        id: content
        anchors.top: titlebar.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Style.space(24)
        implicitWidth: statusPane.visible ? statusPane.implicitWidth
          : counterPane.visible ? counterPane.implicitWidth : emergencyPane.implicitWidth
        implicitHeight: statusPane.visible ? statusPane.implicitHeight
          : counterPane.visible ? counterPane.implicitHeight : emergencyPane.implicitHeight

        // ---------- STATUS
        Column {
          id: statusPane
          visible: overlay.key === "status"
          spacing: Style.space(10)

          Repeater {
            model: [
              ["UPTIME", overlay.statUptime],
              ["LOAD", overlay.statLoad],
              ["RAM", Math.round(overlay.statRamUsed / overlay.statRamTotal * 100) + "%  OF  " + Math.round(overlay.statRamTotal / 1073741824) + " GB"],
              ["DISK", overlay.statDiskPct + " USED"],
            ]
            Row {
              required property var modelData
              spacing: Style.space(16)
              Text {
                width: Style.space(90)
                text: modelData[0]
                color: overlay.mint
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
              }
              Text {
                text: String(modelData[1])
                color: overlay.text
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
              }
            }
          }

          // Footer in the style of "DISK 10% RAM 40% 38911 BYTES FREE".
          Text {
            topPadding: Style.space(12)
            text: "DISK " + overlay.statDiskPct + "  RAM " + Math.round(overlay.statRamUsed / overlay.statRamTotal * 100) + "%  " + overlay.statDiskFree.toLocaleString(Qt.locale(), "f", 0) + " BYTES FREE"
            color: overlay.yellow
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
        }

        // ---------- COUNTER
        Column {
          id: counterPane
          visible: overlay.key === "counter"
          spacing: Style.space(10)

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: overlay.counterLabel
            color: "#bfe6f2"
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.letterSpacing: Style.spaceReal(3)
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "DAYS"
            color: overlay.mint
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: dayText.implicitWidth + Style.space(40)
            height: dayText.implicitHeight + Style.space(20)
            radius: Style.space(10)
            color: overlay.paleYellow
            Text {
              id: dayText
              anchors.centerIn: parent
              text: String(overlay.cdDays)
              color: "#403a22"
              font.family: Style.font.family
              font.pixelSize: Style.font.displayLarge
              font.bold: true
            }
          }
          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(30)
            Repeater {
              model: [["HRS", overlay.cdHours], ["MNS", overlay.cdMins]]
              Column {
                required property var modelData
                spacing: Style.space(4)
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: modelData[0]
                  color: overlay.mint
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                }
                Rectangle {
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: Style.space(46)
                  height: Style.space(22)
                  radius: height / 2
                  color: "transparent"
                  border.width: 1
                  border.color: overlay.frame
                  Text {
                    anchors.centerIn: parent
                    text: String(modelData[1])
                    color: overlay.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                  }
                }
              }
            }
          }
        }

        // ---------- EMERGENCY
        Column {
          id: emergencyPane
          visible: overlay.key === "emergency"
          spacing: Style.space(14)

          Text {
            id: alertText
            anchors.horizontalCenter: parent.horizontalCenter
            text: "⚠ EMERGENCY ⚠"
            color: overlay.amber
            font.family: Style.font.family
            font.pixelSize: Style.font.display
            font.bold: true

            SequentialAnimation on opacity {
              running: emergencyPane.visible
              loops: Animation.Infinite
              NumberAnimation { to: 0.25; duration: 450 }
              NumberAnimation { to: 1.0; duration: 450 }
            }
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "SHELTER IN PLACE\nREPORT TO YOUR LEVEL DEPUTY\nDO NOT ATTEMPT TO LEAVE THE SILO"
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 1.4
            color: overlay.text
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
          }
        }
      }
    }
  }
}
