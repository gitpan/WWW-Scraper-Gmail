package WWW::Scraper::Gmail;

use 5.005003;
use strict;
use warnings;

require Exporter;
require LWP;
require Crypt::SSLeay;

use LWP::UserAgent;
use Env qw{HOME};
use Carp;
use Data::Dumper;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use WWW::Scraper::Gmail ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.04';


# Preloaded methods go here.

my ($url, $url2, $url3, $url_init, $urlx, $ua, $req, $res);
my ($cookie, $dump, $inbox, $head);
my ($gmail_at);
my $num = 0;
my ($username, $password);
my $logged_in = 0;
my $pid = "$ENV{HOME}/.gmailpid";
my $gmailrc = "$ENV{HOME}/.gmailrc";

$url = "https://www.google.com/accounts/ServiceLoginBoxAuth";
$url2 = "https://www.google.com/accounts/CheckCookie?service=mail&chtml=LoginDoneHtml";
#$urlx = "http://gmail.google.com/gmail?search=inbox&view=tl&start=0&init=1&zx=$zx";
$url3 = "http://gmail.google.com/gmail?search=inbox&view=tl&start=0";
$url_init = "http://gmail.google.com/gmail?search=inbox&view=tl&start=0&init=1";

sub getUP {
    open(GMAILRC, "$gmailrc") or die("Can't Open $gmailrc \nFormat:\n[gmail]\nusername=<username>\npassword=<password>\n");
    while (<GMAILRC>) {
        $username = $1 if (/username=(.*)/);
        $password = $1 if (/password=(.*)/);;
    }
    close(GMAILRC);
    return(0) if(!$username or !$password);
    return(1);
}

sub login {
    $ua = LWP::UserAgent->new();
    $ua->agent("Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.4b) Gecko/20030430 Mozilla Firebird/0.6");

    if(open(GMAILPID, "$pid")) {
        my $first = <GMAILPID>;
        if ($first - time() > 50000) {
            #cookie is expired
            unlink($pid);
            last();
        }
        $cookie = <GMAILPID>;
        #$zx = <GMAILPID>;
        #print "cookie = $cookie\ngmail_at = $gmail_at\nzx=$zx\n";
        $head = HTTP::Headers->new(Cookie => $cookie);
        close(GMAILPID);
        return(0);
    }
    getUP();
    #its a GOOSE

    $req = HTTP::Request->new(POST => $url);
    $req->content_type("application/x-www-form-urlencoded");
    $req->content("service=mail&Email=$username&Passwd=$password&null=Sign%20in");
    $res = $ua->request($req);

    $dump = $res->as_string();
    while ($dump =~ m!^Set-Cookie: (SID[^;]*).*!mgs) {
        $cookie .= $1 . ";";
    }

    #They set a Javascript cookie... must intercept it!
    if ($res->is_success()) {
        #try and get the cookie value
        $res->content() =~ /cookieVal=[ ]?\"(.*)\";/;
        $cookie .= " GV=$1;";
        #print "Got cookie - $1\n";
    }

    #print "setting Cookie => $cookie\n";
    $head = HTTP::Headers->new(Cookie => $cookie);
    $req = HTTP::Request->new(GET => $url2, $head);
    $res = $ua->request($req);


    if (open(GMAILPID, "> $pid")) {
        #Save the cookie to a file so that we don't have to go through it all each time
        print GMAILPID time(), "\n";
        print GMAILPID $cookie, "\n";
        #print GMAILPID $zx, "\n";
        close(GMAILPID);
    }

    $logged_in = 1;

}

sub doGmailAt {
    #must be logged in to do the gmail at..
    login() unless $logged_in;

    $req = HTTP::Request->new(GET => $url_init,  $head);
    $res = $ua->request($req);
    $dump = $res->as_string();

    #more cookies
    #$zx = $1 if ($dump =~ m!ver=([A-Za-z0-9]*)!);
    while ($dump =~ m!^Set-Cookie: (GMAIL([^;]*)).*!mgs) {
        $cookie .= $1 . ";";
        if ($1 =~ /GMAIL_AT=(.*)/) {
            $gmail_at = $1;
        }
    }

    $head = HTTP::Headers->new(Cookie => $cookie);
    #print "cookie = $cookie\ngmail_at = $gmail_at\nzx=$zx\n";
}

