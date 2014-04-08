#!/usr/bin/perl
#
#
#
#

use warnings;
use diagnostics;
use strict;
use Sys::Syslog;
use Sys::Hostname;
use File::Basename;
use File::Copy "mv";
use Linux::Inotify2;
use Sys::Filesystem ();
use Log::Log4perl qw(:levels);
use App::Daemon qw( daemonize ); 

# flush buffers immediately
$| = 1;

# We are the lollipop kids the lollipop kids, or are we? What is our hostname?
my $hostname = hostname();

# The name of the script, with the path stripped
my $iAm = basename($0);

# What pattern from the hostname do we use to determine if this host should be
# running this script?
my $dstSrvPattern = '/regex_here/';

# This is the dir where we chdir to after forking
my $workDir = "/tmp";

# We need a pid file to watch
my $pidfile = "/var/run/ifw.pid";
$App::Daemon::pidfile = $pidfile;

# This is the java properties file we need to parse
my $propFile = "/dir/to/java/file.properties";

# The source hash key for the modified properties
my $propSrcKey = "src";

# The destination hash key for the modified properties
my $propDstKey = "dst";

# The options for openlog (syslog)
my $logopt = 'pid';

# The default facility that we syslog to
my $facility = 'local3';

# to $debug or not to $debug
# 0 = debugging disabled
# 1 = debugging enabled
my $debug = 1;
$App::Daemon::loglevel = $DEBUG if $debug;

# Where do we log to other than syslog?
my $logfile = "/tmp/$iAm.log";
$App::Daemon::logfile = $logfile;

# Shall we background this mofo?
# 0 = run in foreground, don't daemonise
# 1 = background, run as proper daemon
$App::Daemon::background = 1 unless $debug;

# By default daemonise will run as the nobody user.
# We want it to run as root right?
$App::Daemon::as_user = 'root';

# It's always nice to know how to start a program that you're never written
my $usage = "
Usage: $0 <start|stop|restart>

";

# This is how we do it... dun dun dun dun
daemonize();

# Our log file that we're writing to
open(LOGFILE, ">>", $logfile) or die "Can't open $logfile.\n$!\n";
select(LOGFILE);
$|=1;

# Initialise Sys::Filesystem object
my $fsh = Sys::Filesystem->new();
my @fslist = $fsh->regular_filesystems();
my $count = 0;
foreach my $fs (@fslist) {
  l("debug", "Filesystem$count :: $fs\n");
  $count++;
}


# These are what we're all about.  The hash of hashes below
# (http://perldoc.perl.org/5.14.2/perldsc.html) is required for proper handling
# of source (src) and destination (dst) directories that this script watches.
my %properties = (
  hash_key_1 => {
    $propSrcKey => 'runtime.source.folder',
    $propDstKey => 'runtime.destination.folder',
  },
  hash_key_2 => {
    $propSrcKey => 'runtime.source.folder',
    $propDstKey => 'runtime.destination.folder',
  },
  hash_key_N => {
    $propSrcKey => 'runtime.source.folder',
    $propDstKey => 'runtime.destination.folder',
  },
);

# We need to register the syslogging system
openlog($iAm, $logopt, $facility);
l("info", "Starting up") or die "Can't send syslog message\n$!\n";
l("debug", "Starting up\n");

# Setup inotify so we can get notified later!
my $inotify = new Linux::Inotify2 or die l("err", "unable to create new inotify object: $!");

# Just like the sands of time, these are the java properties...
%properties = initProperties($propFile, \%properties) or die "Can't initialise \$properties\n$!\n";
l("info", "----------\n");
foreach my $integration (keys %properties) {
  # It's nice to have some output when debugging, so like Nike says, Just do it!
  l("debug", "\$integration :: $integration\n");
  l("debug", "\$propSrcKey == $propSrcKey\n");
  l("debug", "\%properties: $integration :: \$properties{$integration}{$propSrcKey} == $properties{$integration}{$propSrcKey}\n");
  l("debug", "\%properties: $integration :: \$properties{$integration}{$propDstKey} == $properties{$integration}{$propDstKey}\n");
  # We're setting the following 2 variables so we can compare them to ensure
  # that they are on the same filesystem
  my $srcMount = "";
  my $dstMount = "";
  if (-d $properties{$integration}{$propSrcKey} && \
      -d $properties{$integration}{$propDstKey} && \
      $properties{$integration}{$propSrcKey} ne $properties{$integration}{$propDstKey}) {
    # iterate through the fslist array, and assign the path if the path starts
    # with equivalent path.  / will always be the first set, then anything
    # longer will be set as / will always (should?) be the first in the list
    foreach my $fs (@fslist) {
      if ($properties{$integration}{$propSrcKey} =~ /^$fs/) {
        $srcMount = $fs;
      }
      if ($properties{$integration}{$propDstKey} =~ /^$fs/) {
        $dstMount = $fs;
      }
    }
    l("debug", "\$srcMount == $srcMount\n");
    l("debug", "\$dstMount == $dstMount\n");
    # add inotify watchers if both $srcMount and $dstMount on same filesystem
    if ($srcMount == $dstMount) {
      $inotify->watch ($properties{$integration}{$propSrcKey}, IN_CLOSE, sub {
        my $e = shift;
        my $name = $e->fullname;
        if ($e->IN_CLOSE && -f $name) {
          l("info", "$name was closed in directory $properties{$integration}{$propSrcKey}\n") if $e->IN_CLOSE;
          l("info", "Moving $name from $properties{$integration}{$propSrcKey} to $properties{$integration}{$propDstKey}\n");
          if (-f $name) {
            mv($name, $properties{$integration}{$propDstKey});
          } elsif (!-f $name) {
            l("err", "$name doesn't seem to exist anymore!");
            l("warn", "$name doesn't seem to exist anymore!\n");
          } else {
            l("err", "$name couldn't be moved!");
            l("warn", "$name couldn't be moved!\n");
          }
        }
      });
    }
  } else {
    if (!-d $properties{$integration}{$propSrcKey}) {
      l("err", "$properties{$integration}{$propSrcKey} does not exist!");
      l("warn", "$properties{$integration}{$propSrcKey} does not exist!\n");
    } elsif (!-d $properties{$integration}{$propDstKey}) {
      l("err", "$properties{$integration}{$propDstKey} does not exist!");
      l("warn", "$properties{$integration}{$propDstKey} does not exist!\n");
    } elsif ($properties{$integration}{$propSrcKey} eq $properties{$integration}{$propDstKey}) {
      l("err", "$properties{$integration}{$propSrcKey} and $properties{$integration}{$propDstKey} and can't be the same directories!");
      l("debug", "$properties{$integration}{$propSrcKey} and $properties{$integration}{$propDstKey} and can't be the same directories!\n");
    } elsif ($srcMount != $dstMount) {
      l("err", "$srcMount isn't on the same filesystem as $dstMount do not exist!");
      l("debug", "$srcMount isn't on the same filesystem as $dstMount do not exist!");
    }
  }
}

# We should loop, fo eva, fo eva eva... As we're Waiting For The Sun
# waiting for you to... close a file... (sing to the doors)
while (1) {
  my @events = $inotify->read;
  unless (@events > 0) {
    l("warn", "read error: $!");
    last ;
  }
}
l("info", "daemon shutting down $0");
# Elvis has left the building (it's odd because he already left in
# &initProperties)
closelog();

sub initProperties {
  # We need to register the syslogging system
  openlog($iAm, $logopt, $facility);
  my $file = shift;
  my $vars = shift;
  my %vars = %{$vars};
  # We want to return a hash, this is the hash we'll use to return _just_ the
  # values we need.  We create a new hash of just the values we want which in
  # turn is _just_ what we need provide
  my %retHash;
    open (FH, "<", $file) or die l("err", "Can't open $file for read: $!");
    my @contents = <FH>;
    l("debug", "\$file == $file\n");
    close FH or die l("err", "Cannot close $file: $!");
  foreach my $var (keys %vars) {
    l("debug", "1st: $var\n");
    foreach my $key (keys $vars{$var}) {
      l("debug", "  2nd: $vars{$var}{$key}\n");
      my @line = grep(/^$vars{$var}{$key}=/, @contents);
      chomp(@line);
      l("debug", "    \@line == @line\n");
      my ($varName,$varVal) = split(/=/, $line[0], 2);
      l("debug", "    \$varName == $varName\n");
      if ($varVal && $varVal =~ /^\//) {
        l("debug", "    \$varVal = $varVal\n");
        if ($varName =~ /\.origin$/ || $varName =~ /\.out$/) {
          $retHash{$var}{$propSrcKey} = $varVal;
        } else {
          $retHash{$var}{$propDstKey} = $varVal;
        }
      } else {
        if (!$varVal) {
          l("warn", "    ** ERR ** \$varVal isn't set!\n");
          l("warn", "    ** ERR ** \$varName == $varName\n");
        } elsif ($varVal !~ /^\//) {
          l("warn", "    ** ERR ** \$varVal ($varVal) must be a fully qualified pathname!\n");
          l("warn", "    ** ERR ** \$varName == $varName\n");
        }
      }
    }
  }
  # Elvis has left the building.
  closelog();
  return %retHash;
}

sub l {
  my $sev = shift;
  my $msg = shift;
  my $now = localtime;
  if ($sev == "debug" && $debug) {
    print "$now $msg";
  }
  if ($sev != "debug") {
    syslog($sev, "$now	$msg");
    print "$now $msg";
  }
}
