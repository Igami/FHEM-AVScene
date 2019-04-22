# AVScene
  AVScene ist ein Hilfsmodul das Szenen für Audio- und Videokonsum steuert.
  
## Define
  `define <name> AVScene [<dev1>] [<dev2>] [<dev3>] ...`  

## Set
Erweiterung:
 * `commandsOn_<name>`
 * `config done`
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
 * `config`
 * weitere Befehle durch das `commands`-Attribut

## Get
 * `defaultSequence on|off`

## Readings
* `state Initialized|play|pause|stop|off`

## Attribute
 * `autocreate 1|0`
 * `commands <command>:<FHEM command>`
 * `commandsOff <name>:<set>`
 * `commandsOn <name>:<set>`
 * `configMode 1|0`
 * `deviceAudio <name>`
 * `deviceMedia <name>`
 * `disable 0|1`
 * `evalSpecials <key>=<value>`
 * `inputSelection <name>=<FHEM command>`
 * `sequecneOn <name>:<FHEM command>`
 * `sequecneOff <name>:<FHEM command>`
 * [`readingFnAttributes`](#readingFnAttributes)