# Id ##########################################################################
# $Id:  $

# copyright ###################################################################
#
# 37_AVScene.pm
#
# Copyright by igami
#
# This file is part of FHEM.
#
# FHEM is free software: you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation, either version 2 of the License, or (at your option) any later
# version.
#
# FHEM is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# FHEM.  If not, see <http://www.gnu.org/licenses/>.

# packages ####################################################################
package FHEM::AVScene;

use strict;
use warnings;
# use HttpUtils;
# use JSON;
# use List::Util;
# use Time::Seconds;
# use POSIX;
# use Data::Dumper;
# use English;
# use Storable;
use GPUtils qw(GP_Import GP_Export);
# use experimental qw( switch );

our $device;
our $version = '0.1.0';
our @errors;
our %defaultDelays = (
  "input"       => 1000,
  "interDevice" =>  500,
  "interKey"    =>  100,
  "powerOff"    => 2000,
  "powerOn"     => 2000
);

GP_Export(qw(Initialize));

# initialize ##################################################################
sub Initialize {
  my ($hash) = @_;

  $hash->{DefFn}    = "FHEM::AVScene::Define";
  $hash->{SetFn}    = "FHEM::AVScene::Set";
  $hash->{GetFn}    = "FHEM::AVScene::Get";
  $hash->{AttrFn}   = "FHEM::AVScene::Attr";
  $hash->{NotifyFn} = "FHEM::AVScene::Notify";

  $hash->{AttrList} = join( " ",
    (
      "autocreate:1,0",
      "commands:textField-long",
      "commandsOff:sortable",
      "commandsOn:sortable",
      "deviceVolume",
      "deviceMedia",
      "ignorePower:sortable",
      "disable:1,0",
      "evalSpecials:textField-long",
      "inputSelection:textField-long",
      "sequenceOff:sortable",
      "sequenceOn:sortable",
      "$::readingFnAttributes"
    )
  );
}

# regular Fn ##################################################################
sub Define {
  my ($hash, $def) = @_;
  my ($SELF, $TYPE, $devices) = split(/\s+/, $def);

  return("$SELF needs at least one device to handle") unless($devices);
  return("It's not allowed to add AVScene to itself.") if($devices =~ /$SELF/);

  DefineIfInitDone($hash);
}

