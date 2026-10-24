pragma Singleton
import QtQuick

QtObject {
    id: root

    property ListModel queue: ListModel {}
    property int nextId: 0

    function show(message, icon) {
        queue.append({
            toastId: nextId++,
            message: message,
            icon: icon ?? ""
        });
    }

    function dismiss(toastId) {
        for (let i = 0; i < queue.count; i++) {
            if (queue.get(i).toastId === toastId) {
                queue.remove(i);
                return;
            }
        }
    }
}
