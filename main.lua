local addonName, addonTable = ...;
local StoredResearchCounter = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceBucket-3.0", "AceEvent-3.0")

local _G = _G
local BreakUpLargeNumbers = BreakUpLargeNumbers
local AceDB = LibStub("AceDB-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")

local iconString = '|T%s:16:16:0:0:64:64:4:60:4:60|t '

-- init ldbObject
local ldbObject = LDB:NewDataObject("Stored Research", {
    type = "data source",
    text = "-",
    value = 0,
    icon = "Interface\\Icons\\inv_misc_paperbundle04a",
    label = "Stored Research"
})

local Format = {
    stored = 1,
    stored_plus_pool = 2,
    pool_plus_stored = 3,
    sum_only = 4,
    sum_plus_stored = 5,
    stored_plus_sum = 6,
    pool_plus_sum = 7,
    custom_format = 8

}

local FormatLabels = {"stored_only", "stored_plus_pool", "pool_plus_stored", "sum_only", "sum_plus_stored",
                      "stored_plus_sum", "pool_plus_sum", "custom_format"}

local bucketListener = nil
local worldListener = nil
local currListener = nil
local configIsVerbose = false
local configFormat = Format.stored
local configBreakLargeNumbers = true
local configShowLabel = true
local configShowIcon = true
local configCustomFormat = "${stored}+${pool}=${sum}"
local configTTBaggedAnima = true
local configTTReservoirAnima = true
local configTTTotalAnima = true

local defaults = {
    profile = {
        format = Format.stored,
        verbose = false,
        breakLargeNumbers = true,
        showLabel = true,
        showIcon = true,
        customFormat = "${stored}+${pool}=${sum}",
        TTBaggedAnima = true,
        TTReservoirAnima = true,
        TTTotalAnima = true
    }
}

-- Hooks

function StoredResearchCounter:SetUpHooks()
    GameTooltip:HookScript("OnTooltipSetItem", function(self)
        if (configTTBaggedAnima or configTTReservoirAnima or configTTTotalAnima) then
            local item, link = GameTooltip:GetItem()
            if link ~= nil and isCatalogedResearchItem(link) then
                local stored, pool, sum
                if configBreakLargeNumbers then
                    stored = BreakUpLargeNumbers(ldbObject.value)
                    pool = BreakUpLargeNumbers(GetTotalResearch())
                    sum = BreakUpLargeNumbers(GetTotalResearch() + ldbObject.value)
                else
                    stored = ldbObject.value
                    pool = GetTotalResearch()
                    sum = GetTotalResearch() + ldbObject.value
                end

                if (configTTBaggedAnima or configTTReservoirAnima or configTTTotalAnima) then
                    self:AddLine("\n")
                end
                if configTTBaggedAnima then
                    self:AddDoubleLine("|cFFFF7F38Cataloged Research (bag):", "|cFFFFFFFF" .. stored .. "|r")
                end
                if configTTReservoirAnima then
                    self:AddDoubleLine("|cFFFF7F38Cataloged Research (Roh-Suir):", "|cFFFFFFFF" .. pool .. "|r")
                end
                if configTTTotalAnima then
                    self:AddDoubleLine("|cFFFF7F38Cataloged Research (total):", "|cFFFFFFFF" .. sum .. "|r")
                end
            end
        end
    end)
end
-- Lifecycle functions

function StoredResearchCounter:OnInitialize()
    StoredResearchCounter:SetupDB()
    StoredResearchCounter:SetupConfig()
    print("Addon " .. addonName .. " loaded!")
end

function StoredResearchCounter:OnEnable()
    if worldListener == nil then
        worldListener = self:RegisterEvent("PLAYER_ENTERING_WORLD", "ScanForStoredAnimaDelayed")
    end

    if currListener == nil then
        currListener = self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "ScanForStoredAnima") -- When spending anima on the anima conductor\
    end

    if bucketListener == nil then
        bucketListener = self:RegisterBucketEvent("BAG_UPDATE", 0.2, "ScanForStoredAnima")
    end

    StoredResearchCounter:RefreshConfig()

    
end


function StoredResearchCounter:OnDisable()
    if worldListener then
        self:UnregisterEvent(worldListener)
        worldListener = nil
    end

    if currListener then
        self:UnregisterEvent(currListener)
        currListener = nil
    end

    if bucketListener then
        self:UnregisterBucket(bucketListener)
        bucketListener = nil
    end
