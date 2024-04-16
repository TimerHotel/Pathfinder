--!strict

--[[
	Pathfinder
	
	Created By: TimerHotel - timerhotel
	Version 1.0.0
	
	Created: April 13 2024
	Updated: April 16 2024
	
	Modified by: [No one - Origin Version]
	Modification Details:
	[
		-None
	]
]]

--[[
-----------------------------------
------    ATTENTION NEEDED   ------
------           |           ------
------           V           ------
-----------------------------------
]]
-- DOWNLOAD TROVE IF PATHFINDER DOWNLOADED THROUGH GITHUB
local Maid = require(script.Trove) --CHANGE THIS TO THE LOCATION YOU DESIRE 




local ContextActionService = game:GetService("ContextActionService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")


export type Pathfinder = {
	VisualizePath: boolean,
	IsActive: boolean,
	IsPlayerMovementLocked: boolean,
	
	ReachedCheckpoint: RBXScriptSignal,
	Finished: RBXScriptSignal,
	
	Pathfind: (self: PathfinderInternal, Vector3 | CFrame, {[string]: any}?) -> (),
	ExtendPath: (self: PathfinderInternal, Vector3 | CFrame) -> (),
	MoveInto: (self: PathfinderInternal, Vector3 | CFrame) -> (),
	ResetPathfinder: (self: PathfinderInternal) -> (),
	AllowPlayerMovement: (self: PathfinderInternal, boolean) -> (),
	Cancel: (self: PathfinderInternal) -> (),
	Destroy: (self: PathfinderInternal) -> (),
}

type PathfinderInternal = Pathfinder & {
	_Maid: Maid.Trove,
	
	_ReachedCheckpoint: BindableEvent,
	_Finished: BindableEvent,
	
	_PathfindType: "Pathfind" | "MoveInto"?,
	_Path: {Vector3},
	_DesiredDestination: Vector3 | CFrame?,
	_LastAgentParameters: {[string]: any}?,

	_Character: Character,
	_Humanoid: Humanoid,
	
	_VisualizationParts: {BasePart},

	--
	_ResetPathfinder: (self: PathfinderInternal) -> (),
	_ContinuePath: (self: PathfinderInternal) -> (),
	_ToggleMovement: (self: PathfinderInternal) -> (),
	_CancelIfPlayerMoved: (self: PathfinderInternal) -> (),
	_ComputePath: (self: PathfinderInternal, Vector3, Vector3) -> Path,
	_VisualizePath: (any, any) -> (),
}

type Character = Model & {
	Humanoid: Humanoid,
	HumanoidRootPart: BasePart,
}


local Pathfinder = {}
Pathfinder.__index = Pathfinder

function Pathfinder.new(Character: Model): Pathfinder
	local self = setmetatable({}, Pathfinder)
	self._Maid = Maid.new()
	
	self._VisualizationParts = {}
	self.VisualizePath = false
	
	self.IsActive = false
	
	self.IsPlayerMovementLocked = false
	
	self._ReachedCheckpoint = Instance.new("BindableEvent")
	self._Finished = Instance.new("BindableEvent")
	self.ReachedCheckpoint = self._ReachedCheckpoint.Event
	self.Finished = self._Finished.Event
	
	self._Path = {}
	
	self._Character = Character
	if not self._Character then
		error("Character was not provided")
	end
	
	self._Humanoid = self._Character:FindFirstChildWhichIsA("Humanoid")
	if not self._Humanoid then
		error("Character contains no children of class 'Humanoid'")
	end
	
	self._Maid:Add(function()
		self.IsActive = false
		self._PathfindType = nil
		self._DesiredDestination = nil
		self._Path = {}
	end)
	
	self._Maid:AttachToInstance(self._Character)
	
	return (self :: any) :: Pathfinder
end

