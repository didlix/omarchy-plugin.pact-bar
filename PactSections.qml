import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "PactModel.js" as PactModel

// The PACT workspace sections: a 2×5 grid of numbered, named floors.
// Left-click (or Enter in bar-focus mode) opens the section submenu;
// right-click jumps straight to the workspace. Names and submenu entries
// honour ~/.config/omarchy/pact/config.toml (parsed by the bar root into
// bar.pactConfig). Stateful entries (idle/nightlight/dnd) show their
// inverse label from a live probe and keep the menu open when toggled so
// the flip is visible.
Item {
  id: root

  // The host Bar.qml root ("bar" in widget terms).
  required property QtObject bar

  readonly property var config: bar && bar.pactConfig ? bar.pactConfig : ({})
  readonly property int count: PactModel.sectionCount()

  // "idle"/"nightlight"/"dnd" -> bool, refreshed when a menu opens and
  // shortly after a stateful entry fires.
  property var menuStates: ({})

  implicitWidth: grid.implicitWidth
  implicitHeight: grid.implicitHeight

  function workspaceOccupied(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i].toplevels.values.length > 0
    }
    return false
  }

  function focusWorkspace(id) {
    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + id + "\" })"])
  }

  function runEntry(entry) {
    if (!entry) return
    if (entry.floor) { focusWorkspace(entry.floor); return }
    if (entry.window) { bar.pactShowWindow(entry.window); return }
    if (entry.cli) {
      Quickshell.execDetached([Quickshell.env("HOME") + "/.config/omarchy/plugins/pact.bar/bin/pactcli", "bar", String(entry.cli)])
      return
    }
    if (entry.exec) Quickshell.execDetached(entry.exec)
  }

  function refreshStates() { stateProc.running = true }

  Process {
    id: stateProc
    command: ["sh", "-c", PactModel.stateProbeScript(root.config)]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var next = {}
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
          var parts = lines[i].trim().split(" ")
          if (parts.length === 2) next[parts[0]] = parts[1] === "1"
        }
        root.menuStates = next
      }
    }
  }

  Timer {
    id: reprobeTimer
    interval: 450
    onTriggered: root.refreshStates()
  }

  Connections {
    target: root.bar
    function onPactMenuIndexChanged() {
      if (root.bar.pactMenuIndex >= 0) root.refreshStates()
    }
  }

  // Cells register here so popup anchoring and keyboard focus can find
  // them regardless of layout structure.
  property var cellMap: ({})

  function registerCell(index, item) {
    var next = {}
    for (var k in cellMap) next[k] = cellMap[k]
    next[index] = item
    cellMap = next
  }

  function cellAt(index) {
    return cellMap[index] || null
  }

  // The show's grid justifies space-between: five columns spread across
  // whatever width the bar grants (capped there by sections-max-width),
  // with the base gap as the minimum. Each column is one floor pair.
  RowLayout {
    id: grid
    anchors.fill: parent
    spacing: 0

    Repeater {
      model: 5

      RowLayout {
        id: columnHost
        required property int index
        spacing: 0
        Layout.fillHeight: true

        ColumnLayout {
          spacing: Style.space(2)
          Layout.alignment: Qt.AlignVCenter

          SectionCell { index: columnHost.index * 2 }
          SectionCell { index: columnHost.index * 2 + 1 }
        }

        Item {
          visible: columnHost.index < 4
          Layout.fillWidth: true
          Layout.minimumWidth: Style.space(12)
        }
      }
    }
  }

  component SectionCell: Rectangle {
        id: cell
        required property int index
        readonly property int wsId: index + 1
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === wsId
        readonly property bool occupied: root.workspaceOccupied(wsId)
        readonly property bool keyCursor: root.bar.pactFocusMode && root.bar.pactFocusIndex === index
        readonly property bool menuOpen: root.bar.pactMenuIndex === index

        color: "transparent"
        border.width: 1
        border.color: menuOpen || keyCursor ? Color.pick("pact.amber", "#e8942e")
          : focused ? Color.pick("pact.selected", "#c8da7c") : "transparent"
        implicitWidth: cellRow.implicitWidth + Style.space(6)
        implicitHeight: cellRow.implicitHeight + Style.space(2)

        Row {
          id: cellRow
          anchors.centerIn: parent
          spacing: Style.space(4)

          Text {
            // Occupancy lives in the number: bright when the floor has
            // windows, dim when empty — the name keeps one consistent
            // colour so the grid never looks patchy.
            text: (cell.wsId < 10 ? "0" : "") + cell.wsId
            color: cell.focused ? Color.pick("pact.selected", "#c8da7c")
              : cell.occupied ? Color.pick("pact.text", "#6ac8e8") : Color.pick("pact.dim-text", "#3f6f80")
            font.family: Style.font.family
            font.pixelSize: root.bar.pactMenuSmallFontSize
          }
          Text {
            text: PactModel.sectionName(cell.index, root.config)
            color: cell.focused ? Color.pick("pact.selected", "#c8da7c") : Color.pick("pact.text", "#6ac8e8")
            font.family: Style.font.family
            font.pixelSize: root.bar.pactMenuFontSize
          }
        }

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          cursorShape: Qt.PointingHandCursor
          onPressed: function(mouse) {
            if (mouse.button === Qt.RightButton) root.focusWorkspace(cell.wsId)
            else root.bar.pactToggleMenu(cell.index)
          }
        }

        Component.onCompleted: root.registerCell(index, cell)
  }

  PopupCard {
    id: menuCard
    anchorItem: root.bar.pactMenuIndex >= 0 && root.cellAt(root.bar.pactMenuIndex)
      ? root.cellAt(root.bar.pactMenuIndex) : root
    bar: root.bar
    owner: root
    open: root.bar.pactMenuIndex >= 0
    contentWidth: menuColumn.implicitWidth + padding * 2
    contentHeight: fittedContentHeight(menuColumn.implicitHeight)
    borderColor: Color.pick("pact.frame", "#4fb8d8")

    function close() {
      root.bar.pactCloseMenu()
    }

    readonly property var entries: root.bar.pactMenuIndex >= 0
      ? PactModel.menuEntries(root.bar.pactMenuIndex, root.config) : []

    function activate(i) {
      var entry = entries[i]
      if (entry && entry.state) {
        // Stateful toggle: fire it, keep the menu open, and re-probe so the
        // label flips to the inverse in place.
        root.runEntry(entry)
        reprobeTimer.restart()
        return
      }
      root.bar.pactCloseMenu()
      root.runEntry(entry)
    }

    Column {
      id: menuColumn
      spacing: Style.space(2)

      Repeater {
        model: menuCard.entries

        Rectangle {
          id: entryRow
          required property var modelData
          required property int index
          readonly property bool selected: entryHover.hovered
            || (root.bar.pactFocusMode && root.bar.pactMenuSel === index)

          width: Math.max(menuColumn.implicitWidth, entryText.implicitWidth + Style.space(20))
          height: entryText.implicitHeight + Style.space(8)
          color: selected ? Util.alpha(Color.pick("pact.selected", "#c8da7c"), 0.12) : "transparent"
          border.width: 1
          border.color: selected ? Color.pick("pact.selected", "#c8da7c") : "transparent"

          Text {
            id: entryText
            anchors.left: parent.left
            anchors.leftMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            text: PactModel.entryLabel(entryRow.modelData, root.menuStates)
            color: entryRow.selected ? Color.pick("pact.selected", "#c8da7c") : Color.pick("pact.text", "#6ac8e8")
            font.family: Style.font.family
            font.pixelSize: root.bar.pactMenuFontSize
          }

          HoverHandler { id: entryHover }

          MouseArea {
            anchors.fill: parent
            onPressed: menuCard.activate(entryRow.index)
          }
        }
      }
    }
  }

  // Exposed so the panel key handler can activate the selected menu entry.
  function activateMenuSelection() {
    if (root.bar.pactMenuIndex < 0) return
    menuCard.activate(Math.max(0, root.bar.pactMenuSel))
  }

  function menuEntryCount() {
    return menuCard.entries.length
  }

  Component.onCompleted: root.bar.pactRegisterSections(root)
  Component.onDestruction: root.bar.pactUnregisterSections(root)
}
