#!/usr/bin/perl

use warnings;
use strict;

use REST::Client;
use JSON;
use Data::Dumper;
use MIME::Base64;
use Term::ReadKey;

my $debug = 0;

# This be the REST API host we be using man...
my $restHost = "https://<PROJECT NAME HERE>.atlassian.net";

# Yar! We be searching on this URI Reference...
my $searchURIref = "/rest/api/latest/user/search?maxResults=1000&username=";

my $passURIref = "/rest/api/latest/user/password?username=";
my $sessionURIref = "/rest/auth/1/session";

# How long is a piece of password?
my $passLength = '20';

# If you populate these hash keys, you won't be prompted
my %auth = (
  user => '',
  pass => '',
);

# Our valid password characters for genPass()
my @chars = ('0'..'9', 'a'..'z', 'A'..'Z' '!', '@', '#', '$', '%', '(', ')');

# This is a case sensitive list of usernames to ignore processing for
my @userIgnore = (

);

# The whole purpose of this script is to generate a pseudo-random password
# This is the function that does just that, and returns a scalar password
sub genPass {
  my $pass;
  for (my $i=0; $i<=$passLength; $i++) {
    $pass .= $chars[int(rand(scalar(@chars)))]
  }
  return $pass;
}

# Who is us?
if (!$auth{'user'}) {
  print "What is your Jira username? : ";
  chomp($auth{'user'} = <STDIN>);
  $auth{'user'} and print "\n" or die "\nJira username can't be blank!\n";
}

# A password is a nice thing to provide to Jira...
if (!$auth{'pass'}) {
  ReadMode('noecho');
  print "What is your password? : ";
  chomp($auth{'pass'} = <STDIN>);
  ReadMode(0);
  $auth{'pass'} and print "\n" or die "\nJira password can't be blank!\n";
}

# These are the auth headers that we send with most REST requests
my $headers = {
  'Content-Type' => 'application/json',
  Authorization => 'Basic '. encode_base64($auth{'user'}. ':'. $auth{'pass'})
};
my $client = REST::Client->new();
$client->setHost($restHost);

for my $i ('0'..'9','a'..'z') {
  $client->GET( $searchURIref . $i, $headers);
  my $json = from_json($client->responseContent());
  for my $hash ($json) {
    for my $j (@$hash) {
      next if grep { $j->{name} } @userIgnore;
      $entries{$j->{'name'}} = $j->{'emailAddress'};
    }
  }
}

for my $key (keys %entries) {
  print "$key :: $entries{$key}\n" if $debug;

  # Generate a new password for the user
  my $pass->{password} = genPass;
  my $jsonPass = encode_json($pass);

  # Apply the new password for the user
  $client->PUT($passURIref . $key, $jsonPass, $headers);
  print $client->responseCode() if $debug;
  print $client->responseContent() if $debug;
  my $sessionCreds->{username} = $key;
  $sessionCreds->{password} = $pass->{password};

  # We can get the session data for the user if we turn on debugging
  if ($debug) {
    my $jsonSessionCreds = encode_json($sessionCreds);
    $client->POST($sessionURIref, $jsonSessionCreds, $headers);
    print $client->responseCode();
    print $client->responseContent();
  }

  # We need to DELETE all sessions for the user so we can force a new login
  # Now that we've changed the password, we need to start a session as the user
  # and then delete our session.
  $headers = {'Content-Type' => 'application/json',
              'Authorization' => 'Basic ' .
              encode_base64($sessionCreds->{'username'} .
              ':' .
              $sessionCreds->{'password'})
  };
  $client = REST::Client->new();
  $client->setHost($restHost);
  $client->DELETE($sessionURIref, $headers);
  print "$key :: " . $client->responseCode() if $debug;
  print $client->responseContent() if $debug;
}

print genPass . " :: $jsonPass :: $json\n" if $debug;
print "$json\n" if $debug;
