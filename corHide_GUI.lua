-- corHide_GUI.lua
-- Settings panel: two sections.
--   Section 1 – frames hidden unless in combat / group / instance / on target.
--   Section 2 – conditional rules: hide frame X whenever frame Y is visible.
-- Open with /corhide or /ch

corHide_GUI = {}
local GUI = corHide_GUI

local PANEL_W = 360
local PANEL_H = 520
local ROW_H   = 26

local rowPool     = {}   -- section 1 row pool
local condRowPool = {}   -- section 2 row pool
local panel       = nil

-- ── Generic row pool helper ───────────────────────────────────────────────────

local function MakeRow(pool, index, parent, labelWidth)
    if pool[index] then return pool[index] end

    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(labelWidth + 32, ROW_H)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, 0)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.label:SetWidth(labelWidth)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)

    row.removeBtn = CreateFrame("Button", nil, row, "UIPanelCloseButton")
    row.removeBtn:SetSize(22, 22)
    row.removeBtn:SetPoint("RIGHT", row, "RIGHT", 2, 0)

    pool[index] = row
    return row
end

-- ── Section 1: standard managed-frame list ────────────────────────────────────

function GUI:RefreshList()
    if not panel then return end

    local names = {}
    for name in pairs(corHideDB.frames) do names[#names + 1] = name end
    table.sort(names)

    for _, row in ipairs(rowPool) do row:Hide() end

    for i, name in ipairs(names) do
        local row = MakeRow(rowPool, i, panel.content, PANEL_W - 100)
        row:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 0, -(i - 1) * ROW_H)
        row.label:SetText(name)
        row.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.04 or 0)

        local captured = name
        row.removeBtn:SetScript("OnClick", function()
            corHideDB.frames[captured] = nil
            corHide.UpdateFrames()
            GUI:RefreshList()
        end)
        row:Show()
    end

    panel.content:SetHeight(math.max(1, #names * ROW_H))
    if #names == 0 then panel.emptyMsg:Show() else panel.emptyMsg:Hide() end
end

-- ── Section 2: conditional rule list ─────────────────────────────────────────

function GUI:RefreshConditionalList()
    if not panel then return end

    local entries = {}
    for target, condition in pairs(corHideDB.conditionalFrames) do
        entries[#entries + 1] = { target = target, condition = condition }
    end
    table.sort(entries, function(a, b) return a.target < b.target end)

    for _, row in ipairs(condRowPool) do row:Hide() end

    for i, entry in ipairs(entries) do
        local row = MakeRow(condRowPool, i, panel.condContent, PANEL_W - 100)
        row:SetPoint("TOPLEFT", panel.condContent, "TOPLEFT", 0, -(i - 1) * ROW_H)
        row.label:SetText(entry.target .. "  |cff555555when|r  " .. entry.condition)
        row.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.04 or 0)

        local t = entry.target
        row.removeBtn:SetScript("OnClick", function()
            corHideDB.conditionalFrames[t] = nil
            corHide.UpdateFrames()
            GUI:RefreshConditionalList()
        end)
        row:Show()
    end

    panel.condContent:SetHeight(math.max(1, #entries * ROW_H))
    if #entries == 0 then panel.condEmptyMsg:Show() else panel.condEmptyMsg:Hide() end
end

-- ── Add handlers ──────────────────────────────────────────────────────────────

local function AddFrameFromInput()
    local name = panel.inputBox:GetText():match("^%s*(.-)%s*$")
    if name == "" then return end
    corHideDB.frames[name] = true
    panel.inputBox:SetText("")
    corHide.UpdateFrames()
    GUI:RefreshList()
end

local function AddConditionalFromInput()
    local target    = panel.condHideBox:GetText():match("^%s*(.-)%s*$")
    local condition = panel.condWhenBox:GetText():match("^%s*(.-)%s*$")
    if target == "" or condition == "" then return end
    corHideDB.conditionalFrames[target] = condition
    panel.condHideBox:SetText("")
    panel.condWhenBox:SetText("")
    corHide.UpdateFrames()
    GUI:RefreshConditionalList()
end

-- ── Layout helpers ────────────────────────────────────────────────────────────

local function SectionLabel(parent, inset, yOfs, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", inset, "TOPLEFT", 8, yOfs)
    fs:SetWidth(PANEL_W - 40)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    fs:SetText(text)
    return fs
end

local function SmallLabel(parent, inset, xOfs, yOfs, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", inset, "TOPLEFT", xOfs, yOfs)
    fs:SetText(text)
    return fs
end

local function Separator(parent, inset, yOfs)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetPoint("TOPLEFT",  inset, "TOPLEFT",  6, yOfs)
    t:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -6, yOfs)
    t:SetHeight(1)
    t:SetColorTexture(0.4, 0.4, 0.4, 0.6)
end

local function ScrollArea(parent, inset, yOfs, height)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", inset, "TOPLEFT", 6, yOfs)
    sf:SetSize(PANEL_W - 52, height)

    local content = CreateFrame("Frame", nil, sf)
    content:SetWidth(PANEL_W - 68)
    content:SetHeight(1)
    sf:SetScrollChild(content)
    return sf, content
end

local function EmptyMsg(content, text)
    local fs = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    fs:SetPoint("TOP", content, "TOP", 0, -10)
    fs:SetText(text)
    fs:SetJustifyH("CENTER")
    return fs
end

local function InputBox(name, parent, inset, xOfs, yOfs, width, onEnter)
    local eb = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
    eb:SetPoint("TOPLEFT", inset, "TOPLEFT", xOfs, yOfs)
    eb:SetSize(width, 22)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(128)
    eb:SetScript("OnEnterPressed", onEnter)
    return eb
end

-- ── Panel construction ────────────────────────────────────────────────────────

local function BuildPanel()
    local f = CreateFrame("Frame", "corHidePanel", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(PANEL_W, PANEL_H)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:Hide()

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("LEFT",  f.TitleBg, "LEFT",  5, 0)
    f.title:SetPoint("RIGHT", f.TitleBg, "RIGHT", -30, 0)
    f.title:SetText("corHide  |cff888888— Frame Visibility Manager|r")

    local ib = f.InsetBg   -- shorthand; all y offsets are relative to its TOPLEFT

    -- ════════ SECTION 1: standard managed frames ════════

    SectionLabel(f, ib, -6,
        "|cffFFD100Managed Frames|r  |cff777777hidden unless combat / group / instance / target|r")

    local _, content = ScrollArea(f, ib, -24, 185)
    f.content  = content
    f.emptyMsg = EmptyMsg(content, "No frames registered.\nType a name below and press Add.")

    SmallLabel(f, ib, 10, -217, "|cffAAAAFFFrame name|r")

    f.inputBox = InputBox("corHideInputBox", f, ib, 8, -233, 215, AddFrameFromInput)

    local addBtn1 = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    addBtn1:SetPoint("LEFT", f.inputBox, "RIGHT", 6, 0)
    addBtn1:SetSize(70, 22)
    addBtn1:SetText("Add")
    addBtn1:SetScript("OnClick", AddFrameFromInput)

    -- ════════ SEPARATOR ════════

    Separator(f, ib, -265)

    -- ════════ SECTION 2: conditional rules ════════

    SectionLabel(f, ib, -273,
        "|cffFFD100Conditional Rules|r  |cff777777hide frame X whenever frame Y is visible|r")

    local _, condContent = ScrollArea(f, ib, -293, 130)
    f.condContent  = condContent
    f.condEmptyMsg = EmptyMsg(condContent,
        "No rules defined.\nFill both fields below and press Add.")

    SmallLabel(f, ib,   10, -431, "|cffAAAAFFHide frame|r")
    SmallLabel(f, ib,  148, -431, "|cffAAAAFFWhen visible|r")

    f.condHideBox = InputBox("corHideCondHideBox", f, ib,   8, -447, 126, AddConditionalFromInput)
    f.condWhenBox = InputBox("corHideCondWhenBox", f, ib, 146, -447, 126, AddConditionalFromInput)

    local addBtn2 = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    addBtn2:SetPoint("LEFT", f.condWhenBox, "RIGHT", 6, 0)
    addBtn2:SetSize(52, 22)
    addBtn2:SetText("Add")
    addBtn2:SetScript("OnClick", AddConditionalFromInput)

    return f
end

-- ── Public API ────────────────────────────────────────────────────────────────

local function RefreshAll()
    GUI:RefreshList()
    GUI:RefreshConditionalList()
end

function GUI:Toggle()
    if not panel then panel = BuildPanel() end
    if panel:IsShown() then
        panel:Hide()
    else
        RefreshAll()
        panel:Show()
    end
end

function GUI:Show()
    if not panel then panel = BuildPanel() end
    RefreshAll()
    panel:Show()
end

function GUI:Hide()
    if panel then panel:Hide() end
end
