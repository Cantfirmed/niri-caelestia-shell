pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Plugins")
    isSubPage: false

    function setReaderEnabled(id: string, enabled: bool): void {
        if (id === "manga") {
            GlobalConfig.extra.manga = enabled;
            if (!enabled)
                closeOnAllScreens("manga");
        } else if (id === "novel") {
            GlobalConfig.extra.novel = enabled;
            if (!enabled)
                closeOnAllScreens("novel");
        }
    }

    function closeOnAllScreens(prop: string): void {
        const active = Visibilities.getForActive();
        if (active)
            active[prop] = false;

        const screens = Visibilities.screens ?? {};
        for (const name in screens) {
            const vis = screens[name];
            if (vis && vis !== active)
                vis[prop] = false;
        }
    }

    function openReader(id: string): void {
        const state = ShellState.forActive();
        if (!state)
            return;

        if (id === "manga")
            state.manga = true;
        else if (id === "novel")
            state.novel = true;
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Readers")
        }

        PluginRow {
            first: true

            icon: "manga"
            title: Tr.tr("Manga reader")
            description: Tr.tr("Browse and read manga, manhwa, and manhua · Mod+M")
            statusText: checked ? Tr.tr("Enabled") : Tr.tr("Disabled")
            checked: GlobalConfig.extra.manga
            actionVisible: checked

            onToggled: checked => root.setReaderEnabled("manga", checked)
            onActivated: root.openReader("manga")
        }

        PluginRow {
            last: true

            icon: "book"
            title: Tr.tr("Novel reader")
            description: Tr.tr("Browse and read light novels and web novels · Mod+Shift+M")
            statusText: checked ? Tr.tr("Enabled") : Tr.tr("Disabled")
            checked: GlobalConfig.extra.novel
            actionVisible: checked

            onToggled: checked => root.setReaderEnabled("novel", checked)
            onActivated: root.openReader("novel")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            Layout.leftMargin: Tokens.padding.small
            Layout.rightMargin: Tokens.padding.small

            text: Tr.tr("Disabling a plugin stops its local backend and closes it on every screen. Enable it again at any time — nothing is deleted.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }
    }
}
