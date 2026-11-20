--!strict
-- One ScreenGui showing the round phase and seconds left, read from ReplicatedStorage attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hud = {}

local function text(): string
	local phase = ReplicatedStorage:GetAttribute("RoundPhase")
	local timeLeft = ReplicatedStorage:GetAttribute("RoundTimeLeft")
	if type(phase) ~= "string" then
		return ""
	elseif phase == "Lobby" then
		return "Lobby — waiting for players"
	end
	return `{phase} · {if type(timeLeft) == "number" then timeLeft else 0}s`
end

function Hud.start(): ()
	local gui = Instance.new("ScreenGui")
	gui.Name = "KitHud"
	gui.ResetOnSpawn = false

	local label = Instance.new("TextLabel")
	label.Name = "Round"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 12)
	label.Size = UDim2.fromOffset(320, 44)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	label.BackgroundTransparency = 0.3
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 22
	label.Parent = gui

	local function render()
		label.Text = text()
		label.Visible = label.Text ~= ""
	end
	ReplicatedStorage:GetAttributeChangedSignal("RoundPhase"):Connect(render)
	ReplicatedStorage:GetAttributeChangedSignal("RoundTimeLeft"):Connect(render)
	render()

	local player = Players.LocalPlayer
	gui.Parent = player:WaitForChild("PlayerGui")
end

return Hud
