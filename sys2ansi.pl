#!/usr/bin/perl
# $Id: sys2ansi.pl,v 1.3 1999/03/05 15:08:54 hpa Exp $
#
# Perl script to convert a Syslinux-format screen to PC-ANSI
#
@ansicol = (0,4,2,6,1,5,3,7);

while ( read(STDIN, $ch, 1) > 0 ) {
    if ( $ch eq "\x1A" ) {	# <SUB> <Ctrl-Z> EOF
	last;
    } elsif ( $ch eq "\x0C" ) {	# <FF>  <Ctrl-L> Clear screen
	print "\x1b[2J";
    } elsif ( $ch eq "\x0F" ) {	# <SI>  <Ctrl-O> Attribute change
	if ( read(STDIN, $attr, 2) == 2 ) {
	    $attr = hex $attr;
	    print "\x1b[0;";
	    if ( $attr & 0x80 ) {
		print "5;";
		$attr &= ~0x80;
	    }
	    if ( $attr & 0x08 ) {
		print "1;";
		$attr &= ~0x08;
	    }
	    printf "%d;%dm",
	    $ansicol[$attr >> 4] + 40, $ansicol[$attr & 7] + 30;
	}
    } else {
	print $ch;
    }
}

