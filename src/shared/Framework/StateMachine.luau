--!strict
-- Arcane Citadel Studio SDK: tiny finite state machine (Milestone 1).

local StateMachine = {}
StateMachine.__index = StateMachine

export type StateType = {
	Enter: ((...any) -> ())?,
	Exit: (() -> ())?,
	Update: ((dt: number) -> ())?,
}

export type Machine = typeof(setmetatable(
	{} :: {
		_states: { [string]: StateType },
		_current: string?,
	},
	StateMachine
))

function StateMachine.new(): Machine
	return setmetatable({ _states = {}, _current = nil }, StateMachine)
end

function StateMachine.AddState(self: Machine, name: string, state: StateType)
	self._states[name] = state
end

function StateMachine.Transition(self: Machine, name: string, ...: any)
	assert(self._states[name], `StateMachine: unknown state '{name}'`)
	local current = self._current and self._states[self._current]
	if current and current.Exit then
		current.Exit()
	end
	self._current = name
	local next = self._states[name]
	if next.Enter then
		next.Enter(...)
	end
end

function StateMachine.Update(self: Machine, dt: number)
	local current = self._current and self._states[self._current]
	if current and current.Update then
		current.Update(dt)
	end
end

function StateMachine.Current(self: Machine): string?
	return self._current
end

return StateMachine
