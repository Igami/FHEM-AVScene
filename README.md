# AVScene
  AVScene ist ein Hilfsmodul das Szenen für Audio- und Videokonsum steuert.
  
## Define
  `define <name> AVScene [<dev1>] [<dev2>] [<dev3>] ...`  

## Set
Erweiterung:
 * `deviceAdd <name>`
 * `deviceRemove <name>`
 * `ignorePower <name>`
 * `input_<name> <set>`
 * `deviceMedia <name>`
 * `deviceVolume <name>`
 * `commandsOn_<name> <set>`
 * `commandsOff_<name> <set>`
 * `.delays_<name> powerOn:<value> input:<value> interKey:<value> interDevice:<value>`
 * `config done`
 
Steuerung:
 * sceneSwitcher
    * `scene <name>`
 * scene
    * `on`
    * `off`
 * deviceMedia
    * `play`
    * `pause`
    * `stop`
    * `channelUp`
    * `channelDown`
 * deviceVolume
    * `volumeUp`
    * `volumeDown`
    * `mute`
 * `config`
 * weitere Befehle durch das `commands`-Attribut

## Get
 * `defaultSequence on|off`
 * `delays <name>`

## Readings
* `state Initialized|on|off|play|pause|stop`

## Attribute
 * `autocreate 1|0`
 * `commands <command>:<FHEM command>`
 * `commandsOff <name>:<set>,<name>:<set>,...`
 * `commandsOn <name>:<set>,<name>:<set>,...`
 * `deviceAudio <name>`
 * `deviceMedia <name>`
 * `disable 0|1`
 * `evalSpecials <key1>=<value1> <key2>=<value2> ...`
 * `ignorePower <dev1>,<dev2>,...`
 * `inputSelection <name>=<set>,<name>=<set>,...`
 * `sequecneOn <name>:<set>,<name>=<set>,...`
 * `sequecneOff <name>:<set>,<name>=<set>,...`
 * [`readingFnAttributes`](#readingFnAttributes)