end

function StoredResearchCounter:SetupDB()
    self.db = AceDB:New("StoredResearchCounterDB", defaults)
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
end

-- Config functions
function StoredResearchCounter:SetupConfig()
    local options = {
        name = addonName,
        handler = StoredResearchCounter,
        type = "group",
        childGroups = "tree",
        args = {
            config = {
                name = "Configuration",
                desc = "Opens the SRC Configuration panel",
                type = "execute",
                func = "OpenConfigPanel",
                guiHidden = true
            },
            general = {
                name = "General",
                type = "group",
                handler = StoredResearchCounter,
                args = {
                    headerFormat = {
                        name = "Formatting",
                        type = "header",
                        order = 1
                    },
                    format = {
                        name = "Choose output format",
                        type = "select",
                        values = FormatLabels,
                        set = "SetFormat",
                        get = "GetFormat",
                        width = "full",
                        order = 2
                    },
                    formatDesc = {
                        name = "\nChoose a format to adapt how the value of Stored Cataloged Research is displayed. There are several options: \n    stored = 100\n    stored_plus_pool = 100 (4900)\n    pool_plus_stored = 4900 (100)\n    sum_only = 5000\n    sum_plus_stored = 5000 (100)\n    stored_plus_sum = 100 (5000)\n    pool_plus_sum = 4900 (5000)",
                        type = "description",
                        order = 3
                    },
                    customFormat = {
                        name = "Custom format",
                        desc = "Create your own custom format string for the output",
                        type = "input",
                        set = "SetCustomFormat",
                        get = "GetCustomFormat",
                        width = "full",
                        order = 4
                    },
                    customFormatDesc = {
                        name = "\nCreate your own custom format using one of the interpolated variables: ${stored}, ${pool}, ${sum}.\nThese variables will get replaced, all other characters remain untouched.",
                        type = "description",
                        order = 5
                    },
                    headerVerbose = {
                        name = "Extra toggles",
                        type = "header",
                        order = 6
                    },
                    largeNumbers = {
                        name = "Break down large numbers",
                        desc = "Type large number using separators",
                        type = "toggle",
                        set = "SetBreakLargeNumbers",
                        get = "GetBreakLargeNumbers",
                        width = "full",
                        order = 7
                    },
                    icon = {
                        name = "Show icon in text",
                        desc = "Show icon in the value text (workaround for eg. ElvUI Datatexts)",
                        type = "toggle",
                        set = "SetShowIcon",
                        get = "GetShowIcon",
                        width = "full",
                        order = 9
                    },
                    label = {
                        name = "Show label",
                        desc = "Show label in front of output",
                        type = "toggle",
                        set = "SetShowLabel",
                        get = "GetShowLabel",
                        width = "full",
                        order = 10
                    },
                    verbose = {
                        name = "Enable chat output",
                        desc = "Toggle verbose output in chat",
                        type = "toggle",
                        set = "SetVerbose",
                        get = "GetVerbose",
                        width = "full",
                        order = 11
                    }
                }
            },
            tooltip = {
                name = "Tooltip",
                type = "group",
                handler = StoredResearchCounter,
                args = {
                    tooltipDesc = {
                        name = "\nToggle info to show on Korthian Relics item tooltips",
                        type = "description",
                        order = 1
                    },
                    baggedAnimaToggle = {
                        name = "Show bagged Cataloged Research",
                        desc = "Show total Cataloged Research currently in your bags",
                        type = "toggle",
                        set = "SetTTBaggedAnima",
                        get = "GetTTBaggedAnima",
                        width = "full",
                        order = 2
                    },
                    reservoirAnimaToggle = {
                        name = "Show reservoir Cataloged Research",
                        desc = "Show amount of Cataloged Research at Archivist Roh-Suir",
                        type = "toggle",
                        set = "SetTTReservoirAnima",
                        get = "GetTTReservoirAnima",
                        width = "full",
                        order = 3
                    },
                    totalAnimaToggle = {
                        name = "Show total Cataloged Research",
                        desc = "Show total of bagged and Cataloged Research at Archivist Roh-Suir",
                        type = "toggle",
                        set = "SetTTTotalAnima",
                        get = "GetTTTotalAnima",
                        width = "full",
                        order = 3
                    }
                }
            }
        }
    }
    options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)

    AceConfig:RegisterOptionsTable(addonName, options, {"StoredResearchCounter", "src"})
    AceConfigDialog:AddToBlizOptions(addonName)
