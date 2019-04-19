# AVScene
  AVScene ist ein Hilfsmodul das Szenen für Video- oder Audiokonsum steuert.
  
## Define
  `define <name> AVScene [<dev1>] [<dev2>] [<dev3>] ...`  

## Set
Medien-Steuerung:
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

 Modul-Erweiterung:
 * `deviceAdd <name>`
 * `deviceRemove <name>`

## Get
 * `defaultSequence on|off`

## Readings
* `state Initialized|play|pause|stop|off`

## Attribute
 * `commands <command>:<FHEM command>`
 * `deviceAudio <name>`
 * `deviceMedia <name>`
 * `disable 0|1`
 * `inputSelection <name>:<FHEM command>`
 * `sequeceOn <name>:<FHEM command>`
 * `sequeceOff <name>:<FHEM command>`
 * [`readingFnAttributes`](#readingFnAttributes)