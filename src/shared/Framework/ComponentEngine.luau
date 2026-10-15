--!strict
-- Arcane Citadel Studio SDK: CollectionService tag binder (Milestone 1).
-- Client/server systems register handlers per tag; instances added
-- later are picked up automatically.

local CollectionService = game:GetService("CollectionService")

local ComponentEngine = {}

export type TagHandler = {
	Tag: string,
	OnAdded: (instance: Instance) -> (),
	OnRemoved: ((instance: Instance) -> ())?,
}

local bindings: { [string]: { instance: Instance, handler: TagHandler } } = {}

function ComponentEngine.Bind(handler: TagHandler)
	for _, instance in CollectionService:GetTagged(handler.Tag) do
		bindings[instance:GetDebugId()] = { instance = instance, handler = handler }
		handler.OnAdded(instance)
	end
	CollectionService:GetInstanceAddedSignal(handler.Tag):Connect(function(instance: Instance)
		bindings[instance:GetDebugId()] = { instance = instance, handler = handler }
		handler.OnAdded(instance)
	end)
	CollectionService:GetInstanceRemovedSignal(handler.Tag):Connect(function(instance: Instance)
		local key = instance:GetDebugId()
		local entry = bindings[key]
		bindings[key] = nil
		if entry and entry.handler.OnRemoved then
			entry.handler.OnRemoved(instance)
		end
	end)
end

return ComponentEngine
