#Requires AutoHotkey v2.0
#SingleInstance Force

; =================================================================
; Scroll Denoiser — direction-lock filter for cheap mouse wheels.
;
; Port of the macOS MacCleaner module. Filters out reverse-direction
; scroll ticks emitted by encoders that alias at high rotational
; speed. Locks the dominant direction for a short window, drops
; obvious noise, releases on idle. Trackpad/precision-scroll on
; Windows generates WM_MOUSEHWHEEL or fast WM_MOUSEWHEEL bursts with
; the SAME sign — the algorithm naturally lets those through.
;
; Hotkeys:
;   Ctrl+Alt+S  — toggle filter on/off
;   Tray menu   — stats / reset / exit
; =================================================================

; ---------- Tunable settings (match macOS defaults) ----------
global minLockMs     := 30   ; lock window when wheel is slow (ms)
global maxLockMs     := 120  ; lock window when wheel is fast (ms)
global fastThreshold := 5    ; ticks within windowMs to be classed "fast"
global windowMs      := 100  ; sliding window for tick-rate measurement (ms)
global releaseMs     := 200  ; idle gap before lock fully releases (ms)

; ---------- State ----------
global enabled       := true
global lockedSign    := 0
global lockUntil     := 0
global lastTickTime  := 0
global recentTicks   := []
global totalTicks    := 0
global droppedTicks  := 0

; ---------- Hotkeys ----------
$WheelUp::HandleTick(1)
$WheelDown::HandleTick(-1)
^!s::ToggleEnabled()

HandleTick(sign) {
    global

    ; Filter disabled — pass through.
    if (!enabled) {
        ReplayTick(sign)
        return
    }

    now := A_TickCount
    totalTicks++

    ; Drop ticks that fell out of the rate-measurement window.
    cutoff := now - windowMs
    while (recentTicks.Length > 0 && recentTicks[1].time < cutoff)
        recentTicks.RemoveAt(1)

    ; Release lock after idle gap.
    if (now - lastTickTime > releaseMs) {
        lockedSign := 0
        lockUntil := 0
    }

    lockMs := (recentTicks.Length >= fastThreshold) ? maxLockMs : minLockMs

    pass := false
    if (lockedSign == 0) {
        ; First tick after idle — lock this direction.
        lockedSign := sign
        lockUntil := now + lockMs
        pass := true
    } else if (sign == lockedSign) {
        ; Same direction — extend lock.
        if (now + lockMs > lockUntil)
            lockUntil := now + lockMs
        pass := true
    } else if (now < lockUntil) {
        ; Opposite direction within lock window — noise, drop it.
        droppedTicks++
    } else {
        ; Lock expired — legitimate reversal.
        lockedSign := sign
        lockUntil := now + lockMs
        pass := true
    }

    lastTickTime := now
    recentTicks.Push({time: now, sign: sign})

    if (pass)
        ReplayTick(sign)
}

ReplayTick(sign) {
    ; `$` prefix on the wheel hotkeys + AHK's built-in anti-recursion
    ; means this Send does not re-trigger our own HandleTick.
    if (sign > 0)
        Send "{WheelUp}"
    else
        Send "{WheelDown}"
}

ToggleEnabled() {
    global enabled
    enabled := !enabled
    TrayTip("Filter " (enabled ? "ON" : "OFF"), "Scroll Denoiser", 1)
    UpdateTray()
}

UpdateTray() {
    global enabled
    tray := A_TrayMenu
    if (enabled)
        tray.Check("Enabled`tCtrl+Alt+S")
    else
        tray.Uncheck("Enabled`tCtrl+Alt+S")
}

ShowStats(*) {
    global totalTicks, droppedTicks
    rate := totalTicks > 0
        ? Format("{:.1f}%", droppedTicks * 100.0 / totalTicks)
        : "—"
    MsgBox(
        "Total ticks: " totalTicks "`n"
        "Dropped: "     droppedTicks "`n"
        "Drop rate: "   rate,
        "Scroll Denoiser"
    )
}

ResetStats(*) {
    global totalTicks, droppedTicks
    totalTicks := 0
    droppedTicks := 0
    TrayTip("Stats reset", "Scroll Denoiser", 1)
}

; ---------- Tray menu setup ----------
A_IconTip := "Scroll Denoiser"
tray := A_TrayMenu
tray.Delete()
tray.Add("Enabled`tCtrl+Alt+S", (*) => ToggleEnabled())
tray.Add("Show stats",          ShowStats)
tray.Add("Reset stats",         ResetStats)
tray.Add()
tray.Add("Exit",                (*) => ExitApp())
UpdateTray()
