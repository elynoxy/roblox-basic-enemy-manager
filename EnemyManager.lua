--!strict

--//CONSTRUCTOR\\
local EnemyManager = {}
EnemyManager.__index = EnemyManager

type EnemyManager = {
	Enemy: Model,
	State: string,
	Health: number,
	_StateChanged: {[string]: {() -> ()}}
}

--//STATES\\
EnemyManager.States = {
	Idle = "Idle",
	Moving = "Moving",
	Attacking = "Attacking",
	Dead = "Dead"
}

--//NEW\\

function EnemyManager.new(enemy: Model): EnemyManager
	assert(enemy and enemy:IsA("Model"), "Enemy must be a Model")
	
	--//SELF\\
	local self = setmetatable({}, EnemyManager)
	
	self.Enemy = enemy
	self.State = EnemyManager.States.Idle
	
	self.Health = enemy:GetAttribute("Health") or 30
	
	self._StateChanged = {}
	
	return self
end

--//STATE MACHINE\\

local AllowedTransitions = {
	[EnemyManager.States.Idle] = {
		[EnemyManager.States.Moving] = true,
		[EnemyManager.States.Attacking] = true,
		[EnemyManager.States.Dead] = true
	},
	
	[EnemyManager.States.Moving] = {
		[EnemyManager.States.Idle] = true,
		[EnemyManager.States.Dead] = true
	},
	
	[EnemyManager.States.Attacking] = {
		[EnemyManager.States.Moving] = true,
		[EnemyManager.States.Dead] = true
	},
	
	[EnemyManager.States.Dead] = {
		[EnemyManager.States.Dead] = true
	}
}

function EnemyManager:SetState(newState: string): (boolean, string)
	if typeof(newState) ~= "string" then
		return false, "Invalid state"
	end

	local CurrentState: string = self.State
	local Transition = AllowedTransitions[CurrentState]
	
	if not Transition or not Transition[newState] then
		return false, "Invalid transition"
	end
	
	self.State = newState
	
	if self._StateChanged then
		for  _, callback in self._StateChanged do
			task.spawn(callback, newState, CurrentState)
		end
	end
	
	return true, ""
end


function EnemyManager:OnStateChanged(callback: (newState: string, oldState: string) -> ())
	if not callback or typeof(callback) ~= "function" then
		return false, "Invalid callback"
	end
	
	table.insert(self._StateChanged, callback)
	
	return true, ""
end

--//SESSION\\

--/BOOLEAN\
function EnemyManager:IsAlive(): boolean
	return self.State ~= EnemyManager.States.Dead
end

function EnemyManager:CanAttack(): boolean
	if not self:IsAlive() then
		return false
	end

	if self.State == EnemyManager.States.Moving then
		return false
	end
	
	if self.State == EnemyManager.States.Attacking then
		return false
	end

	return true
end

--//ATTACK\\
local AttackCooldown = 0.5

function EnemyManager:Attack(damage: number): (boolean, string)
	if not self:CanAttack() then
		return false, "Enemy can't attack" 
	end
	
	self:SetState(EnemyManager.States.Attacking)
	self:MakeDamage(damage)
	
	task.delay(AttackCooldown, function()
		self:SetState(EnemyManager.States.Idle)
	end)
	
	return true, ""
end

function EnemyManager:MakeDamage(damage: number): (boolean)
	if not self:IsAlive() then
		return false
	end
	
	if typeof(damage) ~= "number" then return false end
	damage= math.clamp(damage, 0, 100)
	
	if not self:CanAttack() then
		return false
	end
	
	return true
end

--//DEAD\\

function EnemyManager:Dead(): (boolean, string)
	if not self:IsAlive() then
		return false, "Enemy is already dead"
	end
	
	self:SetState(EnemyManager.States.Dead)
	
	return true, ""
end

function EnemyManager:TakeDamage(damage: number): (boolean, string)
	if not self:IsAlive() then
		return false, "Enemy is already dead"
	end
	
	if not damage or typeof(damage) ~= "number" then
		return false, "Invalid damage amount"
	end
	
	damage = math.clamp(damage, 0, self.Health)
	self.Health -= damage
	
	if self.Health <= 0 then
		self:Dead()
		return true, "Enemy is dead"
	end
	
	return true, "Enemy took damage and is still alive"
end

--//SNAPSHOT\\

function EnemyManager:GetSnapshot()
	if not self then
		return {}
	end
	
	return {
		Health = self.Health,
		State = self.State,
	}
end

return EnemyManager