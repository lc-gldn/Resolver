-- Sony Meta Warrior B3 1.3.0
-- Zoom Ring, Master Black, and AWB Mode are written into Camera Notes

-- =============================
-- RESOLVE / UI INIT
-- =============================

local resolve = bmd.scriptapp("Resolve")

if not resolve then
    print("[-] Resolve not found.")
    return
end

local ui = fu.UIManager
local disp = bmd.UIDispatcher(ui)

local win = nil
local itm = nil

-- =============================
-- CONFIG
-- =============================

local themeHex = "#086c75"

local resolverPaths = {
    "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/resolvermac",
}

local function get_script_path()
    local info = debug.getinfo(1, "S")
    local path = info.source:sub(2)
    return path:match("(.*[/\\])") or "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/"
end

local configPath = get_script_path() .. "smw.txt"

-- =============================
-- SETTINGS
-- =============================

local function LoadSettings()
    local f = io.open(configPath, "r")

    if f then
        local content = f:read("*all")
        f:close()

        local x, y, w, h, sel = content:match("(%-?%d+),(%-?%d+),(%d+),(%d+),(%d+)")

        if x and y and w and h then
            return {
                tonumber(x),
                tonumber(y),
                tonumber(w),
                tonumber(h),
                tonumber(sel or 1)
            }
        end
    end

    return {446, 110, 371, 378, 1}
end

local function SaveSettings()
    if not win or not itm then return end

    local geom = win.Geometry or {446, 110, 371, 378}
    local sel = itm.CheckSelected.Checked and 1 or 0

    local f = io.open(configPath, "w")

    if f then
        f:write(string.format(
            "%d,%d,%d,%d,%d",
            tonumber(geom[1]) or 446,
            tonumber(geom[2]) or 110,
            tonumber(geom[3]) or 371,
            tonumber(geom[4]) or 378,
            sel
        ))
        f:close()
    end
end

-- =============================
-- DEBUG / LOGGING
-- =============================

local function debug_log(label, data)
    local timestamp = os.date("%H:%M:%S")

    if type(data) == "table" then
        print(string.format("[%s] DEBUG [%s]: (Table)", timestamp, label))

        for k, v in pairs(data) do
            print("   > " .. tostring(k) .. ": " .. tostring(v))
        end
    else
        print(string.format("[%s] DEBUG [%s]: %s", timestamp, label, tostring(data)))
    end
end

local function log(msg)
    if itm and itm.LogBox then
        itm.LogBox:Append(tostring(msg) .. "")
    end
end

-- =============================
-- HELPERS
-- =============================

function string:trim()
    return self:match("^%s*(.-)%s*$")
end

local function file_exists(path)
    local f = io.open(path, "r")

    if f then
        f:close()
        return true
    end

    return false
end

local function find_resolver()
    for _, path in ipairs(resolverPaths) do
        if file_exists(path) then
            return path
        end
    end

    return nil
end

local function quote(path)
    return '"' .. tostring(path):gsub('"', '\\"') .. '"'
end

local function get_filename(path)
    return path:match("^.+/(.+)$") or path:match("^.+\\(.+)$") or path
end

local function safe_string(value)
    if value == nil then return "" end
    return tostring(value)
end

local function clean_control(value)
    return safe_string(value):gsub("[%c\r\n]", ""):trim()
end

local function parse_output(raw)
    debug_log("Parser", "Processing raw binary output...")

    local data = {}

    for line in tostring(raw or ""):gmatch("[^\r\n]+") do
        local key, value = line:match("^([^:]+):(.+)$")

        if key and value then
            key = key:gsub("^%s+", ""):gsub("%s+$", "")
            value = value:gsub("^%s+", ""):gsub("%s+$", "")

            data[key] = value
        end
    end

    debug_log("Parser Data", data)

    return data
end

