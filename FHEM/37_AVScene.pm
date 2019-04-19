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
    ."deviceInput "
    ."disable:0,1 "
    ."inputSelection:textField-long "
    ."sequeceOn "
    ."sequeceOff "
    .$readingFnAttributes
  ;
}

# regular Fn ##################################################################
sub AVScene_Define($$) {
  my ($hash, $def) = @_;
  my ($SELF, $TYPE, @DEVICES) = split(/[\s]+/, $def);

  return(
    "Usage: define <name> $TYPE [<dev1>] [<dev2>] [<dev3>] ..."
  ) unless(@DEVICES);
  my $DEVICES = join(",", @DEVICES);
  my $DevAttrList = $modules{$TYPE}{AttrList};
  $DevAttrList =~ s/deviceAudio\S*/deviceAudio:$DEVICES/;
  $DevAttrList =~ s/deviceMedia\S*/deviceMedia:$DEVICES/;

  $hash->{DEVICES} = $DEVICES;
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
    ,"deviceAdd"    => "deviceAdd:textField"
    ,"deviceRemove" => "deviceremove:textField"
    ,"mute"         => "mute:noArg"
    ,"off"          => "off:noArg"
    ,"on"           => "on:noArg"
    ,"pause"        => "pause:noArg"
    ,"play"         => "play:noArg"
    ,"stop"         => "stop:noArg"
    ,"volumeDown"   => "volumeDown:noArg"
    ,"volumeUp"     => "volumeUp:noArg"
  );

  return(
    "Unknown argument $argument, choose one of ".
    join(" ", sort(values %AVScene_sets))
  ) unless(exists($AVScene_sets{$argument}));

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
