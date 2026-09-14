import QtQuick
import qs.Commons

Item {
  id: root

  property color foreground: Color.foreground
  property color accent: Color.accent
  property color selectedBackground: Color.menu.selectedBackground
  property string fontFamily: Style.font.menuFamily
  property string defaultShortcut: "SUPER + CTRL + SHIFT + L"
  property string shortcut: defaultShortcut
  property string conflict: ""
  property string errorMessage: ""
  property string currentShortcut: ""
  property bool available: false
  property bool checking: false
  property bool installing: false
  property bool recording: false
  property bool launcherInstalled: false
  property bool launcherChecking: false
  property bool launcherInstalling: false
  property string launcherError: ""

  signal recordRequested()
  signal installRequested()
  signal skipRequested()
  signal cancelRequested()
  signal launcherInstallRequested()

  function displayShortcut(value) {
    return String(value || "").replace(/ \+ /g, "  ")
  }

  Column {
    anchors.centerIn: parent
    width: Math.min(parent.width - Style.space(80), Style.space(600))
    spacing: Style.spacing.lg

    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      width: Style.space(72)
      height: width
      radius: width / 2
      color: Style.normalFillFor(root.foreground, root.accent)
      border.color: root.accent
      border.width: Math.max(1, Style.space(1))

      Text {
        anchors.centerIn: parent
        text: "\uf03e"
        color: root.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.display
      }
    }

    Text {
      width: parent.width
      text: "Set up Loopbox"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.display
      font.weight: Font.DemiBold
      horizontalAlignment: Text.AlignHCenter
    }

    Text {
      width: parent.width
      text: root.recording
        ? "Hold the modifiers you want, then press the final key. Loopbox records the complete combination."
        : root.checking
        ? "Checking this chord against current Omarchy and personal Hyprland bindings."
        : root.currentShortcut
        ? "Your active shortcut is " + root.displayShortcut(root.currentShortcut) + ". Record any new key combination to replace it."
        : "Use the suggested shortcut or record your own complete key combination."
      textFormat: Text.PlainText
      color: root.foreground
      opacity: 0.66
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
    }

    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      width: Style.space(440)
      height: Style.space(68)
      radius: Style.cornerRadius
      color: root.recording
        ? Style.hoverFillFor(root.foreground, root.accent)
        : (root.available ? root.selectedBackground : Style.normalFillFor(root.foreground, root.accent))
      border.color: root.conflict || root.errorMessage ? Color.urgent : root.accent
      border.width: root.recording ? Math.max(2, Style.space(2)) : Math.max(1, Style.space(1))

      Column {
        anchors.centerIn: parent
        spacing: Style.spacing.xs

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.recording ? "RECORDING" : "LAUNCH SHORTCUT"
          color: root.recording ? root.accent : root.foreground
          opacity: root.recording ? 1 : 0.56
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.weight: Font.DemiBold
          font.letterSpacing: 0.8
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.recording ? "Press your shortcut now…" : root.displayShortcut(root.shortcut)
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.heading
          font.weight: Font.DemiBold
          font.letterSpacing: 0.5
        }
      }

      MouseArea {
        id: shortcutMouse
        anchors.fill: parent
        enabled: !root.checking && !root.installing
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.recordRequested()
      }
    }

    Text {
      width: parent.width
      text: root.errorMessage
        || (root.recording ? "Hold any modifiers, press a final key · Escape cancels"
        : (root.checking ? "Checking current Hyprland bindings"
        : (root.installing ? "Adding shortcut and reloading Hyprland"
        : (root.conflict ? root.conflict + " already uses this shortcut. Record another combination."
        : (root.available
          ? "This shortcut is available. Save it when you are ready."
          : "Record any modifier-and-key combination.")))))
      textFormat: Text.PlainText
      color: root.errorMessage || root.conflict ? Color.urgent : root.foreground
      opacity: root.errorMessage || root.conflict ? 1 : 0.62
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Style.spacing.lg

      Rectangle {
        width: Style.space(210)
        height: Style.space(48)
        radius: Style.cornerRadius
        color: recordMouse.containsMouse && recordMouse.enabled
          ? Style.hoverFillFor(root.foreground, root.accent)
          : Style.normalFillFor(root.foreground, root.accent)
        border.color: root.recording ? root.accent : Style.normalBorderFor(root.foreground, root.accent)
        border.width: Math.max(1, Style.space(1))

        Text {
          anchors.centerIn: parent
          text: root.recording ? "Recording…" : "Record shortcut"
          color: root.recording || recordMouse.containsMouse ? root.accent : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.weight: Font.DemiBold
        }

        MouseArea {
          id: recordMouse
          anchors.fill: parent
          enabled: !root.checking && !root.installing
          hoverEnabled: true
          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: root.recordRequested()
        }
      }

      Rectangle {
        width: Style.space(210)
        height: Style.space(48)
        radius: Style.cornerRadius
        color: root.available && saveMouse.containsMouse
          ? Style.hoverFillFor(root.foreground, root.accent)
          : (root.available ? root.selectedBackground : Style.normalFillFor(root.foreground, root.accent))
        border.color: root.available ? root.accent : Style.normalBorderFor(root.foreground, root.accent)
        border.width: Math.max(1, Style.space(1))
        opacity: root.available && !root.recording ? 1 : 0.46

        Text {
          anchors.centerIn: parent
          text: root.currentShortcut ? "Save shortcut" : "Use shortcut"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.weight: Font.DemiBold
        }

        MouseArea {
          id: saveMouse
          anchors.fill: parent
          enabled: root.available && !root.recording && !root.checking && !root.installing
          hoverEnabled: true
          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: root.installRequested()
        }
      }
    }

    Rectangle {
      width: parent.width
      height: Math.max(1, Style.space(1))
      color: Style.normalBorderFor(root.foreground, root.accent)
      opacity: 0.72
    }

    Column {
      width: parent.width
      spacing: Style.spacing.md

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Style.space(360)
        height: Style.space(50)
        radius: Style.cornerRadius
        color: launcherMouse.containsMouse && launcherMouse.enabled
          ? Style.hoverFillFor(root.foreground, root.accent)
          : Style.normalFillFor(root.foreground, root.accent)
        border.color: root.launcherError
          ? Color.urgent
          : (root.launcherInstalled ? root.accent : Style.normalBorderFor(root.foreground, root.accent))
        border.width: Math.max(1, Style.space(1))

        Text {
          anchors.centerIn: parent
          text: root.launcherChecking
            ? "Checking Omarchy menu"
            : (root.launcherInstalling
              ? "Adding to Omarchy menu"
              : (root.launcherInstalled
                ? "✓  Added to Omarchy menu"
                : "Add to Omarchy menu"))
          color: root.launcherError
            ? Color.urgent
            : (root.launcherInstalled || launcherMouse.containsMouse ? root.accent : root.foreground)
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.weight: Font.DemiBold
        }

        MouseArea {
          id: launcherMouse
          anchors.fill: parent
          enabled: !root.launcherInstalled && !root.launcherChecking && !root.launcherInstalling
          hoverEnabled: true
          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: root.launcherInstallRequested()
        }
      }

      Text {
        width: parent.width
        text: root.launcherError
          || (root.launcherInstalled
            ? "Press Super+Space and search for gif or Loopbox."
            : "Adds an optional app entry so Super+Space can find Loopbox by typing gif.")
        textFormat: Text.PlainText
        color: root.launcherError ? Color.urgent : root.foreground
        opacity: root.launcherError ? 1 : 0.58
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.currentShortcut ? "Keep current shortcut" : "Use Loopbox without a shortcut"
      color: root.foreground
      opacity: skipMouse.containsMouse ? 0.9 : 0.48
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption

      MouseArea {
        id: skipMouse
        anchors.fill: parent
        anchors.margins: -Style.spacing.md
        enabled: !root.installing
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (root.currentShortcut) root.cancelRequested()
          else root.skipRequested()
        }
      }
    }
  }
}
