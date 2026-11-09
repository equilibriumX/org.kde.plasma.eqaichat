/***************************************************************************
 *   Copyright 2026 by Barnak Zlatko <equilibrium@barnak.co.rs>             *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA .        *
 ***************************************************************************/

import QtQuick
import QtWebEngine
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

PlasmoidItem {
    id: root

    width: Kirigami.Units.gridUnit * 30
    height: Kirigami.Units.gridUnit * 22

    // Kontrola aktivnog stanja procesa (default: true)
    property bool isEngineActive: true

    // Ograničenja minimalne veličine (širina x visina)
    Layout.minimumWidth: 450
    Layout.minimumHeight: 750

    Plasmoid.backgroundHints: Plasma.StandardBackground

    // 1. KOMPAKTNI PRIKAZ NA PANELU
    compactRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.iconSize.small
        Layout.minimumHeight: Kirigami.Units.iconSize.small

        Kirigami.Icon {
            anchors.fill: parent
            source: Qt.resolvedUrl(getIcon())
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    function getIcon() {
        if (Plasmoid.configuration.useCustomIcon && Plasmoid.configuration.customIconPath) {
            return "file://" + Plasmoid.configuration.customIconPath;
        }
        return "assets/eq-aichat.svg";
    }

    // 2. ISKAČUĆI PROZOR (POPUP)
    fullRepresentation: Item {
        Layout.minimumWidth: 450
        Layout.minimumHeight: 750

        anchors.fill: parent

        // LOADER: Dinamički učitava i uništava WebEngineView
        Loader {
            id: webEngineLoader
            anchors.fill: parent
            active: root.isEngineActive
            sourceComponent: webViewComponent
        }

        // Prikaz stanja kada je plasmoid u stanju mirovanja (ugašen)
        Rectangle {
            anchors.fill: parent
            visible: !root.isEngineActive
            color: Kirigami.Theme.backgroundColor


            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 48
                    implicitHeight: 48
                    source: "dialog-warning"
                }

                PlasmaComponents.Label {
                    text: i18n("Plasmoid processes are stopped (Standby)")
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                PlasmaComponents.Label {
                    text: i18n("Memory and CPU have been freed. Click the green button to restart.")
                    opacity: 0.7
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // Komponenta koja se uništava iz memorije kada je isEngineActive = false
        Component {
            id: webViewComponent

            Item {
                id: webContainer
                anchors.fill: parent
                            anchors.bottomMargin: 8

                // Izlažemo webview spoljnom svetu kroz svojstvo radi lakšeg pristupa
                property alias webview: webview

                PlasmaComponents.Menu {
                    id: linkContextMenu
                    parent: webview

                    property string link

                    PlasmaComponents.MenuItem {
                        text: i18nc("@action:inmenu", "Open Link in Browser")
                        icon.name: "search-symbolic"
                        onClicked: Qt.openUrlExternally(linkContextMenu.link)
                    }

                    PlasmaComponents.MenuItem {
                        text: i18nc("@action:inmenu", "Copy Link Address")
                        icon.name: "edit-copy"
                        onClicked: webview.triggerWebAction(WebEngineView.CopyLinkToClipboard)
                    }
                }

                WebEngineView {
                    id: webview
                    anchors.fill: parent
                    clip: true
                    zoomFactor: 1.0

                    visible: true
                    focus: Plasmoid.expanded

                    settings.accelerated2dCanvasEnabled: true
                    settings.webGLEnabled: true
                    settings.localStorageEnabled: true
                    settings.javascriptEnabled: true

                    profile: WebEngineProfile {
                        storageName: "EQChatGPTProfile"
                        offTheRecord: false
                        httpCacheMaximumSize: 100 * 1024 * 1024
                    }

                    onUrlChanged: {
                        if (Plasmoid.configuration) {
                            Plasmoid.configuration.url = url;
                        }
                    }

                    Component.onCompleted: {
                        if (Plasmoid.configuration && Plasmoid.configuration.url) {
                            url = Plasmoid.configuration.url;
                        } else {
                            url = "https://chatgpt.com";
                        }
                    }

                    onLinkHovered: (hoveredUrl) => {
                        if (hoveredUrl.toString() !== "") {
                            mouseArea.cursorShape = Qt.PointingHandCursor;
                        } else {
                            mouseArea.cursorShape = Qt.ArrowCursor;
                        }
                    }

                    onLoadingChanged: (loadRequest) => {
                        if (loadRequest.status === 0) {
                            infoButton.dismiss();
                        }
                    }

                    onContextMenuRequested: (request) => {
                        if (request.linkUrl.toString() !== "") {
                            linkContextMenu.link = request.linkUrl;
                            linkContextMenu.open(request.x, request.y);
                            request.accepted = true;
                        }
                    }

                    onNewWindowRequested: (request) => {
                        var requestedUrl = request.requestedUrl;

                        if (request.userInitiated) {
                            Qt.openUrlExternally(requestedUrl);
                        } else {
                            infoButton.show(i18nc("An unwanted popup was blocked", "Popup blocked"), "document-close",
                                            i18n("Click here to open the following blocked popup:\n%1", requestedUrl), function () {
                                Qt.openUrlExternally(requestedUrl);
                                infoButton.dismiss();
                            });
                        }
                    }
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    acceptedButtons: Qt.BackButton | Qt.ForwardButton
                    // Omogućavamo da klikovi prolaze kroz MouseArea ukoliko nisu navigacioni tasteri miša
                    propagateComposedEvents: true
                    onPressed: (mouse) => {
                        if (mouse.button === Qt.BackButton) {
                            webview.goBack();
                            mouse.accepted = true;
                        } else if (mouse.button === Qt.ForwardButton) {
                            webview.goForward();
                            mouse.accepted = true;
                        } else {
                            mouse.accepted = false;
                        }
                    }
                }
            }
        }

        // LEVA PLUTAJUĆA TRAKA (Navigacija)
        Rectangle {
            id: leftFloatingBar
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 1
            anchors.bottomMargin: -6

            height: 34
            width: leftRow.width + 6
            radius: 5

            color: Kirigami.Theme.backgroundColor
            opacity: 0.90
            border.width: 0
            z: 100 // Povećan z-index da uvek bude iznad sadržaja

            RowLayout {
                id: leftRow
                anchors.centerIn: parent
                spacing: 2

                PlasmaComponents.Button {
                    icon.name: "go-previous"
                    onClicked: {
                        if (webEngineLoader.item && webEngineLoader.item.webview) {
                            webEngineLoader.item.webview.goBack();
                        }
                    }
                    enabled: root.isEngineActive && webEngineLoader.item !== null
                }

                PlasmaComponents.Button {
                    icon.name: "go-next"
                    onClicked: {
                        if (webEngineLoader.item && webEngineLoader.item.webview) {
                            webEngineLoader.item.webview.goForward();
                        }
                    }
                    enabled: root.isEngineActive && webEngineLoader.item !== null
                }
            }
        }

        // DESNA PLUTAJUĆA TRAKA
        Rectangle {
            id: rightFloatingBar
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 1
            anchors.bottomMargin: -6

            height: 34
            width: rightRow.width + 6
            radius: 5

            color: Kirigami.Theme.backgroundColor
            opacity: 0.90
            border.width: 0
            z: 100 // Povećan z-index da uvek bude iznad sadržaja

            RowLayout {
                id: rightRow
                anchors.centerIn: parent
                spacing: 2

                PlasmaComponents.ToolButton {
                    id: infoButton
                    visible: false
                    property var cb
                    onClicked: cb()
                    function show(buttonText, iconName, tooltipText, callback) {
                        infoButton.text = buttonText;
                        infoButton.icon.name = iconName;
                        infoButton.cb = callback;
                        infoButton.visible = true;
                    }
                    function dismiss() {
                        infoButton.visible = false;
                    }
                }

                PlasmaComponents.Button {
                    icon.name: "go-home"
                    enabled: root.isEngineActive && webEngineLoader.item !== null
                    onClicked: {
                        if (webEngineLoader.item && webEngineLoader.item.webview) {
                            webEngineLoader.item.webview.url = "https://chatgpt.com";
                        }
                    }
                }

                PlasmaComponents.Button {
                    icon.name: "list-add"
                    enabled: root.isEngineActive && webEngineLoader.item !== null
                    onClicked: {
                        if (webEngineLoader.item && webEngineLoader.item.webview) {
                            webEngineLoader.item.webview.url = "https://chatgpt.com/library";
                        }
                    }
                }

                PlasmaComponents.Button {
                    icon.name: "view-refresh"
                    enabled: root.isEngineActive && webEngineLoader.item !== null
                    onClicked: {
                        if (webEngineLoader.item && webEngineLoader.item.webview) {
                            webEngineLoader.item.webview.reload();
                        }
                    }
                }

                // DUGME ZA GAŠENJE / POKRETANJE PROCESA
                PlasmaComponents.Button {
                    id: powerButton
                    icon.name: root.isEngineActive ? "application-exit" : "media-playback-start"

                    background: Rectangle {
                        color: root.isEngineActive ? "#d9534f" : "#5cb85c"
                        radius: 4
                        border.color: Qt.darker(color, 1.2)
                        border.width: 1
                    }

                    onClicked: {
                        root.isEngineActive = !root.isEngineActive;
                    }

                    PlasmaComponents.ToolTip {
                        text: root.isEngineActive ? i18n("Stop all processes and free memory") : i18n("Start plasmoid again")
                    }
                }
            }
        }
    }
}