--Public Functions
function Pathfinder.Pathfind(self: PathfinderInternal, DesiredDestination: Vector3 | CFrame, AgentParameters: {[string]: any}?)
	self:_ResetPathfinder()
	
	self._PathfindType = "Pathfind"
	self._DesiredDestination = DesiredDestination
	self._LastAgentParameters = AgentParameters
	
	if typeof(DesiredDestination) == "CFrame" then
		local CFramed = DesiredDestination :: CFrame
		DesiredDestination = CFramed.Position
	end	
	local Path = self:_ComputePath(self._Character.HumanoidRootPart.Position, DesiredDestination :: Vector3)

	local Waypoints = Path:GetWaypoints()
	
	if Path.Status ~= Enum.PathStatus.Success then
		error("Pathfinding failed: "..Path.Status.Name)
	end

	for i,v in Waypoints do
		if i == 1 then continue end
		
		table.insert(self._Path,v.Position)
	end
	
	if self.VisualizePath then
		self:_VisualizePath()
	end
	
	self:_ToggleMovement()
	self:_CancelIfPlayerMoved()
	
	self:_ContinuePath()
end

function Pathfinder.ExtendPath(self: PathfinderInternal, DesiredDestination: Vector3 | CFrame)
	if self._PathfindType ~= "Pathfind" then
		error("Attempt to extend a MoveInto")
	end
	
	local LastPoint = self._DesiredDestination or self._Character.HumanoidRootPart.Position
	if typeof(LastPoint) == "CFrame" then
		local CFramed = LastPoint :: CFrame
		LastPoint = CFramed.Position
	end	
	
	self._DesiredDestination = DesiredDestination
	
	if typeof(DesiredDestination) == "CFrame" then
		local CFramed = DesiredDestination :: CFrame
		DesiredDestination = CFramed.Position
	end	
	local Path = self:_ComputePath(LastPoint:: Vector3, DesiredDestination:: Vector3)
	
	local Waypoints = Path:GetWaypoints()

	if Path.Status ~= Enum.PathStatus.Success then
		error("Pathfinding failed: "..Path.Status.Name)
	end
	
	for i,v in Waypoints do
		if i == 1 then continue end
		
		table.insert(self._Path,v.Position)
	end
	
	if self.VisualizePath then
		self:_VisualizePath()
	end
end

function Pathfinder.MoveInto(self: PathfinderInternal, DesiredDestination: Vector3 | CFrame)
	self:_ResetPathfinder()

	local HasFinished = false
	
	local function Finished()
		if HasFinished then return end
		self._Finished:Fire()
		HasFinished = true
		self._Humanoid:MoveTo(self._Character.HumanoidRootPart.Position)
		self:_ResetPathfinder()
	end
	
	self._Maid:Add(task.delay(8,function()
		Finished()
	end))
	
	local RealTarget = DesiredDestination :: Vector3
	if typeof(RealTarget) == "CFrame" then
		RealTarget = RealTarget.Position
	end
	
	self:_CancelIfPlayerMoved()
	self:_ToggleMovement()
	self._Humanoid:MoveTo(RealTarget)
	self.IsActive = true
	
	local MoveToFinished = self._Humanoid.MoveToFinished:Once(function()
		local DistanceLeft = (self._Character.HumanoidRootPart.Position-RealTarget).Magnitude
		if DistanceLeft > 0.05 then
			local RelativePosition = self._Character.HumanoidRootPart.CFrame:ToObjectSpace(CFrame.new(RealTarget))
			local NewPosition = self._Character.HumanoidRootPart.CFrame * (RelativePosition.Position*2)
			self._Character.Humanoid:MoveTo(NewPosition)
			self._Character.Humanoid.MoveToFinished:Once(function()
				if typeof(DesiredDestination) == "CFrame" then
					local Rotation = DesiredDestination - DesiredDestination.Position
					repeat
						local OldCFrame = self._Character.HumanoidRootPart.CFrame

						self._Character.HumanoidRootPart.CFrame = OldCFrame:Lerp(CFrame.new(self._Character.HumanoidRootPart.Position)*Rotation,0.1)

						task.wait()
					until math.deg(math.acos(DesiredDestination.LookVector:Dot(self._Character.HumanoidRootPart.CFrame.LookVector))) < 1 

					self._Character.HumanoidRootPart.CFrame = CFrame.new(self._Character.HumanoidRootPart.Position)*Rotation
				end

				Finished()
			end)
		end
	end)
	self._Maid:Add(MoveToFinished:: any)
