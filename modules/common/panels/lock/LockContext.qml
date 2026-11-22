import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

Scope {
    id: root

    enum ActionEnum { Unlock, Poweroff, Reboot }

    signal shouldReFocus()
    signal unlocked(targetAction: var)
    signal failed()

    // These properties are in the context and not individual lock surfaces
    // so all surfaces can share the same state.
    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false
    property bool fingerprintsConfigured: false
    property var targetAction: LockContext.ActionEnum.Unlock
    property bool alsoInhibitIdle: false
    property int failedAttempts: 0
    property bool nativeLockPending: false
    property bool nativeLockRequested: false
    property bool verificationUnavailable: false
    readonly property int maxFailedAttempts: 3
    readonly property bool attemptsExhausted: Platform.isWindows && root.failedAttempts >= root.maxFailedAttempts
    readonly property int attemptsLeft: Math.max(0, root.maxFailedAttempts - root.failedAttempts)

    function handOverToWindows() {
        if (root.nativeLockPending) return;
        root.nativeLockPending = true;
        root.nativeLockRequested = true;
        if (!WindowsNative.session?.requestNativeLock()) {
            root.nativeLockPending = false;
            root.nativeLockRequested = false;
            console.warn("[LockContext] Windows did not accept the native lock request");
        } else {
            nativeLockTimeout.restart();
        }
    }

    Timer {
        id: nativeLockTimeout
        interval: 5000
        onTriggered: {
            if (!root.nativeLockPending) return;
            root.nativeLockPending = false;
            console.warn("[LockContext] Windows lock was not confirmed");
        }
    }

    function resetTargetAction() {
        root.targetAction = LockContext.ActionEnum.Unlock;
    }

    function clearText() {
        root.currentText = "";
    }

    function resetClearTimer() {
        passwordClearTimer.restart();
    }

    function reset() {
        root.nativeLockPending = false;
        root.nativeLockRequested = false;
        root.verificationUnavailable = false;
        nativeLockTimeout.stop();
        root.resetTargetAction();
        root.clearText();
        root.unlockInProgress = false;
        root.setupFirstEntry = "";
        root.setupPending = false;
        stopFingerPam();
    }

    property bool setupExpired: false
    readonly property bool setupNeeded: Platform.isWindows && (Config.options.lock.windowsUnlock ?? "") === "" && !root.setupExpired
    Timer {
        id: setupWindowTimer
        interval: 60000
        onTriggered: {
            root.setupExpired = true;
            root.setupFirstEntry = "";
            root.clearText();
        }
    }
    Connections {
        target: GlobalStates
        function onScreenLockedChanged() {
            root.setupExpired = false;
            root.failedAttempts = 0;
            root.verificationUnavailable = false;
            if (GlobalStates.screenLocked && root.setupNeeded)
                setupWindowTimer.restart();
            else
                setupWindowTimer.stop();
        }
    }
    property string setupFirstEntry: ""
    readonly property bool setupConfirming: root.setupFirstEntry.length > 0
    property bool setupPending: false
    signal setupMismatch()

    function submitSetup() {
        if (!root.setupConfirming) {
            if (root.currentText.length === 0)
                return;
            root.setupFirstEntry = root.currentText;
            root.clearText();
            return;
        }
        if (root.currentText !== root.setupFirstEntry) {
            root.setupFirstEntry = "";
            root.clearText();
            root.setupMismatch();
            return;
        }
        if (WindowsNative.session?.setLockPassword(root.setupFirstEntry)) {
            Config.options.lock.windowsUnlock = "password";
            root.setupFirstEntry = "";
            setupWindowTimer.stop();
            root.unlocked(root.targetAction);
            return;
        }
        root.setupFirstEntry = "";
        root.clearText();
        root.setupMismatch();
    }

    function useWindowsHello() {
        Config.options.lock.windowsUnlock = "hello";
        root.setupFirstEntry = "";
        root.clearText();
        root.shouldReFocus();
    }

    Timer {
        id: passwordClearTimer
        interval: 10000
        onTriggered: {
            if (root.unlockInProgress) {
                passwordClearTimer.restart();
                return;
            }
            root.reset();
        }
    }

    onCurrentTextChanged: {
        if (currentText.length > 0) {
            showFailure = false;
            GlobalStates.screenUnlockFailed = false;
        }
        GlobalStates.screenLockContainsCharacters = currentText.length > 0;
        passwordClearTimer.restart();
    }

    function tryUnlock(alsoInhibitIdle = false) {
        root.alsoInhibitIdle = alsoInhibitIdle;
        root.unlockInProgress = true;
        if (Platform.isWindows) {
            if (root.attemptsExhausted) {
                root.unlockInProgress = false;
                return;
            }
            if (root.setupNeeded) {
                root.unlockInProgress = false;
                root.submitSetup();
                return;
            }
            if (root.currentText.length === 0)
                WindowsNative.session?.verifyUser("Unlock illogical-impulse");
            else if (Config.options.lock.windowsUnlock === "password")
                WindowsNative.session?.verifyLockPassword(root.currentText);
            else
                WindowsNative.session?.verifyPassword(root.currentText);
            return;
        }
        pam.start();
    }

    Connections {
        target: Platform.isWindows ? (WindowsNative.session ?? null) : null
        function onNativeSessionLocked() {
            if (!root.nativeLockRequested) return;
            root.nativeLockPending = false;
            root.nativeLockRequested = false;
            nativeLockTimeout.stop();
            root.failedAttempts = 0;
            root.unlocked(LockContext.ActionEnum.Unlock);
        }
        function onUserVerified(verified, result) {
            if (!root.unlockInProgress)
                return;
            if (result === 101) {
                WindowsNative.session?.verifyUser("Unlock illogical-impulse");
                return;
            }
            const unavailable = result === -1 || result === 1 || result === 2 || result === 3;
            if (root.setupPending) {
                root.setupPending = false;
                if (verified && WindowsNative.session?.setLockPassword(root.setupFirstEntry)) {
                    Config.options.lock.windowsUnlock = "password";
                    root.setupFirstEntry = "";
                    root.unlocked(root.targetAction);
                    return;
                }
                root.setupFirstEntry = "";
                root.clearText();
                root.unlockInProgress = false;
                root.setupMismatch();
                return;
            }
            if (verified) {
                root.failedAttempts = 0;
                root.unlocked(root.targetAction);
                return;
            }
            if (unavailable) {
                root.unlockInProgress = false;
                root.verificationUnavailable = true;
                root.clearText();
                root.handOverToWindows();
                return;
            }
            root.clearText();
            root.unlockInProgress = false;
            GlobalStates.screenUnlockFailed = true;
            root.showFailure = true;
            if (result === 6)
                return;
            root.failedAttempts += 1;
        }
    }

    function tryFingerUnlock() {
        if (root.fingerprintsConfigured) {
            fingerPam.start();
        }
    }

    function stopFingerPam() {
        if (fingerPam.active) {
            fingerPam.abort();
        }
    }

    Process {
        id: fingerprintCheckProc
        running: !Platform.isWindows
        command: ["bash", "-c", "fprintd-list $(whoami)"]
        stdout: StdioCollector {
            id: fingerprintOutputCollector
            onStreamFinished: {
                root.fingerprintsConfigured = fingerprintOutputCollector.text.includes("Fingerprints for user");
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                // console.warn("[LockContext] fprintd-list command exited with error:", exitCode, exitStatus);
                root.fingerprintsConfigured = false;
            }
        }
    }
    
    PamContext {
        id: pam

        // pam_unix will ask for a response for the password prompt
        onPamMessage: {
            if (this.responseRequired) {
                this.respond(root.currentText);
            }
        }

        // pam_unix won't send any important messages so all we need is the completion status.
        onCompleted: result => {
            if (result == PamResult.Success) {
                root.unlocked(root.targetAction);
                stopFingerPam();
            } else {
                root.clearText();
                root.unlockInProgress = false;
                GlobalStates.screenUnlockFailed = true;
                root.showFailure = true;
            }
        }
    }

    PamContext {
        id: fingerPam

        configDirectory: "pam"
        config: "fprintd.conf"

        onCompleted: result => {
            if (result == PamResult.Success) {
                root.unlocked(root.targetAction);
                stopFingerPam();
            } else if (result == PamResult.Error) { // if timeout or etc..
                tryFingerUnlock()
            }
        }
    }
}
