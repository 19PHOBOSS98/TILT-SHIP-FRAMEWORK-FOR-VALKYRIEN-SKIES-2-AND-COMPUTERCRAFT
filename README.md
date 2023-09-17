# TILT-SHIP-FLIGHT-CONTROL-SYSTEM-FRAMEWORK-FOR-VALKYRIEN-SKIES-2-AND-COMPUTERCRAFT

## HOW TO USE
  1. Copy the contents of the `DEFAULT_10_THRUSTER_TILTSHIP_FRAMEWORK` folder (BOW_COMPONENT_CONTROLLER_COMPUTER,STERN_COMPONENT_CONTROLLER_COMPUTER and MAIN_COMPUTER) to the `computercraft/computer` directory and rename the three folders to their respective Turtle Computer IDs
  2. Edit the `startup.lua` script inside the `BOW_COMPONENT_CONTROLLER_COMPUTER` and `STERN_COMPONENT_CONTROLLER_COMPUTER` folder to start either `V10T_(BOW/STERN).lua` or `H10T_(BOW/STERN).lua` depending on the kind of thruster template used (TenThrusterTemplateHorizontal or TenThrusterTemplateVertical)
  3. Edit the `DRONE_DESIGNATION` and `DRONE_TO_COMPONENT_BROADCAST_CHANNEL` constants in the `(V/H)10T_(BOW/STERN).lua` scripts to serve the correct drone
  4. Edit the `DRONE_ID ` and `COMPONENT_TO_DRONE_CHANNEL` constants in the `MAIN_COMPUTER/firmwareScript.lua` file
  5. Configure the `designated_ship_id` and `designated_player_name` in `MAIN_COMPUTER/firmwareScript.lua`
  6. Run the `(V/H)10T_(BOW/STERN).lua` scripts on both the BOW & STERN Component Controllers (the two turtles around the main turtle). If you hit restart on both of the turtles they should run the script automatically using the `startup.lua` script
  7. Run the `firmwareScript.lua` script in the Main Turtle. If everything goes well your drone should start hovering in place. Test it with an ImpulseGun (VS2-Tournament). It should try and keep its orientation and position after trying to smacking it away. 

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
    
    
