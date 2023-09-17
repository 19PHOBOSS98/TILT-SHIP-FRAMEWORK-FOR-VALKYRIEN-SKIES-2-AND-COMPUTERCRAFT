local DRONE_DESIGNATION = 506
local group_designation = "STERN"

local DEBUG_TO_DRONE_CHANNEL = 9
local DRONE_TO_COMPONENT_BROADCAST_CHANNEL = 506
local modem = peripheral.find("modem")

modem.open(DRONE_TO_COMPONENT_BROADCAST_CHANNEL)
modem.open(DEBUG_TO_DRONE_CHANNEL)

local group_component_map = 
{
	BOW = 
		{
		"front",--ZF
		"top",--ZCCT
		"bottom",--ZCCB
		"left",--ZCL
		"right"--ZCR
		}
	,
	STERN = 
		{
		"back",--ZB
		"top",--ZCCT
		"bottom",--ZCCB
		"left",--ZCL
		"right"--ZCR
		}
}

local designated_group_component = group_component_map[group_designation]

local c1 = designated_group_component[1]
local c2 = designated_group_component[2]
local c3 = designated_group_component[3]
local c4 = designated_group_component[4]
local c5 = designated_group_component[5]

function applyRedStonePower(component_values)
	
	redstone.setAnalogOutput(designated_group_component[1], component_values[1])
	
	redstone.setAnalogOutput(designated_group_component[2], component_values[2])

	redstone.setAnalogOutput(designated_group_component[3], component_values[3])
	
	redstone.setAnalogOutput(designated_group_component[4], component_values[4])
	
	redstone.setAnalogOutput(designated_group_component[5], component_values[5])
	
	print("ZF/ZB: "..designated_group_component[1].." RS: "..component_values[1])
	print("ZCCT: "..designated_group_component[2].." RS: "..component_values[2])
	print("ZCCB: "..designated_group_component[3].." RS: "..component_values[3])
	print("ZCL: "..designated_group_component[4].." RS: "..component_values[4])
	print("ZCR: "..designated_group_component[5].." RS: "..component_values[5])

end

function resetAllRSI()
	applyRedStonePower({0,0,0,0,0})
end

function receiveCommand()
	while true do
		term.clear()
		term.setCursorPos(1,1)
		local event, modemSide, senderChannel, replyChannel, message, senderDistance = os.pullEvent("modem_message")
		if (senderChannel==DRONE_TO_COMPONENT_BROADCAST_CHANNEL or senderChannel==DEBUG_TO_DRONE_CHANNEL) then
			if (message) then
				if(message.drone_designation==DRONE_DESIGNATION) then
					if message.cmd == "move" then
						--print(textutils.serialize(message))
						applyRedStonePower(message[group_designation])
					elseif message.cmd == "reset" then
						resetAllRSI()
					elseif message.cmd == "hush" then
						resetAllRSI()
						break
					end
				end
			end

		end
	end
end


resetAllRSI()
receiveCommand()