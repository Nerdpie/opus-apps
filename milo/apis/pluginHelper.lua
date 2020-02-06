local Craft = require('milo.craft2')
local itemDB = require('core.itemDB')
local Milo = require('milo')

--[[
This API module is intended to allow for the easier creation of plugins that auto-learn recipes
Due to the amount of text processing involved, node wizard pages have not been similarly abstracted.

TODO Test how much of a performance hit this causes by constantly checking recipes
    If this causes a large hit, we can introduce a config toggle for learning vs just importing
TODO Implement a 'learning queue' for recipes that may have secondary outputs, etc.
	For instance, a machine may have a chance to produce an extra ore dust
--]]

function registerGenericImportTask(taskName, taskPriority, filter, inputSlots, outputSlots)
	local GenericImportTask = {
		name = taskName,
		priority = taskPriority,
		craftQueue = { },
	}

	function GenericImportTask:cycle(context)
		for te in context.storage:filterActive(filter) do
			--FIXME Most tiles may not return a value for remaining craft time;
			--    what can we test for?  Just if there aren't inputs left?
			if te.adapter.getBrewTime() == 0 then
				local list = te.adapter.list()

				local function inputsEmpty()
					for _, v in ipairs(inputSlots) do
						if list[v] then
							return false
						end
					end
					return true
				end

				if list[outputSlots[1]] and inputsEmpty() then
					-- crafting/processing has completed

					local primaryOutput = list[outputSlots[1]]

					if self.craftQueue[te.name] and primaryOutput then
						local key = itemDB:makeKey(primaryOutput)
						if not Craft.findRecipe(key) then
							local recipe = self.craftQueue[te.name]
							-- hopefully this doesn't mess up the counts...
							recipe.count = primaryOutput.count

							Milo:saveMachineRecipe(recipe, primaryOutput, te.name)
						end
					end

					for _, slot in ipairs(outputSlots) do
						if list[slot] then
							context.storage:import(te, slot, list[slot].count, list[slot])
						end
					end
				end
				self.craftQueue[te.name] = nil

			elseif not self.craftQueue[te.name] then
				local recipe = {
					count = 1,
					ingredients = { },
					maxCount = 1,
				}
				local list = te.adapter.list()

				-- TODO The `valid` function may have to be a param...
				local function valid()
					for _, v in ipairs(inputSlots) do
						if not list[v] then
							return false
						end
					end
					return true
				end

				if valid() then
					for _, v in ipairs(inputSlots) do
						recipe.ingredients[v] = itemDB:makeKey(list[v])
					end

					self.craftQueue[te.name] = recipe
				end
			end
		end
	end

	Milo:registerTask(GenericImportTask)
end