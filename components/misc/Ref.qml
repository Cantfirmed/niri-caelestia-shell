import QtQuick

QtObject {
    id: root

    required property var service
    property bool active: true
    property var _attachedService: null

    function _sync(): void {
        const target = root.active ? root.service : null;
        if (target === root._attachedService)
            return;
        if (root._attachedService)
            root._attachedService.refCount--;
        root._attachedService = target;
        if (target)
            target.refCount++;
    }

    onServiceChanged: _sync()
    onActiveChanged: _sync()
    Component.onCompleted: _sync()
    Component.onDestruction: {
        if (root._attachedService) {
            root._attachedService.refCount--;
            root._attachedService = null;
        }
    }
}
