OS-X-Display-Arrangement-Saver
==============================

Simple console tool for saving and restoring display arrangement on OS X.

For doing it, the tool uses serial numbers of the displays and not the IDs that OS X assigns to them.

[Download tool](https://github.com/Archetrix/OS-X-Display-Arrangement-Saver/releases)

#### Usage

`da help` - prints help text <br />
`da list` - prints a list of all connected screens and their current setup<br />
`da save <path_to_plist>` - saves current display arrangement to file <br />
`da load <path_to_plist>` - loads display arrangement from file <br />
If `<path_to_plist>` is not specified - the default is used: '~/Desktop/ScreenArrangement.plist'

#### Note
This fixes Y-axis arrangement and includes some work to ensure non-edid displays work, too

Now includes memorizing and restoring the mirror flag.

Includes code to tie displays to their port so a setup with identical displays that don't have a serial number in EDID data will be recognized by their physical connection.
Be aware that unplugged displays have to be connected to the exact same port again to be recognized.

#### Known Problems 
Currently there are no problems. See previous issues below

[solved this one 19.0.3.2019]
* I've experienced lately that display manufacturers leave the serial number section in EDID
* data untouched (e.g zero) and thus if you happen to have two identical displays you end up
* not being able to determine which one goes where.
* Adding to that is the fact, that Apple macOS separates the display info from the port it
* is plugged into. I know why they do it but it sucks in this case.

[removed this bad idea in favor of other solution 19.03.2019]
* I have found out for some displays you can identify different audio latency values
* comparing HDMI 1 to HDMI 2 on the display. So you can differentiate two displays by using
* different HDMI IN ... probably not a solid solution but it helped me in a situation and
* i've included this in my build.