end

function StoredResearchCounter:RefreshConfig()
    configIsVerbose = self.db.profile.verbose
    configFormat = self.db.profile.format
    configBreakLargeNumbers = self.db.profile.breakLargeNumbers
    configShowLabel = self.db.profile.showLabel
    configShowIcon = self.db.profile.showIcon
    configCustomFormat = self.db.profile.customFormat
    configTTBaggedAnima = self.db.profile.TTBaggedAnima
    configTTReservoirAnima = self.db.profile.TTReservoirAnima
    configTTTotalAnima = self.db.profile.TTTotalAnima
    StoredResearchCounter:SetUpHooks()
    StoredResearchCounter:ScanForStoredAnima()
end

function StoredResearchCounter:GetAnimaIcon()
    return 1506458 --C_CurrencyInfo.GetCurrencyInfo(C_CovenantSanctumUI.GetAnimaInfo()).iconFileID
end

function StoredResearchCounter:OpenConfigPanel(info)
    InterfaceOptionsFrame_OpenToCategory(addonName)
    InterfaceOptionsFrame_OpenToCategory(addonName)
end

function StoredResearchCounter:SetVerbose(info, toggle)
    configIsVerbose = toggle
    self.db.profile.verbose = toggle
end

function StoredResearchCounter:GetVerbose(info)
    return configIsVerbose
end

function StoredResearchCounter:SetFormat(info, toggle)
    configFormat = toggle
    self.db.profile.format = toggle
    StoredResearchCounter:OutputValue(ldbObject.value)
end

function StoredResearchCounter:GetFormat(info)
    return configFormat
end

function StoredResearchCounter:SetBreakLargeNumbers(info, toggle)
    configBreakLargeNumbers = toggle
    self.db.profile.breakLargeNumbers = toggle
    StoredResearchCounter:OutputValue(ldbObject.value)
end

function StoredResearchCounter:GetBreakLargeNumbers(info)
    return configBreakLargeNumbers
end

function StoredResearchCounter:SetShowLabel(info, toggle)
    configShowLabel = toggle
    self.db.profile.showLabel = toggle
    StoredResearchCounter:OutputValue(ldbObject.value)
end

function StoredResearchCounter:GetShowLabel(info)
    return configShowLabel
end

function StoredResearchCounter:SetShowIcon(info, toggle)
    configShowIcon = toggle
    self.db.profile.showIcon = toggle
    StoredResearchCounter:OutputValue(ldbObject.value)
end

function StoredResearchCounter:GetShowIcon(info)
    return configShowIcon
end

function StoredResearchCounter:SetTTBaggedAnima(info, toggle)
    configTTBaggedAnima = toggle
    self.db.profile.TTBaggedAnima = toggle
    StoredResearchCounter:OutputValue(ldbObject.value)
end

function StoredResearchCounter:GetTTBaggedAnima(info)
    return configTTBaggedAnima
end


function StoredResearchCounter:SetTTReservoirAnima(info, toggle)
    configTTReservoirAnima = toggle
    self.db.profile.TTReservoirAnima = toggle
    StoredResearchCounter:OutputValue(ldbObject.value)
end

function StoredResearchCounter:GetTTReservoirAnima(info)
    return configTTReservoirAnima
end


function StoredResearchCounter:SetTTTotalAnima(info, toggle)
    configTTTotalAnima = toggle
    self.db.profile.TTTotalAnima = toggle
    StoredResearchCounter:OutputValue(ldbObject.value)
end

function StoredResearchCounter:GetTTTotalAnima(info)
    return configTTTotalAnima
end

function StoredResearchCounter:SetCustomFormat(info, input)
    configCustomFormat = input
    self.db.profile.customFormat = input
    StoredResearchCounter:OutputValue(ldbObject.value)
end

function StoredResearchCounter:GetCustomFormat(info)
    return configCustomFormat
end

-- Anima functions

