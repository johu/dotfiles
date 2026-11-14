import QtQuick
import Quickshell.Services.Pipewire

// Logic-only: exposes playing Pipewire app streams for the inline mixer
// (see AudioMixerCard.qml).
Item {
    id: root

    property list<var> streams: []

    // Computed in refreshStreams(), not a binding: reading .properties
    // subscribes to every stream's propertiesChanged, which churns ~2x/sec
    // during a Discord call.
    property string summaryText: "No apps playing"

    // Pipewire.nodes.values in a plain binding isn't re-evaluated when apps
    // open or close; recompute on onValuesChanged (as caelestia's Audio.qml).
    function refreshStreams() {
        const apps = [];
        for (const node of Pipewire.nodes.values) {
            // Playback only, like pavucontrol's tab: mic capture (Stream/Input/Audio)
            // also passes isStream and showed up as a duplicate app.
            if (node.isStream && node.audio && node.properties?.["media.class"] === "Stream/Output/Audio")
                apps.push(node);
        }
        // Properties churn far more than membership (Discord flips pulse.corked
        // ~2x/sec). Reassigning streams would rebuild every delegate mid-animation,
        // so only do it when the node set changed.
        const unchanged = apps.length === root.streams.length && apps.every((n, i) => n === root.streams[i]);
        if (!unchanged)
            root.streams = apps;
        root.refreshSummaryText();
    }

    // Separate from refreshStreams(): a Proton game's title resolves
    // asynchronously (SteamGameIcon), after the node set is unchanged, so this
    // must not sit behind the unchanged-set early-out.
    function refreshSummaryText() {
        const apps = root.streams;
        // process.binary beats application.name, and a resolved Proton title beats
        // the binary ("wine64-preloader"); see AppVolumeRow.qml.
        root.summaryText = apps.length === 0 ? "No apps playing" : apps.map(n => {
            const pid = n.properties?.["application.process.id"];
            const steamName = pid ? SteamGameIcon.gameNameForPid(pid) : "";
            return steamName || n.properties?.["application.process.binary"] || n.properties?.["application.name"] || n.description || n.name;
        }).join(" · ");
    }

    Component.onCompleted: root.refreshStreams()

    Connections {
        target: Pipewire.nodes
        function onValuesChanged() {
            root.refreshStreams();
        }
    }

    Connections {
        target: SteamGameIcon
        function onCacheChanged() {
            root.refreshSummaryText();
        }
    }

    // onValuesChanged only covers added/removed nodes. A node present at
    // startup whose .properties turns valid later never re-fires it, so its
    // media.class would read empty and be filtered out forever. Re-run the
    // filter when any node becomes ready or its properties update.
    Instantiator {
        model: Pipewire.nodes.values
        delegate: Item {
            required property var modelData

            Connections {
                target: modelData
                function onReadyChanged() {
                    root.refreshStreams();
                }
                function onPropertiesChanged() {
                    root.refreshStreams();
                }
            }
        }
    }

    // PwNode.audio/.properties need a PwObjectTracker; track every node so the
    // media.class filter can read valid properties.
    PwObjectTracker {
        objects: Pipewire.nodes.values
    }
}
