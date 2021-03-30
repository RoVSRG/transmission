local FOLDER_NAME = "_repl"

local Promise = require(script.Promise)

local RunService = game:GetService("RunService")
local isServer = RunService:IsServer()

local StateReplication = {}

local folder

if isServer then
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME

	folder.Parent = game.ReplicatedStorage
end

function StateReplication.new(replicaName)
	local replica = {}
	
	local get
	local set
	
	if isServer then
		local replicaFolder = Instance.new("Folder")
		replicaFolder.Name = replicaName
		
		replicaFolder.Parent = folder

		get = Instance.new("RemoteFunction")
		get.Name = "Get"
		
		get.Parent = replicaFolder
		
		set = Instance.new("RemoteEvent")
		set.Name = "Set"
		
		set.Parent = replicaFolder

		replicaFolder.Parent = folder
	else
		local replicaFolder = game.ReplicatedStorage:WaitForChild(FOLDER_NAME):WaitForChild(replicaName)
		get = replicaFolder:WaitForChild("Get")
		set = replicaFolder:WaitForChild("Set")
	end

	local function connectServer(store)
		get.OnServerInvoke = function(player)
			return store:GetState()
		end
		
		return store.Changed:Connect(function(state)
			set:FireAllClients(state)
		end)
	end

	local function connectClient(store)
		local getStatePromise = Promise.new(function(resolve, reject)
			resolve(get:InvokeServer())
		end)
		
		getStatePromise:andThen(function(state)
			store:SetState(state)		
		end)
		
		return set.OnClientEvent:Connect(function(state)
			getStatePromise:cancel()
			store:SetState(state)
		end)
	end
	
	function replica.connect(store)
		if isServer then
			return connectServer(store)
		else
			return connectClient(store)
		end
	end
	
	return replica
end

return StateReplication
