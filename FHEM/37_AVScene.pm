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
package main;
  use strict;
  use warnings;

# variables ###################################################################
my %AVScene_defaultDelays = (
   "input"        => 1000
  ,"interDevice"  =>  500
  ,"interKey"     =>  100
  ,"powerOn"      => 2000
);

# forward declarations ########################################################
sub AVScene_Initialize($);

sub AVScene_Define($$);
sub AVScene_Set($@);
sub AVScene_Get($@);
sub AVScene_Attr(@);
sub AVScene_Notify($$);

sub AVScene_DefineInInitDone($);
sub AVScene_diff($$);
sub AVScene_evalSpecials($;$);
sub AVScene_handleSequence($$);
sub AVScene_sequence_power($);
sub AVScene_switchScene($);
sub AVScene_update_deviceCommands($);

# initialize ##################################################################
sub AVScene_Initialize($) {
  my ($hash) = @_;
  my $TYPE = "AVScene";

  $hash->{DefFn}    = $TYPE."_Define";
  $hash->{UndefFn}  = $TYPE."_Undefine";
  $hash->{SetFn}    = $TYPE."_Set";
  $hash->{GetFn}    = $TYPE."_Get";
  $hash->{AttrFn}   = $TYPE."_Attr";
  $hash->{NotifyFn} = $TYPE."_Notify";

  $hash->{AttrList} = ""
    ."autocreate:1,0 "
    ."commands:textField-long "
    ."commandsOff:textField-long "
    ."commandsOn:textField-long "
    ."deviceVolume "
    ."deviceMedia "
    ."ignorePower:sortable "
    ."disable:1,0 "
    ."evalSpecials:textField-long "
    ."inputSelection:textField-long "
    ."sequenceOff:sortable "
    ."sequenceOn:sortable "
    .$readingFnAttributes
  ;
}

# regular Fn ##################################################################
sub AVScene_Define($$) {
  my ($hash, $def) = @_;
  my ($SELF, $TYPE, @devices) = split(/[\s]+/, $def);

  my $devices = join(",", sort(@devices));

  return("It's not allowed to add AVScene to itself.") if($devices =~ /$SELF/);

  AVScene_DefineInInitDone($hash);
}

