--!strict
-- Per-key token bucket rate limiter used by all network handlers and prompts.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = {
	Allow: (self: RateLimiter, key: string, cost: number?) -> boolean,
	Clear: (self: RateLimiter, key: string) -> (),
}

function RateLimiter.new(perSecond: number, burst: number)
	assert(perSecond > 0, "perSecond must be positive")
	assert(burst >= 1, "burst must be at least 1")
	return setmetatable({
		_perSecond = perSecond,
		_burst = burst,
		_buckets = {},
	}, RateLimiter) :: any
end

function RateLimiter:Allow(key: string, cost: number?): boolean
	local now = os.clock()
	local bucket = (self :: any)._buckets[key]
	if bucket == nil then
		bucket = { tokens = (self :: any)._burst, updatedAt = now }
		(self :: any)._buckets[key] = bucket
	end

	local elapsed = math.max(0, now - bucket.updatedAt)
	bucket.tokens = math.min((self :: any)._burst, bucket.tokens + elapsed * (self :: any)._perSecond)
	bucket.updatedAt = now

	local requested = cost or 1
	if bucket.tokens < requested then
		return false
	end
	bucket.tokens -= requested
	return true
end

function RateLimiter:Clear(key: string)
	(self :: any)._buckets[key] = nil
end

return RateLimiter