sub Set {
  my ($hash, @a) = @_;
  my $TYPE = $hash->{TYPE};
  my $MODE = $hash->{MODE};
  my %sets;

  return("\"set $TYPE\" needs at least one argument") if(@a < 2);

  my $SELF     = shift @a;
  my $argument = shift @a;
  my $value    = join(" ", @a) if (@a);

  if
  ($hash->{type} eq "sceneSwitcher"){
    if
    (::ReadingsVal($SELF, ".config", 1)){
      %sets = (
        ".createNewScene" => ".createNewScene:textField",
        "config"          => "config:done",
        "deviceAdd"       => "deviceAdd:".join(",", ::devspec2array("TYPE=$TYPE:FILTER=NAME!=$SELF")),
        "deviceRemove"    => "deviceRemove:$hash->{devices}"
      );
    }
    else{
      %sets = (
        "config"       => "config:noArg",
        "scene"        => "scene:off,$hash->{devices}"
      );
    }
  }
  elsif
  (::ReadingsVal($SELF, ".config", 1)){
    %sets = (
      %{$hash->{commandsOn}},
      %{$hash->{commandsOff}},
      %{$hash->{inputSelection}},
      %{$hash->{delays}},
      "config"        => "config:done",
      "deviceAdd"     => "deviceAdd:".join(",", ::devspec2array("room!=hidden:FILTER=NAME!=$SELF")),
      ".deviceMedia"  => ".deviceMedia:$hash->{devices}",
      "deviceRemove"  => "deviceRemove:$hash->{devices}",
      ".deviceVolume" => ".deviceVolume:$hash->{devices}",
      "ignorePower"   => "ignorePower:$hash->{devices}",
      "updateDeviceCommands" => "updateDeviceCommands:noArg"
    );
  }
  else{
    %sets = (
      "config"      => "config:noArg",
      "off"         => "off:noArg",
      "on"          => "on:noArg"
    );
    %sets = (
      %sets,
      "mute"        => "mute:noArg",
      "volumeDown"  => "volumeDown:noArg",
      "volumeUp"    => "volumeUp:noArg"
    ) if(::AttrVal($SELF, "deviceVolume", undef));
    %sets = (
      %sets,
      "play"        => "play:noArg",
      "pause"       => "pause:noArg",
      "stop"        => "stop:noArg",
      "next"        => "next:noArg",
      "prev"        => "prev:noArg",
      "left"        => "left:noArg",
      "right"       => "right:noArg",
      "up"          => "up:noArg",
      "down"        => "down:noArg",
      "back"        => "back:noArg",
      "enter"       => "enter:noArg"
    ) if(::AttrVal($SELF, "deviceMedia", undef));
  }

  return(
    "Unknown argument $argument, choose one of ".
    join(" ", sort(values %sets))
  ) unless(exists($sets{$argument}));

  if
  ($argument =~ /^(channel(Down|up)|(pause|play|stop))$/){
    ::CommandSet(undef, ::AttrVal($SELF, "deviceMedia", undef)." $argument");
    ::readingsSingleUpdate($hash, "state", $3, 1) if($3);
  }
  elsif
  ($argument =~ /^(mute|volume(Down|Up))$/){
    ::CommandSet(undef, ::AttrVal($SELF, "deviceVolume", undef)." $argument");
  }
  elsif
  ($argument =~ /^(off|on)$/){
    handleSequence($hash, $1);
  }
  elsif
  ($argument eq "scene"){
    return switchScene($hash, $value);
  }
  elsif
  ($argument eq "config"){
    if
    ($value){
      ::readingsSingleUpdate($hash, ".config", 0, 0);
    }
    else
    {
      ::readingsSingleUpdate($hash, ".config", 1, 0);
    }
  }
  elsif
  ($argument =~ /^device(Add|Remove)$/){
    my %devices = map{$_, 1} split(",", $hash->{devices}.",$value");
    delete $devices{$value} if($argument eq "deviceRemove");
    my $devices = ($hash->{type} eq "sceneSwitcher" ? "switcher " : "").join(" ", sort(keys %devices));

    ::CommandDefMod(undef, "$SELF $TYPE $devices");
  }
  elsif
  ($argument =~ /^input_(.+)$/){
    my (undef, $inputSelection, @inputSelection) = ::parseParams(::AttrVal($SELF, "inputSelection", "$1=\"$1\""));  
    $inputSelection->{$1} = $value;

    foreach (sort keys %{$inputSelection}){
      $inputSelection->{$_} = "\"$inputSelection->{$_}\"" if($inputSelection->{$_} =~ m/\s/);
      push(@inputSelection, "$_=$inputSelection->{$_}");
    }

    ::CommandAttr(undef, "$SELF inputSelection ".join("\n", @inputSelection));
  }
  elsif
  ($argument =~ /^.delays_(.+)$/){
    my (undef, $delays) = ::parseParams($value);

    foreach (keys %{$delays}){
      next if($delays->{$_} eq "default");

      ::CommandAttr(undef, "$1 delay_$_ $delays->{$_}");
    }
    update_deviceCommands($hash);
  }
  elsif
  ($argument =~ /^.(device(Media|Volume))$/){
    ::readingsSingleUpdate($hash, $argument, $value, 0);
    ::CommandAttr(undef, "$SELF $1 $value");
  }
  elsif
  ($argument eq "ignorePower"){
    ::CommandAttr(undef, "$SELF $argument ".join(",", $value, ::AttrVal($SELF, $argument, undef)));
  }
  elsif
  ($argument =~ /^command(On|Off)_(.+)$/){
    my @commands = ::AttrVal($SELF, "commands$1", undef);
    push(@commands, "$2:$value");

    ::CommandAttr(undef, "$SELF commands$1 ".join(",", sort @commands));
  }
  elsif
  ($argument eq "updateDeviceCommands"){
    update_deviceCommands($hash);
  }
  elsif
  ($argument eq ".createNewScene"){
    my ($name, $copy, $rest) = split(/\s+/, $value);

    if
    ($copy){
      return("$name is not defined") unless($::defs{$name});
      return("$copy already defined") if($::defs{$copy});
      return("$name ist no $TYPE device") if($::defs{$name}->{TYPE} ne $TYPE);

      ::CommandSet(undef, "$SELF deviceAdd $copy");
      return(::fhem("copy $name $copy ".($rest||"")));
    }
    else{
      return("$name already defined") if($::defs{$name});
      ::CommandSet(undef, "$SELF deviceAdd $name");
      return(::CommandDefine(undef, "$name $TYPE undef"));
    }
  }

  return;
}

