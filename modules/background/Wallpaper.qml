pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.filedialog
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    property string source: Wallpapers.actualCurrent
    property string activeSource: ""
    property CachingImage current
    property bool completed

    onSourceChanged: {
        if (!source) {
            activeSource = "";
            current = null;
        } else if (source !== activeSource) {
            activeSource = source;
            const transitionEnabled = Config.background?.transition?.enabled ?? true;
            current = imgComp.createObject(this, {
                path: source,
                opacity: transitionEnabled ? 1 : (completed ? 0 : 1)
            });
        }
    }

    Component.onCompleted: {
        if (source && !current) {
            activeSource = source;
            current = imgComp.createObject(this, {
                path: source,
                opacity: 1
            });
        }
        completed = true;
    }

    Connections {
        function onFinished(dest) {
            if (dest === root.source && (!root.current || root.current.path !== dest)) {
                root.activeSource = dest;
                root.current = imgComp.createObject(root, {
                    path: dest,
                    opacity: 1
                });
            }
        }

        target: WallFx
    }

    Loader {
        id: missingLoader

        asynchronous: true
        anchors.fill: parent
        active: root.completed && !root.source

        sourceComponent: StyledRect {
            color: Colours.palette.m3surfaceContainer

            Row {
                anchors.centerIn: parent
                spacing: Tokens.spacing.largeIncreased

                MaterialIcon {
                    text: "sentiment_stressed"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.builders.extraLarge.scale(5).build()
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: Tr.tr("Wallpaper missing?")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.builders.large.size(28 * 2).weight(Font.Bold).build()
                    }

                    StyledRect {
                        implicitWidth: selectWallText.implicitWidth + Tokens.padding.extraLargeIncreased
                        implicitHeight: selectWallText.implicitHeight + Tokens.padding.small

                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primary

                        FileDialog {
                            id: dialog

                            title: Tr.tr("Select a wallpaper")
                            filterLabel: Tr.tr("Image files")
                            filters: Images.validImageExtensions
                            onAccepted: path => Wallpapers.setWallpaper(path)
                        }

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3onPrimary
                            onClicked: dialog.open()
                        }

                        StyledText {
                            id: selectWallText

                            anchors.centerIn: parent

                            text: Tr.tr("Set it now!")
                            color: Colours.palette.m3onPrimary
                            font: Tokens.font.body.large
                        }
                    }
                }
            }
        }
    }

    WallpaperTransition {
        id: transition

        z: 1
    }

    Component {
        id: imgComp

        CachingImage {
            id: img

            opacity: 0
            anchors.fill: parent

            onStatusChanged: {
                if (status === Image.Ready && opacity === 0)
                    anim.start();
            }

            Anim on opacity {
                id: anim

                type: Anim.SlowEffects
                running: false
                from: 0
                to: 1
            }

            Timer {
                running: root.current !== img && root.current?.status === Image.Ready
                interval: anim.duration
                onTriggered: img.destroy()
            }
        }
    }
}
