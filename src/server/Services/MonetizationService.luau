--!nonstrict
-- Monetization: the Welcome Back offline-earnings flow and the VIP Pass.
--
-- Design constraints (see docs/ADR/0007-monetization.md and docs/MONETIZATION.md):
--   * Fairness: the free 1x claim is always available; the 199-Robux product
--     only doubles the *already-earned* offline payout. No random rewards, no
--     gameplay advantage beyond a larger offline window/ceiling.
--   * Transparency: prices are read from config and surfaced in the UI.
--   * Robustness: ProductIds default to 0 meaning "not configured". When unset,
--     the purchase action refuses and the store prompt is suppressed, so the
--     game remains fully playable before the products exist in the Dashboard.
--
-- Offline gold is computed and held by EconomyService; this service only
-- validates purchases and asks EconomyService to release the balance.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Logger = require(script.Parent.Parent.Utilities.Logger)

local MonetizationService = {}

local state = {
	ctx = nil,
	logger = nil,
	vipCache = {},
	-- Set when a receipt arrives before the player has pending income to
	-- release, so the multiplier is honored on the next claim instead.
	doubleTokens = {},
}

local function isConfigured(id): boolean
	return type(id) == "number" and id > 0
end

function MonetizationService:Init(ctx)
	state.ctx = ctx
	state.logger = Logger.new("Monetization")
end

-- Cache the VIP entitlement. Game Pass ownership is a network call, so it is
-- read once on join and never per-tick.
local function refreshVip(player: Player)
	local passId = GameConfig.Monetization.VipPassId
	if not isConfigured(passId) then
		state.vipCache[player.UserId] = false
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	state.vipCache[player.UserId] = ok and owns == true
end

function MonetizationService:IsVip(player: Player): boolean
	if state.vipCache[player.UserId] == nil then
		refreshVip(player)
	end
	return state.vipCache[player.UserId] == true
end

-- Push the Welcome Back prompt if the player has a pending offline balance.
function MonetizationService:NotifyOfflineReady(player: Player)
	if not player:IsDescendantOf(Players) then
		return
	end
	local economy = state.ctx.Services.Economy
	local pending = economy:GetPending(player)
	if pending <= 0 then
		return
	end
	local profile = state.ctx.Services.PlayerData:GetProfile(player)
	local capSeconds = economy:GetOfflineCap(profile)
	state.ctx.Services.Network:PushEvent(player, "WelcomeBack", {
		amount = pending,
		multiplier = GameConfig.Monetization.OfflineDoubleMultiplier,
		priceRobux = GameConfig.Monetization.OfflineDoublePriceRobux,
		purchasable = isConfigured(GameConfig.Monetization.OfflineDoubleProductId),
		vip = MonetizationService:IsVip(player),
		capSeconds = capSeconds,
	})
	state.ctx.Services.Analytics:Track("offline_modal_shown", { amount = pending })
end

-- Free 1x claim. The client sends this when the player taps "Claim 1x".
function MonetizationService:ClaimFree(player: Player)
	local granted = state.ctx.Services.Economy:ClaimPending(player, 1)
	if granted <= 0 then
		return false, "Nothing to claim right now."
	end
	state.ctx.Services.Network:PushEvent(player, "WelcomeBackClosed", {})
	state.ctx.Services.Network:Toast(player, "success", string.format("+%d gold claimed", granted))
	return true, nil
end

-- Called from ProcessReceipt: release the pending balance at 2x. If there is
-- nothing pending yet, remember the token so the next claim honours it.
local function grantDouble(player: Player)
	local economy = state.ctx.Services.Economy
	local pending = economy:GetPending(player)
	if pending <= 0 then
		state.doubleTokens[player.UserId] = true
		return
	end
	local multiplier = GameConfig.Monetization.OfflineDoubleMultiplier
	local granted = economy:ClaimPending(player, multiplier)
	state.doubleTokens[player.UserId] = nil
	state.ctx.Services.Network:PushEvent(player, "WelcomeBackClosed", {})
	state.ctx.Services.Network:Toast(player, "success", string.format("+%d gold claimed at %dx", granted, multiplier))
end

-- Prompt the Developer Product for the 2x offline multiplier.
function MonetizationService:PromptDouble(player: Player)
	local productId = GameConfig.Monetization.OfflineDoubleProductId
	if not isConfigured(productId) then
		return false, "This offer is not available yet."
	end
	MarketplaceService:PromptProductPurchase(player, productId)
	return true, nil
end

function MonetizationService:InitReceiptHandler()
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local productId = receiptInfo.ProductId
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if player == nil then
			-- Player left mid-purchase; Roblox will prompt again next session.
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		if
			isConfigured(GameConfig.Monetization.OfflineDoubleProductId)
			and productId == GameConfig.Monetization.OfflineDoubleProductId
		then
			local ok, err = pcall(grantDouble, player)
			if not ok then
				state.logger:error("Failed to grant offline double for %s: %s", player.Name, tostring(err))
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			state.ctx.Services.Analytics:Track("product_purchased", { product = "offline_double" })
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		state.logger:warn("Unknown Developer Product %s from %s", tostring(productId), player.Name)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

function MonetizationService:Start()
	state.ctx.Signals.ProfileLoaded:Connect(function(player)
		refreshVip(player)
		-- Reflect the entitlement on the profile so the cap reflects VIP status
		-- immediately and persists for the next session's offline window.
		local profile = state.ctx.Services.PlayerData:GetProfile(player)
		if profile and profile.vip ~= MonetizationService:IsVip(player) then
			profile.vip = MonetizationService:IsVip(player)
			state.ctx.Services.PlayerData:MarkDirty(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		state.vipCache[player.UserId] = nil
		state.doubleTokens[player.UserId] = nil
	end)

	state.ctx.Services.Network:RegisterAction("ClaimOfflineIncome", function(player)
		return MonetizationService:ClaimFree(player)
	end, { perSecond = 2, burst = 4 })

	state.ctx.Services.Network:RegisterAction("PurchaseOfflineDouble", function(player)
		return MonetizationService:PromptDouble(player)
	end, { perSecond = 2, burst = 4 })

	MonetizationService:InitReceiptHandler()
end

return MonetizationService
