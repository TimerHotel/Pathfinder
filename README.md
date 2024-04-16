# Pathfinder

Pathfinder lets you easily Pathfind for Character Models, including the Player. Pathfinder can be used both on the Server and Client.

## Getting Started
Pathfinder uses OOP, and requires you to provide a Character Model containing a Humanoid in order to work. To create a new Pathfinder Class, type
```lua
local Pathfinder = PathfinderMod.new(Character)
```

**Now that you have your Pathfinder class ready, using it is as simple as doing:**
```lua
Pathfinder:Pathfind(DesiredDestinatin) --Vector3 or CFrame
```
**A path can be extended from the current desired destination by using:**
```lua
Pathfinder:Extend(DesiredDestinatin) --Vector3 or CFrame
```
  
**To cancel Pathfinder, you can use:**
```lua
Pathfinder:Cancel()
```
This will automatically halt Character movement, and clean Pathfinder.  
  
**Once you are done using Pathfinder on a Character, ensure that you destroy it:**
```lua
Pathfinder:Destroy()
```

### Additional Features
**Pathfinder also lets you Visualize your path:**
```lua
Pathfinder.VisualizePath = true
```
This is useful for debugging your paths.

Pathfinder will automatically cancel movement if it is currently moving a player, and the player tries to move themselves
**You can Disable Player Movement while the player is being moved by Pathfinder:**
```lua
Pathfinder:AllowPlayerMovement(false)
```
Allowed Movement will persist for future Pathfinding, so set it to true if you need your players to be able to move again while Pathfinder is moving them.

## Additional Information
> [!WARNING]
> Pathfinder uses Trove by Sleitnick to Clean up when it finishes or gets cancelled - You must download this yourself and ensure it gets required properly in `Pathfinder.lua`. Trove is referred to as Maid in Pathfinder (Not to be confused with the actual Maid module).

> [!CAUTION]
> If you use Pathfinder on a Player Character from the Server, the Ownership will NOT automatically be set to Server - you must ensure this happens yourself, and reset it when Pathfinder Finishes!