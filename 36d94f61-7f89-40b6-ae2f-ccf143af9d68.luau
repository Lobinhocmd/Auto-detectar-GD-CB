-- Serviços
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

-- Tabela para guardar conexões e ESPs
local conectados = {}
local espAtivos = {}

-- Função segura pra pegar HRP
local function getRoot(char)
	return char and char:FindFirstChild("HumanoidRootPart")
end

-- Remove ESP de um jogador
local function removerESP(player)
	if player.Character then
		if player.Character:FindFirstChild("ESPBox") then
			player.Character.ESPBox:Destroy()
		end
		if player.Character:FindFirstChild("ESPLabel") then
			player.Character.ESPLabel:Destroy()
		end
	end
end

-- ESP personalizado
local function ESP(player)
	if player == LocalPlayer then return end
	if not player.Character or not getRoot(player.Character) then return end

	removerESP(player)

	local box = Instance.new("BoxHandleAdornment")
	box.Name = "ESPBox"
	box.Adornee = player.Character
	box.AlwaysOnTop = true
	box.ZIndex = 10
	box.Size = Vector3.new(4, 6, 2)
	box.Color3 = Color3.fromRGB(0, 255, 0)
	box.Transparency = 0.5
	box.Parent = player.Character

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ESPLabel"
	billboard.Size = UDim2.new(0, 100, 0, 30)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.Adornee = player.Character:FindFirstChild("Head") or getRoot(player.Character)
	billboard.AlwaysOnTop = true
	billboard.Parent = player.Character

	local text = Instance.new("TextLabel", billboard)
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextStrokeTransparency = 0
	text.Font = Enum.Font.SourceSansBold
	text.TextScaled = true

	local conn = RunService.RenderStepped:Connect(function()
		if player.Character and player.Character:FindFirstChild("Humanoid") and getRoot(player.Character) then
			local hp = math.floor(player.Character.Humanoid.Health)
			local dist = math.floor((getRoot(LocalPlayer.Character).Position - getRoot(player.Character).Position).Magnitude)
			text.Text = string.format("%s | %dHP | %dm", player.Name, hp, dist)
		end
	end)

	espAtivos[player] = conn
end

-- Detecta [GD] ou [Cb]
local function checarJogador(player)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		for _, nome in pairs({"Divisão", "Patente"}) do
			local dado = stats:FindFirstChild(nome)
			if dado and typeof(dado.Value) == "string" then
				if dado.Value:find("%[GD%]") or dado.Value:find("%[Cb%]") then
					ESP(player)
				end
			end
		end
	end
end

-- Monitoramento
local function monitorar(player)
	if player == LocalPlayer then return end

	-- Conexões
	table.insert(conectados, player.CharacterAdded:Connect(function()
		wait(1)
		checarJogador(player)
	end))

	table.insert(conectados, player.ChildAdded:Connect(function(child)
		if child.Name == "leaderstats" then
			child.ChildAdded:Connect(function(sub)
				if sub:IsA("StringValue") and (sub.Name == "Divisão" or sub.Name == "Patente") then
					table.insert(conectados, sub:GetPropertyChangedSignal("Value"):Connect(function()
						checarJogador(player)
					end))
					checarJogador(player)
				end
			end)
		end
	end))

	local stats = player:FindFirstChild("leaderstats")
	if stats then
		for _, sub in pairs(stats:GetChildren()) do
			if sub:IsA("StringValue") and (sub.Name == "Divisão" or sub.Name == "Patente") then
				table.insert(conectados, sub:GetPropertyChangedSignal("Value"):Connect(function()
					checarJogador(player)
				end))
				checarJogador(player)
			end
		end
	end
end

-- GUI (usando ScreenGui2 já existente no PlayerGui)
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("ScreenGui2") -- ScreenGui já criada no jogo

-- Frame principal
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 80)
frame.Position = UDim2.new(0.5, -100, 0.5, -40)
frame.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
frame.Active = true
frame.Draggable = true
frame.Parent = gui

-- Botão
local button = Instance.new("TextButton")
button.Size = UDim2.new(1, -20, 0, 50)
button.Position = UDim2.new(0, 10, 0, 15)
button.Text = "Detectar GD/Cb: OFF"
button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
button.TextColor3 = Color3.fromRGB(255, 255, 255)
button.Font = Enum.Font.SourceSansBold
button.TextSize = 14
button.Parent = frame

-- Marca "2.0" no rodapé
local marca = Instance.new("TextLabel")
marca.Size = UDim2.new(0, 100, 0, 30)
marca.Position = UDim2.new(0.5, -50, 1, -40) -- centralizado embaixo
marca.BackgroundTransparency = 1
marca.Text = "2.0"
marca.TextColor3 = Color3.fromRGB(255, 255, 255)
marca.Font = Enum.Font.SourceSansBold
marca.TextScaled = true
marca.Parent = gui

-- Controle
local ativo = false
local novaConexao

button.MouseButton1Click:Connect(function()
	ativo = not ativo
	button.Text = "Detectar GD/Cb: " .. (ativo and "ON" or "OFF")

	if ativo then
		StarterGui:SetCore("SendNotification", {
			Title = "Auto ESP",
			Text = "Detectando GD e Cb...",
			Duration = 3
		})

		for _, p in pairs(Players:GetPlayers()) do
			monitorar(p)
		end

		novaConexao = Players.PlayerAdded:Connect(monitorar)

	else
		StarterGui:SetCore("SendNotification", {
			Title = "Auto ESP",
			Text = "ESP desligado.",
			Duration = 3
		})

		-- Desconecta tudo
		for _, c in pairs(conectados) do
			if typeof(c) == "RBXScriptConnection" then
				pcall(function() c:Disconnect() end)
			end
		end
		conectados = {}

		if novaConexao then
			pcall(function() novaConexao:Disconnect() end)
		end

		-- Remove ESPs
		for plr, conn in pairs(espAtivos) do
			removerESP(plr)
			if typeof(conn) == "RBXScriptConnection" then
				pcall(function() conn:Disconnect() end)
			end
		end
		espAtivos = {}
	end
end)
