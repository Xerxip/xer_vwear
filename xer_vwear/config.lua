Config = {}

Config.UpdateInterval = 10000  -- ms between updates (increased for efficiency)
Config.AggressiveMultiplier = 3.0
Config.MechanicJob = "mechanic"  -- Job name

-- FiveM-Optimized Wear: ~1% every 4-5km (tires/brakes), slower for engine/trans
-- Full wear: Tires/Brakes ~400-500km (quick RP visits), Engine ~1k km
Config.WearRates = {  -- % wear per 100km (ultra-accelerated for gameplay)
    engine = 10.0,       -- 1% every 10km (full: 1,000km)
    transmission = 10.0, -- 1% every 10km (full: 1,000km)
    brakes = 25.0,       -- 1% every 4km (full: 400km) – Braking wears fast!
    suspension = 15.0,   -- 1% every ~6.7km (full: 667km)
    tires = 20.0         -- 1% every 5km (full: 500km) – Fastest for realism
}

Config.RepairCost = {  -- Bank costs
    engine = 2500,
    transmission = 2000,
    brakes = 1200,
    suspension = 1800,
    tires = 800
}

Config.ShowCommand = "vehstatus"  -- /command

-- New: Logging and Thresholds
Config.DiscordWebhook = "https://discordapp.com/api/webhooks/1441158706694848593/re5gB1BakP2rmnUQEgTTHqp9TGE1EM3MRUthdRdm544LQgDfqQvIs1KxGlp30j7gtLdw"  -- Paste your Discord webhook URL here for logs (e.g., suspicious activity, admin resets). Leave empty for console only.
Config.Debug = false  -- Enable verbose console logging
Config.WearThreshold = 0.1  -- Min % change to trigger DB update (efficiency)
Config.MileageThreshold = 0.1  -- Min km change to trigger DB update