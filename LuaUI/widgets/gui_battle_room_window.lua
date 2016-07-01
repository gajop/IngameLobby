--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name      = "Battle Room Window",
		desc      = "Battle Room Window handler.",
		author    = "GoogleFrog",
		date      = "30 June 2016",
		license   = "GNU LGPL, v2.1 or later",
		layer     = 0,
		enabled   = true  --  loaded by default?
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Local variables

-- Chili controls
local window

local lblDownload, prDownload

-- Listeners, needed here so they can be deregistered
local onBattleClosed
local onLeftBattle_counter
local onJoinedBattle
local onSaidBattle
local onSaidBattleEx
local onClientStatus
local updateUserBattleStatus
local onLeftBattle
local removeBot

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Helper functions

local function GenerateScriptTxt(battleID)
	local battle = lobby:GetBattle(battleID)
	local scriptTxt = 
[[
[GAME]
{
	HostIP=__IP__;
	HostPort=__PORT__;
	IsHost=0;
	MyPlayerName=__MY_PLAYER_NAME__;
	MyPasswd=__MY_PASSWD__;
}
]]

	scriptTxt = scriptTxt:gsub("__IP__", battle.ip)
						:gsub("__PORT__", battle.port)
						:gsub("__MY_PLAYER_NAME__", lobby:GetMyUserName())
						:gsub("__MY_PASSWD__", lobby:GetScriptPassword())
	return scriptTxt
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Chili/interface management

local largestTeamIndex = -1

local downloads = {}

local lastUpdate = 0
function widget:DownloadProgress(downloadID, downloaded, total)
	if Spring.GetGameSeconds() == lastUpdate or size == 0 then
		return
	end
	lastUpdate = Spring.GetGameSeconds()
-- 	Spring.Echo("done: " .. tostring(done) .. ", size: " .. tostring(size) .. ", progress: " .. (done/size) .. ", progress%: " .. (100 * done/size))
	prDownload:SetValue(100 * downloaded / total)
end

function widget:DownloadStarted(downloadID)
	if prDownload.hidden then
		prDownload:Show()
	end
	if lblDownload.hidden then
		lblDownload:Show()
	end
	lblDownload:SetCaption(downloads[downloadID].archiveName)
	Spring.Echo("DownloadStarted", downloadID)
end

function widget:DownloadFinished(...)
	prDownload:Hide()
	lblDownload:Hide()
	Spring.Echo("DownloadFinished", ...)
end

function widget:DownloadFailed(...)
	prDownload:Hide()
	lblDownload:Hide()
	Spring.Echo("DownloadFailed", ...)
end

function widget:DownloadQueued(downloadID, archiveName, archiveType)
	downloads[downloadID] = { archiveName = archiveName, archiveType = archiveType}
end

-- function widget:DownloadStarted(...)
-- 	self.lblDownload:SetCaption("Download started!")
-- end
-- 
-- function Downloader:DownloadFinished(...)
-- 	self.lblDownload:SetCaption("Download finished!")
-- end
-- 
-- function Downloader:DownloadFailed(x, errorID)
-- 	self.lblDownload:SetCaption("Download failed: " .. errorID)
-- end
-- 
-- lastUpdate = 0
-- function Downloader:DownloadProgress(ID, done, size)
-- 	Spring.Echo("Download progress!")
-- 	if Spring.GetGameSeconds() == lastUpdate or size == 0 then
-- 		return
-- 	end
-- 	lastUpdate = Spring.GetGameSeconds()
-- 	--self.lblDownload:SetCaption("Download progress!")
-- 	Spring.Echo("done: " .. tostring(done) .. ", size: " .. tostring(size) .. ", progress: " .. (done/size) .. ", progress%: " .. (100 * done/size))
-- 	self.prDownload:SetValue(100 * done / size)
-- end
-- 
-- function Downloader:DownloadQueued(...)
-- 	self.lblDownload:SetCaption("Download queued!")
-- end

local function MaybeDownloadArchive(archiveName, archiveType)
	if not VFS.HasArchive(archiveName) then
		VFS.DownloadArchive(archiveName, archiveType)
	end
end

local function MaybeDownloadGame(battle)
	MaybeDownloadArchive(battle.gameName, "game")
end

