// omac-hotkeys — flip WindowServer's live symbolic-hotkey table via SkyLight.
// macOS 26 (Tahoe) no longer reads com.apple.symbolichotkeys.plist at login, so
// prefs alone cannot disable the ⇧⌘3/4/5 screenshot shortcuts; this talks to
// WindowServer directly (the same call launchers use to take over ⌘Space). The
// change is per-login-session — a LaunchAgent re-applies it at every login.
// Usage: omac-hotkeys <id> <0|1> [<id> <0|1> ...]
import Foundation

guard let h = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW),
      let qsym = dlsym(h, "SLSIsSymbolicHotKeyEnabled"),
      let ssym = dlsym(h, "SLSSetSymbolicHotKeyEnabled") else {
    FileHandle.standardError.write(Data("omac-hotkeys: SkyLight unavailable\n".utf8))
    exit(1)
}
let isEnabled  = unsafeBitCast(qsym, to: (@convention(c) (Int32) -> Bool).self)
let setEnabled = unsafeBitCast(ssym, to: (@convention(c) (Int32, Bool) -> Int32).self)

let args = Array(CommandLine.arguments.dropFirst())
guard !args.isEmpty, args.count % 2 == 0 else {
    FileHandle.standardError.write(Data("usage: omac-hotkeys <id> <0|1> ...\n".utf8))
    exit(2)
}
var failed = false
var i = 0
while i < args.count {
    guard let id = Int32(args[i]), let v = Int(args[i + 1]) else {
        FileHandle.standardError.write(Data("omac-hotkeys: bad pair '\(args[i]) \(args[i + 1])'\n".utf8))
        exit(2)
    }
    let want = v != 0
    let err = setEnabled(id, want)
    if err != 0 || isEnabled(id) != want { failed = true }
    print("hotkey \(id): \(want ? "enabled" : "disabled")")
    i += 2
}
exit(failed ? 1 : 0)
