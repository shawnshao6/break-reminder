# Break Reminder

A tiny macOS menu bar app that reminds you to take eye/standing breaks every 20 minutes.

## What it does

- Lives in your menu bar as `☕ Break`
- Every 20 minutes, dims your entire screen with a full-screen overlay
- Shows "Time for a Break! Rest your eyes. Stand up. Stretch."
- Click **Skip** (or press Escape) to dismiss and reset the timer
- Always shows the overlay — does NOT auto-skip during video calls (you skip manually)
- Background activity continues unaffected (audio, downloads, meetings keep running)

## How to run

### Option 1 — Double-click the app
Open Finder, go to `/Users/shawn/Documents/break-reminder/`, and double-click `BreakReminder.app`.

First launch: macOS may block it because it's unsigned. Right-click → **Open** → **Open** to allow.

### Option 2 — Run the binary directly
```bash
/Users/shawn/Documents/break-reminder/BreakReminder
```

## Menu options

Click the `☕ Break` icon in your menu bar:
- **Next break in MM:SS** — live countdown
- **Pause / Resume**
- **Take Break Now** — trigger the overlay immediately (great for testing)
- **Reset Timer** — restart the 20-minute countdown
- **Interval** — change to 5, 10, 15, 20, 30, 45, or 60 minutes
- **Quit**

## Auto-start on login

1. Open **System Settings** → **General** → **Login Items**
2. Click **+** under "Open at Login"
3. Select `/Users/shawn/Documents/break-reminder/BreakReminder.app`

## Rebuild after editing

```bash
cd /Users/shawn/Documents/break-reminder
swiftc -o BreakReminder BreakReminder.swift -framework Cocoa
cp BreakReminder BreakReminder.app/Contents/MacOS/BreakReminder
```
