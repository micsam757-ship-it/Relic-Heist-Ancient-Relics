--!nonstrict
-- Small player/character accessors shared by server services.

local Players = game:GetService("Players")

local PlayerUtil = {}

function PlayerUtil.getCharacter(player: Player): Model?
	local character = player.Character
	if character and character.Parent then
		return character
	end
	return nil
end

function PlayerUtil.getHumanoid(player: Player): Humanoid?
	local character = PlayerUtil.getCharacter(player)
	if character == nil then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

function PlayerUtil.getRoot(player: Player): BasePart?
	local character = PlayerUtil.getCharacter(player)
	if character == nil then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function PlayerUtil.isAlive(player: Player): boolean
	local humanoid = PlayerUtil.getHumanoid(player)
	return humanoid ~= nil and humanoid.Health > 0
end

function PlayerUtil.distanceToPoint(player: Player, point: Vector3): number?
	local root = PlayerUtil.getRoot(player)
	if root == nil then
		return nil
	end
	return (root.Position - point).Magnitude
end

function PlayerUtil.allCharacters(): { Model }
	local characters = {}
	for _, player in Players:GetPlayers() do
		local character = PlayerUtil.getCharacter(player)
		if character then
			table.insert(characters, character)
		end
	end
	return characters
end

return PlayerUtil