sub Get {
  my ($hash, @a) = @_;
  my $TYPE = $hash->{TYPE};
  my $SELF = shift @a;

  return unless(::ReadingsVal($SELF, ".config", 0));
  return("\"get $TYPE\" needs at least one argument") if(@a < 1);

  my $argument = shift @a;
  my $value = join(" ", @a) if (@a);
  my %gets = (
    "defaultSequence"   => "defaultSequence:on,off",
    "delays"            => "delays:$hash->{devices}"
  );
  my $ret;

  return(
    "Unknown argument $argument, choose one of ".
    join(" ", sort(values %gets))
  ) unless(exists($gets{$argument}));

  if
  ($argument eq "defaultSequence"){
    return sequence_power("$SELF|$value|1");
  }
  elsif
  ($argument eq "delays"){
    return(
      join("\n",
        "$value delays (ms)",
        "",
        "powerOn:     ".::AttrVal($value, "delay_powerOn",     "$defaultDelays{powerOn} (default)"),
        "input:       ".::AttrVal($value, "delay_input",       "$defaultDelays{input} (default)"),
        "interKey:    ".::AttrVal($value, "delay_interKey",    "$defaultDelays{interKey} (default)"),
        "interDevice: ".::AttrVal($value, "delay_interDevice", "$defaultDelays{interDevice} (default)")
      )
    )
  }

  return $ret;
}

sub Attr {
  my ($cmd, $SELF, $argument, $value) = @_;
  my $hash = $::defs{$SELF};
  my $TYPE = $hash->{TYPE};

  ::Log3($SELF, 5, "$TYPE ($SELF) - entering Attr");

  if
  ($argument eq "autocreate"){
    ::InternalTimer(gettimeofday()+0.001, "sequence_power", "$SELF|on");
    ::InternalTimer(gettimeofday()+0.001, "sequence_power", "$SELF|off");
  }
  elsif
  ($argument eq "commands"){

  }
  elsif
  ($argument eq "commandsOff"){
    $value =~ s/\n//g;
    $value =~ s/,/,\n/g;
    $_[3] = $value;

    ::InternalTimer(gettimeofday()+0.001, "sequence_power", "$SELF|off");
  }
  elsif
  ($argument eq "commandsOn"){
    $value =~ s/\n//g;
    $value =~ s/,/,\n/g;
    $_[3] = $value;

    ::InternalTimer(gettimeofday()+0.001, "sequence_power", "$SELF|on");
  }
  elsif
  ($argument eq "configMode"){

  }
  elsif
  ($argument eq "deviceVolume"){

  }
  elsif
  ($argument eq "deviceMedia"){

  }
  elsif
  ($argument eq "disable"){

  }
  elsif
  ($argument eq "evalSpecials"){
    evalSpecials($hash, $value);

    ::Log3($SELF, 5, "$TYPE ($SELF) - evalSpecials $hash->{evalSpecials}");
  }
  elsif
  ($argument eq "ignorePower"){
    $_[3] = join(",\n", sort(split(/,\s*/, $value)));

    ::InternalTimer(gettimeofday()+0.001, "sequence_power", "$SELF|on");
    ::InternalTimer(gettimeofday()+0.001, "sequence_power", "$SELF|off");
  }
  elsif
  ($argument eq "inputSelection"){
    ::InternalTimer(gettimeofday()+0.001, "sequence_power", "$SELF|on");
  }
  elsif
  ($argument =~ /sequence(On|Off)/){
    $value =~ s/\n//g;
    $value =~ s/,/,\n/g;
    $_[3] = $value;
  }

  return;
}
  
sub Notify {
  my ($hash, $dev_hash) = @_;

  return if($dev_hash->{NAME} ne "global");

  DefineIfInitDone($hash) if(grep(m/^INITIALIZED|REREADCFG$/, @{$dev_hash->{CHANGED}}));
}

# module Fn ###################################################################
sub DefineIfInitDone {
  my ($hash) = @_;
  my $SELF = $hash->{NAME};
  my $TYPE = $hash->{TYPE};
  my @devices = split(/\s+/, $hash->{DEF});
  my $type = "scene";

  if
  ($devices[0] eq "switcher"){
    shift @devices;
    $type = "sceneSwitcher";
  }

  $hash->{devices} = join(",", sort(@devices));
  $hash->{type} = $type;

  ::readingsSingleUpdate($hash, "state", "Initialized", 1);

  return if($type eq "sceneSwitcher");

  update_deviceCommands($hash);

  sequence_power("$SELF|on");
  sequence_power("$SELF|off");

  return;
}

sub diff {
  my %diff;
  @diff{ split(/,\s*/, shift) } = undef;
  delete @diff{ split(/,\s*/, shift) };

  return(join(",", keys %diff));
}

