# TILT-SHIP-FRAMEWORK-FOR-VALKYRIEN-SKIES-2-AND-COMPUTERCRAFT

## BEFORE YOU USE ANY OF THIS
MAKE SURE TO USE VS2-Tournament Version **1.1.0** or higher.

Trying to fly any of my ships without it WILL crash the physics thread (and your game).

YOU HAVE BEEN WARNED

It's not out yet since the making of this post

but there is a test build that you can get. It's pinned in the `Tournament` channel

over at the [Valkyrien Skies 2 Discord server](https://discord.com/invite/dWwM8G3)

## TUTORIAL WORLD DOWNLOAD
Planet Minecraft:
https://www.planetminecraft.com/project/tilt-ship-tutorial-part-1-world-save/

## HOW TO SETUP DEFAULT SHIP TEMPLATES
  1. Prepare 3 CC(ComputerCraft):Turtles with Wireless Modems. 
        + Two REGULAR CC:Turtles to act as the BOW and STERN thruster controllers
        + One REGULAR/ADVANCED CC:Turtle with an extra mounted PlayerDetector peripheral to act as the main computer
        + Note that REGULAR and ADVANCED Turtles weigh different. The following schematics are calibrated to use the turtles as mentioned above.
  2. Spawn in either `ten_thruster_template_vertical.nbt` or `ten_thruster_template_horizontal.nbt` in your world using schematics
  3. Make sure to upgrade the Tournament Thrusters to Tier 2.
  4. Copy the contents of the `DEFAULT_10_THRUSTER_TILTSHIP_FRAMEWORK` folder (BOW_COMPONENT_CONTROLLER_COMPUTER,STERN_COMPONENT_CONTROLLER_COMPUTER and MAIN_COMPUTER) to the `computercraft/computer` directory and rename the three folders to their respective Turtle Computer IDs
  5. Edit the `startup.lua` script inside the `BOW_COMPONENT_CONTROLLER_COMPUTER` and `STERN_COMPONENT_CONTROLLER_COMPUTER` folder to start either `(V/H)10T_(BOW/STERN).lua`
       + use `V10T_(BOW/STERN).lua` for `ten_thruster_template_vertical.nbt`
       + use `H10T_(BOW/STERN).lua` for `ten_thruster_template_horizontal.nbt`
  6. Edit the `DRONE_DESIGNATION` and `DRONE_TO_COMPONENT_BROADCAST_CHANNEL` constants in the `(V/H)10T_(BOW/STERN).lua` scripts to serve the correct drone
  7. Edit the `DRONE_ID` and `COMPONENT_TO_DRONE_CHANNEL` constants in the `MAIN_COMPUTER/firmwareScript.lua` file to match what we did in step 3
  8. Run the `(V/H)10T_(BOW/STERN).lua` scripts on both the BOW & STERN Component Controllers (the two turtles around the main turtle). 
       + The `startup.lua` script earlier should automatically run them when you boot up the turtles.
  9. Run `firmwareScript.lua` in the Main Turtle. If everything goes well your drone should start hovering in place.
  10. Test it with an ImpulseGun (VS2-Tournament) or grab it with a Gravitron (VS2-Clockwork). It should try and come back to its original position.
  11. On the Main Turtle's terminal window, hit 'q' to safely stop the drone.
      + Send the "hush" command over rednet to shut it down remotely.

## HOW TO MODIFY FLIGHT BEHAVIOR
  1. Open `MAIN_COMPUTER/firmwareScript.lua` with your preferred text editor
  2. Scroll down to the `drone` instance and override its `customFlightLoopBehavior()` function

    ...
    local drone = TenThrusterTemplateVertical(instance_configs)
    
    function drone:customFlightLoopBehavior()
    
    end
    
    drone:run()
    ...
  ### POSITIONING
  To move the ship to a new world position set the drone's `target_global_position` variable

    ...
     
    local new_pos = vector.new(17,-48,10)
    
    function drone:customFlightLoopBehavior()
      self.target_global_position = new_pos
    end
    
    ...

  Run `firmwareScript.lua` in the Main Turtle. The ship should start moving to the new position

  ### ORIENTING
  6. Use `target_rotation` to set the drones orientation. 
      + Remember this variable accepts quaternions
      + [a quick quaternion refresher](https://youtu.be/1yoFjjJRnLY?si=DR1MBM3ReQFn6nXj)
    ...
     
    local new_pos = vector.new(17,-48,10)
    
    local upward = vector.new(0,1,0)
    
    function drone:customFlightLoopBehavior()
    
      self.target_global_position = new_world_pos
      self.target_rotation = quaternion.fromToRotation(self.target_rotation:localPositiveY(), upward)*self.target_rotation

    end
    
    ...
    
  7. Restart the script.
      + The drone should point upwards when it gets to position and westward when it's not
      + Pull the drone away and watch it travel towards the target position while pointing to the west the whole time
  
  ### REACTING TO CHANGES IN POSITION AND ROTATION
  1. Place a Redstone Lamp at the front of the Main Turtle
  2. Use `position_error` and `rotation_error` to gauge how far away the ship is from its target position and rotation
      + `position_error` (vector3)
      + `rotation_error` (quaternion)
    ...
     
    local new_pos = vector.new(17,-48,10)

    local upward = vector.new(0,1,0)
    local west = vector.new(-1,0,0)
    
    function drone:customFlightLoopBehavior()
      self.target_global_position = new_pos
      self.target_rotation = quaternion.fromToRotation(self.target_rotation:localPositiveY(), upward)*self.target_rotation
      
      if (self.position_error:length()<0.5) then
        if (self.rotation_error:length()<1) then
          redstone.setAnalogOutput("front",15)
        end
      else
        redstone.setAnalogOutput("front",0)
      end
      
    end
    
    ...

  3. Restart the script.
      + the lamp should light up when the drone reaches its target position and shut off when it's not
      + try pulling the drone away to watch the lamp react to the change in position

  ### SEQUENCING
  Note that you SHOULD NOT use anything that YIELDS in `customFlightLoopBehavior`. That includes `os.sleep()`, so we need to be a bit more creative in adding sequenced actions.
  The following flight behavior sequences the drone as follows:
  1. fly to world position ( starting at: (17,-48,10) )
      + pointing to the west
      + lamp off
  2. when world position is reached:
      + turn lamp on
      + reorient to point upward
  3. when ship is finished reorienting:
      + hold position for 7 seconds
  4. when timer finishes:
      + switch `target_position` to next waypoint
  5. repeat
    
    ...
    
    local new_world_pos = vector.new(17,-48,10)
    
    local waypoints = {
      vector.new(15,-48,15),
      vector.new(-15,-48,15),
      vector.new(-15,-48,-15),
      vector.new(15,-48,-15),
    }
    
    local upward = vector.new(0,1,0)
    local west = vector.new(-1,0,0)
    
    local prev_time = os.clock()
    local inc = 1
    local timer = 0
    local delay = 7 --seconds
    
    function drone:customFlightLoopBehavior()
    
      self.target_global_position = new_world_pos
      
      if (self.position_error:length()<0.5) then
      
        redstone.setAnalogOutput("front",15)
        
        self.target_rotation = quaternion.fromToRotation(self.target_rotation:localPositiveY(), upward)*self.target_rotation
        
        if (self.rotation_error:length()<1) then
          local current_time = os.clock()
          timer = timer + (current_time - prev_time)
          prev_time = current_time
          
          if (timer >= delay) then
            if (inc <= #waypoints) then
              new_world_pos = waypoints[inc]
              inc = inc + 1
            end
          end
          timer = math.fmod(timer,delay)
        end
        
      else
      
        redstone.setAnalogOutput("front",0)
        self.target_rotation = quaternion.fromToRotation(self.target_rotation:localPositiveY(), west)*self.target_rotation
        timer = 0
        
      end
    
    end
    
    ...

## HOW TO BUILD ON TOP OF THE DEFAULT SHIP TEMPLATES

Before you decide to add more blocks to the template lets talk about **Inertia Tensors** for a second, shall we?
	
Inertia tensors are something that we use to calculate how much torque we need to spin a ship in a certain way.

The kind of blocks you use and where you put it around a ship "adds" to the ships inertia tensor.

Here are a few quick videos if you want to learn more about them:

[What Are Inertia Tensors?](https://youtu.be/Ch-VTxTIt0E?si=3AP0bUOdv7Ck5koE)

[Understanding How Inertia Tensors Are Calculated?](https://youtu.be/SbTSATs-DBA?si=6KFKVtuJIv3T1f6t)

These DEFAULT SHIP TEMPLATES that I made for you guys already have their own pre-calculated inertia tensors. 
That's why they're stable enough to fly on their own right out of the box.

We might have been able to get away with adding one block to our ship earlier but if we want to add more blocks 
we would need to calculate new inertia tensors for our ship.

Until VS2-Computers releases the next update to get the ships inertia tensors for us,
we need to calculate it ourselves for the time being.

I made a separate java project to do just that:
https://github.com/19PHOBOSS98/TILT_SHIP_MINECRAFT_SCHEMATIC_INERTIA_TENSOR_CALCULATOR

Once you're done building and calculated your ships' new Inertia tensors copy them to the `ship_constants_config` table in our `firmwareScript`:
![2023-09-23_13 36 15](https://github.com/19PHOBOSS98/TILT-SHIP-FRAMEWORK-FOR-VALKYRIEN-SKIES-2-AND-COMPUTERCRAFT/assets/37253663/04ea49f2-e5f3-4ae7-b211-276cab403227)

```
(sample inertia tensor from tiltship.nbt)
...

ship_constants_config = {
		DRONE_ID = 420,

		LOCAL_INERTIA_TENSOR = 
		{
		x=vector.new(136646.51503523337,-9.454405916416484,-14.304751273285392),
		y=vector.new(-9.454405916416484,46999.84092653317,-9393.157747854602),
		z=vector.new(-14.304751273285392,-9393.157747854602,92866.67131793764)
		},
		LOCAL_INV_INERTIA_TENSOR = 
		{
		x=vector.new(7.318152495530465E-6,1.7324144970439088E-9,1.302482280966349E-9),
		y=vector.new(1.7324144970439094E-9,2.1715643027917508E-5,2.1964659919891727E-6),
		z=vector.new(1.3024822809663507E-9,2.1964659919891753E-6,1.099029130362614E-5)
		},
	},

...

```

You might decide to use higher tier Tournament thrusters or reconfigure the `thrusterSpeed` settings from the Tournament Mod configs for your new ship if it ever gets too heavy.
If you do, make sure to let the drone know about it by overriding the drones' `MOD_CONFIGURED_THRUSTER_SPEED` and `THRUSTER_TIER` settings in the `ship_constants_config` table.
The ship templates that I made (`TenThrusterTemplateHorizontal` and `TenThrusterTemplateVertical`) have these values at `10'000` and `2` respectively by default.

When upgrading Tournament thruster tiers make sure that they all match.

```
...

ship_constants_config = {
		DRONE_ID = 420,

		LOCAL_INERTIA_TENSOR = 
		{
		x=vector.new(136646.51503523337,-9.454405916416484,-14.304751273285392),
		y=vector.new(-9.454405916416484,46999.84092653317,-9393.157747854602),
		z=vector.new(-14.304751273285392,-9393.157747854602,92866.67131793764)
		},
		LOCAL_INV_INERTIA_TENSOR = 
		{
		x=vector.new(7.318152495530465E-6,1.7324144970439088E-9,1.302482280966349E-9),
		y=vector.new(1.7324144970439094E-9,2.1715643027917508E-5,2.1964659919891727E-6),
		z=vector.new(1.3024822809663507E-9,2.1964659919891753E-6,1.099029130362614E-5)
		},

		MOD_CONFIGURED_THRUSTER_SPEED = 10000,
		THRUSTER_TIER = 5,
	},

...

```



## DEFAULT TILT-SHIP FRAMEWORK

* DroneBaseClass

  * RemoteControlDrone (Optional, to use the SWARM UI)
    
    * TenThrusterTemplateHorizontal
  
      * KiteTTTH
    
      * TracerHorizontal
      
    * TenThrusterTemplateVertical
    
      * KiteTTTV
      
      * TracerVertical
      
      * SegmentBody
      
      * HoundTurretDrone

## YOU MIGHT ALSO LIKE THESE:
+ DRONE SWARM MANAGER UI:
+ HOUND TURRETS:
	+ VIDEO SHOWCASE
 	+ BUILD SETUP GUIDE
+ GEOFISH:
	+ VIDEO SHOWCASE
 	+ BUILD SETUP GUIDE
+ CHORD:
+ GLARE:
+ Mr. GRIN:
