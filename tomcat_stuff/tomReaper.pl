#!/usr/local/bin/perl

# Seriously, just tune your fucking tomcat heap, and you won't have to run this.

use strict;
use warnings;
$| = 1;

my $usage = "
$0 <start/stop script> <tomcat logfile (catalina.out)> <pid file>

eg:
$0 /etc/init.d/tomcat /data/tomcat/logs/catalina.out \
/data/tomcat/tomcat.pid

";

my $tomControl = shift or die "$usage\n";
if (! -x $tomControl) {
  print "Can't execute $tomControl.\n$usage";
  exit 256;
}
my $file = shift or die "$usage\n";
if (!-f $file) {
  print "Can't use $file, it's not a regular file.\n$usage";
}
my $pidFile = shift or die "$usage\n";
open(my $pidfh, '<', $pidFile) or die "Can't open $pidFile\n$!\n";
chomp(my $pid = <$pidfh>) or die "Couldn't get PID\n$!\n";
close($pidfh);
my $logFile = "/var/log/tomReaper.log";
open(my $lfh, '+>', $logFile) or die "Couldn't open $logFile\n$!\n";

my $continue = 1;
$SIG{TERM} = sub { $continue = 0 };

sub tomRestart { # {{{
  my $pid = shift;
  my $now = localtime;
  print "$now Killing PID: $pid\n";
  kill 9, $pid;
  sleep 1;
  $now = localtime;
  print "$now Starting new tomcat process\n";
  my $result = qx/$tomControl start/;
  # Something greater than right away (0)
  sleep 5;
  open(my $pidfh, '<', $pidFile) or die "Can't open $pidFile\n$!\n";
  chomp($pid = <$pidfh>) or die "Couldn't get PID\n$!\n";
  close($pidfh);
  $now = localtime;
  print "$now New tomcat pid: $pid\n";
  return $pid;
}
# }}}
# {{{ Go go gadget watch!
my $startTime = localtime;
print "$startTime	tomReaper.pl starting...\n";
open(my $fh, '<', $file) or die "Can't open file: $file\n$!\n";
while ($continue) {
  seek($fh, 0, 2); # seek to the EOF
  my $curpos;
  for (;;) {
    for ($curpos = tell($fh); <$fh>; $curpos = tell($fh)) {
      if ($_ =~ /OutOfMemoryError/) {
        my $now = localtime;
        print "$now OutOfMemoryError detected. ";
        print "Restarting tomcat pid: $pid\n";
        $pid = tomRestart($pid);
      }
    }
    sleep 1;
    seek($fh, $curpos, 0); # seek to where we had been
  }
}
close($fh);
# }}}