local function MaybeDownloadMap(battle)
	MaybeDownloadArchive(battle.mapName, "map")
end

local function SetupInfoButtonsPanel(parentControl, battle, battleID)

	local lblMapName = Label:New {
		x = 15,
		y = 9,
		font = { size = 14 },
		caption = battle.mapName,
		parent = parentControl,
	}
	
	local btnSpectate = Button:New {
		x = "50.5%",
		y = 25,
		height = 45,
		right = 10,
		caption = "\255\66\138\201" .. i18n("spectate") ..  "\b",
		font = { size = 22 },
		OnClick = {
			function()
				lobby:SetBattleStatus({IsSpectator = not lobby:GetMyIsSpectator()})
			end
		},
		parent = parentControl,
	}
	
	local btnPickMap = Button:New {
		x = 10,
		y = 25,
		height = 45,
		right = "50.5%",
		caption = "\255\66\138\201" .. i18n("pick_map") ..  "\b",
		font = { size = 22 },
		OnClick = {
			function()
				Spring.Echo("implement map selection")
			end
		},
		parent = parentControl,
	}
	
	local btnNewTeam = Button:New {
		x = 10,
		y = 65,
		height = 45,
		right = "50.5%",
		caption = "\255\66\138\201" .. i18n("new_team") ..  "\b",
		font = { size = 22 },
		OnClick = {
			function()
				lobby:SetBattleStatus({
					AllyNumber = largestTeamIndex + 1, 
					IsSpectator = false,
				})
			end
		},
		parent = parentControl,
	}
	
	local lblNumberOfPlayers = Label:New {
		x = 15,
		y = 175,
		width = 200,
		height = 30,
		caption = "",
		parent = parentControl,
	}
	
	local lblHaveGame = Label:New {
		x = 15,
		y = 195,
		caption = i18n("dont_have_game") .. " [" .. WG.Chobby.Configuration:GetErrorColor() .. "?\b]",
		parent = parentControl,
	}
	if VFS.HasArchive(battle.gameName) then
		lblHaveGame.caption = i18n("have_game") .. " [" .. WG.Chobby.Configuration:GetSuccessColor() .. "?\b]"
	end

	local lblHaveMap = Label:New {
		x = 15,
		y = 215,
		caption = i18n("dont_have_map") .. " [" .. WG.Chobby.Configuration:GetErrorColor() .. "?\b]",
		parent = parentControl,
	}
	if VFS.HasArchive(battle.mapName) then
		lblHaveMap.caption = i18n("have_map") .. " [" .. WG.Chobby.Configuration:GetSuccessColor() .. "?\b]"
	end

	lblDownload = Label:New {
		x = 15,
		y = 245,
		parent = parentControl,
		width = 100,
		height = 20,
		caption = "",
	}
	lblDownload:Hide()
	prDownload = Progressbar:New {
		x = 15,
		y = 265,
		parent = parentControl,
		width = 200,
		height = 30,
		value = 0,
	}
	prDownload:Hide()

	local btnStartBattle = Button:New {
		x = 10,
		bottom = 10,
		right = "50.5%",
		height = 45,
		caption = "\255\66\138\201" .. i18n("start") ..  "\b",
		font = { size = 22 },
		OnClick = {
			function()
				lobby:SayBattle("!start")
			end
		},
		parent = parentControl,
	}
	
	local btnQuitBattle = Button:New {
		right = 10,
		bottom = 10,
		x = "50.5%",
		height = 45,
		font = { size = 22 },
		caption = WG.Chobby.Configuration:GetErrorColor() .. i18n("quit") .. "\b",
		OnClick = {
			function()
				lobby:LeaveBattle()
			end
		},
		parent = parentControl,
	}
	
	onUpdateBattleInfo = function(listener, updatedBattleID, spectatorCount, locked, mapHash, mapName)
		if battleID ~= updatedBattleID then
			return
		end
		if mapName then
			lblMapName:SetCaption(mapName)
		end
	end
	lobby:AddListener("OnUpdateBattleInfo", onUpdateBattleInfo)
	
	local UpdatePlayers = function(battleID)
		lblNumberOfPlayers:SetCaption(i18n("players") .. ": " .. tostring(#battle.users) .. "/" .. tostring(battle.maxPlayers))
	end
	
	onLeftBattle_counter = function(listener, leftBattleID, userName)
		if battleID ~= leftBattleID then
			return
		end
		if lobby:GetMyUserName() == userName then
			window:Dispose()
		else
			UpdatePlayers(battleID)
		end
	end
	lobby:AddListener("OnLeftBattle", onLeftBattle_counter)

	onJoinedBattle = function(listener, joinedBattleId, userName)
		if battleID ~= joinedBattleId then
			return
		end
		UpdatePlayers(battleID)
	end
	lobby:AddListener("OnJoinedBattle", onJoinedBattle)
	
	UpdatePlayers(battleID)

	MaybeDownloadGame(battle)
	MaybeDownloadMap(battle)
end

local function SetupPlayerPanel(parentControl, battle, battleID)
	
	local SPACING = 22
		
	local mainScrollPanel = ScrollPanel:New {
		x = 0,
		right = "41%",
		y = 0,
		bottom = 0,
		parent = parentControl,
	}
		
	local mainStackPanel = Control:New {
		x = 0,
		right = 0,
		y = 0,
		parent = mainScrollPanel,
		preserveChildrenOrder = true,
	}	
	
	local spectatorScrollPanel = ScrollPanel:New {
		x = "61%",
		right = 0,
		y = 0,
		bottom = 0,
		parent = parentControl,
	}
		
	local spectatorStackPanel = Control:New {
		x = 0,
		right = 0,
		y = 0,
		parent = spectatorScrollPanel,
	}
	
	-- Object handling
	local player = {}
	local team = {}
	
	local function PositionChildren(panel, minHeight)
		local children = panel.children
		
		minHeight = minHeight - 30
		
		local totalHeight = 0
		local maxHeight = 0
		for i = 1, #children do
			local child = children[i]
			totalHeight = totalHeight + child.height
			if child.height > maxHeight then
				maxHeight = child.height
			end
		end
		
		if #children * maxHeight > minHeight then
			panel:SetPos(nil, nil, nil, totalHeight)
			local runningHeight = 0
			for i = 1, #children do
				local child = children[i]
				child:SetPos(nil, runningHeight)
				child:Invalidate()
				runningHeight = runningHeight + child.height
			end
		else
			panel:SetPos(nil, nil, nil, minHeight)
			for i = 1, #children do
				local child = children[i]
				child:SetPos(nil, minHeight * (i - 1)/#children)
				child:Invalidate()
			end
		end
		panel:Invalidate()
	end
	
	local function GetPlayerData(name)
		if not player[name] then
			player[name] = {
				team = false,
				control = Label:New { -- Replace with generic player control
					name = name,
					x = 5,
					y = 0,
					width = 200,
					height = 30,
					font = {size = 15},
					caption = name,
				},
			}
		end
		return player[name]
	end
	
	local function GetTeam(teamIndex)
		if not team[teamIndex] then
			if teamIndex > largestTeamIndex then
				largestTeamIndex = teamIndex
			end
		
			local humanName, parentStack, parentScroll
			if teamIndex == -1 then
				humanName = "Spectators"
				parentStack = spectatorStackPanel
				parentScroll = spectatorScrollPanel
			else
				humanName = "Team " .. teamIndex
				parentStack = mainStackPanel
				parentScroll = mainScrollPanel
			end

			local teamHolder = Control:New {
				name = teamIndex,
				x = 0,
				right = 0,
				y = 0,
				height = 50,
				padding = {0, 0, 0, 0},
				parent = parentStack,
			} 
			local label = Label:New {
				x = 5,
				y = 0,
				width = 120,
				height = 30,
				font = {size = 20},
				caption = humanName,
				parent = teamHolder,
			}
			if teamIndex ~= -1 then
				local joinTeamButton = Button:New {
					x = 130,
					y = 0,
					height = 30,
					width = 55,
					font = { size = 20 },
					caption = WG.Chobby.Configuration:GetErrorColor() .. i18n("join") .. "\b",
					OnClick = {
						function()
							lobby:SetBattleStatus({
								AllyNumber = teamIndex, 
								IsSpectator = false,
							})
						end
					},
					parent = teamHolder,
				}
			end
			local teamStack = Control:New {
				x = 0,
				y = 25,
				right = 0,
				bottom = 0,
				padding = {0, 0, 0, 0},
				parent = teamHolder,
				preserveChildrenOrder = true,
			}
			
			local teamData = {}
			
			function teamData.AddPlayer(name)
				local playerData = GetPlayerData(name)
				if playerData.team == teamIndex then
					return
				end
				playerData.team = teamIndex
				local playerControl = playerData.control
				teamStack:AddChild(playerControl)
				playerControl:SetPos(nil, (#teamStack.children - 1)*SPACING)
				playerControl:Invalidate()
				
				teamHolder:SetPos(nil, nil, nil, #teamStack.children*SPACING + 35)
				PositionChildren(parentStack, parentScroll.height)
				teamHolder:Invalidate()
			end
			
			function teamData.RemovePlayer(name)
				local playerData = GetPlayerData(name)
				if playerData.team ~= teamIndex then
					return
				end
				playerData.team = false
				local index = 1
				local timeToMove = false
				while index <= #teamStack.children do
					if timeToMove then
						teamStack.children[index]:SetPos(nil, (index - 1)*SPACING)
						teamStack.children[index]:Invalidate()
					elseif teamStack.children[index].name == name then
						teamStack:RemoveChild(teamStack.children[index])
						index = index - 1
						timeToMove = true
					end
					index = index + 1
				end
				teamHolder:SetPos(nil, nil, nil, #teamStack.children*SPACING + 35)
				
				if teamStack:IsEmpty() then
					team[teamIndex] = nil
					parentStack:RemoveChild(parentStack:GetChildByName(teamIndex))
					teamHolder:Dispose()
				else
					teamHolder:Invalidate()
				end
				PositionChildren(parentStack, parentScroll.height)
			end
			
			team[teamIndex] = teamData
		end
		return team[teamIndex] 
	end
	
	-- Object modification
	local function AddPlayerToTeam(allyTeamID, name)
		local teamObject = GetTeam(allyTeamID)
		teamObject.AddPlayer(name)
	end
	
	local function RemovePlayerFromTeam(name)
		local playerData = GetPlayerData(name)
		if playerData.team then
			local teamObject = GetTeam(playerData.team)
			teamObject.RemovePlayer(name)	
		end
	end
	
	updateUserBattleStatus = function(listener, data)
		local name = data.Name
		local allyTeamID = data.AllyNumber
		if name then
			RemovePlayerFromTeam(name)
			if data.IsSpectator then
				AddPlayerToTeam(-1, name)
			elseif allyTeamID then
				AddPlayerToTeam(allyTeamID, name)
			end
		end
	end
	lobby:AddListener("UpdateUserBattleStatus", updateUserBattleStatus)
	
	onLeftBattle = function(listener, LeftBattleID, UserName)
		if LeftBattleID == battleID then
			if UserName then
				RemovePlayerFromTeam(UserName)
				GetPlayerData(UserName).control:Dispose()
			end
		end
	end
	lobby:AddListener("OnLeftBattle", onLeftBattle)
	
	removeBot = function(listener, data)
		if data.Name then
			RemovePlayerFromTeam(data.Name)
			GetPlayerData(data.Name).control:Dispose()
		end
	end
	lobby:AddListener("RemoveBot", removeBot)
end

local function InitializeControls(battleID)
	local battle = lobby:GetBattle(battleID)

	if window then
		window:Dispose()
	end
	
	window = Window:New {
		x = 400,
		width = 720,
		y = 120,
		height = 720,
		parent = screen0,
		resizable = false,
		padding = {0, 0, 0, 0},
		OnDispose = { 
			function()
				largestTeamIndex = -1
			
				lobby:RemoveListener("OnBattleClosed", onBattleClosed)
				lobby:RemoveListener("OnLeftBattle", onLeftBattle_counter)
				lobby:RemoveListener("OnJoinedBattle", onJoinedBattle)
				lobby:RemoveListener("OnSaidBattle", onSaidBattle)
				lobby:RemoveListener("OnSaidBattleEx", onSaidBattleEx)
				lobby:RemoveListener("OnClientStatus", onClientStatus)
				lobby:RemoveListener("UpdateUserBattleStatus", updateUserBattleStatus)
				lobby:RemoveListener("OnLeftBattle", onLeftBattle)
				lobby:RemoveListener("RemoveBot", removeBot)
			end
		},
	}
	
	local subPanel = Control:New {
		x = 0,
		y = 42,
		right = 0,
		bottom = 0,
		padding = {0, 0, 0, 0},
		parent = window,
	}
	
	local playerPanel = Control:New {
		x = "2%",
		y = "2%",
		right = "33%",
		bottom = "51%",
		padding = {0, 0, 0, 0},
		parent = subPanel,
	}
	
	SetupPlayerPanel(playerPanel, battle, battleID)
	
	local infoButtonsPanel = Control:New {
		x = "68%",
		y = "30.5%",
		right = "2%",
		bottom = "2%",
		padding = {0, 0, 0, 0},
		parent = subPanel,
	}
	
	SetupInfoButtonsPanel(infoButtonsPanel, battle, battleID)
	
	local lblBattleTitle = Label:New {
		x = 18,
		y = 18,
		width = 200,
		height = 30,
		font = { size = 20 },
		caption = i18n("battle") .. ": " .. tostring(battle.title),
		parent = window,
	}

	local line = Line:New {
		x = 0,
		y = 0,
		width = 300,
		parent = subPanel,
	}
	
	local minimap = Panel:New {
		x = "68%",
		y = "2%",
		right = "2%",
		bottom = "68%",
		parent = subPanel,
	}

	local battleRoomConsole = WG.Chobby.Console()
	battleRoomConsole.listener = function(message)
		lobby:SayBattle(message)
	end
	
	local chatPanel = Control:New {
		x = "2%",
		y = "51%",
		bottom = "2%",
		right = "33%",
		padding = {0, 0, 0, 0},
		itemPadding = {0, 0, 0, 0},
		itemMargin = {0, 0, 0, 0},
		children = {
			Control:New {
				x = 0, y = 0, right = 0, bottom = 0,
				padding={0,0,0,0}, itemPadding={0,0,0,0}, itemMargin={0,0,0,0},
				children = { battleRoomConsole.panel, },
			},
		},
		parent = subPanel,
	}

	local onSaidBattle = function(listener, userName, message)
		battleRoomConsole:AddMessage(userName .. ": " .. message)
	end
	lobby:AddListener("OnSaidBattle", onSaidBattle)

	local onSaidBattleEx = function(listener, userName, message)
		battleRoomConsole:AddMessage("\255\0\139\139" .. userName .. " " .. message .. "\b")		
	end
	lobby:AddListener("OnSaidBattleEx", onSaidBattleEx)

	onBattleClosed = function(listener, closedBattleID, ... )
		if battleID == closedBattleID then
			window:Dispose()
		end
	end
	lobby:AddListener("OnBattleClosed", onBattleClosed)
	
	-- TODO: implement this as a part of the lobby protocol
	onClientStatus = function(listener, userName, status)
		-- game started
		if userName == battle.founder and math.bit_and(1, status) then
			Spring.Echo("Game starts!")
			local battle = lobby:GetBattle(battleID)
			local springURL = "spring://" .. lobby:GetMyUserName() .. ":" .. lobby:GetScriptPassword() .. "@" .. battle.ip .. ":" .. battle.port
			Spring.Echo(springURL)
			Spring.Start(springURL, "")
			--local scriptFileName = "scriptFile.txt"
			--local scriptFile = io.open(scriptFileName, "w")
			--local scriptTxt = GenerateScriptTxt(battleID)
			--Spring.Echo(scriptTxt)
			--scriptFile:write(scriptTxt)
			--scriptFile:close()
			--Spring.Restart(scriptFileName, "")
			--Spring.Restart("", scriptTxt)
		end
	end
	lobby:AddListener("OnClientStatus", onClientStatus)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Widget Interface

local BattleRoomWindow = {}

function BattleRoomWindow.ShowBattleRoom(battleID)
	InitializeControls(battleID)
	
	lobby:SetBattleStatus({
		AllyNumber = 0,
		IsSpectator = false,  
		Sync = 1, -- 0 = unknown, 1 = synced, 2 = unsynced
	})
end

function widget:Initialize()
	CHOBBY_DIR = "LuaUI/widgets/chobby/"
	VFS.Include("LuaUI/widgets/chobby/headers/exports.lua", nil, VFS.RAW_FIRST)
	
	WG.BattleRoomWindow = BattleRoomWindow
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
