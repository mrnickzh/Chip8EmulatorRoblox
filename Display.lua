local display = {}

local player = game:GetService("Players").LocalPlayer
local pixels = {}

function display.init(w, h, size, xoffset, yoffset)
	local displaybase = Instance.new("ScreenGui", player.PlayerGui)
	for i = 1, w do
		table.insert(pixels, {})
		for j = 1, h do
			local pixel = Instance.new("Frame", player.PlayerGui.ScreenGui)
			pixel.Position = UDim2.new(0, i * size + xoffset, 0, j * size + yoffset)
			pixel.Size = UDim2.new(0, size, 0, size)
			pixel.BackgroundColor3 = Color3.new(0, 0, 0)
			pixel.BorderSizePixel = 0
			table.insert(pixels[i], pixel)
		end
	end
end

function display.lightpixel(x, y)
	pixels[x][y].BackgroundColor3 = Color3.new(1, 1, 1)
end

function display.shutpixel(x, y)
	pixels[x][y].BackgroundColor3 = Color3.new(0, 0, 0)
end

return display
