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
    ."deviceAudio "
    ."deviceMedia "
    ."disable:1,0 "
    ."inputSelection:textField "
    ."sequeceOff:textField-long "
    ."sequeceOn:textField-long "
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
  my %inputSelection = map{$_, "input_$_:".join(",", (split(" ", CommandSet(undef , "$_ ?")))[6..int(split(" ", CommandSet(undef , "$_ ?"))-1)])} split(",", $devices);
  $inputSelection{"input_$_"} = delete $inputSelection{$_} foreach (keys %inputSelection);
  my $DevAttrList = $modules{$TYPE}{AttrList};
  $DevAttrList =~ s/deviceAudio\S*/deviceAudio:$devices/;
  $DevAttrList =~ s/deviceMedia\S*/deviceMedia:$devices/;

  $hash->{devices} = $devices;
  $hash->{type} = $type;
  $hash->{inputSelection} = \%inputSelection;

  setDevAttrList($SELF, "$DevAttrList");

  readingsSingleUpdate($hash, "state", "Initialized", 1);

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

  return("\"set $TYPE\" needs at least one argument") if(@a < 2);

  my $SELF     = shift @a;
  my $argument = shift @a;
  my $value    = join(" ", @a) if (@a);
  my %AVScene_sets = (
     "channelDown"  => "channelDown:noArg"
    ,"channelUp"    => "channelUp:noArg"
    ,"deviceAdd"    => "deviceAdd:".join(",", devspec2array(".+"))
    ,"deviceRemove" => "deviceRemove:$hash->{devices}"
    ,"mute"         => "mute:noArg"
    ,"off"          => "off:noArg"
    ,"on"           => "on:noArg"
    ,"pause"        => "pause:noArg"
    ,"play"         => "play:noArg"
    ,"stop"         => "stop:noArg"
    ,"volumeDown"   => "volumeDown:noArg"
    ,"volumeUp"     => "volumeUp:noArg"
  );
  %AVScene_sets = (%AVScene_sets, %{$hash->{inputSelection}});  

  return(
    "Unknown argument $argument, choose one of ".
    join(" ", sort(values %AVScene_sets))
  ) unless(exists($AVScene_sets{$argument}));

  if
  ($argument =~ /^device(Add|Remove)$/){
    my %devices = map{$_, 1} split(",", $hash->{devices}.",$value");
    delete $devices{$value} if($argument eq "deviceRemove");
    my $devices = join(" ", sort(keys %devices));

    CommandDefMod(undef, "$SELF $TYPE $devices");
  }
  elsif
  ($argument =~ /^input_(.+)$/){
    my $device = $1;
    my $inputSelection = AttrVal($SELF, "inputSelection", undef);
    $inputSelection =~ s/$device:[^,]+//g;
    $inputSelection = join(",", sort(split(",", $inputSelection), "$device:$value"));
    $inputSelection =~ s/^,+//;

    CommandAttr(undef, "$SELF inputSelection $inputSelection");
  }

  return;
}

sub AVScene_Get($@) {
  my ($hash, @a) = @_;
  my $TYPE = $hash->{TYPE};

  return("\"get $TYPE\" needs at least one argument") if(@a < 1);

  my $SELF = shift @a;
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


  return $ret;
}

sub AVScene_Attr(@) {
  my ($cmd, $SELF, $attribute, $value) = @_;
  my $hash = $defs{$SELF};
  my $TYPE = $hash->{TYPE};

  Log3($SELF, 5, "$TYPE ($SELF) - entering AVScene_Attr");

    # ."commands:textField-long "
    # ."deviceAudio "
    # ."deviceMedia "
    # ."disable:1,0 "
    # ."inputSelection:textField-long "
    # ."sequeceOff:textField-long "
    # ."sequeceOn:textField-long "

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