function StoredResearchCounter:ScanForStoredAnimaDelayed()
    SAC__wait(10, StoredResearchCounter.ScanForStoredAnima, time())
end

function StoredResearchCounter:ScanForStoredAnima()
    vprint("Scanning:")
    local total = 0
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            total = total + (StoredResearchCounter:CountAnima(bag, slot) or 0)
        end
    end
    StoredResearchCounter:OutputValue(total)
end

function StoredResearchCounter:OutputValue(storedAnima)
    local stored, pool, sum

    -- Breakdown large numbers
    if configBreakLargeNumbers then
        stored = BreakUpLargeNumbers(storedAnima)
        pool = BreakUpLargeNumbers(GetTotalResearch())
        sum = BreakUpLargeNumbers(GetTotalResearch() + storedAnima)
    else
        stored = storedAnima
        pool = GetTotalResearch()
        sum = GetTotalResearch() + storedAnima
    end

    -- Reset text
    ldbObject.text = ""

    -- Show icon in label
    if configShowIcon then
        ldbObject.text = string.format(iconString, StoredResearchCounter:GetAnimaIcon())
    end

    -- Show label
    if configShowLabel then
        ldbObject.text = ldbObject.text .. string.format("|cFFFF7F38%s:|r ", ldbObject.label)
    end

    -- Update values
    vprint(">> Total stored cataloged research: " .. stored)
    ldbObject.value = storedAnima
    if configFormat == Format.stored then
        ldbObject.text = ldbObject.text .. string.format("%s", stored)
    elseif configFormat == Format.stored_plus_pool then
        ldbObject.text = ldbObject.text .. string.format("%s (%s)", stored, pool)
    elseif configFormat == Format.pool_plus_stored then
        ldbObject.text = ldbObject.text .. string.format("%s (%s)", pool, stored)
    elseif configFormat == Format.sum_only then
        ldbObject.text = ldbObject.text .. string.format("%s", sum)
    elseif configFormat == Format.sum_plus_stored then
        ldbObject.text = ldbObject.text .. string.format("%s (%s)", sum, stored)
    elseif configFormat == Format.stored_plus_sum then
        ldbObject.text = ldbObject.text .. string.format("%s (%s)", stored, sum)
    elseif configFormat == Format.pool_plus_sum then
        ldbObject.text = ldbObject.text .. string.format("%s (%s)", pool, sum)
    elseif configFormat == Format.custom_format then
        local txt = string.gsub(configCustomFormat, "${stored}", stored)
        txt = string.gsub(txt, "${pool}", pool)
        txt = string.gsub(txt, "${sum}", sum)
        ldbObject.text = ldbObject.text .. txt
    end

    -- Hack for controlling label display settings in ElvUI (which shows by default on strlen < 3)
    local len = #ldbObject.text
    if len < 3 then
        ldbObject.text = " " .. ldbObject.text
    end
    if len < 2 then
        ldbObject.text = ldbObject.text .. " "
    end
    if len < 1 then
        ldbObject.text = "-"
    end

end

function StoredResearchCounter:ttCreate()
    local tip, tipText = CreateFrame("GameTooltip"), {}
    for i = 1, 6 do
        local tipLeft, tipRight = tip:CreateFontString(), tip:CreateFontString()
        tipLeft:SetFontObject(GameFontNormal)
        tipRight:SetFontObject(GameFontNormal)
        tip:AddFontStrings(tipLeft, tipRight)
        tipText[i] = tipLeft
    end
    tip.tipText = tipText
    return tip
end

function StoredResearchCounter:CountAnima(bag, slot)
    local itemId = GetContainerItemID(bag, slot)
    local _, itemCount = GetContainerItemInfo(bag, slot)
    local totalResearch = 0
    local researchCount = 0
    if itemId ~= nil then
        local itemLink = select(2, GetItemInfo(itemId))
        local itemClassID, itemSubClassID, _, xpac = select(12, GetItemInfo(itemId))
        tooltip = tooltip or StoredResearchCounter:ttCreate()
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
        tooltip:ClearLines()
        tooltip:SetBagItem(bag, slot)
        
        local isResearch = false
        if tooltip.tipText ~= nil then
            for j = 1, #tooltip.tipText do
                local t = tooltip.tipText[j]:GetText()
                -- Cataloged Research isn't matching the tooltip text properly, so have to search on substring
                if xpac == 8 and t ~= nil and itemClassID == 15 and itemSubClassID == 4 and t:find("Korthian Relics|r$") then
                    isResearch = true
                elseif t ~= nil and isResearch and t:find("^Use") then
                    local num = t:match("%d+%sCataloged%sResearch")
                    num = num:match("%d+")
                    researchCount = tonumber(num or "")
                end
            end
        end
        
        if isResearch and (researchCount > 0) then
            totalResearch = (itemCount or 1) * researchCount
            vprint("Cataloged Research present: " .. totalResearch .. " on " .. itemLink)
        end
        tooltip:Hide()
    end
    return totalResearch
