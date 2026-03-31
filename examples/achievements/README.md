# PD Achievements > Pulp Integration Template

> **NOTE:**\
> The achievements library can be found at https://github.com/PlaydateSquad/pd-achievements.
> In order to compile this example, you'll need to go grab it and put the `achievements/`
> folder in here. Please go to the original repository for further information and documentation.
>
> This template currently has no provisions in place for creating cards/icons without the use of the SDK compiler.

## Configuration

This template adds the following fields to *'config.json'*:
- **(required) achData:** Your achievement configuration data, as described in [achievements.schema.json](https://github.com/PlaydateSquad/pd-achievements/blob/main/achievements.schema.json). (See also [the human-readable documentation](https://github.com/PlaydateSquad/pd-achievements/blob/main/docs/achievements.md#schema).)
- **toastConfig:** The [config for the achievements/toasts module](https://github.com/PlaydateSquad/pd-achievements/blob/main/docs/toasts.md#schema).
	- **pauseWhileToasting**: By default, Pulp temporarily pauses while a toast is onscreen. Setting this additional flag to `false` will disable this.
	- **miniMode**: By default this is explicitly set to true, in order to get around some weird esoteric bugs.
	- **renderMode**: Unconfigurable. The template always sets this to automatic for the sake of required internal logic.
- **viewerConfig:** The [config for the achievements/viewer module](https://github.com/PlaydateSquad/pd-achievements/blob/main/docs/viewer.md#schema).


## Info

The purpose of the included example game is to demonstrate how to grant achievements
within your Pulp project. This example integrates achievements in two ways:

1. The computers in Game 1 directly call the Achievements API functions to grant and advance achievements.

2. The floppy disks in Game 2 are unmodified from the basic Pulp example game, but the game script's `loop` event
	is continually attempting to advance the related achievement to the value of the 'disks' variable using string formatting.
	- Note that because neither the 'disks' variable nor the disks which have been collected are persisted, the achievement resets
		itself whenever Game 2 is restarted.