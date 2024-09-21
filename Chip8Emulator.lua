local emulator = {}

local display = require(script.Parent.Display)
local uis = game:GetService("UserInputService")

local dumped = false

function memzero(size)
	local t = {}
	for i = 0, size - 1 do
		t[i] = 0x0
	end
	return t
end

local opdump = {}

local memory = memzero(4096)
local registers = memzero(16)
local index = 0x0
local programcounter = 0x0
local stack = memzero(16)
local stackpointer = 0x0
local delaytimer = 0x0
local soundtimer = 0x0
local keypad = memzero(16)
local videobuffer = memzero(64 * 32)
local opcode = 0x0

local startaddress = 0x200

local fontsetstartaddress = 0x50
local fontset =
	{
		0xF0, 0x90, 0x90, 0x90, 0xF0,
		0x20, 0x60, 0x20, 0x20, 0x70,
		0xF0, 0x10, 0xF0, 0x80, 0xF0,
		0xF0, 0x10, 0xF0, 0x10, 0xF0,
		0x90, 0x90, 0xF0, 0x10, 0x10,
		0xF0, 0x80, 0xF0, 0x10, 0xF0,
		0xF0, 0x80, 0xF0, 0x90, 0xF0,
		0xF0, 0x10, 0x20, 0x40, 0x40,
		0xF0, 0x90, 0xF0, 0x90, 0xF0,
		0xF0, 0x90, 0xF0, 0x10, 0xF0,
		0xF0, 0x90, 0xF0, 0x90, 0x90,
		0xE0, 0x90, 0xE0, 0x90, 0xE0,
		0xF0, 0x80, 0x80, 0x80, 0xF0,
		0xE0, 0x90, 0x90, 0x90, 0xE0,
		0xF0, 0x80, 0xF0, 0x80, 0xF0,
		0xF0, 0x80, 0xF0, 0x80, 0x80
	}

function OP_00E0()
	videobuffer = memzero(64 * 32)
end

function OP_00EE()
	stackpointer -= 1
	if stackpointer < 0 then
		stackpointer = 255
	end
	programcounter = stack[stackpointer]
end

function OP_1nnn()
	local address = bit32.band(opcode, 0x0FFF)
	programcounter = address
end

function OP_2nnn()
	local address = bit32.band(opcode, 0x0FFF)
	stack[stackpointer] = programcounter
	stackpointer = (stackpointer + 1) % 256
	programcounter = address
end
	
function OP_3xkk()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)
	local byte = bit32.band(opcode, 0x00FF)

	if registers[Vx] == byte then
		programcounter += 2
	end
end

function OP_4xkk()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)
	local byte = bit32.band(opcode, 0x00FF)

	if registers[Vx] ~= byte then
		programcounter += 2
	end
end

function OP_5xy0()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)
	local Vy = bit32.rshift(bit32.band(opcode, 0x00F0), 4)

	if registers[Vx] == registers[Vy] then
		programcounter += 2
	end
end	

function OP_6xkk()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)
	local byte = bit32.band(opcode, 0x00FF)

	registers[Vx] = byte
end

function OP_7xkk()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)
	local byte = bit32.band(opcode, 0x00FF)
	
	registers[Vx] = bit32.band((registers[Vx] + byte), 0xFF)
end

function OP_8xy0()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)
	local Vy = bit32.rshift(bit32.band(opcode, 0x00F0), 4)
	
	registers[Vx] = registers[Vy]
end

function OP_8xy1()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)
	local Vy = bit32.rshift(bit32.band(opcode, 0x00F0), 4)
	
	registers[Vx] = bit32.bor(registers[Vx], registers[Vy])
end

function OP_8xy2()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)
	local Vy = bit32.rshift(bit32.band(opcode, 0x00F0), 4)

	registers[Vx] = bit32.band(registers[Vx], registers[Vy])
end

function OP_8xy3()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)
	local Vy = bit32.rshift(bit32.band(opcode, 0x00F0), 4)
	
	registers[Vx] = bit32.bxor(registers[Vx], registers[Vy])
end

function OP_8xy4()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)
	local Vy = bit32.rshift(bit32.band(opcode, 0x00F0), 4)

	local sum = registers[Vx] + registers[Vy]
	
	registers[Vx] = bit32.band(sum, 0xFF)

	if (sum > 255) then
		registers[0xF] = 1
	else
		registers[0xF] = 0
	end
end

function OP_8xy5()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)
	local Vy = bit32.rshift(bit32.band(opcode, 0x00F0), 4)

	local comp = registers[Vx] >= registers[Vy]

	registers[Vx] = bit32.band(registers[Vx] - registers[Vy], 0xFF)

	if comp then
		registers[0xF] = 1
	else
		registers[0xF] = 0
	end
