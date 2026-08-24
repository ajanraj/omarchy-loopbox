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
  property string defaultConflict: ""
  property string errorMessage: ""
  property bool available: false
  property bool checking: false
  property bool installing: false
  property int candidateIndex: 0
  property int candidateCount: 1

  signal previousRequested()
  signal nextRequested()
  signal installRequested()
  signal skipRequested()

  function displayShortcut(value) {
    return String(value || "").replace(/ \+ /g, "  ")
  }

  Column {
    anchors.centerIn: parent
    width: Math.min(parent.width - Style.space(80), Style.space(600))
    spacing: Style.spacing.xl

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
      text: "Choose a Loopbox shortcut"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.display
      font.weight: Font.DemiBold
      horizontalAlignment: Text.AlignHCenter
    }

    Text {
      width: parent.width
      text: root.checking
        ? "Checking this chord against current Omarchy and personal Hyprland bindings."
        : root.defaultConflict
        ? root.defaultShortcut + " is already used by " + root.defaultConflict + ". Loopbox will never replace an existing shortcut."
        : "The default is free. Press Enter to add it, or type any letter to choose another key."
      color: root.foreground
      opacity: 0.66
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Style.spacing.lg

      Rectangle {
        width: Style.space(44)
        height: Style.space(44)
        radius: Style.cornerRadius
        color: previousMouse.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"
        opacity: root.candidateCount > 1 ? 1 : 0.35

        Text {
          anchors.centerIn: parent
          text: "\uf053"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }

        MouseArea {
          id: previousMouse
          anchors.fill: parent
          enabled: root.candidateCount > 1 && !root.checking && !root.installing
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.previousRequested()
        }
      }

      Rectangle {
        width: Style.space(360)
        height: Style.space(58)
        radius: Style.cornerRadius
        color: root.available ? root.selectedBackground : Style.normalFillFor(root.foreground, root.accent)
        border.color: root.conflict || root.errorMessage ? Color.urgent : root.accent
        border.width: Math.max(1, Style.space(1))

        Text {
          anchors.centerIn: parent
          text: root.displayShortcut(root.shortcut)
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.heading
          font.weight: Font.DemiBold
          font.letterSpacing: 0.5
        }

        MouseArea {
          anchors.fill: parent
          enabled: root.available && !root.checking && !root.installing
          cursorShape: Qt.PointingHandCursor
          onClicked: root.installRequested()
        }
      }

      Rectangle {
        width: Style.space(44)
        height: Style.space(44)
        radius: Style.cornerRadius
        color: nextMouse.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"
        opacity: root.candidateCount > 1 ? 1 : 0.35

        Text {
          anchors.centerIn: parent
          text: "\uf054"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }

        MouseArea {
          id: nextMouse
          anchors.fill: parent
          enabled: root.candidateCount > 1 && !root.checking && !root.installing
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.nextRequested()
        }
      }
    }

    Text {
      width: parent.width
      text: root.errorMessage
        || (root.checking ? "Checking current Hyprland bindings"
        : (root.installing ? "Adding shortcut and reloading Hyprland"
        : (root.conflict ? root.conflict + " already uses this shortcut. Type another letter."
        : (root.available ? "Enter  Use shortcut     Type a letter  Pick key     Tab  Not now" : "Type a letter to choose another shortcut"))))
      color: root.errorMessage || root.conflict ? Color.urgent : root.foreground
      opacity: root.errorMessage || root.conflict ? 1 : 0.62
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "Use Loopbox without a shortcut"
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
        onClicked: root.skipRequested()
      }
    }
  }
}