local function get_selected_clips()
    debug_log("Action", "Fetching selected clips...")

    local pm = resolve:GetProjectManager()
    if not pm then return {} end

    local project = pm:GetCurrentProject()
    if not project then return {} end

    local mp = project:GetMediaPool()
    if not mp then return {} end

    local sel = mp:GetSelectedClips()
    local out = {}

    if sel then
        for _, clip in pairs(sel) do
            if type(clip) == "userdata" then
                table.insert(out, clip)
            end
        end
    end

    debug_log("Result", #out .. " clips found in selection.")

    return out
end

local function get_current_folder_clips()
    debug_log("Action", "Fetching current folder clips...")

    local pm = resolve:GetProjectManager()
    if not pm then return {} end

    local project = pm:GetCurrentProject()
    if not project then return {} end

    local mp = project:GetMediaPool()
    if not mp then return {} end

    local folder = mp:GetCurrentFolder()
    if not folder then return {} end

    local clips = folder:GetClipList() or {}

    debug_log("Result", #clips .. " clips found in folder.")

    return clips
end

local function SetMetadataSafe(clip, key, value)
    if not clip or not key then return false end

    value = safe_string(value)

    local ok, result = pcall(function()
        return clip:SetMetadata(key, value)
    end)

    if not ok then
        debug_log("SetMetadata Failed", key .. " = " .. value .. " | " .. tostring(result))
        return false
    end

    debug_log("SetMetadata", key .. " = " .. value)

    return result
end

local function SetMetadataTableSafe(clip, meta)
    if not clip or not meta then return end

    for key, value in pairs(meta) do
        SetMetadataSafe(clip, key, value)
    end
end

local function format_fps(value)
    if not value or value == "" then return "" end

    local n = tonumber(tostring(value):match("([%d%.]+)"))

    if not n then return tostring(value) end

    return tostring(math.ceil(n))
end

local function format_stabilization(value)
    local stab = safe_string(value):lower()

    if stab == "" then return "" end

    return stab:gsub("^%l", string.upper)
end

local function build_camera_notes(extracted)
    local cameraNotes = {}

    if extracted["Focus Distance"] and extracted["Focus Distance"] ~= "" then
    table.insert(cameraNotes, "Distance: " .. extracted["Focus Distance"])
    end

    if extracted["Zoom Ring"] and extracted["Zoom Ring"] ~= "" then
        table.insert(cameraNotes, "Zoom Ring: " .. extracted["Zoom Ring"])
    end
    
    if extracted["Master Black"] and extracted["Master Black"] ~= "" then
        table.insert(cameraNotes, "Master Black: " .. extracted["Master Black"])
    end
    
    if extracted["ND Filter"] and extracted["ND Filter"] ~= "" then
        table.insert(cameraNotes, "ND: " .. extracted["ND Filter"])
    end
    

    return table.concat(cameraNotes, " | ")
end

local function build_metadata(extracted)
    local fps = format_fps(extracted["Camera FPS"])

    local monColor = safe_string(extracted["Mon Color Space"])

    if monColor ~= "" then
        monColor = monColor:match("^([^%s/]+)") or monColor
    end

    local meta = {
        ["ISO"]                  = extracted["ISO"],
        ["Shutter Speed"]        = safe_string(extracted["Shutter Speed"]):gsub("s$", ""),
        ["Shutter Angle"]        = extracted["Shutter Angle"],
        ["Camera FPS"]           = fps,
        ["Lens Type"]            = extracted["Lens Type"],
        ["Focal Point (mm)"]     = safe_string(extracted["Focal Point (mm)"]):gsub("%.00", ""):gsub(" ", ""),
        ["White Point (Kelvin)"] = extracted["White Balance"],
        ["Camera Type"]          = extracted["Camera Type"],
        ["Mon Color Space"]      = monColor,
        ["Camera Aperture"]      = safe_string(extracted["Camera Aperture"]):gsub("[fF]%s*/%s*", "F"),
        ["Stabilization"]        = format_stabilization(extracted["Stabilization"]),
        ["Camera #"]             = clean_control(extracted["Camera Attributes"] or extracted["Camera #"]):gsub("^.-%s", ""),
        ["LUT Used"]             = clean_control(extracted["LUT Used"]):gsub("^.-:", ""):gsub("%.cube", ""),

        -- Combined notes field
        ["Camera Notes"]         = build_camera_notes(extracted),

        -- B2 extra fields
        -- ["ND Filter"]             = extracted["ND Filter"],
        -- ["Distance"]              = extracted["Focus Distance"],

    }

    return meta
end

-- =============================
-- CORE SYNC
-- =============================

local function RunSync()
    local startTime = os.time()

    debug_log("Sync", "Initialization Started")

    local resolver = find_resolver()

    if not resolver then
        debug_log("Error", "Resolver binary missing")

        log("\n⭕️ Dependency not found!")
        log("Run the install script first.\n")

        return
    end

    debug_log("Resolver", resolver)

    log("\n         [-----  Sync Started  -----]")

    local clips = itm.CheckSelected.Checked and get_selected_clips() or get_current_folder_clips()

    if #clips == 0 then
        log("No clips found.")
        return
    end

    itm.ProgBar.Visible = true
    itm.ProgBar.Value = 0

    for i, clip in ipairs(clips) do
        local path = clip:GetClipProperty("File Path")

        debug_log("Clip Process", "Processing: " .. tostring(path))

        if path and path ~= "" then
            log("Extracted:   " .. get_filename(path))

            local cmd = quote(resolver) .. " " .. quote(path)

            debug_log("Shell Cmd", cmd)

            local pipe = io.popen(cmd .. " 2>&1")

            if pipe then
                local raw_data = pipe:read("*a") or ""
                pipe:close()

                local extracted = parse_output(raw_data)
                local meta = build_metadata(extracted)

                debug_log("Metadata Write", meta)

                SetMetadataTableSafe(clip, meta)
            else
                log("Failed to run resolver.\n")
            end
        else
            log("Skipped clip with no file path.\n")
        end

        itm.ProgBar.Value = math.floor((i / #clips) * 100)
    end

    local duration = os.difftime(os.time(), startTime)

    debug_log("Sync", string.format("Finished in %d seconds", duration))

    log(string.format("\n    [-----  Completed in %d:%02d  -----]\n", math.floor(duration / 60), duration % 60))

    itm.ProgBar.Visible = false
end

-- =============================
-- CLEAR METADATA
-- =============================

local function ClearMetadata()
    debug_log("UI Event", "Clear Button Pressed - Wiping Metadata")

    itm.ProgBar.Visible = true
    itm.ProgBar.Value = 0

    local clips = itm.CheckSelected.Checked and get_selected_clips() or get_current_folder_clips()

    if #clips == 0 then
        log("No clips found.\n")
        itm.ProgBar.Visible = false
        return
    end

    local empty = {
        ["ISO"]                  = "",
        ["Shutter Speed"]        = "",
        ["Shutter Angle"]        = "",
        ["Camera FPS"]           = "",
        ["Lens Type"]            = "",
        ["Focal Point (mm)"]     = "",
        ["White Point (Kelvin)"] = "",
        ["Camera Type"]          = "",
        ["Mon Color Space"]      = "",
        ["Camera Aperture"]      = "",
        ["Stabilization"]        = "",
        ["Camera #"]             = "",
        ["LUT Used"]             = "",
        ["Comments"]             = "",
        ["Description"]          = "",
        ["Camera Notes"]         = "",
        ["Distance"]             = "",
        ["Camera Notes"]         = "",
    }

    for i, clip in ipairs(clips) do
        SetMetadataTableSafe(clip, empty)
        itm.ProgBar.Value = math.floor((i / #clips) * 100)
    end

    itm.ProgBar.Visible = false

    log("Metadata cleared.\n")
end

-- =============================
-- STYLING
-- =============================

local function UpdateStyles()
    local color = themeHex

    local checkStyle = [[
        QCheckBox {
            color: #9f9f9f;
        }

        QCheckBox::indicator {
            width: 16px;
            height: 16px;
            border: 1px solid #5a5a5a;
            border-radius: 3px;
            background-color: #5f5f5f;
        }

        QCheckBox::indicator:checked {
            background-color: ]] .. color .. [[;
            border: 1px solid ]] .. color .. [[;
            image: url(gui/icons/uimanager/check.png);
        }
    ]]

    itm.CheckSelected.StyleSheet = checkStyle
    itm.CheckFolder.StyleSheet = checkStyle

    itm.ProgBar.StyleSheet = [[
        QSlider::groove:horizontal {
            border: 1px solid #4f4f4f00;
            height: 6px;
            background: #2a2a2a;
        }

        QSlider::handle:horizontal {
            background: ]] .. color .. [[;
            width: 1px;
        }

        QSlider::sub-page:horizontal {
            background: qlineargradient(
                x1: 0,
                y1: 0,
                x2: 1,
                y2: 0,
                stop: 0 #3f8f58,
                stop: 1 ]] .. themeHex .. [[
            );
            border-radius: 2px;
        }
    ]]
end

local function ApplyButtonStyles()
    local btnStyle = [[
        QPushButton {
            color: #9f9f9f;
            font-weight: bold;
            border: 1px solid #393939;
            border-radius: 5px;
            background-color: #393939;
            padding: 6px;
        }

        QPushButton:hover {
            background-color: ]] .. themeHex .. [[;
            color: #1a1a1a;
        }

        QPushButton:pressed {
            background-color: #034E54;
        }
    ]]

    itm.SyncBtn.StyleSheet = btnStyle
    itm.ClearBtn.StyleSheet = btnStyle
    itm.ClearLogBtn.StyleSheet = btnStyle
    itm.CloseBtn.StyleSheet = btnStyle
end

-- =============================
-- UI SETUP
-- =============================

local s = LoadSettings()

win = disp:AddWindow({
    ID = "MetaWin",
    WindowTitle = "🛡️ Sony Meta Warrior B2 Fixed 🛡️",
    Geometry = {s[1], s[2], s[3], s[4]},

    ui:VGroup{
        ui:Label{
            ID = "LabelMapping",
            Text = "Choose source for metadata extraction.",
            Alignment = {AlignHCenter = true}
        },

        ui:HGroup{
            Weight = 0,

            ui:HGap(0, 1),

            ui:CheckBox{
                ID = "CheckSelected",
                Text = "Selected Clip",
                Checked = (s[5] == 1)
            },

            ui:HGap(10),

            ui:CheckBox{
                ID = "CheckFolder",
                Text = "Current Folder",
                Checked = (s[5] == 0)
            },

            ui:HGap(0, 1),
        },

        ui:VGap(5),

        ui:HGroup{
            Weight = 0,

            ui:HGap(0, 1),

            ui:Button{
                ID = "SyncBtn",
                Text = "Sync",
                MinimumSize = {90, 30}
            },

            ui:HGap(10),

            ui:Button{
                ID = "ClearBtn",
                Text = "Clear",
                MinimumSize = {90, 30}
            },

            ui:HGap(0, 1),
        },

        ui:Slider{
            ID = "ProgBar",
            Minimum = 0,
            Maximum = 100,
            Value = 0,
            Orientation = "Horizontal",
            Enabled = false,
            Visible = false,
            Weight = 0
        },

        ui:TextEdit{
            ID = "LogBox",
            ReadOnly = true,
            Weight = 10,
            Font = ui:Font{
                Family = "Courier",
                PixelSize = 12
            }
        },

        ui:VGap(5),

        ui:HGroup{
            Weight = 0,

            ui:HGap(0, 1),

            ui:Button{
                ID = "ClearLogBtn",
                Text = "Clear Log",
                MinimumSize = {80, 30}
            },

            ui:HGap(10),

            ui:Button{
                ID = "CloseBtn",
                Text = "Close",
                MinimumSize = {80, 30}
            },

            ui:HGap(0, 1),
        }
    }
})

itm = win:GetItems()

UpdateStyles()
ApplyButtonStyles()

-- =============================
-- EVENTS
-- =============================

function win.On.CheckSelected.Clicked(ev)
    debug_log("UI Event", "Scope set to 'Selected Clip'")
    itm.CheckSelected.Checked = true
    itm.CheckFolder.Checked = false
end

function win.On.CheckFolder.Clicked(ev)
    debug_log("UI Event", "Scope set to 'Current Folder'")
    itm.CheckFolder.Checked = true
    itm.CheckSelected.Checked = false
end

function win.On.SyncBtn.Clicked(ev)
    debug_log("UI Event", "Sync Button Pressed")
    RunSync()
end

function win.On.ClearBtn.Clicked(ev)
    ClearMetadata()
end

function win.On.ClearLogBtn.Clicked(ev)
    debug_log("UI Event", "UI Log Cleared")
    itm.LogBox:Clear()
    itm.ProgBar.Visible = false
end

function win.On.CloseBtn.Clicked(ev)
    debug_log("UI Event", "Closing Window")
    SaveSettings()
    win:Hide()
    disp:ExitLoop()
end

function win.On.MetaWin.Close(ev)
    debug_log("UI Event", "Window X Closed")
    SaveSettings()
    disp:ExitLoop()
end

-- =============================
-- EXECUTION
-- =============================

debug_log("System", "B2 Fixed Script Initialized")

win:Show()
disp:RunLoop()
win:Hide()
