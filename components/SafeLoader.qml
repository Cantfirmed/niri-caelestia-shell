import QtQuick

Loader {
    id: loader

    // We use a custom 'activeState' property instead of binding to 'active' directly.
    // Binding directly to the base 'active' property would cause the QML engine to evaluate
    // the binding during teardown/destruction, leading to segmentation faults.
    property bool activeState: false
    property bool dying: false

    Component.onDestruction: dying = true

    Binding {
        target: loader
        property: "active"
        value: loader.activeState
        restoreMode: Binding.RestoreNone
        when: !loader.dying
    }
}