sub countMail {

    login();

    $req = HTTP::Request->new(GET => $url3, $head);
    $res = $ua->request($req);

    my $num = 0;
    if ($res->is_success()) {
        $inbox = $res->content();
        $inbox =~ m!(D\(\[\"t\".*])!mgis;
        $inbox = $1;
        return(0) if (!$inbox);
        $inbox =~ s!\\!!ig;
        $inbox =~ s!</?b>!!ig;
        while ($inbox =~ m!\[".+?",([01]),[01],"(.+?)","<span id='_user_(.+?)'>.+?",".+?","(.+?)","(.+?)".+?\]!mgis) {
            $num++ if ($1);
            #my ($from, $subject, $new) = ($2, (($3 =~ /raquo/) ? $4 : $3), (($1 == 1) ? " NEW!!! " : ""));
            
        }
    }
    return $num;
}

sub outputMail {

    login();
    my $delim = ($ARGV[0]) ? $ARGV[0] : ";;";
    my $ret;

    $req = HTTP::Request->new(GET => $url3, $head);
    $res = $ua->request($req);

    if ($res->is_success()) {
        $inbox = $res->content();
        $inbox =~ m!(D\(\[\"t\".*])!mgis;
        $inbox = $1;
        return("") if (!$inbox);
        $inbox =~ s!\\!!ig;
        $inbox =~ s!</?b>!!ig;
        while ($inbox =~ m!\[".+?",([01]),[01],"(.+?)","<span id='_user_(.+?)'>.+?",".+?","(.+?)","(.+?)".+?\]!mgis) {
            $num++;
            #my ($from, $subject, $new) = ($2, (($3 =~ /raquo/) ? $4 : $3), (($1 == 1) ? " NEW!!! " : ""));
            my ($time, $from, $subject, $new, $blurb) = ($2, $3, $4, ($1 == 1) ? "new!" : "", $5);
            my $rec = {};
            if ($1) {
                $ret .= "$from$delim$subject$delim$time$delim$blurb\n";
            }
        }
        #print "$num total messages in inbox\n";
        return $ret;

    }
    else {
        warn $res->content();
        warn $res->status_line, "\n";
        return("");
    }
}

sub fetchMail {

    login();

    my @msgs;
    $req = HTTP::Request->new(GET => $url3, $head);
    $res = $ua->request($req);

    if ($res->is_success()) {
        $inbox = $res->content();
        $inbox =~ m!(D\(\[\"t\".*])!mgis;
        $inbox = $1;
        return(0) if (!$inbox);
        $inbox =~ s!\\!!ig;
        $inbox =~ s!</?b>!!ig;
        while ($inbox =~ m!\[".+?",([01]),[01],"(.+?)","<span id='_user_(.+?)'>.+?",".+?","(.+?)","(.+?)".+?\]!mgis) {
            $num++;
            #my ($from, $subject, $new) = ($2, (($3 =~ /raquo/) ? $4 : $3), (($1 == 1) ? " NEW!!! " : ""));
            my ($time, $from, $subject, $new, $blurb) = ($2, $3, $4, ($1 == 1) ? "new!" : "", $5);
            my $rec = {};
            $rec = {
                from    => $from,
                subject => $subject,
                date    => $time,
                blurb   => $blurb,
                new     => $1
            };
            push @msgs, $rec;

            #print "Thread Started by $from, Subject $subject @ $time $new\n\t$blurb\n";
        }
        #print "$num total messages in inbox\n";
        return @msgs;

    }
    else {
        warn $res->content();
        warn $res->status_line, "\n";
        return(0);
    }
}

sub setPrefs {
    my ($arg) = @_;
    login();
    doGmailAt();
    $arg->{"MaxPer"} = 100 unless defined $arg->{MaxPer};
    $arg->{"Signature"} = "" unless defined $arg->{Signature};

    #print Dumper $arg;

    my $url_pref=" http://gmail.google.com/gmail?search=inbox&view=tl&start=0&act=prefs&at=$gmail_at&p_bx_hs=1&p_ix_nt=$arg->{MaxPer}&p_bx_sc=1&p_sx_sg=$arg->{Signature}"; #&zx=$zx";
    #$head = HTTP::Headers->new(Cookie => $cookie); #, Referer => $ref);
    $req = HTTP::Request->new(GET=>$url_pref, $head);
    $res = $ua->request($req);
    return ($res->as_string() =~ /saved/);
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

WWW::Scraper::Gmail - Perl extension for loging in and reading Gmail Mailbox information.

=head1 SYNOPSIS

  use WWW::Scraper::Gmail;
  A simple scraper for gmail.

=head1 DESCRIPTION

Logs into email through https, does some stuff and gets back a list of inbox items.
Uses ~/.gmailrc for now for username and password. The format is as follows
[gmail]
username=<username>
password=<password>

you'd do well to chmod it 700.
Doesn't do error checking for log in problems.

=head2 EXPORT

None by default.



=head1 SEE ALSO

=head1 AUTHOR

Erik F. Kastner, <lt>kastner@gmail.com<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Erik F. Kastner

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.3 or,
at your option, any later version of Perl 5 you may have available.


=cut
