-- MspQueueController class
local MspQueueController = {}
MspQueueController.__index = MspQueueController


function MspQueueController.new()
        local self = setmetatable({}, MspQueueController)
        self.messageQueue = {}
        self.currentMessage = nil
        self.lastTimeCommandSent = nil
        self.retryCount = 0
        self.maxRetries = 3
        return self
end

function MspQueueController:isProcessed()
        return not self.currentMessage and #self.messageQueue == 0
end

local function popFirstElement(tbl)
        return table.remove(tbl, 1)
end

function MspQueueController:processQueue()
        if self:isProcessed() then
                ELRS_PAUSE_TELEMETRY = false
                CRSF_PAUSE_TELEMETRY = false
                rfsuite.app.triggers.mspBusy = false
                return
        end
        ELRS_PAUSE_TELEMETRY = true
        CRSF_PAUSE_TELEMETRY = true
        rfsuite.app.triggers.mspBusy = true

        if not self.currentMessage then
                self.currentMessage = popFirstElement(self.messageQueue)
                self.retryCount = 0
        end

        local cmd, buf, err

        local lastTimeInterval

        if rfsuite.bg.msp.protocol.mspIntervalOveride ~= nil then
                lastTimeInterval = rfsuite.bg.msp.protocol.mspIntervalOveride
        else
                lastTimeInterval = 1
        end

        if not system:getVersion().simulation == true then
                if not self.lastTimeCommandSent or self.lastTimeCommandSent + lastTimeInterval < os.clock() then
                        if self.currentMessage.payload then
                                --rfsuite.utils.log("Sending  cmd "..self.currentMessage.command..": {" .. rfsuite.utils.joinTableItems(self.currentMessage.payload, ", ") .. "}")
                                rfsuite.bg.msp.protocol.mspWrite(self.currentMessage.command, self.currentMessage.payload)
                        else
                                --rfsuite.utils.log("Sending  cmd "..self.currentMessage.command)
                                rfsuite.bg.msp.protocol.mspWrite(self.currentMessage.command, {})
                        end
                        self.lastTimeCommandSent = os.clock()
                        self.retryCount = self.retryCount + 1

                        if rfsuite.app.Page ~= nil then if rfsuite.app.Page.mspRetry then rfsuite.app.Page.mspRetry(self) end end

                end

                mspProcessTxQ()
                cmd, buf, err = mspPollReply()
        else
                if not self.currentMessage.simulatorResponse then
                        rfsuite.utils.log("No simulator response for command " .. tostring(self.currentMessage.command))
                        self.currentMessage = nil
                        return
                end
                cmd = self.currentMessage.command
                buf = self.currentMessage.simulatorResponse
                err = nil
        end

        if cmd then
        
                self.lastTimeCommandSent = nil
                
                if rfsuite.config.mspTxRxDebug == true or rfsuite.config.logEnable == true then
                        local logData = "Requesting:  {" .. tostring(cmd) .. "}"

                        rfsuite.utils.log(logData)

                        if rfsuite.config.mspTxRxDebug == true then print(logData) end

                end

        end

        if (cmd == self.currentMessage.command and not err) or (self.currentMessage.command == 68 and self.retryCount == 2) -- 68 = MSP_REBOOT
        or (self.currentMessage.command == 217 and err and self.retryCount == 2) -- ESC
        then

                if rfsuite.config.mspTxRxDebug == true or rfsuite.config.logEnable == true then
                        local logData = "Received:          {" .. rfsuite.utils.joinTableItems(buf, ", ") .. "}"
                        rfsuite.utils.log(logData)

                        if rfsuite.config.mspTxRxDebug == true then if #buf > 0 then print(logData) end end

                end

                if self.currentMessage.processReply then self.currentMessage:processReply(buf) end
                self.currentMessage = nil
                --collectgarbage()

                if rfsuite.app.Page ~= nil then if rfsuite.app.Page.mspSuccess then rfsuite.app.Page.mspSuccess() end end

        elseif (self.retryCount ~= nil and self.maxRetries ~= nil) and self.retryCount > self.maxRetries then
                -- rfsuite.utils.log("Max retries reached, aborting queue")
                self.messageQueue = {}
                if self.currentMessage.errorHandler then self.currentMessage:errorHandler() end
                self:clear()
                --collectgarbage()

                if rfsuite.app.Page ~= nil then if rfsuite.app.Page.mspTimeout then rfsuite.app.Page.mspTimeout() end end

        end
end

function MspQueueController:clear()
        self.messageQueue = {}
        self.currentMessage = nil
        mspClearTxBuf()
end

local function deepCopy(original)
        local copy
        if type(original) == "table" then
                copy = {}
                for key, value in next, original, nil do copy[deepCopy(key)] = deepCopy(value) end
                setmetatable(copy, deepCopy(getmetatable(original)))
        else -- number, string, boolean, etc
                copy = original
        end
        return copy
end

function MspQueueController:add(message)

        if message ~= nil then
                message = deepCopy(message)

                if rfsuite.config.mspTxRxDebug == true or rfsuite.config.logEnable == true then
                        local logData = "Queueing command " .. message.command .. " at position " .. #self.messageQueue + 1
                        rfsuite.utils.log(logData)

                        if rfsuite.config.mspTxRxDebug == true then print(logData) end

                end

                self.messageQueue[#self.messageQueue + 1] = message
                return self
        else
                rfsuite.utils.log("Unable to queue - nil message.  Check function is callable")
                -- this can go wrong if the function is declared below save function!!!
        end
end

return MspQueueController.new()

--[[ Usage example

local myMspMessage =
{
        command = 111,
        processReply = function(self, buf)
                --rfsuite.utils.log("Do something with the response buffer")
        end,
        simulatorResponse = { 1, 2, 3, 4 }
}

local anotherMspMessage =
{
        command = 123,
        processReply = function(self, buf)
                --rfsuite.utils.log("Received response for command "..tostring(self.command).." with length "..tostring(#buf))
        end,
        simulatorResponse = { 254, 128 }
}

local myMspQueue = MspQueueController.new()
myMspQueue
  :add(myMspMessage)
  :add(anotherMspMessage)

while not myMspQueue:isProcessed() do
        myMspQueue:processQueue()
end
--]]
