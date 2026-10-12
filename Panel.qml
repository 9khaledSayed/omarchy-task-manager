import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.9khaledsayed.task-manager"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  property var rawProcesses: []
  property var displayProcesses: []
  property string filterText: ""
  property string sortBy: "cpu"
  property bool onlyUser: false

  property int lastKilledPid: 0
  property real lastKilledTime: 0

  function updateList() {
    displayProcesses = Model.filterAndSort(rawProcesses, filterText, sortBy, onlyUser)
  }

  onRawProcessesChanged: updateList()
  onFilterTextChanged: updateList()
  onSortByChanged: updateList()
  onOnlyUserChanged: updateList()

  function open() {
    root.controller.show()
    root.refresh()
  }

  function close() {
    root.controller.hide()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function refresh() {
    if (!psProc.running) psProc.running = true
  }

  onOpenedChanged: {
    if (opened) root.refresh()
  }

  Component.onCompleted: root.refresh()

  function killProcess(pid) {
    var now = Date.now()
    var force = (pid === root.lastKilledPid && (now - root.lastKilledTime) < 3000)
    root.lastKilledPid = pid
    root.lastKilledTime = now
    killProc.command = ["kill", force ? "-9" : "-15", String(pid)]
    killProc.running = true
  }

  Process {
    id: psProc
    command: ["ps", "-eo", "pid,user,%cpu,%mem,comm", "--sort=-%cpu", "--no-headers"]
    stdout: StdioCollector {
      id: psOut
      waitForEnd: true
      onStreamFinished: {
        var user = Quickshell.env("USER") || "khaled"
        root.rawProcesses = Model.parseProcesses(psOut.text, user)
      }
    }
  }

  Process {
    id: killProc
    onExited: function() {
      killFeedbackTimer.restart()
    }
  }

  Timer {
    id: killFeedbackTimer
    interval: 150
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    id: pollTimer
    interval: 2000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(mainCol.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: searchInput.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: mainCol
        width: parent.width
        spacing: Style.space(8)

        Row {
          width: parent.width
          spacing: Style.space(8)

          Text {
            text: "Task Manager"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: "(" + root.displayProcesses.length + ")"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            anchors.verticalCenter: parent.verticalCenter
          }

          Item {
            width: Math.max(0, mainCol.width - (parent.children[0].implicitWidth + parent.children[1].implicitWidth + controlsRow.implicitWidth + Style.space(16)))
            height: 1
          }

          Row {
            id: controlsRow
            spacing: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter

            PanelActionButton {
              iconText: root.onlyUser ? "\uf007" : "\uf0c0"
              hoverColor: Color.accent
              tooltipText: root.onlyUser ? "Showing user procs (click for all)" : "Showing all procs (click for user only)"
              onClicked: root.onlyUser = !root.onlyUser
            }

            PanelActionButton {
              iconText: "\uf021"
              hoverColor: Color.accent
              tooltipText: "Refresh process list"
              onClicked: root.refresh()
            }
          }
        }

        TextField {
          id: searchInput
          width: parent.width
          placeholderText: "Filter by process name or PID..."
          onTextChanged: root.filterText = text
          Keys.onEscapePressed: {
            if (text.length > 0) {
              text = ""
            } else {
              focus = false
              root.close()
            }
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(4)

          Text {
            width: Style.space(150)
            text: "NAME"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            color: root.sortBy === "name" ? Color.accent : Color.muted
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.sortBy = "name"
            }
          }

          Text {
            width: Style.space(60)
            text: "PID"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            color: Color.muted
          }

          Text {
            width: Style.space(55)
            text: root.sortBy === "cpu" ? "CPU ▼" : "CPU"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            color: root.sortBy === "cpu" ? Color.accent : Color.muted
            horizontalAlignment: Text.AlignRight
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.sortBy = "cpu"
            }
          }

          Text {
            width: Style.space(55)
            text: root.sortBy === "mem" ? "MEM ▼" : "MEM"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            color: root.sortBy === "mem" ? Color.accent : Color.muted
            horizontalAlignment: Text.AlignRight
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.sortBy = "mem"
            }
          }

          Item {
            width: Style.space(10)
            height: 1
          }

          Text {
            width: Style.space(35)
            text: "END"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            color: Color.muted
            horizontalAlignment: Text.AlignHCenter
          }
        }

        PanelSeparator {
          width: parent.width
        }

        ListView {
          id: procListView
          width: parent.width
          height: Style.space(360)
          spacing: Style.space(4)
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          model: root.displayProcesses

          ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
          }

          delegate: Item {
            required property var modelData
            width: ListView.view.width
            height: Style.space(26)

            Row {
              width: parent.width
              spacing: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter

              Text {
                width: Style.space(150)
                text: modelData.name
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                width: Style.space(60)
                text: String(modelData.pid)
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                width: Style.space(55)
                text: modelData.cpu.toFixed(1) + "%"
                color: modelData.cpu >= 15.0 ? Color.urgent : Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignRight
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                width: Style.space(55)
                text: modelData.mem.toFixed(1) + "%"
                color: modelData.mem >= 15.0 ? Color.urgent : Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignRight
                anchors.verticalCenter: parent.verticalCenter
              }

              Item {
                width: Style.space(10)
                height: 1
              }

              Item {
                width: Style.space(35)
                height: Style.space(22)
                anchors.verticalCenter: parent.verticalCenter

                PanelActionButton {
                  anchors.centerIn: parent
                  visible: !modelData.isSystem
                  enabled: !modelData.isSystem
                  iconText: "\uf00d"
                  hoverColor: Color.urgent
                  tooltipText: "Terminate " + modelData.name + " (" + modelData.pid + ")\n(Click again within 3s to force kill)"
                  onClicked: root.killProcess(modelData.pid)
                }

                Text {
                  anchors.centerIn: parent
                  visible: modelData.isSystem
                  text: "\uf023"
                  color: Qt.darker(Color.muted, 1.4)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }
            }
          }
        }
      }
    }
  }
}
