# ROBLOX & LUAU ANTI-DEPRECATION MATRIX (2026 MODERN STANDARDS)
*(Auto-enforced by `scan_deprecated_apis.sh` and updated by `/verifying-roblox-apis`)*

| Category | BANNED / DEPRECATED API (Never Use) | MANDATORY MODERN REPLACEMENT (Always Use) |
| :--- | :--- | :--- |
| **Task Scheduling** | `wait()`, `spawn()`, `delay()`, ` elapsedTime()` | `task.wait()`, `task.spawn()`, `task.delay()`, `task.defer()`, `task.cancel()` |
| **Time & Clocks** | `tick()`, `os.time()` for frame math | `os.clock()` (high-precision CPU delta) or `workspace:GetServerTimeNow()` (synced cross-network timestamp) |
| **Raycasting & Spatial** | `workspace:FindPartOnRay()`, `FindPartOnRayWithIgnoreList()`, `Region3`, `FindPartsInRegion3()` | `workspace:Raycast(origin, direction, raycastParams)`, `workspace:GetPartBoundsInBox()`, `workspace:GetPartBoundsInRadius()` |
| **Physics & Forces** | `BodyVelocity`, `BodyForce`, `BodyGyro`, `BodyPosition`, `RocketPropulsion` | `LinearVelocity`, `VectorForce`, `AlignOrientation`, `AlignPosition` (with `Attachment0`) or direct `CFrame:Lerp()` on anchored parts |
| **Part Velocity** | `part.Velocity`, `part.RotVelocity` | `part.AssemblyLinearVelocity`, `part.AssemblyAngularVelocity` |
| **Service Access** | `game.Lighting`, `game.Players`, `game.ReplicatedStorage` direct dot-indexing | `game:GetService("Lighting")`, `game:GetService("Players")`, `game:GetService("ReplicatedStorage")` (`workspace` global is allowed) |
| **Cross-Server Teleport** | `TeleportService:TeleportToPrivateServer()`, `TeleportToPlaceInstance()` without `TeleportOptions` | `TeleportService:TeleportAsync(placeId, {player}, teleportOptions)` wrapped in `pcall` |
| **Cross-Server Matchmaking** | Polling `DataStoreService:GetDataStore()` every 5s for server lists | `MemoryStoreService:GetSortedMap("ActiveBloodPactCitadels")` with 30s publisher TTL and 15s local server cache |
| **Chat & Announcements** | `StarterGui:SetCore("ChatMakeSystemMessage")` (Legacy Chat) | `TextChatService.TextChannels.RBXSystem:DisplaySystemMessage()` (on Client) |
| **Character Scale/Pivot** | `model:SetPrimaryPartCFrame()`, `model:GetModelCFrame()` | `model:PivotTo(cframe)`, `model:GetPivot()` |
| **Table Iteration** | Verbose `for k, v in pairs(tbl)` / `ipairs(tbl)` everywhere | Luau Generalized Iteration (`for k, v in tbl do`) + `table.create(n)` / `table.clear(tbl)` / `table.freeze(cfg)` |