sub AVScene_Set($@) {
  my ($hash, @a) = @_;
  my $TYPE = $hash->{TYPE};
  my $MODE = $hash->{MODE};
  my %AVScene_sets;

  return("\"set $TYPE\" needs at least one argument") if(@a < 2);

  my $SELF     = shift @a;
  my $argument = shift @a;
  my $value    = join(" ", @a) if (@a);

  if
  ($hash->{type} eq "sceneSwitcher"){
    if
    (ReadingsVal($SELF, ".config", 1)){
      %AVScene_sets = (
         "config"       => "config:done"
        ,"deviceAdd"    => "deviceAdd:".join(",", devspec2array("TYPE=$TYPE"))
        ,"deviceRemove" => "deviceRemove:$hash->{devices}"
      );
    }
    else{
      %AVScene_sets = (
         "config"       => "config:noArg"
        ,"scene"        => "scene:off,$hash->{devices}"
      );
    }
  }
  elsif
  (ReadingsVal($SELF, ".config", 1)){
    %AVScene_sets = (
       %{$hash->{commandsOn}}
      ,%{$hash->{commandsOff}}
      ,%{$hash->{inputSelection}}
      ,%{$hash->{delays}}
      ,"config"       => "config:done"
      ,"deviceAdd"    => "deviceAdd:".join(",", devspec2array("room!=hidden"))
      ,"deviceMedia"  => "deviceMedia:$hash->{devices}"
      ,"deviceRemove" => "deviceRemove:$hash->{devices}"
      ,"deviceVolume" => "deviceVolume:$hash->{devices}"
      ,"ignorePower"  => "ignorePower:$hash->{devices}"
      ,"updateDeviceCommands" => "updateDeviceCommands:noArg"
    );
  }
  else{
    %AVScene_sets = (
       "config"       => "config:noArg"
      ,"off"          => "off:noArg"
      ,"on"           => "on:noArg"
    );
    %AVScene_sets = (%AVScene_sets
      ,"mute"         => "mute:noArg"
      ,"volumeDown"   => "volumeDown:noArg"
      ,"volumeUp"     => "volumeUp:noArg"
    ) if(AttrVal($SELF, "deviceVolume", undef));
    %AVScene_sets = (%AVScene_sets
      ,"channelDown"  => "channelDown:noArg"
      ,"channelUp"    => "channelUp:noArg"
      ,"pause"        => "pause:noArg"
      ,"play"         => "play:noArg"
      ,"stop"         => "stop:noArg"
    ) if(AttrVal($SELF, "deviceMedia", undef));
  }

  return(
    "Unknown argument $argument, choose one of ".
    join(" ", sort(values %AVScene_sets))
  ) unless(exists($AVScene_sets{$argument}));

  if
  ($argument =~ /^(channel(Down|up)|(pause|play|stop))$/){
    CommandSet(undef, AttrVal($SELF, "deviceMedia", undef)." $argument");
    readingsSingleUpdate($hash, "state", $3, 1) if($3);
  }
  elsif
  ($argument =~ /^(mute|volume(Down|Up))$/){
    CommandSet(undef, AttrVal($SELF, "deviceVolume", undef)." $argument");
  }
  elsif
  ($argument =~ /^(off|on)$/){
    AVScene_handleSequence($hash, $1);
  }
  elsif
  ($argument eq "scene"){
    AVScene_switchScene($hash);
  }
  elsif
  ($argument eq "config"){
    if
    ($value){
      readingsSingleUpdate($hash, ".config", 0, 0);
    }
    else
    {
      readingsSingleUpdate($hash, ".config", 1, 0);
    }
  }
  elsif
  ($argument =~ /^device(Add|Remove)$/){
    my %devices = map{$_, 1} split(",", $hash->{devices}.",$value");
    delete $devices{$value} if($argument eq "deviceRemove");
    my $devices = join(" ", sort(keys %devices));

    CommandDefMod(undef, "$SELF $TYPE $devices");
  }
  elsif
  ($argument =~ /^input_(.+)$/){
    my (undef, $inputSelection, @inputSelection) = parseParams(AttrVal($SELF, "inputSelection", "$1=\"$1\""));  
    $inputSelection->{$1} = $value;

    foreach (sort keys %{$inputSelection}){
      $inputSelection->{$_} = "\"$inputSelection->{$_}\"" if($inputSelection->{$_} =~ m/\s/);
      push(@inputSelection, "$_=$inputSelection->{$_}");
    }

    CommandAttr(undef, "$SELF inputSelection ".join("\n", @inputSelection));
  }
  elsif
  ($argument =~ /^.delays_(.+)$/){
    my (undef, $delays) = parseParams($value);

    foreach (keys %{$delays}){
      next if($delays->{$_} eq "default");

      CommandAttr(undef, "$1 delay_$_ $delays->{$_}");
    }
    AVScene_update_deviceCommands($hash);
  }
  elsif
  ($argument =~ /^device(Media|Volume)$/){
    CommandAttr(undef, "$SELF $argument $value");
  }
  elsif
  ($argument eq "ignorePower"){
    CommandAttr(undef, "$SELF $argument ".join(",", $value, AttrVal($SELF, $argument, undef)));
  }
  elsif
  ($argument =~ /^command(On|Off)_(.+)$/){
    my @commands = AttrVal($SELF, "commands$1", undef);
    push(@commands, "$2:$value");

    CommandAttr(undef, "$SELF commands$1 ".join("\n", sort @commands));
  }
  elsif
  ($argument eq "updateDeviceCommands"){
    AVScene_update_deviceCommands($hash);
  }

  return;
}

sub AVScene_Get($@) {
  my ($hash, @a) = @_;
  my $TYPE = $hash->{TYPE};
  my $SELF = shift @a;

  return unless(ReadingsVal($SELF, ".config", 0));
  return("\"get $TYPE\" needs at least one argument") if(@a < 1);

  my $argument = shift @a;
  my $value = join(" ", @a) if (@a);
  my %AVScene_gets = (
     "defaultSequence"   => "defaultSequence:on,off"
    ,"delays"            => "delays:$hash->{devices}"
  );
  my $ret;

  return(
    "Unknown argument $argument, choose one of ".
    join(" ", sort(values %AVScene_gets))
  ) unless(exists($AVScene_gets{$argument}));

  if
  ($argument eq "defaultSequence"){
    return AVScene_sequence_power("$SELF|$value|1");
  }
  elsif
  ($argument eq "delays"){
    return(
      join("\n",
         "$value delays (ms)"
        ,""
        ,"powerOn:     ".AttrVal($value, "delay_powerOn",     "$AVScene_defaultDelays{powerOn} (default)")
        ,"input:       ".AttrVal($value, "delay_input",       "$AVScene_defaultDelays{input} (default)")
        ,"interKey:    ".AttrVal($value, "delay_interKey",    "$AVScene_defaultDelays{interKey} (default)")
        ,"interDevice: ".AttrVal($value, "delay_interDevice", "$AVScene_defaultDelays{interDevice} (default)")
      )
    )
  }

  return $ret;
}

