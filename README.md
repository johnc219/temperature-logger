# temperature-logger
Log temperature readings in degrees Celsius.

## Installation

```bash
git clone git@github.com:johnc219/temperature-logger.git
```

##### Hardware
Required parts:
- `TI MSP430G2553` microcontroller with Launchpad
- `TMP36` temperature sensor
- `.1uF` capacitor (see `TMP36` [datasheet](https://cdn.sparkfun.com/datasheets/Sensors/Temp/TMP35_36_37.pdf) Basic Temperature Sensor Connections)
>Note the 0.1 μF bypass capacitor on the input. This capacitor
should be a ceramic type, have very short leads (surface-mount
is preferable), and be located as close as possible in physical
proximity to the temperature sensor supply pin. Because these
temperature sensors operate on very little supply current and
may be exposed to very hostile electrical environments, it is
important to minimize the effects of radio frequency interference
(RFI) on these devices.

![Breadboard](/temperature_logger_bb.png?raw=true "Breadboard")

![Schematic](/temperature_logger_schem.png?raw=true "Schematic")

##### Firmware
1. [Install Energia](http://energia.nu/download/)
1. Ensure the `MSP430G2` drivers are [installed](http://energia.nu/pin-maps/guide_msp430g2launchpad/)
1. Open `temperature_sensor.ino`
1. Connect the Launchpad via USB
1. Select `MSP430g2553` under `Tools > Board`, and select the correct serial port under `Tools > Serial Port`. If you don’t see a selectable serial port, you likely have a driver issue.
1. Upload `temperature_sensor.ino` to the `MSP430G2553`

##### Software
1. Ensure `elixir` is [installed](https://elixir-lang.org/install.html)
1. Ensure [C compiler dependencies](https://github.com/nerves-project/nerves_uart#c-compiler-dependencies) are satisfied
1. Navigate to `temperature_logger_umbrella/`
1. Run `mix deps.get`
1. Run `mix compile`

## Usage
```bash
# in the project root folder
cd temperature_logger_umbrella/

# start elixir application
iex -S mix

# In another terminal start a tcp client
telnet 127.0.0.1 4040

# display available ports
> enumerate

# start logging with default period and file path
> start

# stop logging
> stop

# start logging every 60 seconds to the default file
> start 60

> stop

# start logging every 20 seconds to the file `~/logs/temperature.log`
> start 20 ~/logs/temperature.log
```

### TCP Client API

`enumerate`

Prints out the available ports.

---

`start <period> <path>`

Starts logging temperature data.

Option | Description | Default
--- | --- | ---
`period` | How often a sample should be recorded, in seconds (minimum is 1) | 1
`log_path` | The path to the file that is written to | `/temperature_logger_umbrella/log/temperature_logger.log`

---

`stop`

Stops logging temperature data.