end

function isCatalogedResearchItem(itemId)
    local itemClassID, itemSubClassID, _, xpac = select(12, GetItemInfo(itemId))
    if (xpac == 8 and itemClassID == 15 and itemSubClassID == 4 ) then
        tooltip = tooltip or StoredResearchCounter:ttCreate()
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
        tooltip:ClearLines()
        tooltip:SetHyperlink(itemId)
        local isRelic = false
        if tooltip.tipText ~= nil then
            for j = 1, #tooltip.tipText do
                local t = tooltip.tipText[j]:GetText()
                -- Cataloged Research isn't matching the tooltip text properly, so have to search on substring
                if t ~= nil and t:find("Korthian Relics|r$") then
                    isRelic = true
                elseif t ~= nil and isRelic and t:find("^Use") then
                    tooltip:Hide()
                    return true
                end
            end
        end
    end
    tooltip:Hide()
    return false
end

function vprint(val)
    if configIsVerbose then
        print(val)
    end
end

function AnimaPrint(val, itemId)
    if configIsVerbose then
        local itemLink = select(2, GetItemInfo(itemId))
        print("Anima present: " .. val .. " on " .. itemLink)
    end
end

function GetTotalResearch()
    local currencyID = 1931
    return C_CurrencyInfo.GetCurrencyInfo(currencyID).quantity
end

local NORMAL_FONT_COLOR = {1.0, 0.82, 0.0}

function ldbObject:OnTooltipShow()
    local stored, pool, sum
    if configBreakLargeNumbers then
        stored = BreakUpLargeNumbers(ldbObject.value)
        pool = BreakUpLargeNumbers(GetTotalResearch())
        sum = BreakUpLargeNumbers(GetTotalResearch() + ldbObject.value)
    else
        stored = ldbObject.value
        pool = GetTotalResearch()
        sum = GetTotalResearch() + ldbObject.value
    end

    self:AddLine("|cFFFF7F38Stored Research|r")
    self:AddLine("An overview of Cataloged Research stored in your bags, but not yet added to your Cataloged Research at Archivist Roh-Suir.", 1.0, 0.82,
        0.0, 1)
    self:AddLine("\n")
    self:AddDoubleLine("Stored:", "|cFFFFFFFF" .. stored .. "|r")
    self:AddDoubleLine("Pooled:", "|cFFFFFFFF" .. pool .. "|r")
    self:AddDoubleLine("Total:", "|cFFFFFFFF" .. sum .. "|r")
end

function ldbObject:OnClick(button)
    if "RightButton" == button then
        StoredResearchCounter:OpenConfigPanel()
    elseif "LeftButton" == button then
        _G.ToggleCharacter('TokenFrame')
    end
end

local waitTable = {};
local waitFrame = nil;

function SAC__wait(delay, func, ...)
    if (type(delay) ~= "number" or type(func) ~= "function") then
        return false;
    end
    if (waitFrame == nil) then
        waitFrame = CreateFrame("Frame", "WaitFrame", UIParent);
        waitFrame:SetScript("onUpdate", function(self, elapse)
            local count = #waitTable;
            local i = 1;
            while (i <= count) do
                local waitRecord = tremove(waitTable, i);
                local d = tremove(waitRecord, 1);
                local f = tremove(waitRecord, 1);
                local p = tremove(waitRecord, 1);
                if (d > elapse) then
                    tinsert(waitTable, i, {d - elapse, f, p});
                    i = i + 1;
                else
                    count = count - 1;
                    f(unpack(p));
                end
            end
        end);
    end
    tinsert(waitTable, {delay, func, {...}});
    return true;
end
