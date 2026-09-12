import Quickshell

PersistentProperties {
    required property ShellScreen modelData

    // Drawer visibilities
    property bool bar
    property bool osd
    property bool session
    property bool launcher
    property bool dashboard
    property bool utilities
    property bool sidebar
    property bool displaySelect
    property bool soundPanel
    property bool clipboardRequested
    property bool wallpaperRequested
    property bool manga
    property bool novel
    property bool calendar

    // Dashboard state
    property int dashboardTab
    property date dashboardDate: new Date()
}
