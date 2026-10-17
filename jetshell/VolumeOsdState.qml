pragma Singleton

import Quickshell

Singleton {
    property double suppressUntil: 0

    function suppress() {
        suppressUntil = Date.now() + 300
    }

    function isSuppressed() {
        return Date.now() < suppressUntil
    }
}
