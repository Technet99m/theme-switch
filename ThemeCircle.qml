import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root

    required property var theme
    required property bool isActive
    required property bool isFocused

    signal clicked()
    signal hovered()

    // Set by parent: triggers entrance animation
    property bool popIn:         false
    property int  entranceDelay: 0
    property bool popOut:        false

    // ── Constants ─────────────────────────────────────────────────────────────
    readonly property int circleDiam: 220
    readonly property int widgetSize:  360
    readonly property int ringThin:      6
    readonly property int ringThick:    16

    width:  widgetSize
    height: widgetSize

    // ── Primary color components ───────────────────────────────────────────────
    property color primaryColor: "#" + theme.primary
    property real pr: primaryColor.r
    property real pg: primaryColor.g
    property real pb: primaryColor.b

    // ── Hover / focus → unified scale + ring brightness ────────────────────────
    property bool mouseHovered: false

    // activeT: 0.0 at rest, 1.0 when hovered or keyboard-focused (animated)
    property real activeT: (mouseHovered || isFocused) ? 1.0 : 0.0
    Behavior on activeT {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    // ── Pulse for active ring & glow ───────────────────────────────────────────
    property real pulsePhase: 0.0
    NumberAnimation on pulsePhase {
        from:     0
        to:       Math.PI * 2
        duration: 2000
        loops:    Animation.Infinite
        running:  isActive
    }

    // ── Pop-in entrance ───────────────────────────────────────────────────────
    property real popScale:   0.0
    property real popOpacity: 0.0

    opacity: popOpacity

    SequentialAnimation {
        id: popAnim
        PauseAnimation { duration: root.entranceDelay }
        ParallelAnimation {
            NumberAnimation {
                target: root; property: "popScale"
                from: 0; to: 1
                duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.4
            }
            NumberAnimation {
                target: root; property: "popOpacity"
                from: 0; to: 1
                duration: 200; easing.type: Easing.OutCubic
            }
        }
    }

    onPopInChanged: if (popIn) popAnim.start()

    SequentialAnimation {
        id: popOutAnim
        ParallelAnimation {
            NumberAnimation {
                target: root; property: "popScale"
                to: 0; duration: 180; easing.type: Easing.InBack; easing.overshoot: 1.4
            }
            NumberAnimation {
                target: root; property: "popOpacity"
                to: 0; duration: 140; easing.type: Easing.InCubic
            }
        }
    }

    onPopOutChanged: if (popOut) popOutAnim.start()

    // ── Scale transform (centered) ────────────────────────────────────────────
    transform: Scale {
        origin.x: root.width  / 2
        origin.y: root.height / 2
        xScale: root.popScale * (1.0 + root.activeT * 0.10)
        yScale: root.popScale * (1.0 + root.activeT * 0.10)
    }

    // ── Outer glow (active only) ──────────────────────────────────────────────
    Rectangle {
        visible: isActive
        anchors.centerIn: parent
        readonly property real sz: circleDiam + ringThick * 5
        width: sz; height: sz
        radius: sz / 2
        color: "transparent"
        border.width: ringThick * 3.5
        border.color: Qt.rgba(pr, pg, pb, 0.10 + 0.08 * Math.sin(pulsePhase))
    }

    // ── Primary-color ring ────────────────────────────────────────────────────
    Rectangle {
        anchors.centerIn: parent
        readonly property real rw: isActive ? ringThick : ringThin
        readonly property real sz: circleDiam + rw
        width: sz; height: sz
        radius: sz / 2
        color: "transparent"
        border.width: rw
        border.color: isActive
            ? Qt.rgba(pr, pg, pb, 0.78 + 0.22 * Math.sin(pulsePhase))
            : Qt.rgba(pr, pg, pb, 0.35 + 0.55 * activeT)
    }

    // ── Keyboard focus outline ────────────────────────────────────────────────
    Rectangle {
        visible: isFocused
        anchors.centerIn: parent
        readonly property real innerR: circleDiam / 2 + (isActive ? ringThick : ringThin)
        readonly property real sz: (innerR + 7) * 2
        width: sz; height: sz
        radius: sz / 2
        color: "transparent"
        border.width: 2.5
        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.90)
    }

    // ── Wallpaper circle (circular crop via OpacityMask) ──────────────────────
    Image {
        id: wallpaperImg
        anchors.centerIn: parent
        width: circleDiam; height: circleDiam
        source: theme.wallpaper ? ("file://" + theme.wallpaper) : ""
        fillMode: Image.PreserveAspectCrop
        smooth: true
        mipmap: true
        visible: false
    }

    Rectangle {
        id: circleMask
        anchors.centerIn: parent
        width: circleDiam; height: circleDiam
        radius: circleDiam / 2
        visible: false
    }

    // Solid fallback while image loads (or if missing)
    Rectangle {
        visible: wallpaperImg.status !== Image.Ready
        anchors.centerIn: parent
        width: circleDiam; height: circleDiam
        radius: circleDiam / 2
        color: Qt.rgba(pr, pg, pb, 0.35)
    }

    OpacityMask {
        visible: wallpaperImg.status === Image.Ready
        anchors.centerIn: parent
        width: circleDiam; height: circleDiam
        source: wallpaperImg
        maskSource: circleMask
    }

    // ── Mouse interaction ─────────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: { root.mouseHovered = true; root.hovered() }
        onExited:  root.mouseHovered = false
        onClicked: root.clicked()
    }
}