end

function OP_8xy6()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)
	
	local temp = registers[Vx]
	
	registers[Vx] = bit32.rshift(registers[Vx], 1)
	
	registers[0xF] = bit32.band(temp, 0x1)
end

function OP_8xy7()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)
	local Vy = bit32.rshift(bit32.band(opcode, 0x00F0), 4)

	local comp = registers[Vy] >= registers[Vx]
	
	registers[Vx] = bit32.band(registers[Vy] - registers[Vx], 0xFF)
	
	if comp then
		registers[0xF] = 1
	else
		registers[0xF] = 0
	end
end

function OP_8xyE()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)
	
	local temp = registers[Vx]
	
	registers[Vx] = bit32.band(bit32.lshift(registers[Vx], 1), 0xFF)
	
	registers[0xF] = bit32.rshift(bit32.band(temp, 0x80), 7)
end

function OP_9xy0()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)
	local Vy = bit32.rshift(bit32.band(opcode, 0x00F0), 4)

	if registers[Vx] ~= registers[Vy] then
		programcounter += 2
	end
end

function OP_Annn()
	local address = bit32.band(opcode, 0x0FFF)
	index = address
end

function OP_Bnnn()
	local address = bit32.band(opcode, 0x0FFF)
	programcounter = registers[0] + address
end

function OP_Cxkk()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)
	local byte = bit32.band(opcode, 0x00FF)

	registers[Vx] = bit32.band(math.random(1, 255), byte)
end

function OP_Dxyn()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)
	local Vy = bit32.rshift(bit32.band(opcode, 0x00F0), 4)
	local height = bit32.band(opcode, 0x000F)

	local xPos = registers[Vx] % 64
	local yPos = registers[Vy] % 32

	registers[0xF] = 0

	for row = 0, height - 1 do
		local spriteByte = memory[index + row]

		for col = 0, 7 do
			local spritePixel = bit32.band(spriteByte, bit32.rshift(0x80, col))

			if spritePixel ~= 0 then
				if videobuffer[(yPos + row) * 64 + (xPos + col)] == 0xFFFFFFFF then
					registers[0xF] = 1
				end
				videobuffer[(yPos + row) * 64 + (xPos + col)] = bit32.bxor(videobuffer[(yPos + row) * 64 + (xPos + col)], 0xFFFFFFFF)
			end
		end
	end
end

function OP_Ex9E()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)
	local key = registers[Vx]
	
	if keypad[key] ~= 0 then
		programcounter += 2
	end
end

function OP_ExA1()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)
	local key = registers[Vx]
	
	if keypad[key] == 0 then
		programcounter += 2
	end
end

function OP_Fx07()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)
	
	registers[Vx] = delaytimer
end

function OP_Fx0A()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)

	if (keypad[0] ~= 0) then
		registers[Vx] = 0
	elseif (keypad[1] ~= 0) then
		registers[Vx] = 1
	elseif (keypad[2] ~= 0) then
		registers[Vx] = 2
	elseif (keypad[3] ~= 0) then
		registers[Vx] = 3
	elseif (keypad[4] ~= 0) then
		registers[Vx] = 4
	elseif (keypad[5] ~= 0) then
		registers[Vx] = 5
	elseif (keypad[6] ~= 0) then
		registers[Vx] = 6
	elseif (keypad[7] ~= 0) then
		registers[Vx] = 7
	elseif (keypad[8] ~= 0) then
		registers[Vx] = 8
	elseif (keypad[9] ~= 0) then
		registers[Vx] = 9
	elseif (keypad[10] ~= 0) then
		registers[Vx] = 10
	elseif (keypad[11] ~= 0) then
		registers[Vx] = 11
	elseif (keypad[12] ~= 0) then
		registers[Vx] = 12
	elseif (keypad[13] ~= 0) then
		registers[Vx] = 13
	elseif (keypad[14] ~= 0) then
		registers[Vx] = 14
	elseif (keypad[15] ~= 0) then
		registers[Vx] = 15
	else
		programcounter -= 2
	end
end

function OP_Fx15()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)

	delaytimer = registers[Vx]
end

function OP_Fx18()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)

	soundtimer = registers[Vx]
end

function OP_Fx1E()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)
	
	index = index + registers[Vx]
end

function OP_Fx29()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)
	local digit = registers[Vx]

	index = fontsetstartaddress + (5 * digit)
end

function OP_Fx33()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)
	local value = registers[Vx]

	memory[index + 2] = value % 10
	value //= 10

	memory[index + 1] = value % 10
	value //= 10

	memory[index] = value % 10
end

function OP_Fx55()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)

	for i = 0, Vx do
		memory[index + i] = registers[i]
	end
