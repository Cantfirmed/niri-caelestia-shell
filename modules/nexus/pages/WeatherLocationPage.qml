
import QtQuick
import QtQuick.Layouts
import QtPositioning
import QtLocation
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    property var selectedCoord: QtPositioning.coordinate(52.5244, 13.4105)
    property bool isSearching: false
    property bool isReverseGeocoding: false
    property var searchResults: []
    property string reverseGeocodedCity: ""

    function applyLocation(lat, lon, cityName) {
        const latNum = Number(lat);
        const lonNum = Number(lon);
        if (!Number.isFinite(latNum) || !Number.isFinite(lonNum))
            return;

        const coordsStr = `${latNum.toFixed(4)},${lonNum.toFixed(4)}`;
        if (cityName) {
            Weather.cacheCity(coordsStr, cityName);
            reverseGeocodedCity = cityName;
        }

        GlobalConfig.services.weatherLocation = coordsStr;
        selectedCoord = QtPositioning.coordinate(latNum, lonNum);
        map.center = selectedCoord;
        latInput.text = latNum.toFixed(4);
        lonInput.text = lonNum.toFixed(4);
    }

    function setAutomatic() {
        reverseGeocodedCity = "";
        GlobalConfig.services.weatherLocation = "";
        updateFromCurrent();
    }

    function reverseGeocode(lat, lon) {
        const latFixed = lat.toFixed(4);
        const lonFixed = lon.toFixed(4);
        const lang = Qt.locale().name.split("_")[0] || "en";
        const nominatimUrl = `https://nominatim.openstreetmap.org/reverse?lat=${latFixed}&lon=${lonFixed}&format=geocodejson&accept-language=${lang}`;
        const nominatimHeaders = {
            "User-Agent": "caelestia-shell"
        };

        isReverseGeocoding = true;
        reverseGeocodedCity = Tr.tr("Locating...");

        Requests.get(nominatimUrl, text => {
            isReverseGeocoding = false;
            let foundCity = "";
            try {
                const parsed = JSON.parse(text);
                const feats = parsed && parsed.features;
                const feat = feats && feats.length > 0 ? feats[0] : null;
                const props = feat && feat.properties;
                const geo = props && props.geocoding;
                if (geo) {
                    foundCity = geo.type === "city" ? geo.name : (geo.city || geo.locality || geo.name || "");
                }
            } catch (e) {
                console.warn("Reverse geocode parse error:", e);
            }

            if (foundCity) {
                foundCity = Weather.fixCityName(foundCity);
                reverseGeocodedCity = foundCity;
                applyLocation(lat, lon, foundCity);
            } else {
                reverseGeocodedCity = "";
                applyLocation(lat, lon, "");
            }
        }, err => {
            isReverseGeocoding = false;
            reverseGeocodedCity = "";
            applyLocation(lat, lon, "");
        }, nominatimHeaders);
    }

    function searchLocation(query) {
        const trimmed = (query || "").trim();
        if (trimmed.length < 2) {
            searchResults = [];
            isSearching = false;
            return;
        }

        const coordMatch = trimmed.match(/^([-+]?\d+(?:\.\d+)?)\s*,\s*([-+]?\d+(?:\.\d+)?)$/);
        if (coordMatch) {
            const lat = parseFloat(coordMatch[1]);
            const lon = parseFloat(coordMatch[2]);
            if (lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180) {
                searchResults = [{
                    name: Tr.tr("Coordinates"),
                    latitude: lat,
                    longitude: lon,
                    country: "",
                    admin1: `${lat.toFixed(4)}, ${lon.toFixed(4)}`
                }];
                isSearching = false;
                return;
            }
        }

        const lang = Qt.locale().name.split("_")[0] || "en";
        const url = `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(trimmed)}&count=6&language=${lang}&format=json`;

        isSearching = true;
        Requests.get(url, text => {
            isSearching = false;
            try {
                const json = JSON.parse(text);
                searchResults = json.results || [];
            } catch (e) {
                searchResults = [];
            }
        }, err => {
            isSearching = false;
            searchResults = [];
        });
    }

    function updateFromCurrent() {
        let lat = 52.5244;
        let lon = 13.4105;
        let hasCoords = false;

        const configLoc = GlobalConfig.services.weatherLocation;
        if (configLoc && configLoc.indexOf(",") !== -1) {
            const parts = configLoc.split(",");
            const pLat = parseFloat(parts[0]);
            const pLon = parseFloat(parts[1]);
            if (Number.isFinite(pLat) && Number.isFinite(pLon)) {
                lat = pLat;
                lon = pLon;
                hasCoords = true;
            }
        } else if (Weather.loc && Weather.loc.indexOf(",") !== -1) {
            const parts = Weather.loc.split(",");
            const pLat = parseFloat(parts[0]);
            const pLon = parseFloat(parts[1]);
            if (Number.isFinite(pLat) && Number.isFinite(pLon)) {
                lat = pLat;
                lon = pLon;
                hasCoords = true;
            }
        }

        selectedCoord = QtPositioning.coordinate(lat, lon);
        map.center = selectedCoord;
        latInput.text = lat.toFixed(4);
        lonInput.text = lon.toFixed(4);
        if (hasCoords)
            map.zoomLevel = 10;
    }

    title: Tr.tr("Weather location")
    isSubPage: true

    Component.onCompleted: updateFromCurrent()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Timer {
            id: searchDebounceTimer
            interval: 350
            repeat: false
            onTriggered: root.searchLocation(searchBar.text)
        }

        // Current Location Status
        SectionHeader {
            first: true
            text: Tr.tr("Current status")
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: statusRow.implicitHeight + Tokens.padding.large * 2

            RowLayout {
                id: statusRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: GlobalConfig.services.weatherLocation ? "location_on" : "my_location"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.large
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall / 2

                    RowLayout {
                        spacing: Tokens.spacing.small

                        StyledText {
                            text: {
                                if (Weather.city)
                                    return Weather.city;
                                if (root.reverseGeocodedCity)
                                    return root.reverseGeocodedCity;
                                return GlobalConfig.services.weatherLocation ? Tr.tr("Custom location") : Tr.tr("Locating...");
                            }
                            font: Tokens.font.title.small
                            elide: Text.ElideRight
                        }

                        StyledRect {
                            color: Colours.palette.m3secondaryContainer
                            radius: Tokens.rounding.full
                            implicitWidth: badgeText.implicitWidth + Tokens.padding.small * 2
                            implicitHeight: badgeText.implicitHeight + Tokens.padding.extraSmall

                            StyledText {
                                id: badgeText
                                anchors.centerIn: parent
                                text: GlobalConfig.services.weatherLocation ? Tr.tr("Custom") : Tr.tr("Automatic")
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSecondaryContainer
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            if (GlobalConfig.services.weatherLocation)
                                return Tr.tr("Coordinates: %1").arg(GlobalConfig.services.weatherLocation);
                            return Tr.tr("Automatic (IP geolocation) • %1").arg(Weather.loc || Tr.tr("Locating..."));
                        }
                        font: Tokens.font.body.small
                        color: Colours.palette.m3outline
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        visible: Weather.temp !== ""
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: Weather.icon
                            color: Colours.palette.m3primary
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            text: Weather.temp
                            font: Tokens.font.label.medium
                            color: Colours.palette.m3onSurface
                        }

                        StyledText {
                            text: Weather.description
                            font: Tokens.font.label.small
                            color: Colours.palette.m3outline
                        }
                    }
                }

                IconTextButton {
                    icon: "my_location"
                    text: Tr.tr("Reset to auto")
                    type: IconTextButton.Tonal
                    visible: GlobalConfig.services.weatherLocation !== ""
                    onClicked: root.setAutomatic()
                }
            }
        }

        // Search Section
        SectionHeader {
            text: Tr.tr("Search city")
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: searchResults.length === 0 && !root.isSearching && searchBar.text.trim().length < 2
            implicitHeight: searchLayout.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: searchLayout
                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                SearchBar {
                    id: searchBar
                    Layout.fillWidth: true
                    placeholderText: Tr.tr("Search city, region, or coordinates...")
                    onTextEdited: {
                        if (text.trim().length < 2) {
                            searchDebounceTimer.stop();
                            root.searchResults = [];
                            root.isSearching = false;
                        } else {
                            searchDebounceTimer.restart();
                        }
                    }
                    onAccepted: root.searchLocation(text)
                }

                IconTextButton {
                    icon: "search"
                    text: Tr.tr("Search")
                    type: IconTextButton.Tonal
                    onClicked: root.searchLocation(searchBar.text)
                }
            }
        }

        // Search Results List
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            visible: searchResults.length > 0 || root.isSearching || (searchBar.text.trim().length >= 2 && !root.isSearching)

            ConnectedRect {
                visible: root.isSearching
                Layout.fillWidth: true
                first: false
                last: true
                implicitHeight: 48

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    StyledBusyIndicator {
                        running: root.isSearching
                    }

                    StyledText {
                        text: Tr.tr("Searching locations...")
                        font: Tokens.font.body.small
                        color: Colours.palette.m3outline
                    }
                }
            }

            ConnectedRect {
                visible: !root.isSearching && root.searchResults.length === 0 && searchBar.text.trim().length >= 2
                Layout.fillWidth: true
                first: false
                last: true
                implicitHeight: 48

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "search_off"
                        color: Colours.palette.m3outline
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        text: Tr.tr("No matching locations found")
                        font: Tokens.font.body.small
                        color: Colours.palette.m3outline
                    }
                }
            }

            Repeater {
                model: root.searchResults

                ConnectedRect {
                    id: resultItem

                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    first: false
                    last: index === root.searchResults.length - 1
                    implicitHeight: itemRow.implicitHeight + Tokens.padding.medium * 2

                    StateLayer {
                        onClicked: {
                            root.applyLocation(resultItem.modelData.latitude, resultItem.modelData.longitude, resultItem.modelData.name);
                            root.searchResults = [];
                            searchBar.text = "";
                        }
                    }

                    RowLayout {
                        id: itemRow
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        anchors.leftMargin: Tokens.padding.largeIncreased
                        anchors.rightMargin: Tokens.padding.largeIncreased
                        spacing: Tokens.spacing.medium

                        MaterialIcon {
                            text: "location_city"
                            color: Colours.palette.m3primary
                            fontStyle: Tokens.font.icon.medium
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: resultItem.modelData.name || ""
                                font: Tokens.font.body.medium
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: [resultItem.modelData.admin1, resultItem.modelData.country].filter(Boolean).join(", ")
                                font: Tokens.font.label.small
                                color: Colours.palette.m3outline
                                elide: Text.ElideRight
                            }
                        }

                        StyledText {
                            text: `${Number(resultItem.modelData.latitude).toFixed(2)}°, ${Number(resultItem.modelData.longitude).toFixed(2)}°`
                            font: Tokens.font.label.small
                            color: Colours.palette.m3outline
                        }

                        MaterialIcon {
                            text: "arrow_forward"
                            color: Colours.palette.m3outline
                            fontStyle: Tokens.font.icon.small
                        }
                    }
                }
            }
        }

        // Map Picker Section
        SectionHeader {
            text: Tr.tr("Map picker")
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: mapCard.implicitHeight + Tokens.padding.medium * 2

            ColumnLayout {
                id: mapCard
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Click to set location, drag to explore, scroll or pinch to zoom")
                    font: Tokens.font.body.small
                    color: Colours.palette.m3outline
                }

                StyledClippingRect {
                    Layout.fillWidth: true
                    implicitHeight: 320
                    radius: Tokens.rounding.large
                    clip: true

                    Plugin {
                        id: mapPlugin
                        name: "osm"
                        PluginParameter {
                            name: "osm.useragent"
                            value: "caelestia-shell/1.0"
                        }
                        PluginParameter {
                            name: "osm.mapping.providersrepository.disabled"
                            value: true
                        }
                        PluginParameter {
                            name: "osm.mapping.custom.host"
                            value: "https://tile.openstreetmap.org/"
                        }
                    }

                    Map {
                        id: map
                        anchors.fill: parent
                        plugin: mapPlugin
                        center: root.selectedCoord
                        zoomLevel: 10

                        MapQuickItem {
                            id: pinMarker
                            coordinate: root.selectedCoord
                            anchorPoint.x: pinItem.width / 2
                            anchorPoint.y: pinItem.height

                            sourceItem: Item {
                                id: pinItem
                                width: 36
                                height: 42

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    width: 12
                                    height: 5
                                    radius: 2.5
                                    color: Qt.rgba(0, 0, 0, 0.35)
                                }

                                MaterialIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top
                                    text: "location_on"
                                    fontStyle: Tokens.font.icon.extraLarge
                                    color: Colours.palette.m3primary
                                    fill: 1
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            property point lastPos
                            property bool isDragging: false
                            hoverEnabled: true
                            cursorShape: isDragging ? Qt.ClosedHandCursor : Qt.CrossCursor

                            onPressed: mouse => {
                                lastPos = Qt.point(mouse.x, mouse.y);
                                isDragging = false;
                            }

                            onPositionChanged: mouse => {
                                if (pressed) {
                                    const dx = lastPos.x - mouse.x;
                                    const dy = lastPos.y - mouse.y;
                                    if (Math.abs(dx) > 3 || Math.abs(dy) > 3)
                                        isDragging = true;
                                    lastPos = Qt.point(mouse.x, mouse.y);
                                    map.pan(dx, dy);
                                }
                            }

                            onReleased: mouse => {
                                if (!isDragging) {
                                    const coord = map.toCoordinate(Qt.point(mouse.x, mouse.y));
                                    if (coord.isValid) {
                                        root.selectedCoord = coord;
                                        root.reverseGeocode(coord.latitude, coord.longitude);
                                    }
                                }
                                isDragging = false;
                            }

                            onWheel: wheel => {
                                if (wheel.angleDelta.y > 0)
                                    map.zoomLevel = Math.min(map.maximumZoomLevel, map.zoomLevel + 1);
                                else if (wheel.angleDelta.y < 0)
                                    map.zoomLevel = Math.max(map.minimumZoomLevel, map.zoomLevel - 1);
                            }
                        }

                        PinchHandler {
                            target: null
                            onScaleChanged: delta => {
                                if (delta > 1.05)
                                    map.zoomLevel = Math.min(map.maximumZoomLevel, map.zoomLevel + 0.1);
                                else if (delta < 0.95)
                                    map.zoomLevel = Math.max(map.minimumZoomLevel, map.zoomLevel - 0.1);
                            }
                        }
                    }

                    // Floating Map Controls (Top-Right)
                    ColumnLayout {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: Tokens.padding.medium
                        spacing: Tokens.spacing.extraSmall

                        IconButton {
                            icon: "add"
                            font: Tokens.font.icon.small
                            type: IconButton.Tonal
                            isRound: true
                            onClicked: map.zoomLevel = Math.min(map.maximumZoomLevel, map.zoomLevel + 1)
                        }

                        IconButton {
                            icon: "remove"
                            font: Tokens.font.icon.small
                            type: IconButton.Tonal
                            isRound: true
                            onClicked: map.zoomLevel = Math.max(map.minimumZoomLevel, map.zoomLevel - 1)
                        }

                        IconButton {
                            icon: "my_location"
                            font: Tokens.font.icon.small
                            type: IconButton.Tonal
                            isRound: true
                            onClicked: root.updateFromCurrent()
                        }
                    }

                    // Floating Location Badge (Bottom-Left)
                    StyledRect {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.margins: Tokens.padding.medium
                        color: Colours.tPalette.m3surfaceContainerHigh
                        radius: Tokens.rounding.medium
                        implicitWidth: badgeRow.implicitWidth + Tokens.padding.medium * 2
                        implicitHeight: badgeRow.implicitHeight + Tokens.padding.small * 2

                        RowLayout {
                            id: badgeRow
                            anchors.centerIn: parent
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                text: "pin_drop"
                                color: Colours.palette.m3primary
                                fontStyle: Tokens.font.icon.small
                            }

                            StyledText {
                                text: {
                                    const latStr = root.selectedCoord.latitude.toFixed(4);
                                    const lonStr = root.selectedCoord.longitude.toFixed(4);
                                    if (root.reverseGeocodedCity)
                                        return `${root.reverseGeocodedCity} (${latStr}, ${lonStr})`;
                                    return `${latStr}, ${lonStr}`;
                                }
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurface
                            }
                        }
                    }
                }
            }
        }

        // Manual Coordinates Section
        SectionHeader {
            text: Tr.tr("Coordinates")
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: coordRow.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: coordRow
                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                StyledTextField {
                    id: latInput
                    Layout.fillWidth: true
                    placeholderText: Tr.tr("Latitude (-90 to 90)")
                }

                StyledTextField {
                    id: lonInput
                    Layout.fillWidth: true
                    placeholderText: Tr.tr("Longitude (-180 to 180)")
                }

                IconTextButton {
                    Layout.alignment: Qt.AlignVCenter
                    icon: "check"
                    text: Tr.tr("Apply")
                    type: IconTextButton.Tonal
                    onClicked: {
                        const latVal = parseFloat(latInput.text);
                        const lonVal = parseFloat(lonInput.text);
                        if (!isNaN(latVal) && !isNaN(lonVal) && latVal >= -90 && latVal <= 90 && lonVal >= -180 && lonVal <= 180) {
                            root.reverseGeocode(latVal, lonVal);
                        }
                    }
                }
            }
        }
    }
}
