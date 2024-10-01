compile = {}

local arg = {...}
local config = arg[1]
local suiteDir = config.suiteDir

local readConfig
local switchParam
local pref
local spref
local s

function compile.initialise()

end

local function file_exists(name)
        local f = io.open(name, "r")
        if f ~= nil then
                io.close(f)
                return true
        else
                return false
        end
end

local function baseName()
        local baseName
        baseName = config.suiteDir:gsub("/scripts/", "")
        baseName = baseName:gsub("/", "")
        return baseName
end


local INI = assert(loadfile(config.suiteDir .. "lib/lip.lua"))(config)        
local preferences = INI.load(config.suiteDir .. "preferences.ini");

-- explode a string
local function explode(inputstr, sep)
        if sep == nil then sep = "%s" end
        local t = {}
        for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do table.insert(t, str) end
        return t
end

function compile.loadScript(script)

        -- we need to add code to stop this reading every time function runs
        local cachefile
        cachefile = suiteDir .. "compiled/" .. script:gsub("/", "_") .. "c"

        -- overrides
        if config.useCompiler == true then
                if file_exists("/scripts/" .. baseName() .. ".nocompile") == true then config.useCompiler = false end

                if file_exists("/scripts/nocompile") == true then config.useCompiler = false end
        end

        if config.useCompiler == true then
                if file_exists(cachefile) ~= true then
                        system.compile(script)

                        os.rename(script .. 'c', cachefile)
                        
                        -- if not compiled - we compile; but return non compiled to sort timing issue.
                         print("Loading: " .. cachefile)
                        return assert(loadfile(cachefile))
                end
                -- print("Loading: " .. cachefile)
                return assert(loadfile(cachefile))
        else
                if file_exists(cachefile) == true then 
                        os.remove(cachefile) 
                end
                -- print("Loading: " .. script)              
                return assert(loadfile(script))
        end

end

return compile