sub AVScene_Attr(@) {
  my ($cmd, $SELF, $argument, $value) = @_;
  my $hash = $defs{$SELF};
  my $TYPE = $hash->{TYPE};

  Log3($SELF, 5, "$TYPE ($SELF) - entering AVScene_Attr");

  if
  ($argument eq "autocreate"){
    InternalTimer(gettimeofday()+0.001, "AVScene_sequence_power", "$SELF|on");
    InternalTimer(gettimeofday()+0.001, "AVScene_sequence_power", "$SELF|off");
  }
  elsif
  ($argument eq "commands"){

  }
  elsif
  ($argument eq "commandsOff"){
    InternalTimer(gettimeofday()+0.001, "AVScene_sequence_power", "$SELF|off");
  }
  elsif
  ($argument eq "commandsOn"){
    InternalTimer(gettimeofday()+0.001, "AVScene_sequence_power", "$SELF|on");
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
    AVScene_evalSpecials($hash, $value);

    Log3($SELF, 5, "$TYPE ($SELF) - evalSpecials $hash->{evalSpecials}");
  }
  elsif
  ($argument eq "ignorePower"){
    $_[3] = join(",\n", sort(split(/,\s*/, $value)));

    InternalTimer(gettimeofday()+0.001, "AVScene_sequence_power", "$SELF|on");
    InternalTimer(gettimeofday()+0.001, "AVScene_sequence_power", "$SELF|off");
  }
  elsif
  ($argument eq "inputSelection"){
    InternalTimer(gettimeofday()+0.001, "AVScene_sequence_power", "$SELF|on");
  }
  elsif
  ($argument =~ /sequence(On|Off)/){
    $value =~ s/\n//g;
    $value =~ s/,/,\n/g;
    $_[3] = $value;
  }

  return;
}
  
sub AVScene_Notify($$) {
  my ($hash, $dev_hash) = @_;

  return if($dev_hash->{NAME} ne "global");

  AVScene_DefineInInitDone($hash) if(grep(m/^INITIALIZED|REREADCFG$/, @{$dev_hash->{CHANGED}}));
}

# module Fn ###################################################################
sub AVScene_DefineInInitDone($) {
  my ($hash) = @_;
  my $SELF = $hash->{NAME};
  my $TYPE = $hash->{TYPE};
  my $devices = join(",", sort(split(" ", $hash->{DEF})));

  my $type = devspec2array("$devices:FILTER=TYPE!=$TYPE") ? "scene" : "sceneSwitcher";

  $hash->{devices} = $devices;
  $hash->{type} = $type;

  readingsSingleUpdate($hash, "state", "Initialized", 1);

  return if($type eq "sceneSwitcher");

  AVScene_update_deviceCommands($hash);

  AVScene_sequence_power("$SELF|on");
  AVScene_sequence_power("$SELF|off");
}

sub AVScene_diff($$) {
  my %diff;
  @diff{ split(/,\s*/, shift) } = undef;
  delete @diff{ split(/,\s*/, shift) };

  return(join(",", keys %diff));
}

sub AVScene_evalSpecials($;$) {
  my ($hash, $AttrVal) = @_;
  my $SELF = $hash->{NAME};
  my $TYPE = $hash->{TYPE};

  my $parseParams = $AttrVal || AttrVal($SELF, "evalSpecials", undef);

  Log3($SELF, 5, "$TYPE ($SELF) - entering AVScene_evalSpecials");

  my(undef, %evalSpecials) = parseParams($parseParams);

  $hash->{evalSpecials} = \%evalSpecials;
}

