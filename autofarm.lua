-- ==============================================================================
-- My Anime Mine Autofarm + Dashboard  v2026.10.14-10
--   แดชบอร์ด 3 หน้า:
--     ภาพรวม   : เงิน / โซน / % ไปโซนถัดไป (วิจัย + เงิน) + สถานะทุกระบบ (ทำอะไรอยู่ ล่าสุดเมื่อไร) + เหตุการณ์ล่าสุด
--     ของที่มี : คนงานบนแปลง (เลเวล แรร์ Pickaxe) / Pickaxe ที่มี / ของในกระเป๋า (อ่านจากหน้าขาย บอกว่าคนงานตัวไหนจะเก็บ/จะขาย)
--     ตั้งค่า   : เปิด-ปิดแต่ละระบบ / คัดลอกข้อมูลตรวจสอบ / หยุดฟาร์ม
--   ปุ่มบนแถบ: – = ย่อเหลือแถบเดียว , × = ซ่อน (กดปุ่ม MAM ที่ขอบจอเพื่อเปิดคืน) ; ลากแถบบนเพื่อย้าย (ใช้นิ้วหรือเมาส์ได้ ปุ่ม MAM ก็ลากได้)
--   คำสั่ง: _G.MyAnimeMineGodFarm.Dash.Show() / .Hide() / .Tab("overview"|"inv"|"settings")
--           _G.MyAnimeMineGodFarm.Diag()   -- คัดลอกข้อมูลตรวจสอบ (คลิปบอร์ด + ไฟล์ MAM_diag_<UserId>.txt)
--   แดชบอร์ดแค่อ่านค่าและจดสถานะ ไม่ยิงคำสั่งเพิ่มเข้าเกม
--   v2026.10.14-10: ทำงานเป็นรอบ (ค่าเริ่มต้น 45 วิ ปรับได้ในหน้าตั้งค่า) — ขุดแร่ทำตลอด
--     เก็บหีบ → รอ 5 วิ → ใส่คนงานตัวดีสุด → ขาย → วิจัย (หลายขั้น) → ปลดโซน → อัปเลเวลคนงาน → ซื้อ/ใส่ Pickaxe
--   v2026.10.14-7/-9 (เน้นผ่านด่าน):
--     - อัปวิจัยแบบใหม่: อ่าน Skills/ZoneSkillMax/SkillPipCosts/ZoneSkillNodes ซื้อขั้นถูกสุดที่ปุ่มแม่ครบแล้ว
--       ตรวจว่าขั้นเพิ่มจริง ไม่เพิ่ม 3 ครั้งติด = พักสายนั้น 5 นาที
--       ซื้อผ่านหน้าสกิลของเกม: แท็บ → เลือก Node_<Id> → เช็กราคา + เช็กว่าเลือกติด → เรียก buySelected ของเกม 1 ครั้ง
--       (ฟังก์ชันซื้อจริงของเกม ส่ง MineBuySkill ด้วยค่าที่ถูกต้องเอง) ; หา buySelected ไม่เจอ = กดค้างปุ่มซื้อแทน ; ไม่ใช้ remote spy ไม่ hook
--     - อัป Core หลังวิจัยครบ (สวิตช์ ปิดเป็นค่าเริ่มต้น)
--     - โหมดเน้นด่าน (เปิดเริ่มต้น): กันเงินเท่าขั้นวิจัยถัดไป (หรือค่าปลดโซนเมื่อวิจัยครบและป้ายบอกราคา)
--       อัปเลเวลคนงาน/ซื้อ Pickaxe ใช้ได้เฉพาะเงินส่วนเกิน ; ถ้าแพงเกิน 10 เท่าของเงินที่มี = ไม่กัน
--     - ซื้อ Pickaxe แล้วจำนวนไม่เพิ่ม = พักชนิดนั้น 10 นาที
--     - การ์ด "ลำดับการอัปวิจัย" ในหน้าภาพรวม
-- ==============================================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local lp = Players.LocalPlayer
if not lp then return end

if _G.MyAnimeMineGodFarm and typeof(_G.MyAnimeMineGodFarm.Cleanup) == "function" then
    _G.MyAnimeMineGodFarm.Cleanup()
end

local SCRIPT_VERSION = "2026.10.14-10"

local GameState
pcall(function()
    GameState = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameState"))
end)

local Items
pcall(function()
    Items = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Items"))
end)

local MineConfig
pcall(function()
    MineConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MineConfig"))
end)

local MineStock
pcall(function()
    MineStock = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MineStock"))
end)

local CharacterDefs = {}
pcall(function()
    local MineCharacterCatalog = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MineCharacterCatalog"))
    local list = MineCharacterCatalog.Characters or MineCharacterCatalog
    for _, ch in ipairs(list) do
        if ch.ItemName then
            CharacterDefs[ch.ItemName] = ch
        end
    end
end)

local function getCharacterBaseDamage(charName)
    local def = CharacterDefs[charName]
    if not def then return 0, 0, "Unknown" end
    local tier = def.MineTier or 1
    local mult = tonumber(def.MineDamageMult) or 1
    local tierDmg = (MineConfig and MineConfig.TierDamage and MineConfig.TierDamage[tier]) or 1
    local baseDmg = tierDmg * mult
    local rarity = def.Rarity and (typeof(def.Rarity) == "table" and def.Rarity.Rarity or tostring(def.Rarity)) or "Common"
    return baseDmg, tier, rarity
end

local State = {
    Running = true,
    HyperMine = true,
    AutoChest = true,
    AutoSell = true,
    AutoSellMiners = true,
    ProtectHighDamageMiners = true,
    AutoBuyPickaxe = true,
    AutoEquipPickaxe = true,
    BalancedLeveling = true,
    MinerBudgetRatio = 0.10,
    MinerBudgetUnlockedRatio = 0.40,
    AutoEquipBest = true,
    AutoSkillTree = true,
    AutoZoneUnlock = true,
    FocusZone = true,   -- โหมดเน้นด่าน
    AutoCore = false,   -- อัป Core หลังวิจัยโซนครบ
    IsSelling = false,
    MineDelay = 0.025,
    ChestInterval = 4.0,
    SellInterval = 8.0,
    UpgradeInterval = 3.0,
    EquipBestInterval = 15.0,
    SkillInterval = 3.0,
    ZoneInterval = 3.0,
    PickaxeInterval = 5.0,
    CycleInterval = 45,        -- รอบทำงาน (วินาที): เก็บหีบ → รอ → ใส่คนงานตัวดีสุด → ขาย → อัปเกรด
    SellDelay = 5,             -- หลังเก็บหีบ รอกี่วินาทีก่อนขาย
    ResearchPerCycle = 10,     -- ซื้อวิจัยได้สูงสุดกี่ขั้นต่อรอบ
    LevelRunsPerCycle = 10,    -- อัปเลเวลคนงานได้สูงสุดกี่รอบย่อยต่อรอบ
    PickBuysPerCycle = 4,      -- ซื้อ Pickaxe ได้สูงสุดกี่ครั้งต่อรอบ
    Threads = {},
    Connections = {}
}

local suffixes = {
    K = 1e3, M = 1e6, B = 1e9, T = 1e12,
    Qa = 1e15, Qi = 1e18, Sx = 1e21, Sp = 1e24,
    Oc = 1e27, No = 1e30, Dc = 1e33, Ud = 1e36,
    Dd = 1e39, Td = 1e42, Qad = 1e45, Qid = 1e48,
    Sxd = 1e51, Spd = 1e54, Ocd = 1e57, Nod = 1e60,
    Vg = 1e63
}

local function parseCash(str)
    if not str then return 0 end
    local clean = str:gsub("[$,]", ""):gsub("%s+", "")
    local num, suf = clean:match("^([%d%.]+)(%a*)$")
    if num then
        local n = tonumber(num) or 0
        if suf and suffixes[suf] then
            return n * suffixes[suf]
        end
        return n
    end
    return 0
end

-- ---------- ตัวจดสถานะการทำงาน (ใช้แสดงในแดชบอร์ด ไม่มีผลกับการฟาร์ม) ----------
local clock = os.clock
local T_START = clock()
local Act = {
    mods = {},   -- [ระบบ] = { text, kind = "ok"|"wait"|"err", at, runs, lastRun }
    log = {},    -- เหตุการณ์ล่าสุด (ใหม่สุดอยู่บน)
    n = { clicks = 0, chestTakes = 0, sells = 0, soldOre = 0, soldMiners = 0, earned = 0, upgrades = 0,
          picksBought = 0, pickSwaps = 0, skills = 0, zones = 0, equipBest = 0, errors = 0 },
}

local function shortErr(e)
    local s = (tostring(e or "?"):gsub("^.-:%d+: ", ""))
    s = s:gsub('"Players%.[^%.]+%.PlayerGui%.', '"PlayerGui.')   -- ตัดชื่อผู้เล่นออก ข้อความจะได้สั้นลง
    if #s > 90 then s = s:sub(1, 87) .. "..." end
    return s
end

local function modEntry(key)
    local m = Act.mods[key]
    if not m then
        m = { runs = 0 }
        Act.mods[key] = m
    end
    return m
end

local function mark(key, text, kind)
    local m = modEntry(key)
    m.text = text
    m.kind = kind or "ok"
    m.at = clock()
end

local function logEvent(text)
    local ok, stamp = pcall(os.date, "%H:%M:%S")
    if not ok or type(stamp) ~= "string" then stamp = string.format("+%ds", math.floor(clock() - T_START)) end
    local top = Act.log[1]
    if top and top.text == text then   -- เรื่องเดิมซ้ำติดกัน = รวมเป็นบรรทัดเดียว (×จำนวน)
        top.count = top.count + 1
        top.t = stamp
        return
    end
    table.insert(Act.log, 1, { t = stamp, text = text, count = 1 })
    while #Act.log > 40 do table.remove(Act.log) end
end

local function runTracked(key, fn)
    local m = modEntry(key)
    m.runs = m.runs + 1
    m.lastRun = clock()
    local ok, err = pcall(fn)
    if not ok then
        Act.n.errors = Act.n.errors + 1
        m.lastErr = tostring(err)   -- ข้อความเต็ม (ใส่ในข้อมูลตรวจสอบ)
        mark(key, "ผิดพลาด: " .. shortErr(err), "err")
    end
end

