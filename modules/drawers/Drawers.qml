pragma ComponentBehavior: Bound

import qs.components
import qs.components.containers
import qs.services
import qs.config
import qs.modules.bar
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

Variants {
    model: Visibilities.activeScreens

    Scope {
        id: scope

        required property ShellScreen modelData

        Exclusions {
            screen: scope.modelData
            bar: bar
        }

        StyledWindow {
            id: win

            screen: scope.modelData
            visible: Visibilities.hasPhysicalScreens
            name: "drawers"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: visibilities.launcher || visibilities.session || visibilities.keybinds || visibilities.editingWeatherLocation || visibilities.dashboard || visibilities.manga || visibilities.novel || visibilities.displaySelect || visibilities.soundPanel || panels.popouts.isDetached ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            mask: Region {
                x: bar.implicitWidth
                y: Config.border.thickness
                width: win.width - bar.implicitWidth - Config.border.thickness
                height: win.height - Config.border.thickness * 2
                intersection: Intersection.Xor

                regions: regions.instances
            }

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Variants {
                id: regions

                model: panels.children

                Region {
                    required property Item modelData

                    x: modelData.x + bar.implicitWidth
                    y: modelData.y + Config.border.thickness
                    width: modelData.visible ? modelData.width : 0
                    height: modelData.visible ? modelData.height : 0
                    intersection: Intersection.Subtract
                }
            }

            // TODO: Implement focus grab for Niri when available

            StyledRect {
                anchors.fill: parent
                opacity: visibilities.session && Config.session.enabled ? 0.5 : 0
                color: Colours.palette.m3scrim

                Behavior on opacity {
                    Anim {}
                }
            }

            Item {
                anchors.fill: parent
                opacity: Colours.transparency.enabled ? Colours.transparency.base : 1
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    blurMax: 15
                    shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.7)
                }

                Border {
                    bar: bar
                }

                Backgrounds {
                    panels: panels
                    bar: bar
                }
            }

            PersistentProperties {
                id: visibilities

                property bool bar
                property bool osd
                property bool session
                property bool launcher
                property bool dashboard
                property bool utilities
                property bool clipboardRequested
                property bool wallpaperRequested
                property bool quicktoggles
                property bool keybinds
                property bool editingWeatherLocation
                property bool notifsExpanded
                property bool manga
                property bool novel
                property bool displaySelect
                property bool soundPanel
                property string _screenName: ""
                Component.onCompleted: {
                    _screenName = scope.modelData.name;
                    Visibilities.screens[_screenName] = this;
                }
                Component.onDestruction: {
                    if (_screenName) {
                        delete Visibilities.screens[_screenName];
                    }
                }
            }

            Interactions {
                screen: scope.modelData
                popouts: panels.popouts
                visibilities: visibilities
                panels: panels
                bar: bar

                Panels {
                    id: panels

                    screen: scope.modelData
                    visibilities: visibilities
                    bar: bar
                }

                BarWrapper {
                    id: bar

                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    screen: scope.modelData
                    visibilities: visibilities
                    popouts: panels.popouts

                    property var _screen: scope.modelData
                    Component.onCompleted: Visibilities.bars.set(_screen, this)
                    Component.onDestruction: {
                        if (_screen) {
                            Visibilities.bars.delete(_screen);
                        }
                    }
                }
            }
        }
    }

}