end

function OP_Fx65()
	local Vx = bit32.rshift(bit32.band(opcode, 0x0F00), 8)

	for i = 0, Vx do
		registers[i] = memory[index + i]
	end
end

function table0(operationcode)
	local realopcode = bit32.band(operationcode, 0x000F)
	local stropcode = string.format("0x%X", realopcode)
	
	table.insert(opdump, registers[0])
	table.insert(opdump, memory[1182])
	table.insert(opdump, stropcode .. " t0")
	
	--print(stropcode, "t0")
	
	if stropcode == "0x0" then
		OP_00E0()
	elseif stropcode == "0xE" then
		OP_00EE()
	end
end

function table8(operationcode)
	local realopcode = bit32.band(operationcode, 0x000F)
	local stropcode = string.format("0x%X", realopcode)

	--print(stropcode, "t8")
	
	table.insert(opdump, registers[0])
	table.insert(opdump, memory[1182])
	table.insert(opdump, stropcode .. " t8")

	if stropcode == "0x0" then
		OP_8xy0()
	elseif stropcode == "0x1" then
		OP_8xy1()
	elseif stropcode == "0x2" then
		OP_8xy2()
	elseif stropcode == "0x3" then
		OP_8xy3()
	elseif stropcode == "0x4" then
		OP_8xy4()
	elseif stropcode == "0x5" then
		OP_8xy5()
	elseif stropcode == "0x6" then
		OP_8xy6()
	elseif stropcode == "0x7" then
		OP_8xy7()
	elseif stropcode == "0xE" then
		OP_8xyE()
	end
end

function tableE(operationcode)
	local realopcode = bit32.band(operationcode, 0x000F)
	local stropcode = string.format("0x%X", realopcode)

	--print(stropcode, "tE")
	
	table.insert(opdump, registers[0])
	table.insert(opdump, memory[1182])
	table.insert(opdump, stropcode .. " tE")

	if stropcode == "0x1" then
		OP_ExA1()
	elseif stropcode == "0xE" then
		OP_Ex9E()
	end
end

function tableF(operationcode)
	local realopcode = bit32.band(operationcode, 0x00FF)
	local stropcode = string.format("0x%X", realopcode)
	
	--print(stropcode, "tF")
	
	table.insert(opdump, registers[0])
	table.insert(opdump, memory[1182])
	table.insert(opdump, stropcode .. " tF")
	
	if stropcode == "0x07" then
		OP_Fx07()
	elseif stropcode == "0x0A" then
		OP_Fx0A()
	elseif stropcode == "0x15" then
		OP_Fx15()
	elseif stropcode == "0x18" then
		OP_Fx18()
	elseif stropcode == "0x1E" then
		OP_Fx1E()
	elseif stropcode == "0x29" then
		OP_Fx29()
	elseif stropcode == "0x33" then
		OP_Fx33()
	elseif stropcode == "0x55" then
		OP_Fx55()
	elseif stropcode == "0x65" then
		OP_Fx65()
	end
end

function cycle()
	opcode = bit32.bor(bit32.lshift(memory[programcounter], 8), memory[programcounter + 1])
	local realopcode = bit32.rshift(bit32.band(opcode, 0xF000), 12)
	local stropcode = string.format("0x%X", realopcode)

	programcounter += 2
	
	table.insert(opdump, registers[0])
	table.insert(opdump, memory[1182])
	table.insert(opdump, stropcode)
	
	if stropcode == "0x0" then
		table0(opcode)
	elseif stropcode == "0x1" then
		OP_1nnn()
	elseif stropcode == "0x2" then
		OP_2nnn()
	elseif stropcode == "0x3" then
		OP_3xkk()
	elseif stropcode == "0x4" then
		OP_4xkk()
	elseif stropcode == "0x5" then
		OP_5xy0()
	elseif stropcode == "0x6" then
		OP_6xkk()
	elseif stropcode == "0x7" then
		OP_7xkk()
	elseif stropcode == "0x8" then
		table8(opcode)
	elseif stropcode == "0x9" then
		OP_9xy0()
	elseif stropcode == "0xA" then
		OP_Annn()
	elseif stropcode == "0xB" then
		OP_Bnnn()
	elseif stropcode == "0xC" then
		OP_Cxkk()
	elseif stropcode == "0xD" then
		OP_Dxyn()
	elseif stropcode == "0xE" then
		tableE(opcode)
	elseif stropcode == "0xF" then
		tableF(opcode)
	end

	if (delaytimer > 0) then
		delaytimer -= 1
	end

	if (soundtimer > 0) then
		soundtimer -= 1
	end
end

