# Id ##########################################################################
# $Id:  $

# copyright ###################################################################
#
# 37_ACScene.pm
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
  ,"inkerKey"     =>  100
  ,"powerOn"      => 2000
);

# forward declarations ########################################################

# initialize ##################################################################
sub AVScene_Initialize($) {
  my ($hash) = @_;
  my $TYPE = "AVScene";

  $hash->{DefFn}    = $TYPE."_Define";
  $hash->{UndefFn}  = $TYPE."_Undefine";
  $hash->{SetFn}    = $TYPE."_Set";
  $hash->{GetFn}    = $TYPE."_Get";
  $hash->{AttrFn}   = $TYPE."_Attr";

  $hash->{AttrList} = ""
    ."commands:textField-long "
    ."configMode:1,0 "
    ."deviceVolume "
    ."deviceMedia "
    ."disable:1,0 "
    ."evalSpecials:textField-long "
    ."inputSelection:textField-long "
    ."sequeceOff:sortable "
    ."sequeceOn:sortable "
    .$readingFnAttributes
  ;
}

# regular Fn ##################################################################
sub AVScene_Define($$) {
  my ($hash, $def) = @_;
  my ($SELF, $TYPE, @devices) = split(/[\s]+/, $def);

  return(
    "Usage: define <name> $TYPE [<dev1>] [<dev2>] [<dev3>] ..."
  ) unless(@devices);

  my $devices = join(",", sort(@devices));

  return("It's not allowed to add AVScene to itself.") if($devices =~ /$SELF/);

  my $type = devspec2array("$devices:FILTER=TYPE!=$TYPE") ? "scene" : "sceneSwitcher";
  my $DevAttrList = $modules{$TYPE}{AttrList};
  $DevAttrList =~ s/deviceVolume\S*/deviceVolume:$devices/;
  $DevAttrList =~ s/deviceMedia\S*/deviceMedia:$devices/;

  $hash->{devices} = $devices;
  $hash->{type} = $type;

  AVScene_update_inputSelection($hash);

  setDevAttrList($SELF, "$DevAttrList");
  
  readingsSingleUpdate($hash, "state", "Initialized", 1);

  CommandAttr(undef, "$SELF configMode 1");

  return;

}