sub AVScene_handleSequence($$) {
  my ($hash, $sequence) = @_;
  my $SELF = $hash->{NAME};
  my $TYPE = $hash->{TYPE};

  Log3($SELF, 5, "$TYPE ($SELF) - entering AVScene_handleSequence");

  my (undef, $inputSelection) = parseParams(AttrVal($SELF, "inputSelection", undef));  
  my @sequence = AttrVal($SELF, "sequence".ucfirst($sequence), undef);
  $sequence[0] =~ s/\n//g;
  my %delay = map{$_, 0} split(",", $hash->{devices});

  return unless($sequence[0]);

  readingsSingleUpdate($hash, "state", "executing", 1);

  @sequence = split(",", $sequence[0]);
  for (my $i=0; $i<int(@sequence); $i++){
    $sequence[$i] =~ m/(.+):(.+)/;
    $sequence[$i] = "sleep ".($delay{$1}/1000)."; set $1 $2;";

    foreach my $device (keys %delay){
      next if($device eq $1);
      $delay{$device} = max($delay{$device}, ($delay{$1}+AttrVal($1, "delay_interDevice", $AVScene_defaultDelays{interDevice})));
    }

    if
    ($2 eq "on"){
      $delay{$1} += AttrVal($1, "delay_powerOn", $AVScene_defaultDelays{powerOn});
    }
    elsif
    (%{$inputSelection}{$1} eq $2){
      $delay{$1} += AttrVal($1, "delay_input", $AVScene_defaultDelays{input});
    }
    else{
      $delay{$1} += AttrVal($1, "delay_interKey", $AVScene_defaultDelays{interKey});
    }
  }
  
  push(@sequence, "sleep ".(max(values %delay)/1000)."; setreading $SELF state $sequence;");

  AnalyzeCommandChain(undef, join(" ", @sequence));
}

sub AVScene_sequence_power($) {
  my ($SELF, $command, $get) = split("\\|", shift);
  my $Command = ucfirst($command);
  my ($hash) = $defs{$SELF};
  my $TYPE = $hash->{TYPE};
  my $devices = $hash->{devices};
  my @devicesPower = split(",", AVScene_diff($devices, AttrVal($SELF, "ignorePower", undef)));
  my (%commandsPower, %commands, @ret);
  my(undef, $inputSelection) = parseParams(AttrVal($SELF, "inputSelection", undef));

  if
  ($command eq "on"){
    # handle commands on
    $commandsPower{"$_:on"} = AttrVal($_, "delay_powerOn", $AVScene_defaultDelays{powerOn})
      for(@devicesPower);
    foreach (sort { $commandsPower{$b} <=> $commandsPower{$a} } keys %commandsPower) {
      push(@ret, $_);
    }
    # handle commands input
    $commands{"$_:$inputSelection->{$_}"} = AttrVal($_, "delay_input", $AVScene_defaultDelays{input})
      for(keys %{$inputSelection});
  }

  # handle commands other
  for (split("\n", AttrVal($SELF, "commands$Command", ""))){
    $_ =~ m/(.+):.+/;
    $commands{$_} = AttrVal($1, "delay_interKey", $AVScene_defaultDelays{interKey});
  }
  foreach (sort { $commands{$a} <=> $commands{$b} } keys %commands) {
    push(@ret, $_);
  }

  if
  ($command eq "off"){
    # handle commands off
    $commandsPower{"$_:off"} = AttrVal($_, "delay_interKey", $AVScene_defaultDelays{interKey}) 
      for(@devicesPower);
    foreach (sort { $commandsPower{$b} <=> $commandsPower{$a} } keys %commandsPower) {
      push(@ret, $_);
    }
  }

  return join("\n", @ret) if($get);

  my $argument = "sequence$Command";
  my $value = join(",", @ret);

  CommandAttr(undef, "$SELF $argument $value") if(AttrVal($SELF, "autocreate", 1) && AttrVal($SELF, "argumen", "") ne $value);
}

sub AVScene_switchScene($) {
  my ($hash) = @_;

  # get current scene
  # execute ("sequenceOn next" - "sequenceOn current")
  # executing("sequenceOff current" - "devices next")

  return;
}

sub AVScene_update_deviceCommands($) {
  my ($hash) = @_;
  my $TYPE = $hash->{TYPE};
  my $SELF = $hash->{NAME};
  my $devices = $hash->{devices};
  my (%commandsOn, %commandsOff, %inputSelection, %delays);

  readingsBeginUpdate($hash);

  for my $device (split(",", $devices)){
    addToDevAttrList($device, $_) for("delay_powerOn", "delay_input", "delay_interKey", "delay_interDevice");
    readingsBulkUpdate(
      $hash, ".delays_$device", join("\n",
         "powerOn="    .AttrVal($device, "delay_powerOn",     "default")
        ,"input="      .AttrVal($device, "delay_input",       "default")
        ,"interKey="   .AttrVal($device, "delay_interKey",    "default")
        ,"interDevice=".AttrVal($device, "delay_interDevice", "default")
      )
    );
    $delays{".delays_$device"}  = ".delays_$device:textField-long";

    my @sets = split(" ", CommandSet(undef , "$device ?"));
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

  readingsEndUpdate($hash, 0);

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
