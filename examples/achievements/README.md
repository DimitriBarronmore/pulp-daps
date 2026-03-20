The achievements library can be found at https://github.com/PlaydateSquad/pd-achievements.
In order to compile this example, you'll need to go grab it and put the `achievements/`
folder in here. Please go to the original repository for further information and documentation.

This example integrates achievements in two ways:
- The computers in Game 1 directly call the Achievements API functions to grant and advance achievements.
- The floppy disks in Game 2 are unmodified from the basic Pulp example game, but the game script's `loop` event
	is continually attempting to advance the related achievement to the value of the 'disks' variable using string formatting.
	- Note that because neither the 'disks' variable nor the disks which have been collected are persisted, the achievement resets
		itself whenever Game 2 is restarted.