sub evalSpecials {
  my ($hash, $AttrVal) = @_;
  my $SELF = $hash->{NAME};
  my $TYPE = $hash->{TYPE};

  my $parseParams = $AttrVal || ::AttrVal($SELF, "evalSpecials", undef);

  ::Log3($SELF, 5, "$TYPE ($SELF) - entering evalSpecials");

  my(undef, %evalSpecials) = ::parseParams($parseParams);

  $hash->{evalSpecials} = \%evalSpecials;
}

sub handleSequence {
  my ($hash, $sequence) = @_;
  my $SELF = $hash->{NAME};
  my $TYPE = $hash->{TYPE};
  my $scene = ::ReadingsVal($SELF, "scene", $SELF);
  my (%devices, $now);

  ::Log3($SELF, 5, "$TYPE ($SELF) - entering handleSequence");

  my (undef, $inputSelection) = ::parseParams(::AttrVal($scene, "inputSelection", undef));
  my @sequence = ::AttrVal($SELF, "sequence".ucfirst($sequence), ::ReadingsVal($SELF, ".sequence".ucfirst($sequence), undef));
  $sequence[0] =~ s/\n//g;

  return unless($sequence[0]);

  @sequence = split(",", $sequence[0]);

  foreach (@sequence){
    $_ =~ m/([^:]*):(.+)/;
    $devices{$1} = 1;
  }

  my %delay = map{$_, 0} keys %devices;

  ::readingsSingleUpdate($hash, "state", "executing", 1);

  for (my $i=0; $i<int(@sequence); $i++){
    $sequence[$i] =~ m/(.+):(.+)/;
    $sequence[$i] = "sleep ".($delay{$1}/1000)."; set $1 $2;";

    foreach my $device (keys %delay){
      next if($device eq $1);
      my $newDelay = $delay{$device}-$delay{$1};
      my $delay_interDevice = ::AttrVal($1, "delay_interDevice", $defaultDelays{interDevice});

      $delay{$device} = $newDelay > $delay_interDevice ? $newDelay : $delay_interDevice;
    }

    if
    ($2 eq "on"){
      $delay{$1} = ::AttrVal($1, "delay_powerOn", $defaultDelays{powerOn});
    }
    elsif
    (%{$inputSelection}{$1} eq $2){
      $delay{$1} = ::AttrVal($1, "delay_input", $defaultDelays{input});
    }
    else{
      $delay{$1} = ::AttrVal($1, "delay_interKey", $defaultDelays{interKey});
    }
  }

  my $maxDelay = ($delay{(sort {$delay{$b} <=> $delay{$a}} keys %delay)[0]}/1000);
  push(@sequence, "sleep $maxDelay; setreading $SELF state ".::ReadingsVal($SELF, "scene", $sequence).";");

  if
  ($sequence eq "switch"){
    $scene = ::ReadingsVal($SELF, "scene", "off");
    my $previousScene = ::ReadingsVal($SELF, "previousScene", "off");

    push(@sequence, "setreading $previousScene state off;") if($previousScene ne "off");
    push(@sequence, "setreading $scene state on;") if($scene ne "off");
  }

  ::AnalyzeCommandChain(undef, join(" ", @sequence));
}

sub sequence_power {
  my ($SELF, $command, $get) = split("\\|", shift);
  my $Command = ucfirst($command);
  my ($hash) = $::defs{$SELF};
  my $TYPE = $hash->{TYPE};
  my $devices = $hash->{devices};
  my @devicesPower = split(",", diff($devices, ::AttrVal($SELF, "ignorePower", "")));
  my (%commandsPower, %commands, @ret);
  my(undef, $inputSelection) = ::parseParams(::AttrVal($SELF, "inputSelection", undef));

  if
  ($command eq "on"){
    # handle commands on
    $commandsPower{"$_:on"} = ::AttrVal($_, "delay_powerOn", $defaultDelays{powerOn})
      for(@devicesPower);
    foreach (sort { $commandsPower{$b} <=> $commandsPower{$a} } keys %commandsPower) {
      push(@ret, $_);
    }
    # handle commands input
    $commands{"$_:$inputSelection->{$_}"} = ::AttrVal($_, "delay_input", $defaultDelays{input})
      for(keys %{$inputSelection});
  }

  # handle commands other
  for (split(",\n", ::AttrVal($SELF, "commands$Command", ""))){
    $_ =~ m/(.+):.+/;
    $commands{$_} = ::AttrVal($1, "delay_interKey", $defaultDelays{interKey});
  }
  foreach (sort { $commands{$a} <=> $commands{$b} } keys %commands) {
    push(@ret, $_);
  }

  if
  ($command eq "off"){
    # handle commands off
    $commandsPower{"$_:off"} = ::AttrVal($_, "delay_interKey", $defaultDelays{interKey}) 
      for(@devicesPower);
    foreach (sort { $commandsPower{$b} <=> $commandsPower{$a} } keys %commandsPower) {
      push(@ret, $_);
    }
  }

  return join("\n", @ret) if($get);

  my $argument = "sequence$Command";
  my $value = join(",", @ret);

  ::CommandAttr(undef, "$SELF $argument $value") if(::AttrVal($SELF, "autocreate", 1) && ::AttrVal($SELF, "argumen", "") ne $value);
}

