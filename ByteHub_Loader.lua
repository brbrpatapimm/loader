-- BYTEHUB LOADER
-- Check latest commit, download ByteHub_V72_Main.lua, then execute it.

local Env = _G
if type(getgenv) == "function" then
    local ok, value = pcall(getgenv)
    if ok and type(value) == "table" then Env = value end
end

local compiler = loadstring or Env.loadstring
assert(type(compiler) == "function",
    "[ByteHub] Executor tidak menyediakan loadstring.")

local repository = "brbrpatapimm/plerr"
local branch = "main"
local filename = "NewUI_Second_73.lua"

local httpService = game:GetService("HttpService")
local lastError = "respons kosong"

local function checked(source)
    if type(source) ~= "string" or source:match("^%s*$") then
        return nil, "respons kosong"
    end
    if source:match("^%s*<") then
        return nil, "Server mengirim HTML, bukan script Lua."
    end
    return source
end

local function requestList()
    local list, seen = {}, {}
    local function add(fn)
        if type(fn) == "function" and not seen[fn] then
            seen[fn] = true
            list[#list + 1] = fn
        end
    end
    add(Env.request)
    add(Env.http_request)
    add(Env.syn and Env.syn.request)
    add(Env.http and Env.http.request)
    return list
end

local function download(url)
    local err = "respons kosong"

    local ok, source = pcall(function()
        return game:HttpGet(url)
    end)
    if ok then
        local valid, reason = checked(source)
        if valid then return valid end
        err = reason
    else
        err = tostring(source)
    end

    for _, api in ipairs(requestList()) do
        local sent, response = pcall(api, {
            Url = url,
            Method = "GET",
        })

        if sent and type(response) == "table" then
            local status = tonumber(response.StatusCode or response.Status)
            if status and (status < 200 or status >= 300) then
                err = "HTTP " .. tostring(status)
            else
                local valid, reason = checked(response.Body or response.body)
                if valid then return valid end
                err = reason
            end
        else
            err = tostring(response)
        end
    end

    error("[ByteHub] Unduh gagal: " .. tostring(err), 0)
end

local function latestSource()
    local refUrl = "https://api.github.com/repos/"
        .. repository
        .. "/git/ref/heads/"
        .. branch
        .. "?update="
        .. httpService:GenerateGUID(false)

    local ref = httpService:JSONDecode(download(refUrl))
    local commit = type(ref) == "table"
        and type(ref.object) == "table"
        and ref.object.sha

    if type(commit) ~= "string"
        or #commit ~= 40
        or not commit:match("^%x+$") then
        local reason = type(ref) == "table" and ref.message or "Metadata tidak valid"
        error("[ByteHub] Gagal mengecek update: " .. tostring(reason), 0)
    end

    local rawUrl = "https://raw.githubusercontent.com/"
        .. repository
        .. "/"
        .. commit
        .. "/"
        .. filename

    return download(rawUrl), commit
end

if not game:IsLoaded() then
    game.Loaded:Wait()
end

for attempt = 1, 3 do
    local ok, source, commit = pcall(latestSource)

    if ok then
        local fn, compileError = compiler(source, "ByteHub_V72_Main")
        if not fn then
            error("[ByteHub] Gagal compile main script: " .. tostring(compileError), 0)
        end

        print("[ByteHub] Menjalankan main script commit " .. commit:sub(1, 8))
        local ran, result = xpcall(fn, function(err)
            if debug and type(debug.traceback) == "function" then
                return debug.traceback(tostring(err), 2)
            end
            return tostring(err)
        end)

        if not ran then
            error("[ByteHub] Runtime error main script:\n" .. tostring(result), 0)
        end

        return result
    end

    lastError = tostring(source)
    warn("[ByteHub] Percobaan " .. attempt .. " gagal: " .. lastError)
    if attempt < 3 then task.wait(1) end
end

error("[ByteHub] Gagal mengambil ByteHub_V72_Main.lua setelah 3 percobaan: "
    .. lastError, 0)
