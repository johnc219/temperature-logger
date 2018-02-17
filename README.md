# temperature-logger
Log ambient temperature readings in degrees Celsius and Fahrenheit.

Motivation:
The ideal temperature while sleeping is between [60 and 67](https://sleep.org/articles/temperature-for-sleep/) degrees Fahrenheit. I am using this application to experimentally tune my heating systems (heater or thermostat settings) to the sweet spot. Of course, this application can be used for many other use cases where temperature logging is desired.

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

`start <period> <path>`

Starts logging temperature data.

Option | Description | Default
--- | --- | ---
`period` | How often a sample should be recorded, in seconds (minimum is 1) | 1
`log_path` | The path to the file that is written to | `/temperature_logger_umbrella/log/temperature_logger.log`

`stop`

Stops logging temperature data.

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

![Breadboard](assets/temperature_logger_bb.png?raw=true "Breadboard")

![Schematic](assets/temperature_logger_schem.png?raw=true "Schematic")

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

## Extending to different boards
If you are using a board other than the MSP430, you can implement your own microcontroller code. The Elixir app expects to receive UART messages every second. The message is expected to be a JSON string **with a `\n` at the end** in the following format:
```
{ "celsius": <Number>, "fahrenheit": <Number> }
```
The code must adhere to the following rules:
- Baudrate of 9600 b/s
- Must start sending data when a "O" is received
- Must stop sending data when an "F" is received
- When sending, data must be set at a period of 1 sec
- The data must be sent in format described above

**Caveat**

There is no current option to specify the port in the TCP client API. You must invoke
```TemperatureLogger.start_logging(TemperatureLogger, [port: <String>])
```
directly in `iex`.

## Q&A
>Why not just buy a thermometer?

This application is to automate *logging* temperatures in addition to reading them.
