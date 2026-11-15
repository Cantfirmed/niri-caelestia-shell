pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.services

Item {
    id: root

    readonly property bool transitionReady: oldImg.status === Image.Ready && newImg.status === Image.Ready
        && fieldImg.status === Image.Ready && lineImg.status === Image.Ready

    function crop(img) {
        const iw = Math.max(img.implicitWidth, 1);
        const ih = Math.max(img.implicitHeight, 1);
        const s = Math.max(root.width / iw, root.height / ih);
        const w = root.width / (iw * s);
        const h = root.height / (ih * s);
        return Qt.vector4d((1 - w) / 2, (1 - h) / 2, w, h);
    }

    anchors.fill: parent
    visible: WallFx.active && transitionReady

    onTransitionReadyChanged: {
        if (transitionReady)
            WallFx.screenReady();
    }

    Image {
        id: oldImg

        visible: false
        asynchronous: true
        cache: false
        sourceSize: Qt.size(root.width, root.height)
        fillMode: Image.PreserveAspectCrop
        source: WallFx.oldPath ? (WallFx.oldPath.startsWith("file://") ? WallFx.oldPath : ("file://" + WallFx.oldPath)) : ""
    }

    Image {
        id: newImg

        visible: false
        asynchronous: true
        cache: false
        sourceSize: Qt.size(root.width, root.height)
        fillMode: Image.PreserveAspectCrop
        source: WallFx.newPath ? (WallFx.newPath.startsWith("file://") ? WallFx.newPath : ("file://" + WallFx.newPath)) : ""
    }

    Image {
        id: fieldImg

        visible: false
        asynchronous: true
        cache: false
        smooth: WallFx.kind === "perfil"
        source: WallFx.fieldPath ? (WallFx.fieldPath.startsWith("file://") ? WallFx.fieldPath : ("file://" + WallFx.fieldPath)) : ""
    }

    Image {
        id: lineImg

        visible: false
        asynchronous: true
        cache: false
        source: WallFx.linePath ? (WallFx.linePath.startsWith("file://") ? WallFx.linePath : ("file://" + WallFx.linePath)) : ""
    }

    ShaderEffect {
        id: effect

        property var oldTex: oldImg
        property var newTex: newImg
        property var fieldTex: fieldImg
        property var lineTex: lineImg
        property real t: WallFx.t
        property real mode: WallFx.kind === "perfil" ? 1 : 0
        property real sw: root.width
        property real sh: root.height
        property real fw: Math.max(fieldImg.implicitWidth, 1)
        property real fh: Math.max(fieldImg.implicitHeight, 1)
        property real lw: Math.max(lineImg.implicitWidth, 1)
        property real lh: Math.max(lineImg.implicitHeight, 1)
        property real glow: Config.background?.transition?.glow ?? 0.9
        property real lineW: 1.5
        property real sdRange: 16
        property real seed: WallFx.seed
        property vector4d cropOld: root.crop(oldImg)
        property vector4d cropNew: root.crop(newImg)
        property color ember: WallFx.ember
        property color ink: WallFx.ink

        anchors.fill: parent
        visible: root.visible
        fragmentShader: Qt.resolvedUrl("shaders/wallfx.frag.qsb")
    }
}
