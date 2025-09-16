#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

appName    := "Key Disabler"
appVersion := "v2.0.1"
RegPath    := "HKCU\SOFTWARE\" appName
ExePath    := A_ScriptFullPath
startupReg := "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"


keyPairs := [
  ["LWin",       "Windows Key"],
  ["Esc",        "ESC Key"],
  ["CapsLock",   "Caps Lock"],
  ["NumLock",    "Num Lock"],
  ["ScrollLock", "Scroll Lock"],
  ["Insert",     "Insert Key"],
  ["Pause",      "Pause/Break Key"]
]

orderedKeys := []
keyNames := []
for _, pair in keyPairs {
  orderedKeys.Push(pair[1])
  keyNames.Push(pair[2])
}

defaultKey     := orderedKeys[1]
blockedKey     := defaultKey
isBlocked      := false
startupChecked := false
lastKey        := ""

TrayMenu := A_TrayMenu
TrayMenu.Delete()

subKeyMenu := Menu()
subKeyLabels := []

MakeSelectKeyHandler(index) {
  return (*) => SelectKey(index)
}

Loop orderedKeys.Length {
  i := A_Index
  thisKey := orderedKeys[i]
  thisName := keyNames[i]
  subKeyLabels.Push(thisName)
  subKeyMenu.Add(thisName, MakeSelectKeyHandler(i))
}

myGui := Gui("-MinimizeBox -Resize")
myGui.Title := appName
try {
  hIcon := DllCall("LoadImage", "Ptr", 0, "Str", A_ScriptDir "\on.ico", "UInt", 1, "Int", 0, "Int", 0, "UInt", 0x10, "Ptr")
  SendMessage(0x80, 1, hIcon,, myGui.Hwnd)
  SendMessage(0x80, 0, hIcon,, myGui.Hwnd)
} catch {
  ;
}

year := A_YYYY
copyright := "© 2025" (year > 2025 ? "-" year : "") " Michael Hulala"

myGui.OnEvent("Escape", (*) => myGui.Hide())
myGui.SetFont("s16 Bold", "Segoe UI")
myGui.Add("Text", "x10 y10 w330 h30 Center", appName)
myGui.SetFont("s12 Norm", "Segoe UI")
myGui.Add("Text", "x10 y40 w330 h30 Center", appVersion)
myGui.SetFont("s8 Norm", "Segoe UI")
myGui.Add("Text", "x10 y70 w330 h30 Center", copyright)
myGui.Add("Button", "x125 y105 w100 Default", "&Close").OnEvent("Click", (*) => myGui.Hide())

blockToggleLabel := "Start Blocking " keyNames[FindIndex(orderedKeys, blockedKey)]

TrayMenu.Add(blockToggleLabel, ToggleBlock)
TrayMenu.Add("Select Key to Block", subKeyMenu)
TrayMenu.Add()
TrayMenu.Add("Run on Startup", ToggleStartup)
TrayMenu.Add("About...", (*) => myGui.Show("w350 h145"))
TrayMenu.Add("Exit", (*) => ExitApp())
TrayMenu.Default := blockToggleLabel
TrayMenu.ClickCount := 1

UpdateTray() {
  global isBlocked, blockedKey, orderedKeys, keyNames
  idx := FindIndex(orderedKeys, blockedKey)
  friendly := idx ? keyNames[idx] : blockedKey
  if isBlocked {
    TraySetIcon("on.ico")
    A_IconTip := "Key Disabler (" friendly ")"
  } else {
    TraySetIcon("off.ico")
    A_IconTip := "Key Disabler (inactive)"
  }
}

UpdateTrayMenuLabel() {
  global isBlocked, blockedKey, orderedKeys, keyNames, TrayMenu, blockToggleLabel
  idx := FindIndex(orderedKeys, blockedKey)
  friendly := idx ? keyNames[idx] : blockedKey
  label := isBlocked ? "Pause Blocking " friendly : "Start Blocking " friendly
  TrayMenu.Rename(blockToggleLabel, label)
  blockToggleLabel := label
}

FindIndex(arr, value) {
  for i, v in arr {
    if (v = value)
      return i
  }
  return 0
}

SelectKey(index) {
  global blockedKey, orderedKeys, isBlocked, subKeyLabels, subKeyMenu
  if index <= 0 || index > orderedKeys.Length
    return
  blockedKey := orderedKeys[index]
  RegWrite(blockedKey, "REG_SZ", RegPath, "blockedKey")
  for i, label in subKeyLabels
    subKeyMenu.Uncheck(label)
  subKeyMenu.Check(subKeyLabels[index])
  if isBlocked {
    BlockKey(blockedKey)
    UpdateTray()
  }
  UpdateTrayMenuLabel()
}

BlockHandler(*) {
  global blockedKey
  ; ToolTipBlocked(blockedKey)
}

BlockKey(keyName) {
  global lastKey
  if lastKey && lastKey != keyName
    Hotkey("*" lastKey, BlockHandler, "Off")
  Hotkey("*" keyName, BlockHandler, "On")
  lastKey := keyName
}

UnblockKey() {
  global lastKey
  if lastKey
    Hotkey("*" lastKey, BlockHandler, "Off")
  lastKey := ""
}

ToolTipBlocked(k) {
  global orderedKeys, keyNames
  idx := FindIndex(orderedKeys, k)
  friendly := idx ? keyNames[idx] : k
  ToolTip friendly " is blocked", 0, 0
  SetTimer () => ToolTip(), -1000
}

ToggleBlock(*) {
  global isBlocked, blockedKey
  if isBlocked {
    UnblockKey()
    RegWrite("0", "REG_SZ", RegPath, "isBlocked")
    isBlocked := false
  } else {
    BlockKey(blockedKey)
    RegWrite("1", "REG_SZ", RegPath, "isBlocked")
    isBlocked := true
  }
  UpdateTray()
  UpdateTrayMenuLabel()
}

try {
  RegRead(RegPath, "ExePath")
} catch {
  try {
    RegWrite(ExePath, "REG_SZ", RegPath, "ExePath")
    RegWrite("1", "REG_SZ", RegPath, "isBlocked")
    RegWrite(blockedKey, "REG_SZ", RegPath, "blockedKey")
  } catch {
    MsgBox("Access to the registry was denied or insufficient.", appName, "Icon!")
    ExitApp()
  }
}

try {
  isBlocked := RegRead(RegPath, "isBlocked") = "1"
  blockedKey := RegRead(RegPath, "blockedKey")
} catch {
  isBlocked := true
  blockedKey := defaultKey
  RegWrite(blockedKey, "REG_SZ", RegPath, "blockedKey")
}

idx := FindIndex(orderedKeys, blockedKey)
if idx {
  for i, label in subKeyLabels
    subKeyMenu.Uncheck(label)
  subKeyMenu.Check(subKeyLabels[idx])
}

try {
  if RegRead(startupReg, appName) = ExePath {
    TrayMenu.Check("Run on Startup")
    startupChecked := true
  }
}

ToggleStartup(*) {
  global startupChecked
  try {
    if startupChecked {
      RegDelete(startupReg, appName)
      TrayMenu.Uncheck("Run on Startup")
      startupChecked := false
    } else {
      RegWrite(ExePath, "REG_SZ", startupReg, appName)
      TrayMenu.Check("Run on Startup")
      startupChecked := true
    }
  } catch {
    MsgBox("Startup toggle failed.`n`nAccess to the registry was denied or insufficient.", appName, "Icon!")
  }
}

if isBlocked {
  BlockKey(blockedKey)
} else {
  UnblockKey()
}
UpdateTray()
UpdateTrayMenuLabel()
