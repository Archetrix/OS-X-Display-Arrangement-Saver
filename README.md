OS-X-Display-Arrangement-Saver
==============================

Simple console tool for saving and restoring display arrangement on OS X.

For doing it, the tool uses serial numbers for the displays and not the IDs that OS X assigns to them.

[Download tool](https://github.com/archetrix/OS-X-Display-Arrangement-Saver/releases)

#### Usage 

`da help` - prints help text <br />
`da list` - prints a list of all connected screens <br />
`da save <path_to_plist>` - saves current display arrangement to file <br />
`da load <path_to_plist>` - loads display arrangement from file <br />
If `<path_to_plist>` is not specified - the default is used: '~/Desktop/ScreenArrangement.plist'

#### Note
This fixes Y-axis arrangement and includes some work to ensure non-edid displays work, too

Now includes memorizing and restoring the mirror flag.

#### Known Problems
I've experienced lately that display manufacturers leave the serial number section in EDID
data untouched (e.g zero) and thus if you happen to have two identical displays you end up
not being able to determine which one goes where.
Adding to that is the fact, that Apple macOS separates the display info from the port it
plugged into. I know why they do it but it sucks in this case.
** If anyone has an idea on how to tie display and port to a unique identifier ping me **

I have found out for some displays you can identify different audio latency values
comparing HDMI 1 to HDMI 2 on the display. So you can differentiate two displays by using
different HDMI IN ... probably not a solid solution but it helped me in a situation and
i've included this in my build.