sub switchScene {
  my ($hash, $scene) = @_;
  my $TYPE = $hash->{TYPE};
  my $SELF = $hash->{NAME};

  unless
  ($scene eq "off"){
    return("$scene is not defined") unless($::defs{$scene});
    return("$scene ist no $TYPE device") if($::defs{$scene}->{TYPE} ne $TYPE);
  }

  my $previousScene = ::ReadingsVal($SELF, "scene", "off");
  my (%sequenceOn, %sequenceOff);

  my @sequenceOn = split(/,\s*/, ::AttrVal($scene, "sequenceOn", ""));
  @sequenceOn{@sequenceOn} = 0..$#sequenceOn;
  delete $sequenceOn{$_} foreach (split(/,\s*/, ::AttrVal($previousScene, "sequenceOn", "")));

  my %devices = map{$_, 1} split(",", ::InternalVal($scene, "devices", ""));
  my @sequenceOff = split(/,\s*/, ::AttrVal($previousScene, "sequenceOff", ""));
  @sequenceOff{@sequenceOff} = 0..$#sequenceOff;

  foreach (keys %sequenceOff){
    $_ =~ m/([^:]*):(.+)/;
    delete $sequenceOff{$_} if($devices{$1});
  }

  ::readingsBeginUpdate($hash);
  ::readingsBulkUpdate($hash, "previousScene", $previousScene);
  ::readingsBulkUpdate($hash, "scene", $scene);
  ::readingsBulkUpdate(
    $hash, ".sequenceSwitch", join(",\n", 
      sort {$sequenceOn{$a} <=> $sequenceOn{$b}} keys %sequenceOn,
      sort {$sequenceOff{$a} <=> $sequenceOff{$b}} keys %sequenceOff
    )
  );
  ::readingsEndUpdate($hash, 1);

  handleSequence($hash, "switch");

  return;
}

sub update_deviceCommands {
  my ($hash) = @_;
  my $TYPE = $hash->{TYPE};
  my $SELF = $hash->{NAME};
  my $devices = $hash->{devices};
  my (%commandsOn, %commandsOff, %inputSelection, %delays);

  ::readingsBeginUpdate($hash);

  for my $device (split(",", $devices)){
    ::addToDevAttrList($device, $_) for("delay_powerOn", "delay_input", "delay_interKey", "delay_interDevice");
    ::readingsBulkUpdate(
      $hash, ".delays_$device", join("\n",
        "powerOn="    .::AttrVal($device, "delay_powerOn",     "default"),
        "input="      .::AttrVal($device, "delay_input",       "default"),
        "interKey="   .::AttrVal($device, "delay_interKey",    "default"),
        "interDevice=".::AttrVal($device, "delay_interDevice", "default")
      )
    );
    $delays{".delays_$device"}  = ".delays_$device:textField-long";

    my @sets = split(" ", ::CommandSet(undef, "$device ?"));
    splice(@sets, 0, 6);

    next unless(@sets);

    for (my $i=0; $i<int(@sets); $i++){
      next unless($sets[$i] =~ m/([^:]*):(.+)/);
      
      $sets[$i] = join(",", map{"$1#$_"} split(",", $2));
    }
    
    my $commands = join(",", sort(@sets));

    $commandsOn{"commandOn_$device"}  = "commandOn_$device:$commands";
    $commandsOn{"commandOff_$device"} = "commandOff_$device:$commands";
    $inputSelection{"input_$device"}  = "input_$device:$commands";
   }

  ::readingsEndUpdate($hash, 0);

  $hash->{commandsOn} = \%commandsOn;
  $hash->{commandsOff} = \%commandsOff;
  $hash->{inputSelection} = \%inputSelection;
  $hash->{delays} = \%delays;

  return;
}

1;

# commandref ##################################################################
=pod
=item helper
=item summary    
=item summary_DE 

=begin html

=end html
=begin html_DE

=end html_DE
=cut
