pragma Singleton

import QtQuick
import Quickshell
import Caelestia
import qs.components
import qs.services

Singleton {
    property ShellRoot shellRoot

    function anySidebarOpen(): bool {
        return states.instances.some(s => s.sidebar);
    }

    function forScreen(screen: ShellScreen): ScreenState {
        for (const s of states.instances)
            if (s.modelData === screen)
                return s;
        return null;
    }

    function forActive(): ScreenState {
        if (typeof Hypr !== "undefined" && Hypr.focusedMonitor) {
            const mon = Hypr.focusedMonitor;
            for (const s of states.instances)
                if (Hypr.monitorFor(s.modelData) === mon)
                    return s;
        }
        const targetName = typeof Niri !== "undefined" ? Niri.focusedMonitorName : "";
        if (targetName) {
            for (const s of states.instances)
                if (s.modelData && s.modelData.name === targetName)
                    return s;
        }
        if (states.instances.length > 0)
            return states.instances[0];
        return null;
    }

    function componentsFor(screen: ShellScreen): Components {
        for (const c of components.instances)
            if (c.modelData === screen)
                return c;
        return null;
    }

    function componentsForActive(): Components {
        if (typeof Hypr !== "undefined" && Hypr.focusedMonitor) {
            const mon = Hypr.focusedMonitor;
            for (const c of components.instances)
                if (Hypr.monitorFor(c.modelData) === mon)
                    return c;
        }
        const targetName = typeof Niri !== "undefined" ? Niri.focusedMonitorName : "";
        if (targetName) {
            for (const c of components.instances)
                if (c.modelData && c.modelData.name === targetName)
                    return c;
        }
        if (components.instances.length > 0)
            return components.instances[0];
        return null;
    }


    Variants {
        id: states

        model: Screens.screens

        ScreenState {}
    }

    Variants {
        id: components

        model: Screens.screens

        Components {}
    }

    component Components: QtObject {
        required property ShellScreen modelData

        property var background
        property var rootWindow
        property var interactionWrapper
        property var bar
        property var panels

        function find(name: string, rootItem: Item): var {
            return CUtils.findChild(rootItem ?? rootWindow?.contentItem, name);
        }

        function findAll(name: string, rootItem: Item): var {
            return CUtils.findChildren(rootItem ?? rootWindow?.contentItem, name);
        }

        function findMatching(pattern: string, rootItem: Item): var {
            return CUtils.findChildrenMatching(rootItem ?? rootWindow?.contentItem, pattern);
        }
    }

    component ComponentRef: QtObject {
        required property ShellScreen screen
        required property string slot
        required property var component

        readonly property QtObject target: ShellState.componentsFor(screen)

        onTargetChanged: {
            if (target)
                target[slot] = component;
        }
        Component.onDestruction: {
            if (target && target[slot] === component)
                target[slot] = null;
        }
    }
}