local SUFFIX_ORDER = {}
for k, v in pairs(suffixes) do SUFFIX_ORDER[#SUFFIX_ORDER + 1] = { k, v } end
table.sort(SUFFIX_ORDER, function(a, b) return a[2] > b[2] end)

local function fmtNum(n)
    n = tonumber(n) or 0
    local neg = n < 0
    if neg then n = -n end
    local s
    if n < 1000 then
        s = (n == math.floor(n)) and tostring(math.floor(n)) or string.format("%.1f", n)
    else
        for _, p in ipairs(SUFFIX_ORDER) do
            if n >= p[2] then
                s = (string.format("%.2f", n / p[2]):gsub("%.?0+$", "")) .. p[1]
                break
            end
        end
        s = s or string.format("%.2e", n)
    end
    return (neg and "-" or "") .. s
end

local function fmtCash(n)
    local s = fmtNum(n)
    if s:sub(1, 1) == "-" then return "-$" .. s:sub(2) end
    return "$" .. s
end

local function getPlayerMoney()
    local ok, m = pcall(function()
        return debug.getupvalues(GameState.GetData2)[3][tostring(lp.UserId)].plrData.Money
    end)
    if ok and typeof(m) == "number" then return m end
    return 0
end

local function getMyPlot()
    local plotsFolder = workspace:FindFirstChild("MineWorld") and workspace.MineWorld:FindFirstChild("Plots")
    if not plotsFolder then return nil end

    local plotIndex = lp:GetAttribute("MinePlotIndex")
    if plotIndex then
        local found = plotsFolder:FindFirstChild("MinePlot" .. tostring(plotIndex))
        if found then return found end
    end

    for _, p in ipairs(plotsFolder:GetChildren()) do
        local owner = p:FindFirstChild("Owner") or p:FindFirstChild("Player")
        if (owner and owner.Value == lp) or string.find(p.Name, lp.Name) then
            return p
        end
    end

    return plotsFolder:FindFirstChild("MinePlot1")
end

local function getEquippedBenchmark()
    local minBaseDmg = math.huge
    local minTier = 999
    local plot = getMyPlot()
    local holders = plot and plot:FindFirstChild("Holders")
    if holders then
        for i = 1, 15 do
            local slotKey = "M" .. tostring(i)
            local holder = holders:FindFirstChild(slotKey)
            local charName = holder and holder:GetAttribute("CrewChar")
            if charName then
                local baseDmg, tier = getCharacterBaseDamage(charName)
                if baseDmg > 0 and baseDmg < minBaseDmg then
                    minBaseDmg = baseDmg
                end
                if tier > 0 and tier < minTier then
                    minTier = tier
                end
            end
        end
    end
    return minBaseDmg, minTier
end

local function isNextZoneUnlocked()
    local ok, res = pcall(function()
        local plrData = debug.getupvalues(GameState.GetData2)[3][tostring(lp.UserId)].plrData.MineGame
        if not plrData then return false end
        local curZone = plrData.CurrentZone or lp:GetAttribute("CurrentZone") or 1
        local nextZone = curZone + 1
        local nextKey = "Z" .. tostring(nextZone)
        if plrData.UnlockedZones and plrData.UnlockedZones[nextKey] == true then
            return true
        end
        return false
    end)
    return ok and res == true
end

local function isCurrentZoneResearchComplete()
    local ok, res = pcall(function()
        local plrData = debug.getupvalues(GameState.GetData2)[3][tostring(lp.UserId)].plrData.MineGame
        if plrData and plrData.Skills and MineConfig and MineConfig.IsZoneResearchComplete then
            local curZone = plrData.CurrentZone or lp:GetAttribute("CurrentZone") or 1
            return MineConfig.IsZoneResearchComplete(plrData.Skills, "Z" .. tostring(curZone))
        end
    end)
    return ok and res == true
end

-- คนงานตัวนี้ "เก็บไว้" ไหม (กติกาเดิมของระบบขาย ย้ายมาเป็นฟังก์ชันเพื่อให้แดชบอร์ดบอกได้ว่าตัวไหนจะเก็บ/จะขาย)
local PROTECTED_RARITIES = {
    ["Epic"] = true,
    ["Legendary"] = true,
    ["Mythical"] = true,
    ["Exotic"] = true,
    ["Limited"] = true,
    ["Exclusive"] = true
}

local function judgeMiner(entry, minEquippedDmg, minEquippedTier)
    local name = entry.Name or entry.Display or entry.Key
    local baseDmg, tier, rarity = getCharacterBaseDamage(name)
    if entry.Ex and typeof(entry.Ex.Damage) == "number" and entry.Ex.Damage > baseDmg then
        baseDmg = entry.Ex.Damage
    end
    if entry.Tier and typeof(entry.Tier) == "number" and entry.Tier > tier then
        tier = entry.Tier
    end

    local why
    if State.ProtectHighDamageMiners then
        if PROTECTED_RARITIES[rarity] then
            why = "แรร์ " .. tostring(rarity)
        elseif (entry.Zone and entry.Zone >= 4) or tier >= 30 then
            why = (entry.Zone and entry.Zone >= 4) and "มาจากโซน 4+" or "Tier 30+"
        elseif minEquippedDmg < math.huge and baseDmg >= minEquippedDmg then
            why = "ดาเมจไม่น้อยกว่าตัวที่ใส่"
        elseif minEquippedTier < 999 and tier >= minEquippedTier then
            why = "Tier ไม่น้อยกว่าตัวที่ใส่"
        end
    end
    return why ~= nil, why, rarity, tier, baseDmg, name
end

local minMinerUpgradeCost = 0
pcall(function()
    local notifRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("SendNotification")
    if notifRemote then
        local c = notifRemote.OnClientEvent:Connect(function(msg)
            if typeof(msg) == "string" and msg:find("Not enough cash") then
                local costStr = msg:match("costs%s+([%$%d%.%a,]+)")
                if costStr then
                    local costVal = parseCash(costStr)
                    if costVal > 0 then
                        minMinerUpgradeCost = costVal
                    end
                end
            end
        end)
        table.insert(State.Connections, c)
    end
end)

local function executeHyperMine()
    local plot = getMyPlot()
    if not plot then mark("HyperMine", "หาแปลงของตัวเองไม่เจอ", "wait") return end

    local nodesFolder = plot:FindFirstChild("Nodes")
    if not nodesFolder then mark("HyperMine", "ไม่พบโฟลเดอร์ Nodes ในแปลง", "wait") return end

    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and not State.IsSelling then
        local sum = Vector3.zero
        local count = 0
        for _, n in ipairs(nodesFolder:GetChildren()) do
            local p = n:FindFirstChildWhichIsA("BasePart")
            if p then
                sum = sum + p.Position
                count = count + 1
            end
        end
        if count > 0 then
            local center = sum / count
            if (hrp.Position - center).Magnitude > 5 then
                hrp.CFrame = CFrame.new(center + Vector3.new(0, 2.5, 0))
            end
        end
    end

    local clicks = 0
    for _, node in ipairs(nodesFolder:GetChildren()) do
        if not State.Running or not State.HyperMine or State.IsSelling then break end

        local clickDetector = node:FindFirstChild("NodeClick")
        if clickDetector and fireclickdetector then
            pcall(function()
                fireclickdetector(clickDetector)
            end)
            clicks = clicks + 1
            Act.n.clicks = Act.n.clicks + 1
            task.wait(State.MineDelay)
        end
    end

    if clicks > 0 then
        mark("HyperMine", "ขุดแร่ " .. clicks .. " ก้อนต่อรอบ")
    elseif State.IsSelling then
        mark("HyperMine", "พักขุดระหว่างไปขายของ", "wait")
    elseif not fireclickdetector then
        mark("HyperMine", "executor ไม่รองรับ fireclickdetector", "err")
    elseif State.Running and State.HyperMine then
        mark("HyperMine", "ไม่มีก้อนแร่ให้ขุด (รอเกิดใหม่)", "wait")
    end
end

local function executeChestLoot()
    local plot = getMyPlot()
    if not plot then mark("Chest", "หาแปลงของตัวเองไม่เจอ", "wait") return end

    local chest = plot:FindFirstChild("Chest")
    local chestBox = chest and (chest:FindFirstChild("ChestBox") or chest:FindFirstChild("Root") or chest:FindFirstChildWhichIsA("BasePart"))
    local prompt = chest and chest:FindFirstChildWhichIsA("ProximityPrompt", true)

    if not prompt and chestBox then
        prompt = chestBox:FindFirstChildWhichIsA("ProximityPrompt")
    end

    if prompt then
        if fireproximityprompt then
            pcall(function() fireproximityprompt(prompt) end)
        else
            for _, c in ipairs(getconnections(ProximityPromptService.PromptTriggered)) do
                if c.Function then pcall(c.Function, prompt, lp) end
            end
        end

        task.wait(0.2)

        local chestFrame = lp.PlayerGui:FindFirstChild("MineGui") and lp.PlayerGui.MineGui:FindFirstChild("ChestFrame")
        if chestFrame and chestFrame.Visible then
            local takeBtn = chestFrame:FindFirstChild("TakeAll", true) or chestFrame:FindFirstChild("TakeButton", true)
            if takeBtn then
                for _, c in ipairs(getconnections(takeBtn.MouseButton1Click)) do
                    if c.Function then pcall(c.Function) else pcall(function() c:Fire() end) end
                end
                Act.n.chestTakes = Act.n.chestTakes + 1
                logEvent("เก็บของจากหีบ")
                mark("Chest", "เก็บของจากหีบแล้ว")
            else
                mark("Chest", "เปิดหีบแล้ว แต่ไม่พบปุ่มเก็บทั้งหมด", "wait")
            end
            task.wait(0.15)
            local closeBtn = chestFrame:FindFirstChild("Close", true)
            if closeBtn then
                for _, c in ipairs(getconnections(closeBtn.MouseButton1Click)) do
                    if c.Function then pcall(c.Function) else pcall(function() c:Fire() end) end
                end
            end
        else
            mark("Chest", "กดเปิดหีบแล้ว (หน้าหีบไม่เด้ง = ยังไม่มีของ)", "wait")
        end
    else
        local chestFrame = lp.PlayerGui:FindFirstChild("MineGui") and lp.PlayerGui.MineGui:FindFirstChild("ChestFrame")
        if not chestFrame or not chestFrame.Visible then
            mark("Chest", "ไม่พบปุ่มเปิดหีบในแปลง", "wait")
            return
        end

        local takeBtn = chestFrame:FindFirstChild("TakeAll", true) or chestFrame:FindFirstChild("TakeButton", true)
        if takeBtn then
            for _, c in ipairs(getconnections(takeBtn.MouseButton1Click)) do
                if c.Function then pcall(c.Function) else pcall(function() c:Fire() end) end
            end
            Act.n.chestTakes = Act.n.chestTakes + 1
            logEvent("เก็บของจากหีบ")
            mark("Chest", "เก็บของจากหีบแล้ว")
        end
        task.wait(0.15)
        local closeBtn = chestFrame:FindFirstChild("Close", true)
        if closeBtn then
            for _, c in ipairs(getconnections(closeBtn.MouseButton1Click)) do
                if c.Function then pcall(c.Function) else pcall(function() c:Fire() end) end
            end
        end
    end
end

local function executeMassSell()
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local sellStand = workspace:FindFirstChild("SellStand")
    local prompt = sellStand and sellStand:FindFirstChild("SellPrompt", true)
    local part = prompt and prompt.Parent

    if not hrp or not part or not prompt then
        mark("Sell", (not hrp) and "รอตัวละครเกิด" or "หาจุดขาย (SellStand) ไม่เจอ", "wait")
        return
    end

    if GameState and typeof(GameState.SendEvent) == "function" then
        pcall(function()
            GameState.SendEvent("MineEquipBest")
        end)
    end
    task.wait(0.1)

    State.IsSelling = true
    local origCF = hrp.CFrame

    hrp.CFrame = part.CFrame + Vector3.new(0, 0, 3)
    task.wait(0.2)

    if fireproximityprompt then
        pcall(function() fireproximityprompt(prompt) end)
    else
        for _, c in ipairs(getconnections(ProximityPromptService.PromptTriggered)) do
            local f = c.Function
            if f and debug.info(f, "s"):find("MineSellClient") then
                pcall(f, prompt, lp)
                break
            end
        end
    end

    task.wait(0.25)

    local soldOre, soldMiners, keptMiners, sold = 0, 0, 0, false
    local moneyBefore = getPlayerMoney()
    pcall(function()
        local sellFrame = lp.PlayerGui:FindFirstChild("MineGui") and lp.PlayerGui.MineGui:FindFirstChild("SellFrame")
        local sellBtn = sellFrame and sellFrame:FindFirstChild("Content") and sellFrame.Content:FindFirstChild("SellButton")
        if not sellBtn then return end

        local conns = getconnections(sellBtn.MouseButton1Click)
        if #conns == 0 then return end

        local sellFunc = conns[1].Function
        if not sellFunc then return end

        local u1 = debug.getupvalues(sellFunc)[1]
        local u2 = debug.getupvalues(sellFunc)[2]

        if typeof(u1) == "table" and typeof(u2) == "table" then
            local minEquippedDmg, minEquippedTier = getEquippedBenchmark()

            for k, item in pairs(u2) do
                if typeof(item) == "table" and typeof(item.entry) == "table" then
                    local entry = item.entry
                    local role = entry.Role
                    local kind = entry.Kind

                    if role == "Pickaxe" or kind == "Pickaxe" or role == "Potion" or kind == "Potion" then
                        u1[k] = nil
                    elseif role == "Ore" or kind == "Ore" then
                        u1[k] = true
                        soldOre = soldOre + 1
                    elseif (role == "Miner" or kind == "Character") and State.AutoSellMiners then
                        local isProtected = judgeMiner(entry, minEquippedDmg, minEquippedTier)

                        if not isProtected then
                            u1[k] = true
                            soldMiners = soldMiners + 1
                        else
                            u1[k] = nil
                            keptMiners = keptMiners + 1
                        end
                    end
                end
            end
            moneyBefore = getPlayerMoney()
            sellFunc()
            sold = true
        end
    end)

    task.wait(0.3)

    local sellFrame = lp.PlayerGui:FindFirstChild("MineGui") and lp.PlayerGui.MineGui:FindFirstChild("SellFrame")
    if sellFrame and sellFrame.Visible then
        local closeBtn = sellFrame:FindFirstChild("Close")
        if closeBtn then
            for _, c in ipairs(getconnections(closeBtn.MouseButton1Click)) do
                if c.Function then pcall(c.Function) else pcall(function() c:Fire() end) end
            end
        end
    end

    task.wait(0.15)

    hrp.CFrame = origCF
    State.IsSelling = false

    if not sold then
        mark("Sell", "ไปจุดขายแล้ว แต่เปิดหน้าขายไม่ได้", "wait")
    elseif soldOre + soldMiners == 0 then
        mark("Sell", "ไม่มีของให้ขาย" .. (keptMiners > 0 and (" (เก็บคนงานไว้ " .. keptMiners .. " ตัว)") or ""), "wait")
    else
        local gained = getPlayerMoney() - moneyBefore
        Act.n.sells = Act.n.sells + 1
        Act.n.soldOre = Act.n.soldOre + soldOre
        Act.n.soldMiners = Act.n.soldMiners + soldMiners
        if gained > 0 then Act.n.earned = Act.n.earned + gained end
        local txt = "ขายแร่ " .. soldOre .. " รายการ" .. (soldMiners > 0 and (" · คนงาน " .. soldMiners .. " ตัว") or "")
        if gained > 0 then txt = txt .. " (+" .. fmtCash(gained) .. ")" end
        logEvent(txt)
        mark("Sell", txt)
    end
end

-- ==============================================================================
-- วางแผนวิจัย (อ่านข้อมูลเกมตรง ๆ ไม่ใช้หน้าสกิล)
--   ขั้นที่มี  : MineGame.Skills[โซน][สาย]
--   ขั้นสูงสุด : MineConfig.ZoneSkillMax[โซน][สาย]
--   ราคา      : MineConfig.SkillPipCosts[โซน][สาย][ขั้น]
--   ต้นไม้     : MineConfig.ZoneSkillNodes[โซน] (ปุ่มละ Family/FamilyOffset/Pips/Parents) ซื้อได้เมื่อปุ่มแม่ครบทุกขั้น
-- ==============================================================================
local Research = { fails = {}, pause = {}, pending = nil, buyer = nil, plan = nil, planAt = -1e9 }
local PickGuard = { cool = {}, pending = nil }

local function readMineGame()
    local ok, mg = pcall(function() return debug.getupvalues(GameState.GetData2)[3][tostring(lp.UserId)].plrData.MineGame end)
    if ok and type(mg) == "table" then return mg end
    ok, mg = pcall(function() return GameState.GetData2().MineGame end)
    if ok and type(mg) == "table" then return mg end
    return nil
end

local function buildResearchPlan()
    local mg = readMineGame()
    if not mg or not MineConfig then return nil end
    local cur = tonumber(mg.CurrentZone) or 1
    local zk = "Z" .. tostring(cur)
    local maxT = type(MineConfig.ZoneSkillMax) == "table" and MineConfig.ZoneSkillMax[zk]
    local nodes = type(MineConfig.ZoneSkillNodes) == "table" and MineConfig.ZoneSkillNodes[zk]
    if type(maxT) ~= "table" or type(nodes) ~= "table" then return nil end
    local costs = (type(MineConfig.SkillPipCosts) == "table" and type(MineConfig.SkillPipCosts[zk]) == "table") and MineConfig.SkillPipCosts[zk] or {}
    local have = (type(mg.Skills) == "table" and type(mg.Skills[zk]) == "table") and mg.Skills[zk] or {}
    local function lvl(fam) return math.max(0, tonumber(have[fam]) or 0) end
    local byId = {}
    for _, nd in pairs(nodes) do
        if type(nd) == "table" and nd.Id ~= nil then byId[nd.Id] = nd end
    end
    local function maxed(nd)
        return lvl(nd.Family) >= (tonumber(nd.FamilyOffset) or 0) + (tonumber(nd.Pips) or 0)
    end
    local function blockerOf(nd)   -- ปุ่มแม่ตัวแรกที่ยังไม่ครบ (nil = เปิดแล้ว)
        if type(nd.Parents) ~= "table" then return nil end
        for _, pid in pairs(nd.Parents) do
            local par = byId[pid]
            if par and not maxed(par) then return par end
        end
        return nil
    end

    local P = { zone = cur, zk = zk, pips = {}, done = 0, total = 0, totalCost = 0 }
    for fam, mx in pairs(maxT) do
        mx = tonumber(mx) or 0
        if mx > 0 then
            P.total = P.total + mx
            P.done = P.done + math.min(lvl(fam), mx)
        end
    end
    local now = clock()
    for _, nd in pairs(nodes) do
        if type(nd) == "table" and nd.Family ~= nil then
            local fam = nd.Family
            local off = tonumber(nd.FamilyOffset) or 0
            local mx = tonumber(maxT[fam])
            local L = lvl(fam)
            local blocker = blockerOf(nd)
            for k = off + 1, off + (tonumber(nd.Pips) or 0) do
                if k > L and (not mx or k <= mx) then
                    local fc = costs[fam]
                    local cost = type(fc) == "table" and tonumber(fc[k]) or nil
                    local pip = { fam = fam, k = k, max = mx, node = nd, name = tostring(nd.Name or nd.Id or fam), cost = cost }
                    if blocker then
                        pip.state, pip.blocker = "locked", tostring(blocker.Name or blocker.Id)
                    elseif k ~= L + 1 then
                        pip.state = "after"
                    elseif not cost then
                        pip.state = "nocost"
                    else
                        pip.state = "next"
                    end
                    if Research.pause[fam] and Research.pause[fam] > now then pip.paused = Research.pause[fam] end
                    if cost then P.totalCost = P.totalCost + cost end
                    P.pips[#P.pips + 1] = pip
                end
            end
        end
    end
    table.sort(P.pips, function(a, b)
        if (a.cost ~= nil) ~= (b.cost ~= nil) then return a.cost ~= nil end
        if a.cost and b.cost and a.cost ~= b.cost then return a.cost < b.cost end
        if a.fam ~= b.fam then return tostring(a.fam) < tostring(b.fam) end
        return a.k < b.k
    end)
    for _, pip in ipairs(P.pips) do
        if pip.state == "next" and not pip.paused then P.cheapest = pip break end
    end
    P.complete = (P.total > 0 and P.done >= P.total) or isCurrentZoneResearchComplete()
    return P
end

local function researchPlan(fresh)
    if not fresh and Research.plan and clock() - Research.planAt < 0.5 then return Research.plan end
    local ok, P = pcall(buildResearchPlan)
    Research.plan = ok and P or nil
    Research.planErr = (not ok) and tostring(P) or nil
    Research.planAt = clock()
    return Research.plan
end

-- ราคาปลดโซนจากป้ายโซนบนแปลง (0 = ไม่เห็นราคา)
local function zoneUnlockCost(nextZone)
    local cost = 0
    pcall(function()
        local plot = getMyPlot()
        local row = plot.ZoneBoard.ZoneBoardGui.Root.List:FindFirstChild("ZoneRow" .. tostring(nextZone))
        local lbl = row and row:FindFirstChild("Label", true)
        if lbl and lbl.Text ~= "" then cost = parseCash(lbl.Text:match("%$[%d%.%a,]+")) end
    end)
    return cost
end

-- โหมดเน้นด่าน: กันเงินไว้เท่าราคาขั้นวิจัยที่ถูกที่สุดที่ซื้อได้ ; ถ้าแพงเกิน 10 เท่าของเงินที่มี = ไม่กัน
--   วิจัยครบแล้ว: กันเงินไว้เท่าค่าปลดโซนถัดไป (เฉพาะเมื่อป้ายโซนบอกราคา และเปิดระบบปลดโซน)
local function researchReserve(money)
    if not State.FocusZone then return 0, "off" end
    local P = researchPlan()
    if not P then return 0, "nodata" end
    if P.complete then
        local nz = P.zone + 1
        local mg = readMineGame()
        if not State.AutoZoneUnlock or nz > 12 or (mg and type(mg.UnlockedZones) == "table" and mg.UnlockedZones["Z" .. nz] == true) then
            return 0, "complete"
        end
        local zc = zoneUnlockCost(nz)
        if zc <= 0 then return 0, "complete" end
        money = money or getPlayerMoney()
        local target = { cost = zc, name = "ปลดโซน Z" .. nz }
        if zc > 10 * money then return 0, "toofar", target end
        return zc, "zone", target
    end
    local c = P.cheapest
    if not c then return 0, "none" end
    money = money or getPlayerMoney()
    if c.cost > 10 * money then return 0, "toofar", c end
    return c.cost, "hold", c
end

local function executeRemoteBalancedLeveling()
    if not State.Running or not State.BalancedLeveling then return end
    if not GameState or not GameState.GetData2 then mark("Level", "ไม่พบข้อมูลเกม (GameState)", "err") return end

    local myMoney = getPlayerMoney()
    if myMoney <= 0 then mark("Level", "อ่านเงินไม่ได้ / เงินเป็น 0", "wait") return end
    local reserve, rwhy = researchReserve(myMoney)   -- โหมดเน้นด่าน: ใช้ได้เฉพาะเงินที่เกินเงินกัน
    local rfor = (rwhy == "zone") and "ปลดโซน" or "วิจัย"
    if reserve > 0 then
        myMoney = myMoney - reserve
        if myMoney <= 0 then mark("Level", "กันเงินไว้ให้" .. rfor .. " " .. fmtCash(reserve) .. " (ใช้ได้เฉพาะส่วนเกิน)", "wait") return end
    end

    if minMinerUpgradeCost > 0 and myMoney < minMinerUpgradeCost then
        mark("Level", "รอเงิน (ต้องมี " .. fmtCash(minMinerUpgradeCost) .. ")", "wait")
        return
    end

    local plot = getMyPlot()
    if not plot or not plot:FindFirstChild("Holders") then mark("Level", "หาแปลง/ที่วางคนงานไม่เจอ", "wait") return end

    local budgetRatio = isNextZoneUnlocked() and (State.MinerBudgetUnlockedRatio or 0.40) or (State.MinerBudgetRatio or 0.10)
    local maxSpendPerUpgrade = myMoney * budgetRatio

    local miners = {}
    local minLevel = math.huge

    for i = 1, 15 do
        local slotKey = "M" .. tostring(i)
        local holder = plot.Holders:FindFirstChild(slotKey)
        if holder and holder:GetAttribute("CrewChar") then
            local lvlLabel = holder:FindFirstChild("Level", true)
            if lvlLabel and lvlLabel.Text ~= "" then
                local lvlNum = tonumber(string.match(lvlLabel.Text, "%d+"))
                if lvlNum then
                    table.insert(miners, {
                        Slot = slotKey,
                        Char = holder:GetAttribute("CrewChar"),
                        Level = lvlNum
                    })
                    if lvlNum < minLevel then
                        minLevel = lvlNum
                    end
                end
            end
        end
    end

    if #miners == 0 or minLevel == math.huge then mark("Level", "ยังไม่มีคนงานบนแปลง", "wait") return end

    local ups = 0
    for _, miner in ipairs(miners) do
        if not State.Running or not State.BalancedLeveling then break end

        if miner.Level <= minLevel then
            local item = Items and Items.GetItemData and Items.GetItemData(miner.Char)
            local dmgCost = (item and MineConfig and MineConfig.GetCharacterUpgradeCost) and MineConfig.GetCharacterUpgradeCost(miner.Level, item) or 0
            local speedCost = (item and MineConfig and MineConfig.GetCharacterMineSpeedUpgradeCost) and MineConfig.GetCharacterMineSpeedUpgradeCost(miner.Level, item) or 0

            local curMoney = getPlayerMoney() - reserve
            if dmgCost > 0 and curMoney >= dmgCost and dmgCost <= maxSpendPerUpgrade and (minMinerUpgradeCost == 0 or curMoney >= minMinerUpgradeCost) then
                pcall(function()
                    GameState.SendEvent("MineUpgradeCharacter", miner.Slot, "Damage")
                end)
                ups = ups + 1
                task.wait(0.08)
            end

            curMoney = getPlayerMoney() - reserve
            if speedCost > 0 and curMoney >= speedCost and speedCost <= maxSpendPerUpgrade and (minMinerUpgradeCost == 0 or curMoney >= minMinerUpgradeCost) then
                pcall(function()
                    GameState.SendEvent("MineUpgradeCharacter", miner.Slot, "MineSpeed")
                end)
                ups = ups + 1
                task.wait(0.08)
            end
        end
    end

    if ups > 0 then
        Act.n.upgrades = Act.n.upgrades + ups
        logEvent("อัปเลเวลคนงาน " .. ups .. " ครั้ง (ต่ำสุด Lv " .. minLevel .. ")")
        mark("Level", "อัปแล้ว " .. ups .. " ครั้ง · ต่ำสุด Lv " .. minLevel)
    else
        mark("Level", "รอเงิน (งบต่อครั้ง " .. fmtCash(maxSpendPerUpgrade) .. ") · ต่ำสุด Lv " .. minLevel
            .. (reserve > 0 and (" · กันไว้ให้" .. rfor .. " " .. fmtCash(reserve)) or ""), "wait")
    end
end

local function executeEquipBest()
    if not State.Running or not State.AutoEquipBest then return end

    if GameState and typeof(GameState.SendEvent) == "function" then
        pcall(function()
            GameState.SendEvent("MineEquipBest")
        end)
        Act.n.equipBest = Act.n.equipBest + 1
        mark("EquipBest", "สั่งใส่คนงานตัวดีสุดแล้ว")
    else
        mark("EquipBest", "ไม่พบข้อมูลเกม (GameState)", "err")
    end
end

-- ---------- ตัวซื้อผ่านหน้าสกิลของเกม (กดเหมือนผู้เล่น: แท็บ → ปุ่มสกิล → กดค้างปุ่มซื้อ → ปล่อย) ----------
--   ปุ่มสกิลชื่อ Node_<Id> อยู่ใน SkillTreeFullFrame.Tree.Canvas.Zone_Z<n> (Core อยู่ใน Tree.CoreCanvas)
--   ก่อนกดซื้อเช็กราคาบนปุ่มสกิล/ปุ่มซื้อว่าตรงกับแผน (ไม่ตรง = ไม่กด) ; ปล่อยทันทีที่ขั้นเพิ่ม หรือครบ 2.5 วิ
local UIBUY_HOLD_MAX = 2.5
local function fireSig(sig)
    local ok, conns = pcall(getconnections, sig)
    if not ok or type(conns) ~= "table" then return 0 end
    local n = 0
    for _, c in ipairs(conns) do
        if c.Function then pcall(c.Function) else pcall(function() c:Fire() end) end
        n = n + 1
    end
    return n
end
local function skillFrame()
    local g = lp.PlayerGui:FindFirstChild("MineGui")
    return g and g:FindFirstChild("SkillTreeFullFrame")
end
local function childText(inst, name)
    local l = inst and inst:FindFirstChild(name, true)
    return l and l.Text or nil
end
local function uiPips(btn)
    local a, b = tostring(childText(btn, "Pips") or ""):match("(%d+)%s*/%s*(%d+)")
    return tonumber(a), tonumber(b)
end
local function uiCost(btn)
    local c = tostring(childText(btn, "Cost") or ""):match("%$[%d%.%a,]+")
    return c and parseCash(c) or nil
end
local function allText(inst)
    local t = {}
    pcall(function()
        if inst:IsA("TextButton") and inst.Text ~= "" then t[#t + 1] = inst.Text end
        for _, d in ipairs(inst:GetDescendants()) do
            if d:IsA("TextLabel") and d.Text ~= "" then t[#t + 1] = d.Text end
        end
    end)
    return table.concat(t, " ")
end
local function near(a, b) return a ~= nil and b ~= nil and b > 0 and math.abs(a - b) / b <= 0.02 end

-- ฟังก์ชันซื้อของเกมเอง (MineSkillTreeClient: buySelected) — ปุ่มซื้อ (กดลง) = holdStart ซึ่งเก็บ buySelected ไว้ข้างใน
--   buySelected ซื้อ "ปุ่มที่เลือกอยู่" และส่งคำสั่ง (MineBuySkill / Core Event) ด้วยค่าที่ถูกต้องเอง → ไม่ต้องเดาค่าที่ส่ง ไม่ต้องกดค้าง
--   หาโดยชื่อฟังก์ชัน (debug.info) หรือดูว่าในโค้ดมีข้อความ "MineBuySkill" (debug.getconstants) — อ่านอย่างเดียว
local function findBuySelected(buyBtn)
    local ok, conns = pcall(getconnections, buyBtn.MouseButton1Down)
    if not ok or type(conns) ~= "table" then return nil end
    local fallback
    for _, c in ipairs(conns) do
        local f = c.Function
        if type(f) == "function" then
            local okU, ups = pcall(debug.getupvalues, f)
            if okU and type(ups) == "table" then
                for _, v in pairs(ups) do
                    if type(v) == "function" then
                        local okN, n = pcall(debug.info, v, "n")
                        if okN and n == "buySelected" then return v end
                        if not fallback and type(debug.getconstants) == "function" then
                            local okC, consts = pcall(debug.getconstants, v)
                            if okC and type(consts) == "table" then
                                for _, k in pairs(consts) do
                                    if k == "MineBuySkill" then fallback = v break end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return fallback
end
-- ปุ่มที่ buySelected จะซื้อ = ค่าที่มันเก็บไว้ (upvalue) ; true = เลือกติด , false = ไม่ตรง , nil = อ่านไม่ได้
local function buySelectedHas(fn, id)
    local ok, ups = pcall(debug.getupvalues, fn)
    if not ok or type(ups) ~= "table" then return nil end
    for _, v in pairs(ups) do
        if v == id then return true end
    end
    return false
end

-- opts = { tab, core, canvasName, nodeId, cost, check } ; คืน false,เหตุผล = ไม่ได้กด (หน้ายังไม่พร้อม/ราคาไม่ตรง) ; true,ผล = กดแล้ว
local function uiHoldBuy(opts)
    local st = skillFrame()
    if not st then return false, "ยังไม่พบหน้าสกิลของเกม — เปิดหน้าสกิลในเกม 1 ครั้ง" end
    local tree = st:FindFirstChild("Tree")
    local list = st:FindFirstChild("Sidebar") and st.Sidebar:FindFirstChild("List")
    local function canvasOf()
        if opts.core then return tree and tree:FindFirstChild("CoreCanvas") end
        local cv = tree and tree:FindFirstChild("Canvas")
        return cv and cv:FindFirstChild(opts.canvasName)
    end
    local tab = list and list:FindFirstChild(opts.tab)
    if tab then fireSig(tab.MouseButton1Click) task.wait(0.2) end
    local canvas = canvasOf()
    if not canvas then return false, "หน้าสกิลยังไม่สร้าง " .. tostring(opts.core and "Core" or opts.canvasName) .. " — เปิดหน้าสกิลในเกม 1 ครั้ง" end
    local btn = canvas:FindFirstChild("Node_" .. tostring(opts.nodeId))
    if not btn then return false, "ไม่พบปุ่ม Node_" .. tostring(opts.nodeId) .. " ในหน้าสกิล" end
    local shown = uiCost(btn)
    if opts.cost and shown and not near(shown, opts.cost) then
        return false, "ราคาบนปุ่มสกิล " .. fmtCash(shown) .. " ไม่ตรงกับแผน " .. fmtCash(opts.cost) .. " (ไม่กด)"
    end
    fireSig(btn.MouseButton1Click)
    task.wait(0.15)
    local buy = st:FindFirstChild("BuyButton", true)
    if not buy then return false, "ไม่พบปุ่มซื้อในหน้าสกิล" end
    local direct = findBuySelected(buy)
    if direct and buySelectedHas(direct, opts.nodeId) == false then
        return false, "เลือกปุ่ม " .. tostring(opts.nodeId) .. " ไม่ติด (ไม่ซื้อ)"
    end
    local label = allText(buy)
    local lc = label:match("%$[%d%.%a,]+")
    if not lc and label:lower():find("max") then return false, "ปุ่มซื้อขึ้น Max (ปุ่มนี้เต็มแล้ว)" end
    if lc and opts.cost and not near(parseCash(lc), opts.cost) then
        return false, "ราคาบนปุ่มซื้อ " .. lc .. " ไม่ตรงกับแผน (เลือกผิดปุ่ม? ไม่กด)"
    end
    -- ทางหลัก: เรียก buySelected ของเกม 1 ครั้ง (ซื้อ 1 ขั้นของปุ่มที่เลือก)
    if direct then
        local okB, errB = pcall(direct)
        if not okB then return false, "เรียกฟังก์ชันซื้อของเกมไม่ได้: " .. shortErr(errB) end
        local got = false
        local t0 = clock()
        while clock() - t0 < 1.5 do
            task.wait(0.1)
            local okC, r = pcall(opts.check)
            if okC and r then got = true break end
        end
        return true, got and "ซื้อแล้ว" or "สั่งซื้อแล้ว รอผล"
    end
    -- สำรอง (หา buySelected ไม่เจอ): กดค้างปุ่มซื้อจนขั้นเพิ่ม แล้วปล่อย
    local bought = false
    fireSig(buy.MouseButton1Down)
    local ok = pcall(function()
        local t0 = clock()
        while clock() - t0 < UIBUY_HOLD_MAX do
            task.wait(0.05)
            local okC, r = pcall(opts.check)
            if okC and r then bought = true break end
        end
    end)
    fireSig(buy.MouseButton1Up)   -- ปล่อยปุ่มเสมอ
    return true, bought and "ซื้อแล้ว" or "กดค้างแล้วยังไม่เห็นผล"
end

local function uiBuyResearch(zk, fam, nodeId, k, cost)
    local zn = tostring(zk):match("%d+")
    return uiHoldBuy({
        tab = "Tab" .. tostring(zn), canvasName = "Zone_" .. tostring(zk), nodeId = nodeId, cost = cost,
        check = function()
            local mg = readMineGame()
            return mg and type(mg.Skills) == "table" and type(mg.Skills[zk]) == "table" and (tonumber(mg.Skills[zk][fam]) or 0) >= k
        end,
    })
end
Research.buyer = uiBuyResearch

-- ---------- Core (หลังวิจัยโซนครบ ; สวิตช์ "อัป Core" ปิดเป็นค่าเริ่มต้น) ----------
--   ขั้นของแต่ละปุ่ม/ราคา อ่านจากปุ่มใน Tree.CoreCanvas (Pips x/y, Cost) ; ปุ่มแม่จาก MineConfig.CoreNodes[].Parents
local CoreState = { fails = {}, pause = {} }
local function buildCorePlan()
    local st = skillFrame()
    if not st or not MineConfig or type(MineConfig.CoreNodes) ~= "table" then return nil end
    local canvas = st:FindFirstChild("Tree") and st.Tree:FindFirstChild("CoreCanvas")
    if not canvas then return nil end
    local info = {}
    for _, nd in pairs(MineConfig.CoreNodes) do
        if type(nd) == "table" and nd.Id ~= nil then
            local btn = canvas:FindFirstChild("Node_" .. tostring(nd.Id))
            if btn then
                local a, b = uiPips(btn)
                info[nd.Id] = { nd = nd, a = a, b = b or tonumber(nd.Pips), cost = uiCost(btn) }
            end
        end
    end
    local list, now = {}, clock()
    for id, x in pairs(info) do
        if x.a and x.b and x.a < x.b then
            local blocker
            if type(x.nd.Parents) == "table" then
                for _, pid in pairs(x.nd.Parents) do
                    local par = info[pid]
                    if not par or not par.a or par.a < par.b then blocker = par and tostring(par.nd.Name or pid) or tostring(pid) break end
                end
            end
            list[#list + 1] = { id = id, name = tostring(x.nd.Name or id), a = x.a, b = x.b, cost = x.cost, blocker = blocker,
                                paused = (CoreState.pause[id] and CoreState.pause[id] > now) and CoreState.pause[id] or nil }
        end
    end
    table.sort(list, function(p, q)
        local po, qo = (not p.blocker and p.cost) and 1 or 0, (not q.blocker and q.cost) and 1 or 0
        if po ~= qo then return po > qo end
        if p.cost and q.cost and p.cost ~= q.cost then return p.cost < q.cost end
        return tostring(p.id) < tostring(q.id)
    end)
    return list
end

local function runCore()
    local list = buildCorePlan()
    if not list then
        local st = skillFrame()
        local tab = st and st:FindFirstChild("Sidebar") and st.Sidebar:FindFirstChild("List") and st.Sidebar.List:FindFirstChild("CoreTab")
        if tab then fireSig(tab.MouseButton1Click) task.wait(0.2) end
        list = buildCorePlan()
    end
    if not list then mark("Skill", "วิจัยครบ · อ่านหน้า Core ไม่ได้ — เปิดหน้าสกิล > Core ในเกม 1 ครั้ง", "wait") return end
    local pick
    for _, c in ipairs(list) do
        if not c.blocker and c.cost and not c.paused then pick = c break end
    end
    if not pick then mark("Skill", (#list == 0) and "วิจัยครบ · Core ครบแล้ว" or "วิจัยครบ · ยังไม่มี Core ที่ซื้อได้", "wait") return end
    local money = getPlayerMoney()
    local zr = researchReserve(money)   -- เงินที่กันไว้ปลดโซน (ถ้ามี) ไม่เอามาซื้อ Core
    money = money - zr
    if money < pick.cost then
        mark("Skill", "วิจัยครบ · เก็บเงินซื้อ Core " .. pick.name .. " · ขาดอีก " .. fmtCash(pick.cost - money) .. (zr > 0 and (" (กันไว้ปลดโซน " .. fmtCash(zr) .. ")") or ""), "wait")
        return
    end
    local before = pick.a
    local okB, res, msg = pcall(uiHoldBuy, { tab = "CoreTab", core = true, nodeId = pick.id, cost = pick.cost,
        check = function()
            local st = skillFrame()
            local btn = st and st.Tree.CoreCanvas:FindFirstChild("Node_" .. tostring(pick.id))
            local a = btn and uiPips(btn)
            return a and a > before
        end })
    if not okB then mark("Skill", "ซื้อ Core ไม่ได้: " .. shortErr(res), "err") return end
    if res == false then mark("Skill", "Core: " .. tostring(msg), "wait") return end
    if msg == "ซื้อแล้ว" then
        CoreState.fails[pick.id] = 0
        Act.n.skills = Act.n.skills + 1
        logEvent("อัป Core " .. pick.name .. " ขั้น " .. (before + 1) .. " (" .. fmtCash(pick.cost) .. ")")
        mark("Skill", "อัป Core " .. pick.name .. " ขั้น " .. (before + 1) .. " แล้ว")
    else
        local f = (CoreState.fails[pick.id] or 0) + 1
        CoreState.fails[pick.id] = f
        if f >= 3 then
            CoreState.fails[pick.id] = 0
            CoreState.pause[pick.id] = clock() + 300
            logEvent("ซื้อ Core " .. pick.name .. " ไม่สำเร็จ 3 ครั้งติด — พัก 5 นาที")
        end
        mark("Skill", "กดซื้อ Core " .. pick.name .. " แล้วยังไม่เห็นผล (" .. f .. "/3)", "wait")
    end
end

-- ระบบอัปวิจัย: ซื้อขั้นที่ถูกที่สุดที่เปิดอยู่และเงินพอ (ผ่านหน้าสกิลของเกม) ; ตรวจผลรอบถัดไป ; ไม่เพิ่ม 3 ครั้งติด = พักสายนั้น 5 นาที
local function executeResearch()
    if not State.Running or not State.AutoSkillTree then return end

    local pend = Research.pending
    if pend then   -- ตรวจผลการสั่งซื้อรอบก่อน
        Research.pending = nil
        local mg = readMineGame()
        local nowLvl = (mg and type(mg.Skills) == "table" and type(mg.Skills[pend.zk]) == "table") and (tonumber(mg.Skills[pend.zk][pend.fam]) or 0) or 0
        if nowLvl >= pend.k then
            Research.fails[pend.fam] = 0
            Act.n.skills = Act.n.skills + 1
            logEvent("อัปวิจัย " .. pend.name .. " ขั้น " .. pend.k .. " (" .. fmtCash(pend.cost) .. ")")
        else
            local f = (Research.fails[pend.fam] or 0) + 1
            Research.fails[pend.fam] = f
            if f >= 3 then
                Research.fails[pend.fam] = 0
                Research.pause[pend.fam] = clock() + 300
                logEvent("ซื้อวิจัย " .. pend.name .. " ไม่สำเร็จ 3 ครั้งติด — พักสาย " .. tostring(pend.fam) .. " 5 นาที")
            end
        end
    end

    local P = researchPlan(true)
    if not P then mark("Skill", "อ่านข้อมูลวิจัยของโซนนี้ไม่ได้", "wait") return end
    if P.complete then
        if State.AutoCore then runCore() return end
        mark("Skill", "วิจัย " .. P.zk .. " ครบแล้ว — รอปลดโซน")
        return
    end
    local c = P.cheapest
    if not c then
        local paused = false
        for _, pip in ipairs(P.pips) do if pip.paused then paused = true break end end
        mark("Skill", paused and "ขั้นที่ซื้อได้ถูกพักอยู่ (ซื้อไม่สำเร็จ 3 ครั้ง)" or "ไม่มีขั้นที่ซื้อได้ตอนนี้", "wait")
        return
    end
    local money = getPlayerMoney()
    if money < c.cost then
        mark("Skill", "เก็บเงินซื้อ " .. c.name .. " ขั้น " .. c.k .. " · ขาดอีก " .. fmtCash(c.cost - money), "wait")
        return
    end
    if not Research.buyer then
        mark("Skill", "พร้อมซื้อ " .. c.name .. " ขั้น " .. c.k .. " (" .. fmtCash(c.cost) .. ") · ไม่มีตัวซื้อ", "wait")
        return
    end
    local ok, res, msg = pcall(Research.buyer, P.zk, c.fam, c.node.Id, c.k, c.cost)
    if not ok then mark("Skill", "ส่งคำสั่งซื้อไม่ได้: " .. shortErr(res), "err") return end
    if res == false then   -- ไม่ได้กด (หน้าสกิลยังไม่พร้อม/ราคาไม่ตรง) = ไม่นับเป็นซื้อไม่สำเร็จ
        mark("Skill", tostring(msg or "ยังกดซื้อไม่ได้"), "wait")
        return
    end
    Research.pending = { zk = P.zk, fam = c.fam, k = c.k, name = c.name, cost = c.cost }
    Research.planAt = -1e9
    mark("Skill", "กดซื้อ " .. c.name .. " ขั้น " .. c.k .. " (" .. fmtCash(c.cost) .. ")" .. (msg and (" · " .. tostring(msg)) or ""))
end

local lastZoneTry, lastZoneTryAt = nil, -1e9
local function executeAutoZoneUnlock()
    if not State.Running or not State.AutoZoneUnlock then return end
    if not GameState or not GameState.GetData2 then mark("Zone", "ไม่พบข้อมูลเกม (GameState)", "err") return end

    local ok, plrData = pcall(function()
        return debug.getupvalues(GameState.GetData2)[3][tostring(lp.UserId)].plrData.MineGame
    end)
    if not ok or not plrData then mark("Zone", "อ่านข้อมูลโซนไม่ได้", "wait") return end

    local currentZone = plrData.CurrentZone or 1
    local nextZone = currentZone + 1
    if nextZone > 12 then mark("Zone", "อยู่โซนสุดท้ายแล้ว (Z" .. tostring(currentZone) .. ")") return end

    local curZoneKey = "Z" .. tostring(currentZone)
    local nextZoneKey = "Z" .. tostring(nextZone)

    local isComplete = false
    pcall(function()
        if MineConfig and typeof(MineConfig.IsZoneResearchComplete) == "function" then
            isComplete = MineConfig.IsZoneResearchComplete(plrData.Skills, curZoneKey)
        end
    end)

    if isComplete then
        local plot = getMyPlot()
        local zoneBoard = plot and plot:FindFirstChild("ZoneBoard")
        local boardGui = zoneBoard and zoneBoard:FindFirstChild("ZoneBoardGui")
        local nextRow = boardGui and boardGui:FindFirstChild("Root") and boardGui.Root:FindFirstChild("List") and boardGui.Root.List:FindFirstChild("ZoneRow" .. tostring(nextZone))

        local unlockCost = 0
        if nextRow then
            local label = nextRow:FindFirstChild("Label", true)
            if label and label.Text ~= "" then
                unlockCost = parseCash(label.Text:match("%$[%d%.%a,]+"))
            end
        end

        local myMoney = getPlayerMoney()
        if unlockCost == 0 or myMoney >= unlockCost then
            pcall(function()
                GameState.SendEvent("MineSelectZone", nextZoneKey)
            end)

            local btn = nextRow and nextRow:FindFirstChild("Button")
            if btn then
                pcall(function()
                    if firesignal then
                        firesignal(btn.MouseButton1Click)
                    else
                        for _, c in ipairs(getconnections(btn.MouseButton1Click)) do
                            if c.Function then c.Function() end
                        end
                    end
                end)
            end
            if lastZoneTry ~= nextZoneKey or clock() - lastZoneTryAt > 60 then   -- กันบันทึกซ้ำทุก 3 วิ
                lastZoneTry, lastZoneTryAt = nextZoneKey, clock()
                logEvent("สั่งปลดล็อก/ไปโซน " .. nextZoneKey .. (unlockCost > 0 and (" (" .. fmtCash(unlockCost) .. ")") or ""))
            end
            mark("Zone", "สั่งไปโซน " .. nextZoneKey .. " แล้ว")
        else
            mark("Zone", "วิจัยครบ รอเงินปลด " .. nextZoneKey .. " (ต้องมี " .. fmtCash(unlockCost) .. ")", "wait")
        end
    else
        mark("Zone", "รอวิจัยโซน " .. curZoneKey .. " ให้ครบ", "wait")
    end
end

local function executeAutoBuyPickaxes()
    if not State.Running or not State.AutoBuyPickaxe then return end
    if not GameState or not GameState.GetData2 or not MineConfig or not MineConfig.Pickaxes then mark("BuyPick", "ไม่พบข้อมูล Pickaxe ของเกม", "err") return end

    local Data2 = GameState.GetData2()
    local plrData = Data2 and Data2.MineGame
    if not plrData then mark("BuyPick", "อ่านข้อมูลผู้เล่นไม่ได้", "wait") return end

    local myMoney = getPlayerMoney()
    local unlocked = plrData.UnlockedZones or {}
    local owned = plrData.Pickaxes or {}
    local reserve, rwhy = researchReserve(myMoney)   -- โหมดเน้นด่าน: ใช้ได้เฉพาะเงินที่เกินเงินกัน
    myMoney = myMoney - reserve

    local pend = PickGuard.pending   -- สั่งซื้อรอบก่อนแล้วจำนวนไม่เพิ่ม = พักชนิดนั้น 10 นาที
    if pend then
        PickGuard.pending = nil
        if (owned[pend.name] or 0) <= pend.before then
            PickGuard.cool[pend.name] = clock() + 600
            logEvent("ซื้อ " .. tostring(pend.name) .. " ไม่สำเร็จ (จำนวนไม่เพิ่ม) — พัก 10 นาที")
        end
    end

    local bought = false
    for i = #MineConfig.Pickaxes, 1, -1 do
        local def = MineConfig.Pickaxes[i]
        if def and not (def.RobuxOnly or (MineConfig.IsPickaxeFree and MineConfig.IsPickaxeFree(def))) then
            local zoneReq = def.ZoneReq
            if not zoneReq or unlocked[zoneReq] == true then
                local cost = def.Cost or 0
                local stock = MineStock and MineStock.GetRemaining(Data2, def.Name) or 1

                local cooling = PickGuard.cool[def.Name] and PickGuard.cool[def.Name] > clock()
                if stock > 0 and cost > 0 and myMoney >= cost and not cooling then
                    local ownedCount = owned[def.Name] or 0
                    if ownedCount < 8 then
                        PickGuard.pending = { name = def.Name, before = ownedCount }
                        pcall(function()
                            GameState.SendEvent("MineBuyPickaxe", i)
                        end)
                        bought = true
                        Act.n.picksBought = Act.n.picksBought + 1
                        logEvent("สั่งซื้อ " .. tostring(def.Name) .. " (" .. fmtCash(cost) .. ")")
                        mark("BuyPick", "สั่งซื้อ " .. tostring(def.Name) .. " (มีอยู่ " .. tostring(ownedCount) .. ")")
                        task.wait(0.2)
                        break
                    end
                end
            end
        end
    end
    if not bought then
        mark("BuyPick", "ยังไม่มีอันที่ซื้อได้ (เงิน/สต็อก/มีครบ 8/พักอยู่)" .. (reserve > 0 and (" · กันไว้ให้" .. ((rwhy == "zone") and "ปลดโซน" or "วิจัย") .. " " .. fmtCash(reserve)) or ""), "wait")
    end
end

local function executeAutoEquipBestPickaxes()
    if not State.Running or not State.AutoEquipPickaxe then return end
    if not GameState or not GameState.GetData2 or not MineConfig then mark("EquipPick", "ไม่พบข้อมูลเกม", "err") return end

    local Data2 = GameState.GetData2()
    local plrData = Data2 and Data2.MineGame
    if not plrData or not plrData.Holders or not plrData.Pickaxes then mark("EquipPick", "อ่านข้อมูลคนงาน/Pickaxe ไม่ได้", "wait") return end

    local pickMultipliers = {}
    for _, p in ipairs(MineConfig.Pickaxes or {}) do
        local mult = p.Stats and p.Stats.DamageMultiplier or p.DamageMultiplier or p.Multiplier or 1
        pickMultipliers[p.Name] = mult
    end

    local ownedPool = {}
    for name, count in pairs(plrData.Pickaxes) do
        local mult = pickMultipliers[name] or 1
        for _ = 1, count do
            table.insert(ownedPool, {Name = name, Mult = mult})
        end
    end
    table.sort(ownedPool, function(a, b) return a.Mult > b.Mult end)

    local holders = {}
    for slot, h in pairs(plrData.Holders) do
        table.insert(holders, {
            Slot = slot,
            Char = h.CharName,
            Level = h.CharLevel or 1,
            CurrentPick = h.Pickaxe
        })
    end
    table.sort(holders, function(a, b)
        if a.Level ~= b.Level then return a.Level > b.Level end
        return a.Slot < b.Slot
    end)

    local needsChange = false
    for i, h in ipairs(holders) do
        local targetPick = ownedPool[i] and ownedPool[i].Name or "Iron Pickaxe"
        if h.CurrentPick ~= targetPick then
            needsChange = true
            break
        end
    end

    if not needsChange then mark("EquipPick", "ใส่ Pickaxe ดีสุดครบแล้ว") return end

    for i, h in ipairs(holders) do
        local targetPick = ownedPool[i] and ownedPool[i].Name or "Iron Pickaxe"
        if h.CurrentPick ~= targetPick then
            pcall(function()
                GameState.SendEvent("MineEquipPickaxe", h.Slot, "")
            end)
        end
    end
    task.wait(0.15)

    local swaps = 0
    for i, h in ipairs(holders) do
        local targetPick = ownedPool[i] and ownedPool[i].Name or "Iron Pickaxe"
        if h.CurrentPick ~= targetPick then
            pcall(function()
                GameState.SendEvent("MineEquipPickaxe", h.Slot, targetPick)
            end)
            swaps = swaps + 1
            task.wait(0.08)
        end
    end
    Act.n.pickSwaps = Act.n.pickSwaps + swaps
    logEvent("เปลี่ยน Pickaxe " .. swaps .. " ช่อง")
    mark("EquipPick", "เปลี่ยน Pickaxe " .. swaps .. " ช่องแล้ว")
end

local mineThread = task.spawn(function()
    while State.Running do
        if State.HyperMine then
            runTracked("HyperMine", executeHyperMine)
        end
        task.wait(State.MineDelay)
    end
end)
table.insert(State.Threads, mineThread)

-- ---------- รอบการทำงาน (ทุก CycleInterval วินาที) ----------
--   1) เก็บหีบ → รอ SellDelay วิ → 2) ใส่คนงานตัวดีสุด → 3) ขาย → 4) อัปเกรด: วิจัย (หลายขั้น) → ปลดโซน → อัปเลเวลคนงาน → ซื้อ/ใส่ Pickaxe
--   ขุดแร่ทำตลอดเวลาในเธรดของมันเอง (หยุดเฉพาะตอนวาร์ปไปขาย)
local Cycle = { n = 0, phase = "รอเริ่ม", startedAt = nil, nextAt = nil }

local function cycleWait(sec)
    local t0 = clock()
    while State.Running and clock() - t0 < sec do task.wait(0.25) end
end

local function runCycle()
    Cycle.n = Cycle.n + 1
    Cycle.startedAt = clock()
    Cycle.nextAt = Cycle.startedAt + math.max(5, tonumber(State.CycleInterval) or 45)

    if State.AutoChest then
        Cycle.phase = "เก็บหีบ"
        runTracked("Chest", executeChestLoot)
        Cycle.phase = "รอขาย " .. tostring(State.SellDelay) .. " วิ"
        cycleWait(math.max(0, tonumber(State.SellDelay) or 5))
    end
    if not State.Running then return end

    if State.AutoEquipBest then
        Cycle.phase = "ใส่คนงานตัวดีสุด"
        runTracked("EquipBest", executeEquipBest)
    end

    if State.AutoSell and State.Running then
        Cycle.phase = "ขาย"
        runTracked("Sell", executeMassSell)
    end

    if State.AutoSkillTree and State.Running then
        Cycle.phase = "อัปวิจัย"
        for _ = 1, math.max(1, tonumber(State.ResearchPerCycle) or 10) do
            if not State.Running or not State.AutoSkillTree then break end
            local before = Act.n.skills
            runTracked("Skill", executeResearch)
            if not Research.pending and Act.n.skills == before then break end   -- ไม่ได้สั่งซื้อ/ไม่ได้อะไรเพิ่ม = พอแล้วรอบนี้
        end
    end

    if State.AutoZoneUnlock and State.Running then
        Cycle.phase = "ปลดโซน"
        runTracked("Zone", executeAutoZoneUnlock)
    end

    if State.BalancedLeveling and State.Running then
        Cycle.phase = "อัปเลเวลคนงาน"
        for _ = 1, math.max(1, tonumber(State.LevelRunsPerCycle) or 10) do
            if not State.Running or not State.BalancedLeveling then break end
            local before = Act.n.upgrades
            runTracked("Level", executeRemoteBalancedLeveling)
            if Act.n.upgrades == before then break end
            task.wait(1)   -- ให้เลเวลบนป้ายอัปเดตก่อนรอบย่อยถัดไป
        end
    end

    if State.AutoBuyPickaxe and State.Running then
        Cycle.phase = "ซื้อ Pickaxe"
        for _ = 1, math.max(1, tonumber(State.PickBuysPerCycle) or 4) do
            if not State.Running or not State.AutoBuyPickaxe then break end
            local before = Act.n.picksBought
            runTracked("BuyPick", executeAutoBuyPickaxes)
            if Act.n.picksBought == before then break end
            task.wait(1.5)   -- ให้จำนวนในข้อมูลอัปเดตก่อนตรวจผล/ซื้อชิ้นถัดไป
        end
    end

    if State.AutoEquipPickaxe and State.Running then
        Cycle.phase = "ใส่ Pickaxe"
        runTracked("EquipPick", executeAutoEquipBestPickaxes)
    end
    Cycle.phase = "รอรอบถัดไป"
end

local cycleThread = task.spawn(function()
    task.wait(1)
    while State.Running do
        local okC, errC = pcall(runCycle)
        if not okC then
            Act.n.errors = Act.n.errors + 1
            logEvent("รอบทำงานผิดพลาด: " .. shortErr(errC))
        end
        while State.Running and Cycle.nextAt and clock() < Cycle.nextAt do task.wait(0.25) end
    end
end)
table.insert(State.Threads, cycleThread)

local function stopFarm()
    State.Running = false
    for _, t in ipairs(State.Threads) do
        pcall(task.cancel, t)
    end
    for _, c in ipairs(State.Connections) do
        pcall(function() c:Disconnect() end)
    end
end

-- ==============================================================================
-- แดชบอร์ด (อ่านอย่างเดียว: ข้อมูลผู้เล่น + หน้าขาย ; ไม่ยิงคำสั่งเข้าเกม)
-- ==============================================================================
local Dash = { alive = true, mode = "full", tab = "overview" }

local MODS = {   -- ลำดับในแดชบอร์ด: ระบบ / สวิตช์ใน State / ชื่อ / คำอธิบาย / ตัวนับ
    { key = "HyperMine", flag = "HyperMine", name = "ขุดแร่", desc = "วาร์ปไปกลางแปลงแล้วคลิกแร่ทุกก้อน", cnt = function() return "ขุด " .. fmtNum(Act.n.clicks) end },
    { key = "Chest", flag = "AutoChest", name = "เก็บหีบ", desc = "ต้นรอบ: เปิดหีบแล้วกดเก็บทั้งหมด", cnt = function() return "เก็บ " .. Act.n.chestTakes end },
    { key = "Sell", flag = "AutoSell", name = "ขายของ", desc = "หลังเก็บหีบ + ใส่คนงาน: ไปจุดขายแล้วขาย", cnt = function() return "ขาย " .. Act.n.sells end },
    { key = "Level", flag = "BalancedLeveling", name = "อัปเลเวลคนงาน", desc = "อัปตัวเลเวลต่ำสุดก่อน งบ 10% ของเงิน (40% เมื่อโซนถัดไปปลดแล้ว)", cnt = function() return "อัป " .. Act.n.upgrades end },
    { key = "EquipBest", flag = "AutoEquipBest", name = "ใส่คนงานตัวดีสุด", desc = "ก่อนขายทุกรอบ: สั่งใส่ตัวดีสุด", cnt = function() return "สั่ง " .. Act.n.equipBest end },
    { key = "BuyPick", flag = "AutoBuyPickaxe", name = "ซื้อ Pickaxe", desc = "ซื้ออันดีสุดที่ซื้อได้ (ไม่เกิน 8 อันต่อชนิด)", cnt = function() return "ซื้อ " .. Act.n.picksBought end },
    { key = "EquipPick", flag = "AutoEquipPickaxe", name = "ใส่ Pickaxe ดีสุด", desc = "ให้คนงานเลเวลสูงได้อันที่ดีที่สุด", cnt = function() return "เปลี่ยน " .. Act.n.pickSwaps end },
    { key = "Skill", flag = "AutoSkillTree", name = "อัปสกิล/วิจัย", desc = "ซื้อขั้นวิจัยถูกสุดที่เปิดอยู่ กดผ่านหน้าสกิลของเกม", cnt = function() return "อัป " .. Act.n.skills end },
    { key = "Zone", flag = "AutoZoneUnlock", name = "ปลดล็อกโซน", desc = "วิจัยครบ + เงินพอ → ไปโซนถัดไป", cnt = function() return "ย้าย " .. Act.n.zones end },
}
local EXTRA_SWITCHES = {
    { flag = "FocusZone", name = "โหมดเน้นด่าน", desc = "กันเงินไว้ซื้อวิจัยขั้นถัดไป อัปคนงาน/ซื้อ Pickaxe ใช้ส่วนเกิน" },
    { flag = "AutoCore", name = "อัป Core หลังวิจัยครบ", desc = "วิจัยโซนครบแล้ว ซื้อ Core ขั้นถูกสุดที่เปิดอยู่ (ผ่านหน้าสกิล)" },
    { flag = "AutoSellMiners", name = "ขายคนงานที่ไม่ใช้", desc = "ตอนขายของ ขายคนงานในกระเป๋าด้วย" },
    { flag = "ProtectHighDamageMiners", name = "กันขายคนงานดี", desc = "ไม่ขาย Epic ขึ้นไป / โซน 4+ / Tier 30+ / ตัวที่ไม่ด้อยกว่าตัวที่ใส่" },
}

local RARITY_COLOR = {
    Common = { 148, 163, 184 }, Uncommon = { 74, 222, 128 }, Rare = { 96, 165, 250 }, Epic = { 192, 132, 252 },
    Legendary = { 251, 191, 36 }, Mythical = { 251, 113, 133 }, Exotic = { 45, 212, 191 }, Limited = { 251, 146, 60 },
    Exclusive = { 244, 114, 182 },
}
local RARITY_RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythical = 6, Exotic = 7, Limited = 8, Exclusive = 9 }

-- ---------- อ่านข้อมูลผู้เล่น ----------
local function getPlrData()
    local ok, d = pcall(function() return debug.getupvalues(GameState.GetData2)[3][tostring(lp.UserId)].plrData end)
    if ok and type(d) == "table" then return d end
    ok, d = pcall(function() return GameState.GetData2() end)
    if ok and type(d) == "table" then return d end
    return nil
end

local function readMoney()
    local ok, m = pcall(function() return debug.getupvalues(GameState.GetData2)[3][tostring(lp.UserId)].plrData.Money end)
    if ok and type(m) == "number" then return m end
    local d = getPlrData()
    if d and type(d.Money) == "number" then return d.Money end
    return nil
end

local function slotNum(s)
    return tonumber(tostring(s):match("%d+")) or 999
end

local function minersOnPlot()
    local list = {}
    local d = getPlrData()
    local mg = d and d.MineGame
    if mg and type(mg.Holders) == "table" then
        for slot, h in pairs(mg.Holders) do
            if type(h) == "table" and h.CharName then
                list[#list + 1] = { slot = tostring(slot), name = tostring(h.CharName), level = tonumber(h.CharLevel) or 1, pick = h.Pickaxe }
            end
        end
    end
    if #list == 0 then   -- สำรอง: อ่านจากป้ายบนแปลง
        local plot = getMyPlot()
        local holders = plot and plot:FindFirstChild("Holders")
        if holders then
            for i = 1, 15 do
                local holder = holders:FindFirstChild("M" .. tostring(i))
                local charName = holder and holder:GetAttribute("CrewChar")
                if charName then
                    local lv
                    local lbl = holder:FindFirstChild("Level", true)
                    if lbl and lbl.Text then lv = tonumber(string.match(lbl.Text, "%d+")) end
                    list[#list + 1] = { slot = "M" .. tostring(i), name = tostring(charName), level = lv or 1 }
                end
            end
        end
    end
    table.sort(list, function(a, b) return slotNum(a.slot) < slotNum(b.slot) end)
    return list
end

local function pickMultMap()
    local map = {}
    pcall(function()
        for _, p in ipairs(MineConfig.Pickaxes or {}) do
            map[p.Name] = p.Stats and p.Stats.DamageMultiplier or p.DamageMultiplier or p.Multiplier or 1
        end
    end)
    return map
end

-- ของในกระเป๋า: อ่านรายการจากหน้าขายของเกม (ตารางเดียวกับที่ระบบขายใช้เลือกของ) ; อ่านอย่างเดียว ไม่กดขาย
local BAG = { at = nil, groups = nil, total = 0 }
local function qtyOf(item, entry)
    for _, t in ipairs({ item, entry }) do   -- เกมนี้เก็บจำนวนไว้ที่ item.count (ดูจากข้อมูลตรวจสอบจริง)
        for _, k in ipairs({ "count", "Count", "Amount", "amount", "Qty", "Quantity", "Stack" }) do
            local v = t[k]
            if type(v) == "number" and v >= 1 then return v, true end
        end
    end
    return 1, false
end

local function readBag()
    local u2
    pcall(function()
        local sellFrame = lp.PlayerGui:FindFirstChild("MineGui") and lp.PlayerGui.MineGui:FindFirstChild("SellFrame")
        local sellBtn = sellFrame and sellFrame:FindFirstChild("Content") and sellFrame.Content:FindFirstChild("SellButton")
        if not sellBtn then return end
        local conns = getconnections(sellBtn.MouseButton1Click)
        local f = conns and conns[1] and conns[1].Function
        if not f then return end
        local t = debug.getupvalues(f)[2]
        if type(t) == "table" then u2 = t end
    end)
    if not u2 then return end

    local minDmg, minTier = getEquippedBenchmark()
    local groups = { ore = {}, miner = {}, other = {} }
    local index = { ore = {}, miner = {}, other = {} }
    local total = 0
    for _, item in pairs(u2) do
        if type(item) == "table" and type(item.entry) == "table" then
            local e = item.entry
            local role, kind = e.Role, e.Kind
            local name = tostring(e.Name or e.Display or e.Key or "?")
            local q, exact = qtyOf(item, e)
            local g
            if role == "Ore" or kind == "Ore" then g = "ore"
            elseif role == "Miner" or kind == "Character" then g = "miner"
            else g = "other" end
            local tag = name
            local rec = { name = name, qty = 0, exact = exact, role = tostring(role or kind or "") }
            if g == "miner" then
                local keep, why, rarity, tier = judgeMiner(e, minDmg, minTier)
                rec.rarity, rec.tier = rarity, tier
                if not State.AutoSellMiners then rec.fate, rec.why = "keep", "ปิดขายคนงานอยู่"
                elseif keep then rec.fate, rec.why = "keep", why
                else rec.fate = "sell" end
                tag = name .. "|" .. rec.fate .. "|" .. tostring(rec.why)
            elseif g == "other" then
                local isPick = role == "Pickaxe" or kind == "Pickaxe"
                local isPot = role == "Potion" or kind == "Potion"
                rec.role = isPick and "Pickaxe" or (isPot and "ยา" or rec.role)
            end
            local ex = index[g][tag]
            if ex then
                ex.qty = ex.qty + q
                ex.exact = ex.exact and exact
            else
                rec.qty = q
                index[g][tag] = rec
                table.insert(groups[g], rec)
            end
            total = total + 1
        end
    end
    table.sort(groups.ore, function(a, b) if a.qty ~= b.qty then return a.qty > b.qty end return a.name < b.name end)
    table.sort(groups.miner, function(a, b)
        local ra, rb = RARITY_RANK[a.rarity] or 0, RARITY_RANK[b.rarity] or 0
        if ra ~= rb then return ra > rb end
        return a.name < b.name
    end)
    table.sort(groups.other, function(a, b) return a.name < b.name end)
    BAG.groups, BAG.total, BAG.at = groups, total, clock()
end

-- ---------- ข้อมูลตรวจสอบ (ส่งมาให้ดูเวลาแสดงผลไม่ตรง) ----------
local function shallow(t, depth)
    depth = depth or 0
    if type(t) ~= "table" then return tostring(t) end
    if depth >= 2 then
        local n = 0
        for _ in pairs(t) do n = n + 1 end
        return "{" .. n .. " ค่า}"
    end
    local parts, n = {}, 0
    for k, v in pairs(t) do
        n = n + 1
        if n > 12 then parts[#parts + 1] = "..." break end
        parts[#parts + 1] = tostring(k) .. "=" .. (type(v) == "table" and shallow(v, depth + 1) or tostring(v))
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

local function diagText()
    local L = {}
    local function add(s) L[#L + 1] = s end
    add("MAM Diag v" .. SCRIPT_VERSION .. " | UserId " .. tostring(lp.UserId) .. " | Running=" .. tostring(State.Running))
    add("GameState=" .. tostring(GameState ~= nil) .. " MineConfig=" .. tostring(MineConfig ~= nil) .. " Items=" .. tostring(Items ~= nil) .. " MineStock=" .. tostring(MineStock ~= nil))
    add("fireclickdetector=" .. tostring(fireclickdetector ~= nil) .. " fireproximityprompt=" .. tostring(fireproximityprompt ~= nil) .. " getconnections=" .. tostring(getconnections ~= nil))
    add("Money=" .. tostring(readMoney()))
    local d = getPlrData()
    if d then
        local keys = {}
        for k, v in pairs(d) do keys[#keys + 1] = tostring(k) .. ":" .. type(v) end
        table.sort(keys)
        add("plrData keys: " .. table.concat(keys, ", "))
        local mg = d.MineGame
        if type(mg) == "table" then
            local mk = {}
            for k, v in pairs(mg) do
                local s = tostring(k) .. ":" .. type(v)
                if type(v) == "table" then
                    local n = 0
                    for _ in pairs(v) do n = n + 1 end
                    s = s .. "(" .. n .. ")"
                elseif type(v) ~= "function" then
                    s = s .. "=" .. tostring(v)
                end
                mk[#mk + 1] = s
            end
            table.sort(mk)
            add("MineGame: " .. table.concat(mk, ", "))
            add("Holders: " .. shallow(mg.Holders))
            add("Pickaxes: " .. shallow(mg.Pickaxes))
            add("UnlockedZones: " .. shallow(mg.UnlockedZones))
        else
            add("MineGame: ไม่พบ")
        end
    else
        add("plrData: อ่านไม่ได้")
    end
    local okU, u2 = pcall(function()
        local sellBtn = lp.PlayerGui.MineGui.SellFrame.Content.SellButton
        return debug.getupvalues(getconnections(sellBtn.MouseButton1Click)[1].Function)[2]
    end)
    if okU and type(u2) == "table" then
        local n, shown = 0, 0
        for _, item in pairs(u2) do
            n = n + 1
            if shown < 4 and type(item) == "table" then
                shown = shown + 1
                add("bag#" .. shown .. ": " .. shallow(item))
            end
        end
        add("bag entries: " .. n)
    else
        add("bag: อ่านจากหน้าขายไม่ได้ (" .. tostring(u2) .. ")")
    end
    for _, m in ipairs(MODS) do
        local a = Act.mods[m.key] or {}
        add(string.format("%s flag=%s runs=%s kind=%s text=%s", m.key, tostring(State[m.flag]), tostring(a.runs or 0), tostring(a.kind), tostring(a.text)))
        if a.lastErr then add("  error เต็ม: " .. a.lastErr) end
    end
    local P = researchPlan(true)
    if P then
        add(string.format("research %s: %d/%d complete=%s cheapest=%s buyer=%s FocusZone=%s", P.zk, P.done, P.total, tostring(P.complete),
            P.cheapest and (P.cheapest.name .. "#" .. P.cheapest.k .. " " .. fmtCash(P.cheapest.cost)) or "-", tostring(Research.buyer ~= nil), tostring(State.FocusZone)))
        for i = 1, math.min(12, #P.pips) do
            local pip = P.pips[i]
            add(string.format("  %s %s#%d cost=%s state=%s%s", tostring(pip.fam), pip.name, pip.k, tostring(pip.cost), pip.state, pip.blocker and (" รอ " .. pip.blocker) or ""))
        end
    else
        add("research: อ่านไม่ได้ " .. tostring(Research.planErr or ""))
    end
    local nk = {}
    for k, v in pairs(Act.n) do nk[#nk + 1] = k .. "=" .. tostring(v) end
    table.sort(nk)
    add("counters: " .. table.concat(nk, " "))
    return L
end

local function diagRun()
    local ok, L = pcall(diagText)
    if not ok then warn("[MAM] Diag ผิดพลาด: " .. tostring(L)) return nil end
    local text = table.concat(L, "\n")
    for _, line in ipairs(L) do print("[MAM Diag] " .. line) end
    local saved = {}
    local fn = "MAM_diag_" .. tostring(lp.UserId) .. ".txt"
    pcall(function() if type(writefile) == "function" then writefile(fn, text) saved[#saved + 1] = "ไฟล์ " .. fn end end)
    pcall(function() if type(setclipboard) == "function" then setclipboard(text) saved[#saved + 1] = "คลิปบอร์ด" end end)
    print("[MAM Diag] " .. (#saved > 0 and ("บันทึกแล้วที่: " .. table.concat(saved, " + ")) or "executor ไม่รองรับ writefile/setclipboard — คัดลอกจาก Console"))
    return text, #saved > 0
end

-- ---------- ข้อความช่วย ----------
local function ago(t)
    if not t then return "" end
    local s = math.max(0, math.floor(clock() - t))
    if s < 3 then return "เมื่อกี้" end
    if s < 60 then return s .. " วิที่แล้ว" end
    if s < 3600 then return math.floor(s / 60) .. " นาทีที่แล้ว" end
    return math.floor(s / 3600) .. " ชม.ที่แล้ว"
end

local function hms(s)
    s = math.max(0, math.floor(s))
    return string.format("%02d:%02d:%02d", math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
end

local SESSION = { money0 = nil, zone = nil }

local function zoneInfo()
    local d = getPlrData()
    local mg = d and d.MineGame
    if type(mg) ~= "table" then return nil end
    local cur = tonumber(mg.CurrentZone) or tonumber(lp:GetAttribute("CurrentZone")) or 1
    local unlocked = 0
    if type(mg.UnlockedZones) == "table" then
        for _, v in pairs(mg.UnlockedZones) do if v == true then unlocked = unlocked + 1 end end
    end
    return cur, unlocked, isCurrentZoneResearchComplete()
end

-- ความคืบหน้าไปโซนถัดไป = เฉลี่ยของ (วิจัยโซนนี้ กี่ขั้นจากทั้งหมด) กับ (เงินเทียบค่าปลดโซนถัดไป)
--   วิจัย: ขั้นที่อัปแล้ว (MineGame.Skills[โซน]) รวมทุกสาย ÷ ขั้นสูงสุด (MineConfig.ZoneSkillMax[โซน]) ; ถ้าเกมบอกว่าวิจัยครบ = 100%
--          สำรอง: ตัวเลข x/y บนปุ่มสกิลในหน้าสกิลของเกม
--   เงิน : อ่านราคาจากป้ายโซนบนแปลง (ที่เดียวกับที่ระบบปลดโซนใช้) ; ถ้าปลดโซนถัดไปแล้ว = 100%
--   ส่วนไหนอ่านไม่ได้ จะไม่นับส่วนนั้น
local function nextZoneProgress(money)
    local d = getPlrData()
    local mg = d and d.MineGame
    local cur = (type(mg) == "table" and tonumber(mg.CurrentZone)) or tonumber(lp:GetAttribute("CurrentZone"))
    if not cur then return nil end
    local P = { cur = cur, next = cur + 1 }
    if P.next > 12 then P.last = true return P end

    -- หลัก: ข้อมูลเกม  ขั้นที่อัปแล้ว MineGame.Skills["Z5"][สาย]  เทียบ  ขั้นสูงสุด MineConfig.ZoneSkillMax["Z5"][สาย]
    pcall(function()
        local zk = "Z" .. tostring(cur)
        local maxT = MineConfig.ZoneSkillMax[zk]
        if type(maxT) ~= "table" then return end
        local have = (type(mg) == "table" and type(mg.Skills) == "table" and type(mg.Skills[zk]) == "table") and mg.Skills[zk] or {}
        local done, total = 0, 0
        for fam, mx in pairs(maxT) do
            mx = tonumber(mx)
            if mx and mx > 0 then
                total = total + mx
                done = done + math.max(0, math.min(tonumber(have[fam]) or 0, mx))
            end
        end
        if total > 0 then P.rDone, P.rTotal, P.rPct, P.rSrc = done, total, done / total, "data" end
    end)
    if isCurrentZoneResearchComplete() then
        P.rPct = 1   -- เกมบอกว่าครบ = 100% เสมอ
        if P.rTotal then P.rDone = P.rTotal end
    elseif not P.rTotal then
        -- สำรอง: ตัวเลข x/y บนปุ่มสกิลในหน้าสกิลของเกม (หน้าถูกสร้างไว้แล้วแม้ไม่ได้เปิด)
        pcall(function()
            local canvas = lp.PlayerGui.MineGui.SkillTreeFullFrame.Tree.Canvas:FindFirstChild("Zone_Z" .. tostring(cur))
            if not canvas then return end
            local done, total = 0, 0
            for _, node in ipairs(canvas:GetChildren()) do
                if node:IsA("TextButton") or node:IsA("ImageButton") then
                    local text = ""
                    for _, dsc in ipairs(node:GetDescendants()) do
                        if dsc:IsA("TextLabel") and dsc.Text ~= "" then text = text .. " " .. dsc.Text end
                    end
                    local a, b = string.match(text, "(%d+)/(%d+)")
                    a, b = tonumber(a), tonumber(b)
                    if a and b and b > 0 then
                        done = done + math.min(a, b)
                        total = total + b
                    end
                end
            end
            if total > 0 then P.rDone, P.rTotal, P.rPct, P.rSrc = done, total, done / total, "ui" end
        end)
    end

    local nextKey = "Z" .. tostring(P.next)
    if type(mg) == "table" and type(mg.UnlockedZones) == "table" and mg.UnlockedZones[nextKey] == true then
        P.unlocked, P.mPct = true, 1
    else
        P.cost = 0
        pcall(function()
            local plot = getMyPlot()
            local row = plot.ZoneBoard.ZoneBoardGui.Root.List:FindFirstChild("ZoneRow" .. tostring(P.next))
            local lbl = row and row:FindFirstChild("Label", true)
            if lbl and lbl.Text ~= "" then P.cost = parseCash(lbl.Text:match("%$[%d%.%a,]+")) end
        end)
        if P.cost > 0 and money then P.mPct = math.min(1, math.max(0, money / P.cost)) end
    end

    local parts = {}
    if P.rPct then parts[#parts + 1] = P.rPct end
    if P.mPct then parts[#parts + 1] = P.mPct end
    if #parts > 0 then
        local sum = 0
        for _, v in ipairs(parts) do sum = sum + v end
        P.pct = sum / #parts
    end
    return P
end

-- ==============================================================================
-- หน้าตาแดชบอร์ด
-- ==============================================================================
local function buildDashboard()
    local gui = Instance.new("ScreenGui")
    gui.Name = "MAM_Dashboard"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999
    local parented = false
    if gethui then parented = pcall(function() gui.Parent = gethui() end) end
    if not parented then parented = pcall(function() gui.Parent = game:GetService("CoreGui") end) end
    if not parented then pcall(function() gui.Parent = lp:WaitForChild("PlayerGui") end) end
    Dash.gui = gui

    local W, H = 340, 520
    do
        local vw, vh
        pcall(function() local vs = workspace.CurrentCamera.ViewportSize vw, vh = vs.X, vs.Y end)
        if type(vw) == "number" and vw > 0 then W = math.max(300, math.min(360, math.floor(vw - 16))) end
        if type(vh) == "number" and vh > 0 then H = math.max(260, math.min(620, math.floor(vh - 16))) end
    end
    local CHROME, PAD, GAP = 42, 14, 12
    local CW = W - PAD * 2
    local TABS_Y = CHROME + 6
    local PAGE_Y = TABS_Y + 38

    local C = Color3.fromRGB
    local BG, SURF, INSET, TABON = C(15, 23, 42), C(30, 41, 59), C(21, 30, 50), C(51, 65, 85)
    local TXT, SUB, DIM = C(248, 250, 252), C(203, 213, 225), C(148, 163, 184)
    local GREEN, GREENT, AMBER, AMBERT = C(52, 211, 153), C(110, 231, 183), C(251, 191, 36), C(252, 211, 77)
    local RED, REDT = C(248, 113, 113), C(255, 139, 152)
    local OFFSW, OFFDOT, WHITE, LINE = C(71, 85, 105), C(100, 116, 139), C(255, 255, 255), C(51, 65, 85)
    local function rarityColor(r)
        local c = RARITY_COLOR[r]
        return c and C(c[1], c[2], c[3]) or DIM
    end

    -- ---------- เครื่องมือสร้างหน้าตา ----------
    local function mk(class, parent, x, y, w, h)
        local o = Instance.new(class)
        o.Position = UDim2.fromOffset(x, y)
        o.Size = UDim2.fromOffset(w, h)
        o.BorderSizePixel = 0
        o.Parent = parent
        return o
    end
    local function round(o, r)
        local c = Instance.new("UICorner")
        c.CornerRadius = (r == "full") and UDim.new(0.5, 0) or UDim.new(0, r)
        c.Parent = o
    end
    local function stroke(o, color)
        local s
        pcall(function()
            s = Instance.new("UIStroke")
            s.Color = color or LINE
            s.Thickness = 1
            s.Parent = o
        end)
        if s then pcall(function() s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border end) end
        return s
    end
    local function frame(parent, x, y, w, h, color, r, transp)
        local f = mk("Frame", parent, x, y, w, h)
        f.BackgroundColor3 = color
        f.BackgroundTransparency = transp or 0
        if r then round(f, r) end
        return f
    end
    local function label(parent, str, x, y, w, h, size, color, o)
        local l = mk("TextLabel", parent, x, y, w, h)
        l.BackgroundTransparency = 1
        l.Font = (o and o.bold) and Enum.Font.GothamBold or Enum.Font.GothamMedium
        l.TextSize = math.floor(size)
        l.TextColor3 = color or TXT
        l.TextXAlignment = (o and o.right) and Enum.TextXAlignment.Right or ((o and o.center) and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left)
        if o and o.wrap then
            l.TextWrapped = true
            l.TextYAlignment = Enum.TextYAlignment.Top
        end
        l.TextTruncate = Enum.TextTruncate.AtEnd
        l.Text = str
        return l
    end
    local function button(parent, str, x, y, w, h, bg, fn, size, color, transp, r)
        local b = mk("TextButton", parent, x, y, w, h)
        b.BackgroundColor3 = bg
        b.BackgroundTransparency = transp or 0
        b.AutoButtonColor = false
        b.Font = Enum.Font.GothamMedium
        b.TextSize = math.floor(size or 12)
        b.TextColor3 = color or TXT
        b.Text = str
        round(b, r or 8)
        b.MouseButton1Click:Connect(function() pcall(fn) end)
        return b
    end
    local function switch(parent, x, y, fn, name)
        local w, h = 44, 24
        local b = mk("TextButton", parent, x, y, w, h)
        b.Name = name
        b.Text = ""
        b.AutoButtonColor = false
        b.BackgroundColor3 = OFFSW
        round(b, "full")
        local k = frame(b, 2, 2, h - 4, h - 4, WHITE, "full")
        b.MouseButton1Click:Connect(function() pcall(fn) end)
        local sw = { btn = b }
        function sw.set(on)
            on = on and true or false
            if sw.on == on then return end
            sw.on = on
            b.BackgroundColor3 = on and GREEN or OFFSW
            k.Position = UDim2.fromOffset(on and (w - h + 2) or 2, 2)
        end
        sw.set(false)
        return sw
    end
    local function card(parent, x, y, w, h)
        local f = frame(parent, x, y, w, h, SURF, 16)
        stroke(f)
        return f
    end
    local function page(name, visible)
        local s = mk("ScrollingFrame", Dash.main, 0, PAGE_Y, W, H - PAGE_Y)
        s.Name = name
        s.BackgroundTransparency = 1
        s.ScrollBarThickness = 3
        s.ScrollingDirection = Enum.ScrollingDirection.Y
        s.CanvasSize = UDim2.fromOffset(0, 0)
        s.Visible = visible
        return s
    end

    -- การ์ดรายการ (แถวสร้างครั้งเดียวแล้วใช้ซ้ำ) ; item = { main, right, sub, color, style = "head"|"plain" }
    local function listCard(parent, title)
        local c = { rows = {} }
        c.frame = card(parent, PAD, 0, CW, 60)
        c.title = label(c.frame, title, 16, 12, CW - 150, 20, 14, TXT, { bold = true })
        c.right = label(c.frame, "", CW - 16 - 130, 12, 130, 20, 11, DIM, { right = true })
        c.empty = label(c.frame, "", 16, 40, CW - 32, 34, 11, DIM, { wrap = true })
        local function row(i)
            local r = c.rows[i]
            if r then return r end
            r = {}
            r.f = frame(c.frame, 0, 0, CW, 36, SURF, nil, 1)
            r.dot = frame(r.f, 16, 8, 8, 8, DIM, "full")
            r.main = label(r.f, "", 32, 2, CW - 32 - 106, 18, 12, TXT, { bold = true })
            r.rt = label(r.f, "", CW - 16 - 100, 2, 100, 18, 11, SUB, { right = true })
            r.sub = label(r.f, "", 32, 19, CW - 48, 15, 10, DIM)
            c.rows[i] = r
            return r
        end
        function c.set(items, y, emptyText)
            c.frame.Position = UDim2.fromOffset(PAD, y)
            local yy = 40
            if #items == 0 then
                c.empty.Text = emptyText or "ยังไม่มีข้อมูล"
                c.empty.Visible = true
                yy = 40 + 38
            else
                c.empty.Visible = false
            end
            for i, it in ipairs(items) do
                local r = row(i)
                local style = it.style
                local h = (style == "head") and 24 or (it.sub and 36 or 24)
                r.f.Visible = true
                r.f.Position = UDim2.fromOffset(0, yy)
                r.f.Size = UDim2.fromOffset(CW, h)
                r.dot.Visible = (style == nil) and it.color ~= nil
                if it.color then r.dot.BackgroundColor3 = it.color end
                local x = (style == nil) and 32 or 16
                r.main.Position = UDim2.fromOffset(x, (style == "head") and 6 or 2)
                r.main.Size = UDim2.fromOffset(CW - x - 16 - (it.right and it.right ~= "" and 100 or 0), 18)
                r.main.Font = (style == "plain") and Enum.Font.GothamMedium or Enum.Font.GothamBold
                r.main.TextSize = (style == "head") and 11 or 12
                r.main.TextColor3 = (style == "head") and DIM or ((style == "plain") and SUB or (it.mainColor or TXT))
                r.main.Text = it.main or ""
                r.rt.Position = UDim2.fromOffset(CW - 16 - 100, (style == "head") and 6 or 2)
                r.rt.Text = it.right or ""
                r.rt.TextColor3 = it.rightColor or SUB
                r.sub.Visible = it.sub ~= nil and style ~= "head"
                r.sub.Position = UDim2.fromOffset(x, 19)
                r.sub.Size = UDim2.fromOffset(CW - x - 16, 15)
                r.sub.Text = it.sub or ""
                yy = yy + h
            end
            for i = #items + 1, #c.rows do c.rows[i].f.Visible = false end
            local hgt = yy + 10
            c.frame.Size = UDim2.fromOffset(CW, hgt)
            return y + hgt
        end
        return c
    end

    -- ---------- ลากด้วยนิ้ว/เมาส์ (แทน Draggable แบบเก่าที่บนมือถือลากไม่ค่อยติด) ----------
    local UIS = game:GetService("UserInputService")
    Dash.conns = Dash.conns or {}
    local function keep(c) if c then Dash.conns[#Dash.conns + 1] = c end return c end
    local function viewport()
        local vw, vh
        pcall(function() local vs = workspace.CurrentCamera.ViewportSize vw, vh = vs.X, vs.Y end)
        return vw, vh
    end
    local function isPress(t) return t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 end
    local function isMove(t) return t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseMovement end
    -- handle = จุดที่จับลาก , target = สิ่งที่ย้าย ; คืนค่า ฟังก์ชันถามว่า "เพิ่งลากไปหรือเปล่า" (กันการลากปุ่มแล้วนับเป็นการกด)
    local function makeDraggable(handle, target, keepW, keepH)
        local dragging, dragStart, startPos, dragInput
        local moved, lastMoveAt = false, -1e9
        keep(handle.InputBegan:Connect(function(input)
            if not isPress(input.UserInputType) then return end
            dragging, moved = true, false
            dragStart, startPos, dragInput = input.Position, target.Position, input
            local c
            c = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if c then c:Disconnect() end
                end
            end)
        end))
        keep(handle.InputChanged:Connect(function(input)
            if isMove(input.UserInputType) then dragInput = input end
        end))
        keep(UIS.InputChanged:Connect(function(input)
            if not dragging or input ~= dragInput then return end
            local dx, dy = input.Position.X - dragStart.X, input.Position.Y - dragStart.Y
            if math.abs(dx) + math.abs(dy) > 6 then moved = true lastMoveAt = clock() end
            if not moved then return end
            local ox, oy = startPos.X.Offset + dx, startPos.Y.Offset + dy
            local vw, vh = viewport()
            if vw and vh then   -- เหลือส่วนให้จับได้ในจอเสมอ
                local ax, ay = startPos.X.Scale * vw + ox, startPos.Y.Scale * vh + oy
                local cx = math.max(-(keepW - 70), math.min(vw - 70, ax))
                local cy = math.max(0, math.min(vh - (keepH or 40), ay))
                ox, oy = ox + (cx - ax), oy + (cy - ay)
            end
            target.Position = UDim2.new(startPos.X.Scale, ox, startPos.Y.Scale, oy)
        end))
        keep(UIS.InputEnded:Connect(function(input)
            if dragging and (input == dragInput or isPress(input.UserInputType)) then dragging = false end
        end))
        return function() return clock() - lastMoveAt < 0.4 end
    end

    -- ---------- กรอบหน้าต่าง + แถบบน ----------
    local main = frame(gui, 0, 0, W, H, BG, 20)
    main.Name = "Main"
    main.Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2)
    main.Active = true
    main.ClipsDescendants = true
    stroke(main)
    Dash.main = main

    local dragBar = frame(main, 0, 0, W, CHROME, BG, nil, 1)   -- แถบจับลาก (ปุ่ม – × อยู่ด้านบนแถบนี้)
    dragBar.Name = "DragBar"
    dragBar.Active = true
    pcall(makeDraggable, dragBar, main, W, CHROME)
    local chromeTxt = label(main, "MAM Dashboard", 14, 0, W - 110, CHROME, 11, DIM, { bold = true })
    frame(main, math.floor(W / 2) - 18, 6, 36, 4, DIM, "full", 0.6)
    local bMin = button(main, "–", W - 86, 3, 40, CHROME - 6, SURF, function() Dash.setMode(Dash.mode == "mini" and "full" or "mini") end, 18, SUB, 0, 10)
    bMin.Name = "Btn_min"
    local bHide = button(main, "×", W - 44, 3, 40, CHROME - 6, SURF, function() Dash.setMode("hidden") end, 18, SUB, 0, 10)
    bHide.Name = "Btn_hide"
    frame(main, 0, CHROME - 1, W, 1, WHITE, nil, 0.94)

    local restore = mk("TextButton", gui, 8, 120, 64, 40)
    restore.Name = "Restore"
    restore.Text = "MAM"
    restore.Font = Enum.Font.GothamBold
    restore.TextSize = 14
    restore.TextColor3 = TXT
    restore.BackgroundColor3 = SURF
    restore.AutoButtonColor = false
    restore.Visible = false
    restore.Active = true
    round(restore, 12)
    stroke(restore, GREEN)
    local okDrag, restoreJustDragged = pcall(makeDraggable, restore, restore, 64, 40)
    if not okDrag then restoreJustDragged = function() return false end end
    restore.MouseButton1Click:Connect(function()
        if restoreJustDragged() then return end   -- ลากย้ายปุ่ม ไม่ใช่การกดเปิด
        pcall(function() Dash.setMode("full") end)
    end)

    -- แถบเลือกหน้า
    local tabsBg = frame(main, PAD, TABS_Y, CW, 32, INSET, 10)
    local TABS = { { "overview", "ภาพรวม" }, { "inv", "ของที่มี" }, { "settings", "ตั้งค่า" } }
    local tabW = math.floor((CW - 8) / #TABS)
    local tabBtns = {}
    for i, t in ipairs(TABS) do
        local b = button(tabsBg, t[2], 4 + (i - 1) * tabW, 4, tabW, 24, TABON, function() Dash.setTab(t[1]) end, 12, DIM, 1, 8)
        b.Name = "Tab_" .. t[1]
        tabBtns[t[1]] = b
    end

    -- ================= หน้าภาพรวม =================
    local po = page("Page_overview", true)
    local y = 6
    label(po, "My Anime Mine", PAD, y, CW - 120, 24, 18, TXT, { bold = true })
    label(po, "ออโต้ฟาร์ม · v" .. SCRIPT_VERSION, PAD, y + 24, CW - 120, 16, 10, DIM)
    local badge = frame(po, W - PAD - 112, y + 4, 112, 28, GREEN, "full", 0.86)
    local badgeStroke = stroke(badge, GREEN)
    local badgeDot = frame(badge, 12, 10, 8, 8, GREEN, "full")
    local badgeTxt = label(badge, "กำลังทำงาน", 26, 0, 82, 28, 11, GREENT, { bold = true })
    y = y + 46 + GAP

    local stat = {}
    local SW = math.floor((CW - 10) / 2)
    local STAT_H = 78
    local STATS = { { "money", "เงิน" }, { "zone", "โซน" } }
    for i, s in ipairs(STATS) do
        local cx = PAD + ((i - 1) % 2) * (SW + 10)
        local cy = y + math.floor((i - 1) / 2) * (STAT_H + 10)
        local f = card(po, cx, cy, SW, STAT_H)
        label(f, s[2], 14, 10, SW - 28, 16, 11, DIM)
        stat[s[1]] = {
            v = label(f, "—", 14, 28, SW - 28, 24, 18, TXT, { bold = true }),
            s = label(f, "", 14, 53, SW - 28, 16, 10, DIM),
        }
    end
    y = y + STAT_H + 10

    -- การ์ดความคืบหน้าไปโซนถัดไป (เต็มความกว้าง)
    local PROG_H = 112
    local pc = card(po, PAD, y, CW, PROG_H)
    local prog = {}
    prog.title = label(pc, "ไปโซนถัดไป", 14, 10, CW - 130, 16, 11, DIM)
    prog.state = label(pc, "", CW - 14 - 150, 10, 150, 16, 11, DIM, { right = true })
    prog.v = label(pc, "—", 14, 28, CW - 28, 26, 22, TXT, { bold = true })
    prog.barBg = frame(pc, 14, 60, CW - 28, 8, INSET, "full")
    prog.bar = frame(prog.barBg, 0, 0, 0, 8, GREEN, "full")
    prog.r = label(pc, "", 14, 74, CW - 28, 15, 10, SUB)
    prog.m = label(pc, "", 14, 91, CW - 28, 15, 10, SUB)
    prog.barW = CW - 28
    y = y + PROG_H + GAP
    local planCard = listCard(po, "ลำดับการอัปวิจัย")
    local actCard = listCard(po, "การทำงาน")
    local logCard = listCard(po, "เหตุการณ์ล่าสุด")
    Dash.overviewTop = y

    -- ================= หน้าของที่มี =================
    local pi = page("Page_inv", false)
    local minerCard = listCard(pi, "คนงานบนแปลง")
    local pickCard = listCard(pi, "Pickaxe ที่มี")
    local bagCard = listCard(pi, "ของในกระเป๋า")

    -- ================= หน้าตั้งค่า =================
    local ps = page("Page_settings", false)
    local sy = 6
    local switches = {}
    local allSw = {}
    for _, m in ipairs(MODS) do allSw[#allSw + 1] = { flag = m.flag, name = m.name, desc = m.desc } end
    for _, e in ipairs(EXTRA_SWITCHES) do allSw[#allSw + 1] = e end
    local ROW_H = 46
    local swCard = card(ps, PAD, sy, CW, 44 + #allSw * ROW_H + 6)
    label(swCard, "เปิด/ปิดระบบ", 16, 12, CW - 32, 20, 14, TXT, { bold = true })
    for i, e in ipairs(allSw) do
        local ry = 40 + (i - 1) * ROW_H
        label(swCard, e.name, 16, ry + 4, CW - 32 - 56, 18, 13, TXT, { bold = true })
        label(swCard, e.desc, 16, ry + 22, CW - 32 - 56, 16, 10, DIM)
        local flag, nm = e.flag, e.name
        switches[flag] = switch(swCard, CW - 16 - 44, ry + 9, function()
            State[flag] = not State[flag]
            switches[flag].set(State[flag])
            logEvent((State[flag] and "เปิด " or "ปิด ") .. nm)
        end, "Sw_" .. flag)
        if i < #allSw then frame(swCard, 16, ry + ROW_H - 1, CW - 32, 1, WHITE, nil, 0.95) end
    end
    sy = sy + 44 + #allSw * ROW_H + 6 + GAP

    -- จังหวะการทำงาน (ปรับเวลา)
    local timingRows = {
        { key = "CycleInterval", name = "รอบทำงาน", unit = " วิ", step = 5, min = 15, max = 600 },
        { key = "SellDelay", name = "รอขายหลังเก็บหีบ", unit = " วิ", step = 1, min = 0, max = 30 },
        { key = "ResearchPerCycle", name = "วิจัยสูงสุดต่อรอบ", unit = " ขั้น", step = 1, min = 1, max = 30 },
    }
    local TROW = 40
    local tCard = card(ps, PAD, sy, CW, 44 + #timingRows * TROW + 6)
    label(tCard, "จังหวะการทำงาน", 16, 12, CW - 32, 20, 14, TXT, { bold = true })
    local timingVals = {}
    for i, r in ipairs(timingRows) do
        local ry = 40 + (i - 1) * TROW
        label(tCard, r.name, 16, ry + 8, CW - 32 - 130, 20, 12, TXT, { bold = true })
        local val = label(tCard, "", CW - 16 - 92, ry + 6, 56, 24, 12, SUB, { center = true })
        timingVals[r.key] = { lbl = val, row = r }
        local function bump(d)
            local v = (tonumber(State[r.key]) or r.min) + d
            State[r.key] = math.max(r.min, math.min(r.max, v))
            val.Text = tostring(State[r.key]) .. r.unit
            logEvent("ตั้ง" .. r.name .. " = " .. tostring(State[r.key]) .. r.unit)
            if r.key == "CycleInterval" and Cycle.startedAt then Cycle.nextAt = Cycle.startedAt + State.CycleInterval end
        end
        local bMinus = button(tCard, "−", CW - 16 - 130, ry + 4, 34, 28, INSET, function() bump(-r.step) end, 16, SUB, 0, 8)
        bMinus.Name = "Dec_" .. r.key
        local bPlus = button(tCard, "+", CW - 16 - 34, ry + 4, 34, 28, INSET, function() bump(r.step) end, 16, SUB, 0, 8)
        bPlus.Name = "Inc_" .. r.key
        val.Text = tostring(State[r.key]) .. r.unit
    end
    sy = sy + 44 + #timingRows * TROW + 6 + GAP

    local toolCard = card(ps, PAD, sy, CW, 150)
    label(toolCard, "เครื่องมือ", 16, 12, CW - 32, 20, 14, TXT, { bold = true })
    local diagNote = label(toolCard, "ข้อมูลเกมที่สคริปต์อ่านได้ ไว้ส่งให้ตรวจเวลาแสดงผลไม่ตรง", 16, 80, CW - 32, 16, 10, DIM)
    local bDiag = button(toolCard, "คัดลอกข้อมูลตรวจสอบ", 16, 42, CW - 32, 34, INSET, function()
        local _, saved = diagRun()
        diagNote.Text = saved and ("คัดลอกแล้ว · ไฟล์ MAM_diag_" .. tostring(lp.UserId) .. ".txt") or "พิมพ์ไว้ใน Console แล้ว (executor ไม่รองรับคัดลอก)"
    end, 12, SUB, 0, 10)
    bDiag.Name = "Btn_diag"
    stroke(bDiag)
    local stopArm = 0
    local bStop
    bStop = button(toolCard, "หยุดฟาร์มทั้งหมด", 16, 104, CW - 32, 34, RED, function()
        if not State.Running then return end
        if clock() - stopArm > 4 then
            stopArm = clock()
            bStop.Text = "แตะอีกครั้งเพื่อหยุด"
            return
        end
        stopFarm()
        logEvent("หยุดฟาร์มจากแดชบอร์ด")
        bStop.Text = "หยุดแล้ว — รันสคริปต์ใหม่เพื่อเริ่ม"
    end, 12, REDT, 0.85, 10)
    bStop.Name = "Btn_stop"
    stroke(bStop, RED)
    sy = sy + 150 + GAP

    local infoCard = card(ps, PAD, sy, CW, 92)
    label(infoCard, "รายละเอียด", 16, 12, CW - 32, 20, 14, TXT, { bold = true })
    label(infoCard, "เวอร์ชัน " .. SCRIPT_VERSION .. " · ผู้เล่น " .. tostring(lp.Name), 16, 40, CW - 32, 16, 11, SUB)
    local infoData = label(infoCard, "", 16, 60, CW - 32, 16, 11, SUB)
    sy = sy + 92 + 16
    ps.CanvasSize = UDim2.fromOffset(0, sy)

    -- ---------- โหมด / หน้า ----------
    local pages = { overview = po, inv = pi, settings = ps }
    function Dash.setTab(name)
        if not pages[name] then return end
        Dash.tab = name
        for k, pg in pairs(pages) do pg.Visible = (k == name) and Dash.mode == "full" end
        for k, b in pairs(tabBtns) do
            b.BackgroundTransparency = (k == name) and 0 or 1
            b.TextColor3 = (k == name) and TXT or DIM
        end
        if Dash.refresh then pcall(Dash.refresh, true) end
    end
    function Dash.setMode(mode)
        Dash.mode = mode
        main.Visible = mode ~= "hidden"
        restore.Visible = mode == "hidden"
        main.Size = UDim2.fromOffset(W, mode == "mini" and CHROME or H)
        tabsBg.Visible = mode == "full"
        bMin.Text = mode == "mini" and "+" or "–"
        for k, pg in pairs(pages) do pg.Visible = (k == Dash.tab) and mode == "full" end
        if Dash.refresh then pcall(Dash.refresh, true) end
    end

    -- ---------- อัปเดตข้อมูล ----------
    local function modView(m)
        local a = Act.mods[m.key]
        if not State.Running then return OFFDOT, "หยุดแล้ว" end
        if not State[m.flag] then return OFFDOT, "ปิดอยู่" end
        if not a or not a.text then return AMBER, "รอเริ่ม" end
        local txt = a.text .. " · " .. ago(a.at)
        local staleAfter = (m.key == "HyperMine") and 90 or math.max(90, (tonumber(State.CycleInterval) or 45) * 2 + 60)
        if a.lastRun and clock() - a.lastRun > staleAfter then return AMBER, "ไม่ได้ทำงานมา " .. ago(a.lastRun) .. " (อาจค้าง)" end
        if a.kind == "err" then return RED, txt end
        if a.kind == "wait" then return AMBER, txt end
        return GREEN, txt
    end

    local function refreshTop()
        local on, errs = 0, 0
        for _, m in ipairs(MODS) do
            if State[m.flag] then on = on + 1 end
            local a = Act.mods[m.key]
            if State[m.flag] and a and a.kind == "err" and a.at and clock() - a.at < 30 then errs = errs + 1 end
        end
        local col, colT, txt
        if not State.Running then col, colT, txt = RED, REDT, "หยุดแล้ว"
        elseif on == 0 then col, colT, txt = AMBER, AMBERT, "ปิดทุกระบบ"
        elseif errs > 0 then col, colT, txt = AMBER, AMBERT, "มีข้อผิดพลาด"
        else col, colT, txt = GREEN, GREENT, "กำลังทำงาน" end
        badge.BackgroundColor3 = col
        if badgeStroke then badgeStroke.Color = col end
        badgeDot.BackgroundColor3 = col
        badgeTxt.TextColor3 = colT
        badgeTxt.Text = txt
        local money = readMoney()
        if Dash.mode == "mini" then
            local cur = zoneInfo()
            chromeTxt.Text = "MAM · " .. txt .. (money and (" · " .. fmtCash(money)) or "") .. (cur and (" · Z" .. cur) or "")
        else
            chromeTxt.Text = "MAM Dashboard"
        end
        return on, money
    end

    local function refreshOverview(on, money)
        if money then
            stat.money.v.Text = fmtCash(money)
            local d = SESSION.money0 and (money - SESSION.money0) or 0
            stat.money.s.Text = "เทียบตอนเริ่ม " .. (d >= 0 and "+" or "") .. fmtCash(d)
        else
            stat.money.v.Text = "—"
            stat.money.s.Text = "อ่านเงินไม่ได้"
        end
        local cur, unlocked, research = zoneInfo()
        if cur then
            stat.zone.v.Text = "Z" .. tostring(cur)
            stat.zone.s.Text = "ปลด " .. unlocked .. " โซน · " .. (research and "วิจัยครบ" or "วิจัยไม่ครบ")
        else
            stat.zone.v.Text = "—"
            stat.zone.s.Text = "อ่านข้อมูลโซนไม่ได้"
        end
        local P = nextZoneProgress(money)
        local function pctTxt(x) return tostring(math.floor(x * 100 + 0.5)) .. "%" end
        local fill, col = 0, GREEN
        if not P then
            prog.title.Text = "ไปโซนถัดไป"
            prog.v.Text = "—"
            prog.state.Text = ""
            prog.r.Text = "อ่านข้อมูลโซนไม่ได้"
            prog.m.Text = ""
        elseif P.last then
            prog.title.Text = "โซน Z" .. P.cur
            prog.v.Text = "100%"
            prog.state.Text = "โซนสุดท้ายแล้ว"
            prog.r.Text = "ไม่มีโซนถัดไปให้ปลด"
            prog.m.Text = ""
            fill = 1
        else
            prog.title.Text = "ไปโซนถัดไป · Z" .. P.cur .. " → Z" .. P.next
            prog.v.Text = P.pct and pctTxt(P.pct) or "—"
            fill = P.pct or 0
            if P.pct and P.pct >= 1 then prog.state.Text = "พร้อมไปโซนถัดไป" else prog.state.Text = "" end
            if P.rPct == 1 then
                prog.r.Text = "วิจัย: ครบแล้ว (100%)"
            elseif P.rTotal then
                prog.r.Text = "วิจัย: " .. P.rDone .. "/" .. P.rTotal .. " ขั้น (" .. pctTxt(P.rPct) .. ")"
            else
                prog.r.Text = "วิจัย: อ่านข้อมูลวิจัยไม่ได้ (ไม่นับ)"
            end
            if P.unlocked then
                prog.m.Text = "เงิน: ปลดโซนนี้แล้ว (100%)"
            elseif P.cost and P.cost > 0 and money then
                prog.m.Text = "เงิน: " .. fmtCash(money) .. " / " .. fmtCash(P.cost) .. " (" .. pctTxt(P.mPct) .. ")"
            elseif P.cost == 0 then
                prog.m.Text = "เงิน: ไม่เห็นราคาบนป้ายโซน (ไม่นับ)"
            else
                prog.m.Text = "เงิน: อ่านเงินไม่ได้"
            end
            if (P.pct or 0) < 1 then col = AMBER end
        end
        fill = math.max(0, math.min(1, fill))
        prog.bar.Size = UDim2.fromOffset(math.floor(prog.barW * fill + 0.5), 8)
        prog.bar.Visible = fill > 0
        prog.bar.BackgroundColor3 = col

        local items = {}
        for _, m in ipairs(MODS) do
            local col, txt = modView(m)
            items[#items + 1] = { main = m.name, right = m.cnt(), sub = txt, color = col }
        end
        -- การ์ดลำดับการอัปวิจัย
        local pitems = {}
        local P = researchPlan(true)
        local reserve, why, rc = researchReserve(money)
        local limited = {}
        if reserve > 0 then
            if State.BalancedLeveling then limited[#limited + 1] = "อัปเลเวลคนงาน" end
            if State.AutoBuyPickaxe then limited[#limited + 1] = "ซื้อ Pickaxe" end
        end
        local rtxt
        if why == "off" then rtxt = "โหมดเน้นด่าน: ปิดอยู่ (ไม่กันเงิน)"
        elseif why == "hold" then rtxt = "กันเงินไว้ " .. fmtCash(reserve) .. " · จำกัด: " .. (#limited > 0 and table.concat(limited, ", ") or "-")
        elseif why == "zone" then rtxt = "กันเงินไว้ " .. fmtCash(reserve) .. " ให้" .. rc.name .. " · จำกัด: " .. (#limited > 0 and table.concat(limited, ", ") or "-")
        elseif why == "toofar" then rtxt = "ไม่กันเงิน: ขั้นถัดไป " .. fmtCash(rc and rc.cost or 0) .. " แพงเกิน 10 เท่าของเงิน"
        elseif why == "complete" then rtxt = "วิจัยครบ — ไม่กันเงิน"
        else rtxt = "ไม่กันเงิน (ยังไม่มีขั้นที่ซื้อได้)" end
        if P and not P.complete then
            pitems[#pitems + 1] = { main = rtxt, style = "plain" }
            if not State.AutoSkillTree then
                pitems[#pitems + 1] = { main = "ระบบอัปวิจัยปิดอยู่ (แสดงลำดับอย่างเดียว)", style = "plain" }
            end
            local shown = 0
            for _, pip in ipairs(P.pips) do
                shown = shown + 1
                if shown > 8 then
                    pitems[#pitems + 1] = { main = "… อีก " .. (#P.pips - 8) .. " ขั้น", style = "plain" }
                    break
                end
                local col, st
                if pip.paused then
                    col, st = RED, "พักอยู่อีก " .. math.max(1, math.ceil((pip.paused - clock()) / 60)) .. " นาที (ซื้อไม่สำเร็จ 3 ครั้ง)"
                elseif pip.state == "locked" then
                    col, st = OFFDOT, "ล็อก — รอ " .. pip.blocker .. " ให้ครบ"
                elseif pip.state == "after" then
                    col, st = OFFDOT, "ต่อจากขั้น " .. (pip.k - 1)
                elseif pip.state == "nocost" then
                    col, st = OFFDOT, "ไม่รู้ราคา (ไม่ซื้ออัตโนมัติ)"
                elseif money and money >= pip.cost then
                    col, st = GREEN, "ซื้อได้ตอนนี้"
                else
                    col, st = AMBER, "เงินไม่พอ ขาดอีก " .. fmtCash(pip.cost - (money or 0))
                end
                pitems[#pitems + 1] = {
                    main = pip.name .. " · ขั้น " .. pip.k .. (pip.max and ("/" .. pip.max) or ""),
                    right = pip.cost and fmtCash(pip.cost) or "?",
                    sub = tostring(pip.fam) .. " · " .. st, color = col,
                }
            end
            planCard.right.Text = #P.pips .. " ขั้น · " .. fmtCash(P.totalCost)
        else
            planCard.right.Text = P and P.zk or ""
            if P and P.complete then
                pitems[#pitems + 1] = { main = "วิจัย " .. P.zk .. " ครบแล้ว — รอปลดโซน", style = "plain" }
                pitems[#pitems + 1] = { main = rtxt, style = "plain" }
                if State.AutoCore then
                    local a = Act.mods.Skill
                    pitems[#pitems + 1] = { main = "Core: " .. tostring(a and a.text or "รอเริ่ม"), style = "plain" }
                end
            end
        end
        local planEmpty = (P and P.complete) and ("วิจัย " .. P.zk .. " ครบแล้ว — รอปลดโซน") or "อ่านข้อมูลวิจัยของโซนนี้ไม่ได้"
        local yy = planCard.set(pitems, Dash.overviewTop, planEmpty)

        actCard.right.Text = "เปิด " .. on .. "/" .. #MODS
        local ctext
        if not State.Running then ctext = "รอบทำงาน: หยุดแล้ว"
        elseif Cycle.n == 0 then ctext = "รอบทำงาน: กำลังเริ่ม"
        else
            local left = Cycle.nextAt and math.max(0, math.ceil(Cycle.nextAt - clock())) or 0
            ctext = "รอบที่ " .. Cycle.n .. " · " .. tostring(Cycle.phase) .. (Cycle.phase == "รอรอบถัดไป" and (" · อีก " .. left .. " วิ") or "")
        end
        table.insert(items, 1, { main = ctext, style = "plain" })
        yy = actCard.set(items, yy + GAP)

        local logs = {}
        for i = 1, math.min(10, #Act.log) do
            local e = Act.log[i]
            logs[#logs + 1] = { main = e.text .. (e.count > 1 and (" ×" .. e.count) or ""), right = e.t, style = "plain", rightColor = DIM }
        end
        logCard.right.Text = Act.n.errors > 0 and ("ผิดพลาด " .. Act.n.errors .. " ครั้ง") or ""
        yy = logCard.set(logs, yy + GAP, "ยังไม่มีเหตุการณ์ — รอระบบเริ่มทำงานสักครู่")
        po.CanvasSize = UDim2.fromOffset(0, yy + 16)
    end

    local function refreshInventory(force)
        local miners = minersOnPlot()
        local multMap = pickMultMap()
        local usedPick = {}
        local items = {}
        for _, m in ipairs(miners) do
            local _, tier, rarity = getCharacterBaseDamage(m.name)
            if m.pick and m.pick ~= "" then usedPick[m.pick] = (usedPick[m.pick] or 0) + 1 end
            local subBits = { rarity ~= "Unknown" and rarity or "ไม่รู้แรร์" }
            if tier and tier > 0 then subBits[#subBits + 1] = "Tier " .. tier end
            if m.pick ~= nil then subBits[#subBits + 1] = (m.pick ~= "" and tostring(m.pick) or "ไม่มี Pickaxe") end
            items[#items + 1] = { main = m.slot .. "  " .. m.name, right = "Lv " .. tostring(m.level), sub = table.concat(subBits, " · "), color = rarityColor(rarity) }
        end
        minerCard.right.Text = #miners .. "/15 ช่อง"
        local yy = minerCard.set(items, 6, "ยังไม่พบคนงานบนแปลง")

        local d = getPlrData()
        local mg = d and d.MineGame
        local picks = {}
        local totalPick = 0
        if mg and type(mg.Pickaxes) == "table" then
            for name, count in pairs(mg.Pickaxes) do
                if type(count) == "number" and count > 0 then
                    picks[#picks + 1] = { name = tostring(name), count = count, mult = tonumber(multMap[name]) or 1 }
                    totalPick = totalPick + count
                end
            end
        end
        table.sort(picks, function(a, b) if a.mult ~= b.mult then return a.mult > b.mult end return a.name < b.name end)
        local pitems = {}
        for i, p in ipairs(picks) do
            local used = usedPick[p.name] or 0
            pitems[#pitems + 1] = {
                main = p.name, right = "×" .. p.count .. (used > 0 and (" · ใช้ " .. used) or ""),
                sub = "ดาเมจ x" .. fmtNum(p.mult), color = (i == 1) and GREEN or SUB,
            }
        end
        pickCard.right.Text = "รวม " .. totalPick .. " อัน"
        yy = pickCard.set(pitems, yy + GAP, mg and "ยังไม่มี Pickaxe" or "อ่านข้อมูล Pickaxe ไม่ได้")

        if force or not BAG.at or clock() - BAG.at > 4 then pcall(readBag) end
        local bitems = {}
        local g = BAG.groups
        if g then
            local function section(title, list, fn)
                if #list == 0 then return end
                bitems[#bitems + 1] = { main = title .. " (" .. #list .. ")", style = "head" }
                for i, r in ipairs(list) do
                    if i > 25 then
                        bitems[#bitems + 1] = { main = "… อีก " .. (#list - 25) .. " รายการ", style = "plain" }
                        break
                    end
                    bitems[#bitems + 1] = fn(r)
                end
            end
            section("แร่", g.ore, function(r)
                return { main = r.name, right = (r.exact and "×" or "") .. fmtNum(r.qty) .. (r.exact and "" or " ชิ้น"), color = AMBER }
            end)
            section("คนงานในกระเป๋า", g.miner, function(r)
                local keep = r.fate == "keep"
                local bits = { (r.rarity and r.rarity ~= "Unknown") and r.rarity or "ไม่รู้แรร์" }
                if r.tier and r.tier > 0 then bits[#bits + 1] = "Tier " .. r.tier end
                bits[#bits + 1] = keep and ("เก็บไว้: " .. tostring(r.why)) or "จะถูกขายรอบหน้า"
                return { main = r.name .. (r.qty > 1 and (" ×" .. fmtNum(r.qty)) or ""), right = keep and "เก็บ" or "ขาย",
                         rightColor = keep and GREENT or AMBERT, sub = table.concat(bits, " · "), color = rarityColor(r.rarity) }
            end)
            section("อื่น ๆ", g.other, function(r)
                return { main = r.name, right = "×" .. fmtNum(r.qty), sub = (r.role ~= "" and r.role or nil), color = SUB }
            end)
        end
        bagCard.right.Text = BAG.at and ("อัปเดต " .. ago(BAG.at)) or ""
        local emptyBag = State.AutoSell and "ยังไม่มีข้อมูล — ระบบขายจะเปิดหน้าขายแล้วอ่านให้เอง (ทุก ~8 วิ)"
            or "ยังไม่มีข้อมูล — เปิด 'ขายของ' หรือเปิดหน้าขายในเกมเองหนึ่งครั้ง"
        if g and BAG.total == 0 then emptyBag = "กระเป๋าว่าง (หน้าขายไม่มีของ)" end
        yy = bagCard.set(bitems, yy + GAP, emptyBag)
        pi.CanvasSize = UDim2.fromOffset(0, yy + 16)
    end

    local function refreshSettings()
        for flag, sw in pairs(switches) do sw.set(State[flag]) end
        for k, t in pairs(timingVals) do t.lbl.Text = tostring(State[k]) .. t.row.unit end
        local okData = getPlrData() ~= nil
        infoData.Text = "ข้อมูลเกม: " .. (okData and "อ่านได้" or "อ่านไม่ได้") .. " · ผิดพลาดสะสม " .. Act.n.errors .. " ครั้ง"
        if not State.Running then bStop.Text = "หยุดแล้ว — รันสคริปต์ใหม่เพื่อเริ่ม"
        elseif clock() - stopArm > 4 and bStop.Text ~= "หยุดฟาร์มทั้งหมด" then bStop.Text = "หยุดฟาร์มทั้งหมด" end
    end

    local invTick = 0
    function Dash.refresh(force)
        local on, money = 0, nil
        local ok, a, b = pcall(refreshTop)
        if ok then on, money = a, b end
        if money and not SESSION.money0 then SESSION.money0 = money end
        pcall(function()   -- จดการย้ายโซน
            local cur = zoneInfo()
            if cur then
                if SESSION.zone and cur ~= SESSION.zone then
                    Act.n.zones = Act.n.zones + 1
                    logEvent("ย้ายไปโซน Z" .. tostring(cur))
                end
                SESSION.zone = cur
            end
        end)
        if Dash.mode ~= "full" then return end
        if Dash.tab == "overview" then
            pcall(refreshOverview, on, money)
        elseif Dash.tab == "inv" then
            invTick = invTick + 1
            if force or invTick % 2 == 1 then pcall(refreshInventory, force) end
        else
            pcall(refreshSettings)
        end
    end

    Dash.setTab("overview")
    Dash.setMode("full")
end

local okDash, dashErr = pcall(buildDashboard)
if not okDash then
    warn("[MAM] สร้างแดชบอร์ดไม่สำเร็จ (ฟาร์มยังทำงานปกติ): " .. tostring(dashErr))
    Dash.alive = false
else
    task.spawn(function()
        while Dash.alive do
            if Dash.refresh then pcall(Dash.refresh, false) end
            task.wait(1)
        end
    end)
end

_G.MyAnimeMineGodFarm = {
    Version = SCRIPT_VERSION,
    State = State,
    Activity = Act,
    EquipBest = executeEquipBest,
    EquipPickaxes = executeAutoEquipBestPickaxes,
    BuyPickaxes = executeAutoBuyPickaxes,
    SkillTree = executeResearch,
    ResearchPlan = function() return researchPlan(true) end,
    -- เปลี่ยนตัวซื้อวิจัย (ค่าเริ่มต้น = กดผ่านหน้าสกิล): fn(zoneKey, family, nodeId, pipIndex, cost) คืน false,เหตุผล = ไม่ได้กด
    SetSkillBuyer = function(fn) Research.buyer = (type(fn) == "function") and fn or nil end,
    ZoneUnlock = executeAutoZoneUnlock,
    GetBaseDamage = getCharacterBaseDamage,
    GetBenchmark = getEquippedBenchmark,
    Diag = diagRun,
    Stop = stopFarm,
    Dash = {
        Show = function() if Dash.setMode then Dash.setMode("full") end end,
        Hide = function() if Dash.setMode then Dash.setMode("hidden") end end,
        Tab = function(name) if Dash.setTab then Dash.setTab(name) end end,
        Refresh = function() if Dash.refresh then pcall(Dash.refresh, true) end end,
    },
    Cleanup = function()
        stopFarm()
        Dash.alive = false
        for _, c in ipairs(Dash.conns or {}) do pcall(function() c:Disconnect() end) end
        if Dash.gui then pcall(function() Dash.gui:Destroy() end) end
    end
}
