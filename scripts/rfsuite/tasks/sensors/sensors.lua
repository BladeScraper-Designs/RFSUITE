--
local arg = {...}
local config = arg[1]
local compile = arg[2]


local sensors = {}

sensors.elrs = assert(compile.loadScript(config.suiteDir .. "tasks/sensors/elrs.lua"))(config,compile)
sensors.sport = assert(compile.loadScript(config.suiteDir .. "tasks/sensors/sport.lua"))(config,compile)

function sensors.wakeup()

        -- we cant do anything if bg task not running
        if not rfsuite.bg.active() then 
                return
        end
        
        -- quick kill if not using crsf as this script
        -- is only for crsf code
        if rfsuite.rssiSensor == nil then
                sensors.sport.sensors = {}
        else        
        
                if rfsuite.bg.msp.protocol.mspProtocol == "crsf" and rfsuite.rssiSensor then
                        sensors.elrs.wakeup()
                end

                if rfsuite.bg.msp.protocol.mspProtocol == "smartPort" and rfsuite.rssiSensor  then
                        sensors.sport.wakeup()
                end        
        end
       
end


return sensors