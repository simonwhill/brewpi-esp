# Chiller-pump firmware (ESP32-S2) — wiring and flashing

This fork of [thorrak/brewpi-esp](https://github.com/thorrak/brewpi-esp) adds one feature to the
ESP32-S2 build: the **Door** terminal becomes an output that drives a chiller recirculation pump.
The pump runs whenever the controller is in **Beer Constant, Beer Profile or Fridge Constant**
(idle, heating or cooling) and stops when the controller is set to **Off**.

Releases are named `<upstream version>-pump` (e.g. `v16-pump`) and are rebuilt automatically when
Thorrak publishes a new stable release. BrewFlasher does not list these builds, so you flash them
with a web flasher or esptool as below.

## 1. Wiring

The Door terminal (2-pin screw terminal on the RJ-45 sensor board; GPIO11 on the S2 Mini) is a
**3.3 V logic signal**. It cannot power a relay coil or a pump directly.

- Use a **solid-state relay with a DC input of 3–32 V** (e.g. a "DA" type SSR for an AC pump), or a
  relay module that triggers from a 3.3 V signal.
- Door terminal **signal** → SSR input **+**; Door terminal **GND** → SSR input **−**.
- The SSR's load side switches the pump's mains/supply. Mains wiring must be done safely and to
  your local regulations.

## 2. Which file to flash

| File | When | Flash address | What it keeps |
|------|------|---------------|---------------|
| `esp32_s2_wifi_pump_full.bin` | First install on a controller | `0x0` | Nothing: WiFi settings and device assignments are erased |
| `esp32_s2_wifi_pump_app.bin`  | Upgrading a controller that already runs a `-pump` build | shown in the release notes (`0xe000`) | WiFi and all device assignments |

Never flash the full image to upgrade: it overwrites the filesystem where your Heat/Cool/sensor
assignments are stored.

## 3. Put the S2 Mini into download mode

Plug the S2 Mini into your computer by USB. Hold the **0** button, press and release **RST**, then
release **0**. It now shows up as a serial port.

## 4a. Flash with a web browser (Chrome or Edge)

1. Open <https://espressif.github.io/esptool-js/>.
2. Click **Connect** and choose the S2 Mini's port.
3. In the file list, set the **Flash Address** from the table above and choose the `.bin` file.
4. Click **Program**. When it finishes, press **RST** on the S2 Mini.

## 4b. Flash with esptool (command line)

```sh
pip install esptool
# first install:
esptool --chip esp32s2 write_flash 0x0 esp32_s2_wifi_pump_full.bin
# upgrade:
esptool --chip esp32s2 write_flash 0xe000 esp32_s2_wifi_pump_app.bin
```

Press **RST** afterwards.

## 5. Set it up in Fermentrack 2

1. After a first install, set up WiFi and reconnect the controller to Fermentrack 2 as you would
   for a normal BrewPi-ESP, then re-assign Heat, Cool and the temperature sensors.
2. If a **door sensor** was ever assigned on **pin 11**, uninstall it first. Left in place it
   fights the pump output and can stop the pump from switching on.
3. In the controller's device list, assign the pin device on **pin 11** to **Chamber Fan**.
   (Fermentrack may still label it "Door"; that is just the pin's name.)
4. Make sure **invert is off** for that device. This firmware offers pin 11 with invert off by
   default, but check it: inverted, the pump would run in Off mode and stop otherwise.

## 6. Check it

With an LED or multimeter on the Door terminal (before connecting the pump), the output should be
on in Fridge Constant, Beer Constant and Beer Profile, and off within a few seconds of selecting
Off. After a power cut it comes back in the saved mode, so the pump restarts by itself.

Note: this pin is off for a moment while the controller boots, so the pump briefly stops on a reboot.
