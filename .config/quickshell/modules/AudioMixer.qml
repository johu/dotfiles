import QtQuick
import Quickshell.Services.Pipewire

// Logic-only: exposes currently-playing Pipewire app streams for the
// inline mixer. No visual representation of its own — see
// AudioMixerCard.qml, embedded in Dashboard.qml's expand section.
Item {
    id: root

    property list<var> streams: []

    // Not a `readonly property: root.streams.map(n => n.properties...)`
    // binding - same reasoning as AppVolumeRow.qml's appName: reading
    // .properties inside a binding subscribes it to every stream's
    // propertiesChanged, which churns ~2x/sec during a Discord voice call.
    // Computed imperatively in refreshStreams() below instead, only when
    // the stream set actually changes.
    property string summaryText: "No apps playing"

    // Mirrors caelestia/shell's Audio.qml refreshNodes(): reading
    // Pipewire.nodes.values inside a plain property binding only captures
    // whatever nodes exist at binding-evaluation time and does not
    // re-evaluate when apps open/close later - nodes.values changing
    // needs an explicit Connections/onValuesChanged to recompute the list.
    function refreshStreams() {
        const apps = [];
        for (const node of Pipewire.nodes.values) {
            // isStream alone covers both directions - an app sending audio
            // out (Stream/Output/Audio) *and* an app capturing input, e.g.
            // Discord's mic capture (Stream/Input/Audio) - both pass
            // isStream+audio and both resolved to the same app name,
            // showing as a duplicate (confirmed via pw-dump: Discord's
            // "playStream" and "recStream" nodes). Scoped to playback only,
            // matching pavucontrol's "Playback" tab per the idea doc.
            if (node.isStream && node.audio && node.properties?.["media.class"] === "Stream/Output/Audio")
                apps.push(node);
        }
        // A stream's `properties` churn far more often than its membership
        // in this list actually changes - Discord's voice stream flips its
        // own `pulse.corked` property roughly twice a second on voice
        // activity (confirmed via pw-dump), firing propertiesChanged on
        // every flip. Reassigning root.streams unconditionally would give
        // it a new array identity each time, rebuilding every
        // AudioMixerCard delegate mid-animation (same flicker class
        // ResourceRow.qml's own comment warns about for a poll-driven
        // array literal) - only reassign when the actual node set changed.
        const unchanged = apps.length === root.streams.length && apps.every((n, i) => n === root.streams[i]);
        if (!unchanged)
            root.streams = apps;
        root.refreshSummaryText();
    }

    // Split out from refreshStreams() - SteamGameIcon's process-tree
    // lookup (see its own comment) resolves asynchronously, so a Proton
    // game's title ("Diablo II: Resurrected") isn't available on the
    // first pass, only once that lookup's Process finishes and bumps
    // SteamGameIcon.cache. The stream node set itself hasn't changed at
    // that point, so this needs to be callable on its own, not gated
    // behind refreshStreams()'s unchanged-node-set early-out above.
    function refreshSummaryText() {
        const apps = root.streams;
        // See AppVolumeRow.qml's appName for why process.binary wins over
        // application.name - and its steamGameName for why a Proton
        // game's resolved title wins over that binary name
        // ("wine64-preloader") when available.
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

    // Pipewire.nodes.values firing onValuesChanged only covers nodes being
    // added/removed - it does NOT fire again for a node that already
    // existed at startup (e.g. joining a Discord voice call before this
    // dashboard/mixer instance loaded) once that node's .properties (read
    // by refreshStreams() above) transitions from invalid to valid. Without
    // this, such a pre-existing stream's media.class reads empty forever
    // and refreshStreams() permanently filters it out, even though
    // Pipewire genuinely has an active Stream/Output/Audio node for it
    // (confirmed via pw-dump). Re-run the filter whenever any node
    // becomes ready or its properties update.
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

    // PwNode.audio/.properties are only valid once bound via
    // PwObjectTracker - track every node (not just the already-filtered
    // subset) so the media.class filter itself can read valid properties.
    PwObjectTracker {
        objects: Pipewire.nodes.values
    }
}