function processinput()
	local quit = false
	
	if uis:IsKeyDown(Enum.KeyCode.RightShift) then
		if not dumped then
			print(opdump)
			dumped = true
		end
		quit = true
	end
	
	if uis:IsKeyDown(Enum.KeyCode.Escape) then
		quit = true
	end
	
	if not uis:IsKeyDown(Enum.KeyCode.X) then
		keypad[0] = 0
	end
	if not uis:IsKeyDown(Enum.KeyCode.One) then
		keypad[1] = 0
	end
	if not uis:IsKeyDown(Enum.KeyCode.Two) then
		keypad[2] = 0
	end
	if not uis:IsKeyDown(Enum.KeyCode.Three) then
		keypad[3] = 0
	end
	if not uis:IsKeyDown(Enum.KeyCode.Q) then
		keypad[4] = 0
	end
	if not uis:IsKeyDown(Enum.KeyCode.W) then
		keypad[5] = 0
	end
	if not uis:IsKeyDown(Enum.KeyCode.E) then
		keypad[6] = 0
	end
	if not uis:IsKeyDown(Enum.KeyCode.A) then
		keypad[7] = 0
	end
	if not uis:IsKeyDown(Enum.KeyCode.S) then
		keypad[8] = 0
	end
	if not uis:IsKeyDown(Enum.KeyCode.D) then
		keypad[9] = 0
	end
	if not uis:IsKeyDown(Enum.KeyCode.Z) then
		keypad[10] = 0
	end
	if not uis:IsKeyDown(Enum.KeyCode.C) then
		keypad[11] = 0
	end
	if not uis:IsKeyDown(Enum.KeyCode.Four) then
		keypad[12] = 0
	end
	if not uis:IsKeyDown(Enum.KeyCode.R) then
		keypad[13] = 0
	end
	if not uis:IsKeyDown(Enum.KeyCode.F) then
		keypad[14] = 0
	end
	if not uis:IsKeyDown(Enum.KeyCode.V) then
		keypad[15] = 0
	end
	
	if uis:IsKeyDown(Enum.KeyCode.X) then
		keypad[0] = 1
	end
	if uis:IsKeyDown(Enum.KeyCode.One) then
		keypad[1] = 1
	end
	if uis:IsKeyDown(Enum.KeyCode.Two) then
		keypad[2] = 1
	end
	if uis:IsKeyDown(Enum.KeyCode.Three) then
		keypad[3] = 1
	end
	if uis:IsKeyDown(Enum.KeyCode.Q) then
		keypad[4] = 1
	end
	if uis:IsKeyDown(Enum.KeyCode.W) then
		keypad[5] = 1
	end
	if uis:IsKeyDown(Enum.KeyCode.E) then
		keypad[6] = 1
	end
	if uis:IsKeyDown(Enum.KeyCode.A) then
		keypad[7] = 0
	end
	if uis:IsKeyDown(Enum.KeyCode.S) then
		keypad[8] = 1
	end
	if uis:IsKeyDown(Enum.KeyCode.D) then
		keypad[9] = 1
	end
	if uis:IsKeyDown(Enum.KeyCode.Z) then
		keypad[10] = 1
	end
	if uis:IsKeyDown(Enum.KeyCode.C) then
		keypad[11] = 1
	end
	if uis:IsKeyDown(Enum.KeyCode.Four) then
		keypad[12] = 1
	end
	if uis:IsKeyDown(Enum.KeyCode.R) then
		keypad[13] = 1
	end
	if uis:IsKeyDown(Enum.KeyCode.F) then
		keypad[14] = 1
	end
	if uis:IsKeyDown(Enum.KeyCode.V) then
		keypad[15] = 1
	end
	
	return quit
end

function updatevideo()
	for i = 0, 64 * 32 - 1 do
		if videobuffer[i] ~= 0 then
			display.lightpixel(i%64+1, i//64+1)
		else
			display.shutpixel(i%64+1, i//64+1)
		end
	end
end

function emulator.run(cdl, ips)
	programcounter = startaddress
	
	for i = 1, #fontset do
		memory[fontsetstartaddress + i - 1] = fontset[i]
	end
	
	local cycleDelay = cdl

	local lastCycleTime = os.time()
	local quit = false

	while not quit do
		task.wait()
		for i = 1, ips do
			quit = processinput()

			local currentTime = os.time()
			local dt = currentTime - lastCycleTime

			if (dt >= cycleDelay) then
				lastCycleTime = currentTime
				cycle()
				updatevideo(videobuffer)
			end
		end
	end
end

function emulator.loadrom(rom)
	local rom = string.split(rom, " ")
	for i = startaddress, #rom + startaddress - 1 do
		memory[i] = tonumber(rom[i - startaddress + 1], 16)
	end
end

return emulator