sub AVScene_Undefine($$) {
  my ($hash, $arg) = @_;

  RemoveInternalTimer($hash);

  return;
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
  (AttrVal($SELF, "configMode", 0)){
    %AVScene_sets = (
       "deviceAdd"    => "deviceAdd:".join(",", devspec2array(".+"))
      ,"deviceMedia"  => "deviceMedia:$hash->{devices}"
      ,"deviceRemove" => "deviceRemove:$hash->{devices}"
      ,"deviceVolume" => "deviceVolume:$hash->{devices}"
      ,"updateInputSelection"       => "updateInputSelection:noArg"
    );
    %AVScene_sets = (%AVScene_sets, %{$hash->{inputSelection}});  
  }
  else{
    %AVScene_sets = (
       "channelDown"  => "channelDown:noArg"
      ,"channelUp"    => "channelUp:noArg"
      ,"mute"         => "mute:noArg"
      ,"off"          => "off:noArg"
      ,"on"           => "on:noArg"
      ,"pause"        => "pause:noArg"
      ,"play"         => "play:noArg"
      ,"stop"         => "stop:noArg"
      ,"volumeDown"   => "volumeDown:noArg"
      ,"volumeUp"     => "volumeUp:noArg"
    );
  }

  return(
    "Unknown argument $argument, choose one of ".
    join(" ", sort(values %AVScene_sets))
  ) unless(exists($AVScene_sets{$argument}));

  if
  ($argument =~ /^(channel(Down|up)|pause|play|stop)/){
    CommandSet(undef, AttrVal($SELF, "deviceMedia", undef)." $argument");
  }
  elsif
  ($argument =~ /^(mute|volume(Down|Up))/){
    CommandSet(undef, AttrVal($SELF, "deviceVolume", undef)." $argument");
  }
  elsif
  ($argument =~ /^(off|on)/){
    return("Not implemented yet :(");
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
  ($argument =~ /^device(Media|Volume)$/){
    CommandAttr(undef, "$SELF $argument $value");
  }
  elsif
  ($argument eq "updateInputSelection"){
    AVScene_update_inputSelection($hash);
  }

  return;
}

sub AVScene_Get($@) {
  my ($hash, @a) = @_;
  my $TYPE = $hash->{TYPE};
  my $SELF = shift @a;

  return unless(AttrVal($SELF, "configMode", 0));
  return("\"get $TYPE\" needs at least one argument") if(@a < 1);

  my $argument = shift @a;
  my $value = join(" ", @a) if (@a);
  my %AVScene_gets = (
     "defaultSequence"   => "defaultSequence:on,off"
  );
  my $ret;

  return(
    "Unknown argument $argument, choose one of ".
    join(" ", sort(values %AVScene_gets))
  ) unless(exists($AVScene_gets{$argument}));

  if
  ($argument eq "defaultSequence"){
    if
    ($value eq "on"){
      return AVScene_sequence_on($hash);
      return("Not implemented yet :(");
    }
    elsif
    ($value eq "off"){
      $ret = "set $hash->{devices} off";
    }
  }

  return $ret;
}

sub AVScene_Attr(@) {
  my ($cmd, $SELF, $argument, $value) = @_;
  my $hash = $defs{$SELF};
  my $TYPE = $hash->{TYPE};

  Log3($SELF, 5, "$TYPE ($SELF) - entering AVScene_Attr");

    # ."commands:textField-long "
    # ."sequeceOff:textField-long "
    # ."sequeceOn:textField-long "

  if
  ($argument eq "evalSpecials"){
    AVScene_evalSpecials($hash, $value);

    Log3($SELF, 5, "$TYPE ($SELF) - evalSpecials $hash->{evalSpecials}");
  }

  return;
}

# module Fn ###################################################################
sub AVScene_evalSpecials($;$) {
  my ($hash, $AttrVal) = @_;
  my $SELF = $hash->{NAME};
  my $TYPE = $hash->{TYPE};

  my $parseParams = $AttrVal || AttrVal($SELF, "evalSpecials", undef);

  Log3($SELF, 5, "$TYPE ($SELF) - entering AVScene_evalSpecials");

  my(undef, %evalSpecials) = parseParams($parseParams);

  $hash->{evalSpecials} = \%evalSpecials;

  return;
}

sub AVScene_update_inputSelection($) {
  my ($hash) = @_;
  my $TYPE = $hash->{TYPE};
  my $SELF = $hash->{NAME};
  my $devices = $hash->{devices};
  my %inputSelection;

  for my $device (split(",", $devices)){
    my @sets = split(" ", CommandSet(undef , "$device ?"));
    splice(@sets, 0, 6);

    for (my $i=0; $i<int(@sets); $i++){
      next unless($sets[$i] =~ m/([^:]*):(.+)/);
      
      $sets[$i] = join(",", map{"$1#$_"} split(",", $2));
    }

    $inputSelection{"input_$device"} = "input_$device:".join(",", sort(@sets));
   }

  $hash->{inputSelection} = \%inputSelection;

  return;
}

sub AVScene_sequence_on($) {
  my ($hash) = @_;
  my $TYPE = $hash->{TYPE};
  my $SELF = $hash->{NAME};
  my $devices = $hash->{devices};
  my (%sequence, @ret);
  my(undef, $inputSelection) = parseParams(AttrVal($SELF, "inputSelection", undef));

  $sequence{"$_:on"} = "1".AttrVal($_, "delay_powerOn", $AVScene_defaultDelays{powerOn}) 
    for(split(",", $devices));
  $sequence{"$_:$inputSelection->{$_}"} = "0".AttrVal($_, "delay_input", $AVScene_defaultDelays{input}) 
    for(keys %{$inputSelection});

  foreach (sort { $sequence{$b} <=> $sequence{$a} } keys %sequence) {
    push(@ret, $_);
  } 

  return join("\n", @ret);
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
