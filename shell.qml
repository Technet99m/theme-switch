import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    // ── State ─────────────────────────────────────────────────────────────────
    property var    themes:          []
    property string currentTheme:   ""
    property int    focusedIdx:      0
    property string homeDir:         ""
    property string blurredWallpaper: ""
    property bool   ready:           false
    property var    outputLines:     []
    property real   bgOpacity:        0.0
    property bool   circlesReady:     false
    property bool   circlesClosing:   false
    property string pendingThemePath: ""

    // ── Load themes ───────────────────────────────────────────────────────────
    Process {
        id: loader
        running: true
        command: ["bash", String(Qt.resolvedUrl("load-themes.sh")).replace("file://", "")]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.outputLines.push(data)
        }

        onExited: function(code, status) {
            var ts   = []
            var cur  = ""
            var home = ""

            for (var i = 0; i < root.outputLines.length; i++) {
                var line = root.outputLines[i].trim()
                if (line === "") continue

                if (line.startsWith("HOME:")) {
                    home = line.substring(5)
                    root.homeDir = home
                } else if (line.startsWith("CURRENT:")) {
                    cur = line.substring(8)
                    root.currentTheme = cur
                } else if (line.startsWith("THEME\t")) {
                    var parts = line.split("\t")
                    if (parts.length >= 5) {
                        ts.push({
                            path:      parts[1],
                            name:      parts[2],
                            primary:   parts[3],
                            wallpaper: parts[4]
                        })
                    }
                }
            }

            root.themes = ts

            // Keyboard focus starts on the active theme
            for (var k = 0; k < ts.length; k++) {
                if (ts[k].path === cur) {
                    root.focusedIdx = k
                    break
                }
            }

            // Blurred wallpaper path
            if (cur !== "") {
                var themeId = cur.replace(/.*\//, "").replace(/\.sh$/, "")
                root.blurredWallpaper = home +
                    "/.cache/ml4w/hyprland-dotfiles/blurred_" + themeId + ".png"
            }

            root.ready = true
        }
    }

    // ── Entrance animation: bg fade → circles pop ─────────────────────────────
    SequentialAnimation {
        id: entranceAnim
        NumberAnimation {
            target: root; property: "bgOpacity"
            from: 0; to: 1
            duration: 280; easing.type: Easing.OutCubic
        }
        ScriptAction { script: root.circlesReady = true }
    }

    onReadyChanged: if (ready) entranceAnim.start()

    // ── Exit animation: circles pop out, then instant close ──────────────────
    SequentialAnimation {
        id: exitAnim
        ScriptAction  { script: root.circlesClosing = true }
        PauseAnimation { duration: 200 }
        ScriptAction {
            script: {
                if (root.pendingThemePath !== "") {
                    applyProc.command = [root.homeDir + "/dev/rice/theme-switch/apply.sh",
                                         root.pendingThemePath]
                    applyProc.running = true
                } else {
                    Qt.quit()
                }
            }
        }
    }

    function applyTheme(path) {
        if (!exitAnim.running) {
            root.pendingThemePath = path
            exitAnim.start()
        }
    }

    function closeApp() {
        if (!exitAnim.running) exitAnim.start()
    }

    // ── Apply theme ───────────────────────────────────────────────────────────
    Process {
        id: applyProc
        onExited: Qt.quit()
    }

    // ── Window ────────────────────────────────────────────────────────────────
    PanelWindow {
        id: win
        visible: root.ready

        WlrLayershell.layer:         WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace:     "theme-picker"

        anchors {
            top:    true
            bottom: true
            left:   true
            right:  true
        }
        exclusiveZone: -1

        // ── Root item (needed for focus + Keys) ───────────────────────────────
        Item {
            id: mainItem
            anchors.fill: parent
            focus: true

            // ── Background: solid black base ──────────────────────────────────
            Rectangle {
                anchors.fill: parent
                color: "black"
            }

            // ── Blurred wallpaper ─────────────────────────────────────────────
            Image {
                anchors.fill: parent
                source: root.blurredWallpaper !== ""
                    ? ("file://" + root.blurredWallpaper)
                    : ""
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
                opacity: root.bgOpacity
            }

            // ── Dark overlay ──────────────────────────────────────────────────
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.50)
                opacity: root.bgOpacity
            }

            // ── Theme circles ─────────────────────────────────────────────────
            Row {
                id: circleRow
                anchors.centerIn: parent
                spacing: 70

                Repeater {
                    model: root.themes

                    ThemeCircle {
                        required property var modelData
                        required property int index

                        theme:     modelData
                        isActive:  modelData.path === root.currentTheme
                        isFocused: index === root.focusedIdx

                        popIn:         root.circlesReady
                        entranceDelay: index * 80
                        popOut:        root.circlesClosing

                        onClicked: root.applyTheme(modelData.path)
                        onHovered: root.focusedIdx = index
                    }
                }
            }

            // ── Keyboard navigation ───────────────────────────────────────────
            Keys.onPressed: event => {
                if (!root.ready) return

                switch (event.key) {
                case Qt.Key_Escape:
                    root.closeApp()
                    event.accepted = true
                    break
                case Qt.Key_Left:
                    root.focusedIdx = (root.focusedIdx - 1 + root.themes.length) % root.themes.length
                    event.accepted = true
                    break
                case Qt.Key_Right:
                    root.focusedIdx = (root.focusedIdx + 1) % root.themes.length
                    event.accepted = true
                    break
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    root.applyTheme(root.themes[root.focusedIdx].path)
                    event.accepted = true
                    break
                }
            }
        }
    }
}
