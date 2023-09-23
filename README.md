# TILT-SHIP-FRAMEWORK-FOR-VALKYRIEN-SKIES-2-AND-COMPUTERCRAFT

## BEFORE YOU USE ANY OF THIS
MAKE SURE TO USE VS2-Tournament Version **1.1.0** or higher.

Trying to fly any of my ships without it WILL crash the physics thread (and your game).

YOU HAVE BEEN WARNED

It's not out yet since the making of this post

but there is a test build available in the [Valkyrien Skies 2 Discord server](https://discord.com/invite/dWwM8G3)

## HOW TO SETUP DEFAULT SHIP TEMPLATES
  1. Prepare 3 CC(ComputerCraft):Turtles with Wireless Modems. 
        + Two REGULAR CC:Turtles to act as the BOW and STERN thruster controllers
        + One REGULAR/ADVANCED CC:Turtle with an extra mounted PlayerDetector peripheral to act as the main computer
        + Note that REGULAR and ADVANCED Turtles weigh different. The following schematics are calibrated to use the turtles as mentioned above.
  2. Spawn in either `ten_thruster_template_vertical.nbt` or `ten_thruster_template_horizontal.nbt` in your world using schematics
  3. Copy the contents of the `DEFAULT_10_THRUSTER_TILTSHIP_FRAMEWORK` folder (BOW_COMPONENT_CONTROLLER_COMPUTER,STERN_COMPONENT_CONTROLLER_COMPUTER and MAIN_COMPUTER) to the `computercraft/computer` directory and rename the three folders to their respective Turtle Computer IDs
  4. Edit the `startup.lua` script inside the `BOW_COMPONENT_CONTROLLER_COMPUTER` and `STERN_COMPONENT_CONTROLLER_COMPUTER` folder to start either `(V/H)10T_(BOW/STERN).lua`
       + use `V10T_(BOW/STERN).lua` for `ten_thruster_template_vertical.nbt`
       + use `H10T_(BOW/STERN).lua` for `ten_thruster_template_horizontal.nbt`
  5. Edit the `DRONE_DESIGNATION` and `DRONE_TO_COMPONENT_BROADCAST_CHANNEL` constants in the `(V/H)10T_(BOW/STERN).lua` scripts to serve the correct drone
  6. Edit the `DRONE_ID` and `COMPONENT_TO_DRONE_CHANNEL` constants in the `MAIN_COMPUTER/firmwareScript.lua` file to match what we did in step 3
  7. Run the `(V/H)10T_(BOW/STERN).lua` scripts on both the BOW & STERN Component Controllers (the two turtles around the main turtle). 
       + The `startup.lua` script earlier should automatically run them when you boot up the turtles.
  8. Run `firmwareScript.lua` in the Main Turtle. If everything goes well your drone should start hovering in place.
  9. Test it with an ImpulseGun (VS2-Tournament) or grab it with a Gravitron (VS2-Clockwork). It should try and come back to its original position.
  10. On the Main Turtle's terminal window, hit 'q' to safely stop the drone.
      + Send the "hush" command over rednet to shut it down remotely.

### HOW TO MODIFY FLIGHT BEHAVIOR
  1. Open `MAIN_COMPUTER/firmwareScript.lua` with your preferred text editor
  2. Scroll down to the `drone` instance and override its `customFlightLoopBehavior()` function

    ...
    local drone = TenThrusterTemplateVertical(instance_configs)
    
    function drone:customFlightLoopBehavior()
    
    end
    
    drone:run()
    ...
    
  3. To move the ship to a new world position set the drone's `target_global_position` variable

    ...
     
    local new_pos = vector.new(17,-48,10)
    
    function drone:customFlightLoopBehavior()
      self.target_global_position = new_pos
    end
    
    ...

  4. Run `firmwareScript.lua` in the Main Turtle. The ship should start moving to the new position
  5. Safely stop the drone by hitting 'q' on the Main Turtle's terminal
  6. Place a Redstone Lamp at the front of the Main Turtle
  7. Use `position_error` and `rotation_error` to gauge how far away the ship is from its target position and rotation

    ...
     
    local new_pos = vector.new(17,-48,10)
    
    function drone:customFlightLoopBehavior()
      self.target_global_position = new_pos
      
      if (self.position_error:length()<0.5) then
        redstone.setAnalogOutput("front",15)
      else
        redstone.setAnalogOutput("front",0)
      end
      
    end
    
    ...
    
  5. Restart the script.
      + the lamp should light up when the drone reaches its target position and shut off when it's not
      + try pulling the drone away to watch the lamp react to the change in position
  6. Use `target_rotation` to set the drones orientation. 
      + Remember this variable accepts quaternions

    ...
     
    local new_pos = vector.new(17,-48,10)
    
    function drone:customFlightLoopBehavior()
      self.target_global_position = new_pos
      
      if (self.position_error:length()<0.5) then
        redstone.setAnalogOutput("front",15)
        self.target_rotation = quaternion.fromToRotation(self.target_rotation:localPositiveY(), upward)*self.target_rotation
      else
        redstone.setAnalogOutput("front",0)
      end
      
    end
    
    ...
    
  7. 

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

## NOTE
Until Valkyrien Computers releases an update to expose a ships inertia tensors, we need to calculate it manually for each new tilt-ship we build. I made this java project that uses CreateMod Schematic files to do just that:
https://github.com/19PHOBOSS98/TILT_SHIP_MINECRAFT_SCHEMATIC_INERTIA_TENSOR_CALCULATOR/tree/main
