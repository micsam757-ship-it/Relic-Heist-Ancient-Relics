--!nonstrict
-- Purely cosmetic client effects: slowly rotate exhibited relics and bob
-- collectible relics in the world.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local EffectsController = {}

local bindings = {}

local function track(tag: string)
	local entries = {}
	bindings[tag] = entries

	local function bind(instance: Instance)
		local pivot = instance:GetPivot()
		entries[instance] = { base = pivot, phase = math.random() * math.pi * 2 }
	end

	for _, instance in CollectionService:GetTagged(tag) do
		bind(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(bind)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		entries[instance] = nil
	end)
	return entries
end

function EffectsController.start()
	local displays = track("MuseumDisplay")
	local pickups = track("RelicPickup")

	RunService.Heartbeat:Connect(function(deltaTime)
		for instance, data in displays do
			if instance.Parent == nil then
				displays[instance] = nil
				continue
			end
			instance:PivotTo(data.base * CFrame.Angles(0, deltaTime * 0.5, 0))
		end
		local clock = os.clock()
		for instance, data in pickups do
			if instance.Parent == nil then
				pickups[instance] = nil
				continue
			end
			local bob = math.sin(clock * 1.8 + data.phase) * 0.35
			instance:PivotTo(data.base * CFrame.new(0, bob, 0))
		end
	end)
end

return EffectsController
