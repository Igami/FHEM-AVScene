# AVScene
  AVScene ist ein Hilfsmodul das Szenen für Audio- und Videokonsum steuert.
  
## Define
  `define <name> AVScene [<dev1>] [<dev2>] [<dev3>] ...`  

## Set
Erweiterung:
 * `deviceAdd <name>`
 * `deviceRemove <name>`
 * `deviceMedia <name>`
 * `deviceVolume <name>`
 * `input_<name>`
 * `updateInputSelection`

Steuerung:
 * `on`
 * `off`
 * `play`
 * `pause`
 * `stop`
 * `volumeUp`
 * `volumeDown`
 * `mute`
 * `channelUp`
 * `channelDown`
 * weitere Befehle durch das `commands`-Attribut

## Get
 * `defaultSequence on|off`

## Readings
* `state Initialized|play|pause|stop|off`

## Attribute
 * `commands <command>:<FHEM command>`
 * `configMode 1|0`
 * `deviceAudio <name>`
 * `deviceMedia <name>`
 * `disable 0|1`
 * `evalSpecials <key>=<value>`
 * `inputSelection <name>:<FHEM command>`
 * `sequeceOn <name>:<FHEM command>`
 * `sequeceOff <name>:<FHEM command>`
 * [`readingFnAttributes`](#readingFnAttributes)