end

function Pathfinder.AllowPlayerMovement(self: PathfinderInternal, State: boolean)
	if RunService:IsServer() then
		warn("Cannot toggle Player Movement Allowed on Server, action was ignored")
		return
	end
	
	self.IsPlayerMovementLocked = not State
	self:_ToggleMovement()
end

function Pathfinder.Cancel(self: PathfinderInternal)
	self:_ResetPathfinder()
end

function Pathfinder.Destroy(self: PathfinderInternal)
	self._Maid:Clean()
	
	setmetatable(self, nil)
end


--Private Functions
function Pathfinder._ResetPathfinder(self: PathfinderInternal)
	self._Maid:Clean()
	
	self._Maid:Add(function()
		self.IsActive = false
		self._PathfindType = nil
		self._DesiredDestination = nil
		self._Path = {}
	end)
end

function Pathfinder._ContinuePath(self: PathfinderInternal)
	if #self._Path <= 0 then return end
	
	self.IsActive = true
	
	self._Maid:Add(task.defer(function()
		local PathTo = self._Path[1]
		self._Humanoid:MoveTo(PathTo)
		self._Humanoid.MoveToFinished:Wait()
		self._ReachedCheckpoint:Fire()
		
		table.remove(self._Path,1)
		
		if #self._Path == 1 then
			self:MoveInto(self._DesiredDestination:: Vector3 | CFrame)
		else
			self:_ContinuePath()
		end
	end))
end

function Pathfinder._ToggleMovement(self: PathfinderInternal)
	if RunService:IsServer() then return end
	
	if self.IsPlayerMovementLocked then
		ContextActionService:BindAction(
			"FreezeMovement",
			function()
				return Enum.ContextActionResult.Sink
			end,
			false,
			unpack(Enum.PlayerActions:GetEnumItems())
		)
		
		self._Maid:Add(function()
			ContextActionService:UnbindAction("FreezeMovement")
		end)
	end
end

function Pathfinder._CancelIfPlayerMoved(self: PathfinderInternal)
	self._Maid:Add(self._Humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
		if self._Humanoid.MoveDirection ~= Vector3.new(0,0,0) then
			self:Cancel()
		end
	end):: any)
end

function Pathfinder._ComputePath(self: PathfinderInternal, From: Vector3, To: Vector3): Path
	local Path: Path = PathfindingService:CreatePath(self._LastAgentParameters)

	local Success
	local Tries = 0
	repeat
		local Error
		Success, Error = pcall(function()
			Path:ComputeAsync(From, To)
		end)
		if (Error) and (Tries >= 10) then
			error(Error)
		end

		Tries += 1

		task.wait(0.25)
	until Success
	
	return Path
end

function Pathfinder._VisualizePath(self: PathfinderInternal)
	for i,v in (self._Path) do
		local Next = self._Path[i+1]
		if not Next then return end
		
		Next += Vector3.new(0,self._Humanoid.HipHeight,0)
		local Current = v + Vector3.new(0,self._Humanoid.HipHeight,0)
		
		local Part = Instance.new("Part")
		Part.Size = Vector3.new(0.2,0.2,(Current - Next).Magnitude)
		Part.Anchored = true
		Part.CanCollide = false
		Part.Color = Color3.fromRGB(0,255,0)
		Part.Material = Enum.Material.Neon
		Part.CFrame = CFrame.lookAt((Current + Next) / 2,Next)
		Part.Parent = workspace
		
		self._Maid:Add(Part)
		table.insert(self._VisualizationParts,Part)
	end
end

return {
	new = Pathfinder.new,
}