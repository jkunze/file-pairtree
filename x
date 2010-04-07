#!/bin/sh
#! -*- perl -*-
eval 'exec perl -x -S $0 ${1+"$@"} ;'
	if 0;
# The above make for portable Perl startup honoring PATH and emacs.  Don't
# change lightly.  Options may be inserted before "-x".  For background see
# 'perldoc perlrun' and http://cr.yp.to/slashpackage/studies/findingperl/7 .
# For development consider:  alias tp='perl -x -Mblib', eg, tp foo t/foo.t

use strict;
use warnings;

# xxx support for shadow tree of deletions? pairtree_trash?

=for roff
.nr PS 12p
.nr VS 14.4p

=head1 NAME

pt - pairtree manipulation commands

=head1 SYNOPSIS

=over

=item B<pt> [B<-dfmvh>] [B<mktree>] I<directory> [I<prefix>]

=item B<pt> [B<-dlfmvh>] [B<rmtree | lstree>] [I<directory>] ...

=item B<pt> [B<-dlfmvh>] [B<mknode | rmnode | lsnode>] I<id> ...

=item B<pt> [B<-lfmvh>] [B<i2p | p2i>] I<name> ...

=back

=head1 DESCRIPTION

The B<pt> command introduces (sub)commands that can be used to create,
delete, modify, and report on a pairtree.  When not made explicit via
an argument (see the first two forms above), the pairtree in question
is assumed to reside in a F<pairtree_root/> directory descending from
the current directory or from a directory specified with B<-d>.

The first form creates a pairtree, recording an optional prefix that
will be stripped from an identifier before mapping it to a pairpath
and prepended to an identifier generated from a pairpath.

The second form deletes or lists an entire tree of nodes and the third
form creates, deletes, or tests the existence of a node.  If B<-l> is
also given, more detailed listings are produced for B<lstree> or
B<lsnode>.

The third form permits access to the purely lexical lower level
conversion between identifiers and pairpaths, independent of any
existing pairtree.

=head1 EXAMPLES

=cut

my $VERSION;
$VERSION = sprintf "%d.%02d", q$Revision: 0.01 $ =~ /(\d+)/g;

# this :config allows -h24w80 for '‐h 24 ‐w 80', -vax for --vax or --Vax
use Getopt::Long qw(:config bundling_override);

use Pod::Usage;

#XXXX
#use File::Pairtree qw( $pair $pairp1 $pairm1 );
use File::Pairtree;
use File::Path qw( mkpath );	# don't import rmtree, which we want to define

#XXXX move to module
my $pfixtail = 'pairtree_prefix';
my $prefix;			# need this global to talk to lstree/find

my ($dir, $R, $P);
# This matches the base ppath in 'perl'.
# xxx define these as compiled regexps in Pairtree.pm
$R = $File::Pairtree::root;
$P = "([^/]{$pair}/)*[^/]{1,$pair}";

my $objectcount = 0;		# number of objects encountered
my $filecount = 0;		# number of files encountered xxx
my $dircount = 0;		# number of directories encountered xxx
my $symlinkcount = 0;		# number of symlinks encountered xxx
my $irregularcount = 0;		# non file, non dir fs items to report xxx

use constant OM_ANVL => 1;

my %opt = (
	bud		=> 0,
	directory	=> 0,
	force		=> 0,
	format		=> 0,
	help		=> 0,
	long		=> 0,
	man		=> 0,
	version		=> 0,
	verbose		=> 0,
);

# main
{
	GetOptions(\%opt,
		'bud|b=s',
		'directory|d=s',
		'force|f',
		'format|m=s',		# xxx not implemented yet
		'help|?',
		'long|l',
		'man',
		'version',
		'verbose|v',
	) or pod2usage(1);

	pod2usage(1)
		if $opt{help};
	pod2usage(-exitstatus => 0, -verbose => 2)
		if $opt{man};
	print "$VERSION\n" and exit(0)
		if $opt{version};

	my $subcmd = shift @ARGV;
	pod2usage("$0: no sub-command given")
		unless defined $subcmd;
	$subcmd = lc $subcmd;
	pod2usage("$0: unknown sub-command: $subcmd")
		unless defined(&$subcmd);	# is it a defined function?

	# Which pairtree?
	#
	$dir = $opt{directory} || ".";
	$dir = prep_file($dir, $R);

	no strict 'refs';		# permits the next call
	&$subcmd(@ARGV);
	# XXX exit status?
}

# Prepare base path with last component according to the table, normalizing
# multiple slashes between $base and $last.  Useful to get tedious details
# right and when path may already have the last component on it (in which
# case we don't want it there twice).  Removes final slashes from $last.
#
# 	$base		$last		Returns
#  1.	/		bar		/bar
#  2.	.		bar		bar
#  3.	foo		bar		foo/bar
#  4.	foo/		bar		foo/bar
#  5.	foo/bar		bar		foo/bar
#  6.	bar		bar		bar
#
# xxx may not port to Windows due to use of explicit slashes (/)
# XXXXXX probably should use File::Spec
# xxx do some test cases for this
# xxx find a better name
sub prep_file { my( $base, $last )=@_;

	$last =~ s{/*(.*)/*$}{$1};	# remove bounding slashes
	return "/$last"		if $base =~ m{^/+$};	# case 1 eliminated
	$base =~ s{/+$}{};		# remove trailing slashes
	return "$last"		if $base =~ m{^\./+$};	# case 2 eliminated
	return "$base/$last"	if $base !~ m{$last$};	# cases 3-4 gone
	return "$last"		if $base =~ m{^$last$};	# case 6 eliminated
	$base =~ s{/*$last$}{};		# remove $last and preceding slashes
	return "$base/$last";				# case 5 eliminated
}

# Return parent with trailing slash intact.
#
sub up_dir { ( $_ )=@_;

	return "/"		if m,^/+$,;
	return "./"		if m,^\./*$,;
	s,[^/]+/*$,,;
	return "./"		if m,^$,;
	return $_;
}

use File::Value;

# Return empty string unless we find a prefix value.
sub get_prefix { my( $pdir )=@_;

	my $prefix = "";
	my $pxfile = $pdir . $pfixtail;
	return $prefix			unless -e $pxfile;
	my $msg = file_value("< $pxfile", $prefix);
	die "$pxfile: $msg"		if $msg;
	return $prefix;
}

# Create the bud that will encapsulate the leaf node
#
sub bud { my( $bud )=@_;

	# Xxx add chars if less than $pair chars in $_
	$bud ||= "";
	! $bud and				# valid but empty id/ppath
		return "supernode";

	my $n = length($bud) - 1;
	$n < $pair and				# pad on left with zeroes
		$bud = ("0" x ($pair - $n)) . $bud;

	# xxx optional variation on endings
	$opt{bud} == 0 and			# "full"
		return s2ppchars($bud);
	#or			# XXX no other possibility right now
	;
	return s2ppchars($bud);
}

#######################
#
# Now for the sub-command functions.
#

use File::Glob ':glob';		# standard use of module, which we need
				# as vanilla glob won't match whitespace
use File::Find;

sub help { my( $topic )=@_;

	$topic ||= "";
	return print "XXX place holder for help on $topic\n";
}

sub lsnode { my( @nodes )=@_;

	# Don't allow empty node, especially for delnode, which could
	# result in a disastrous rmtree against the entire pairtree.
	#
	die "lsnode: no node"		unless scalar(@nodes);

	my $pdir = up_dir($dir);	# parent directory
	$prefix = get_prefix($pdir);
	my ($pp, $ret);
	for (@nodes) {
		s/^$prefix//;
		$pp = $pdir . id2ppath($_);
		! -e $pp and
			($ret = print "No such node: $pp\n"),
			next;

		# Now we have a valid ppath, but we don't know what the
		# encapsulating directory (or anything else for that
		# matter) looks like, so we glob around for things.
		# Recall that $pp ends in a '/' (from id2ppath).
		#
		my @in = bsd_glob("$pp*");		# anything visible
		push @in, bsd_glob("$pp.??*");		# of interest
		! scalar @in and	# an empty ppath is just echoed
			($ret = print "$pp\n"),
			next;

		# If we get here, there's at least one thing at the end of
		# of the ppath.  Print the first one normally; anything
		# else is indented and is likely an encapsulation error.
		# xxx should that be flagged somehow?
		#
		$ret = print shift @in, "\n";
		$ret = print "   $_\n"		for (@in);
	}
	return $ret;
}

sub lstree { my( $tree )=@_;

	$tree ||= $dir;
	! -e $tree	and die "$tree: no such file or directory";

	my $pdir = up_dir($dir);	# parent directory
	$prefix = get_prefix($pdir);

	my $follow_fast = 1;	# follow symlinks without rigorous
		# checking; also means that (-X _) works without stat

	my $ret = find(
		{ wanted => \&visit, follow_fast => $follow_fast },
		$tree
	);
	# Dummy call to newptobj() to cough up the last buffered object.
	newptobj("", 0, 0, 0);			# shake out the last one

	# XXX what does find return?
	print "lstree: find returned '$ret' for $tree"		if $ret;
	# XXX call om*
	print "$objectcount object", ($objectcount == 1 ? "" : "s"), "\n";
	return $ret;
}

sub mknode { my( @nodes )=@_;

	# Don't allow empty node, especially for delnode, which could
	# result in a disastrous rmtree against the entire pairtree.
	#
	die "mknode: no node"		unless scalar(@nodes);

	my $pdir = up_dir($dir);	# parent directory
	$prefix = get_prefix($pdir);
	my ($pp, $ret);
	for (@nodes) {
		s/^$prefix//;
		$pp = id2ppath($_);
		# double check that we won't create a bad pairtree
		die "bad node: $_"			if m,$R/*$,;
		$pp = $pdir . $pp . bud($_);
		eval { $ret = mkpath($pp) };
		die "Couldn't create $pp: $@"		if $@;
		if ($ret == 0) {
			! -e $pp and
				die("mknode: mkpath returned '0' for $pp");
			print "error: $pp ($_) already exists\n";
			next;
		}
		# XXX should do anvls quoting
		$opt{format} == OM_ANVL and
			print("node: $_ | $pp\n")
		or
			print($pp, "\n")
		;
	}
	return $ret;
}

sub mktree { my( $tree, $prefix )=@_;

	$tree ||= $dir;			# use default, but only if the
	$tree = prep_file($tree, $R)	# tree wasn't given explicitly
		if ($tree ne $dir);
	my $pdir = up_dir($tree);	# parent directory
	my $ret;
	eval { $ret = mkpath($tree) };
	die "Couldn't create $tree: $@"			if $@;
	die "mktree: mkpath returned '$ret' for $tree"	if ! $ret;

	$prefix ||= "";
	my $pxfile = $pdir . $pfixtail;
	my $msg = file_value("> $pxfile", $prefix)
		if ($prefix);
	if ($msg) {
		print "$pxfile: $msg\n";
		return 0;
	}
	# set_namaste(0, "pairtree_$VERSION");  XXXXXXXXX no way to give dir!
	return 1;
}

sub rmnode { my( @nodes )=@_;

	# Don't allow empty node, especially for delnode, which could
	# result in a disastrous rmtree against the entire pairtree.
	#
	die "rmnode: no node"		unless scalar(@nodes);

	my $pdir = up_dir($dir);	# parent directory
	$prefix = get_prefix($pdir);
	my ($pp, $ret);
	for (@nodes) {
		s/^$prefix//;
		$pp = $pdir . id2ppath($_);
		# double check that we won't delete whole pairtree
		die "bad node: $_"
			if m,$R/*$,;
		eval { $ret = File::Path::rmtree($pp) };
		die "Couldn't delete $pp: $@"		if $@;
		if (! $ret) {
			print "warning: $_ ($pp) ", (-e $pp ?
				"not removed" : "doesn't exist"), "\n";
			next;
			# xxx this shouldn't be a fatal error, but almost
			#     a lazy existence check -- what should our
			#     exit status be in this case?
		}
		print "removed: $_ | $pp\n";
		# XXX should do anvls quoting
	}
	return $ret;
}

sub rmtree { my( $tree )=@_;

	print "XXX Not implemented yet; use 'rm -r'\n";
}

sub i2p { my( @ids )=@_;

	print id2ppath($_), "\n"	for (@ids);
}

sub p2i { my( @paths )=@_;

	print ppath2id($_), "\n"	for (@paths);
}

# =============
#find({ wanted => \&donode, preprocess => \&prenode, postprocess => \&postnode }, $tree);
#
#sub prenode{
#
#	return () if (scalar(@_) == 0);		# no work if no items
#	return @_ if ($in_object);		# no-op if inside object
#	my @ground = ();
#	my @objdirs = ();
#	for (@_) {
#		($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $sze)
#			= stat($_);
#		#if (m@^[^/]{$pairp1,}@ || S_ISREG($mode)) {	# xxx efficiency?
#		if (m@^[^/]{$pairp1,}@ || -f $_) {
#			push(@ground, $_);
#		}
#		elsif (-d $_)  {
#			push(@objdirs, $_);
#		}
#		else {		# nothing else will be processed
#			$irregularcount++;
#		}
#	}
#	print("Ground files: ", join(", ", @ground), "\n")
#		if (scalar(@ground) > 0);
#	push @ground, sort(@objdirs);
#	return @ground;
#}
# =============

# XXX add to spec: two ways that a pairpath ends: 1) the form of the
# ppath (ie, ends in a morty) and 2) you run "aground" smack into
# a "longy" ("thingy") or a file

# xxx other stats to gather: total dir count, total count of all things
# that aren't either reg files or dirs; plus max and averages for all
# things like depth of ppaths (ids), depth of objects, sizes of objects,
# fanout; same numbers for "pairtree.*" branches

my ($pdname, $tpname, $wpname);
my $symlinks_followed = 1;
my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $sze);

my %curobj = ( 'ppath' => '', 'encaperr' => 0, 'octets' => 0, 'streams' => 0 );
sub newptobj{ my( $ppath, $encaperr, $octets, $streams )=@_;

	if ($curobj{'ppath'}) {		# print record of previous obj
		$_ = ppath2id($curobj{'ppath'});
		s/^/$prefix/;		# uses global $prefix from lstree()
		# XXX redo properly 
		$opt{format} == OM_ANVL and
			print("node: ",
				$_, " | ",
				$curobj{'ppath'}, " | ",
				$curobj{'encaperr'}, " | ",
				$curobj{'octets'}, ".", $curobj{'streams'},
				"\n")
		or
			print($_, (! $opt{long} ? "" :
				" $curobj{'octets'}.$curobj{'streams'}"),
				"\n")
		;

		$curobj{'ppath'} eq $ppath and
			print "ERROR: bad pairtree: $ppath contains more ",
				"than one object\n";	# xxx better msg
	}
	# xxx strange
	die "newptobj: all args must be defined"
		unless (defined($ppath) && defined($encaperr)
			&& defined($octets) && defined($streams));
	$curobj{'ppath'} = $ppath;
	$curobj{'encaperr'} = $encaperr;
	$curobj{'octets'} = $octets;
	$curobj{'streams'} = $streams;
}

sub visit {	# receives no args

	$pdname = $File::Find::dir;		# current parent directory name
	$tpname = $_;				# current filename in that dir
	$_ = $wpname = $File::Find::name;	# whole pathname to file

	# We always need lstat() info on the current node XXX why?
	# xxx tells us all, but if following symlinks the lstat is done
	#
	($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $sze) = lstat($tpname)
		unless ($symlinks_followed);	# ... by find:  use (-X _).

	#print "NEXT: $pdname $_ $wpname\n";

	# If we follow symlinks (usual), we have to expect the -l type,
	# which hides the type of the link target (what we really want).
	#
	if (-l _) {
		$symlinkcount++;
		print "XXXX SYMLINK $_\n";
		# yyy presumably this branch never happens when
		#     _not_ following links?
		($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $sze)
			= stat($tpname);	# get the real thing
	}
	# After this, tests of the form (-X _) give almost everything.

	if (-f $tpname) {
		$filecount++;
		if (m@^.*$R/(.*/)?pairtree.*$@) {
			### print "$pdname PTREEFILE $tpname\n";
			# xxx    if $verbose;
			# else -prune ??
		}
		elsif (m@^.*$R/$P/[^/]+$@) {
			#print "m@.*$R/$P/[^/]+@: $_\n";
		 	print "$pdname UF $tpname\n";
		}
		else {
			# xxx sanity check that $curobj is defined
			$curobj{'octets'} += $sze;
			### print "sssss $curobj{'octets'}\n";
			$curobj{'streams'}++;
		#	-fprintf $altout 'IN %p %s\n'
		#	$noprune
		}
	}
	elsif (-d $tpname) {
		$dircount++;
		if (m@^.*$R/(.*/)?pairtree.*$@) {
			print "$pdname PTREEDIR $tpname\n";
			# xxx if $verbose;
		#	-prune
		}
		# At last, we're entering a "regular" object.
		# XXXXXXX add re qualifier so Perl knows re's not changing
		elsif (m@^.*$R/($P/)?[^/]{$pairp1,}$@) {
			# start new object; but end previous object first
			# form: ppath, EncapErr, octets, streams
			$objectcount++;
			newptobj($pdname, 0, 0, 0);
			# print "$pdname NS $tpname\n";
			#	-fprintf $altout 'START %h 0\n'
			#	$noprune
		}
		elsif (m@^.*$R/$P$@) {
			#	-empty
			# xxx if $verbose...	-printf '%p EP -\n'
		}
		# $pair, $pairm1, $pairp1
		# We have a post-morty encapsulation error
		elsif (m@^.*$R/([^/]{$pair}/)*[^/]{1,$pairm1}/[^/]{1,$pair}$@) {
			print "$pdname PM $tpname\n";
			#	-fprintf $altout 'START %h 0\n'
			#	$noprune
		}
	}
	else {
		$irregularcount++;
	}
}

# xxx bring in om and oml from Namaste.pm

# 	# Node invariants:
# 	#   1.  During main execution of a node visit, the stack top
# 	#       names the parent dir (pdname) of the current node.
# 	#   2.  To achieve this, before main execution our node's parent
# 	#       is compared to the stack top, from which we expect one of
# 	#       two outcomes.
# 	#            ab/cd/ef
# 	#            ab/cd/efg
# 	#   3.  Either our node is an immediate descendant of the stack top,
# 	#       or the stack top is from a completed subtree on a different
# 	#       branch.
# 	#   4.  In the latter case we "unvisit" each node in the stack top,
# 	#       popping the stack as we go.
# 	#   5.  Lstat will always have been called before the real work
# 	#       begins, regardless of whether symlinks are being followed.
# 	#   6.  Upon exit, if we are a directory, the current wpname is
# 	#       pushed on the stack in anticipation of descent into it;
# 	#       if we want to detect the case of an empty path or
# 	#       directory, it is necessary to push onto the stack now
# 	#       because we won't have a record of it (because there's
# 	#       no further descent into it if the directory is empty).
# 	# 
# 	# Check our current ancestory and pop the stack as needed
# 	# until stack top equals the parent for this (current) node.
# 	# If there's a current item (open), we have to check for item
# 	# boundaries; if we pop back through an item name, we need to
# 	# close it.
# 
# 	# We may accumulate an item at any level.  We need to close an
# 	# item when (a) we pop out of it or (b) descend into a ppath
# 	# that extends from the same level.  If we pop out of it (a), a
# 	# common case is when its enclosing directory is the only thing
# 	# at the end of a ppath.  If we descend (b) into a ppath
# 	# extension, we'll have to save the current item info on the
# 	# stack first, as we might encounter other items before we pop
# 	# back up an know whether our item is properly encapsulated.
# 	#
# 
# 	# Feb 16:
# 	# Modeling assumptions below.  If these are wrong then our theory
# 	# is wrong, and we bail with "broken model".
# 	# 
# 	# Search is a depth-first, pre-order traversal.  Because we want
# 	# to follow symlinks, we can't take advantage of the preprocess
# 	# and postprocess options, which become no-ops in this case.
# 	# This means we have to build our own stack.
# 	# 
# 	# We compute object sizes with a straightforward but naive use of
# 	# what stat() returns for files that we visit.  This means we will
# 	# be inaccurate when hard links or symlinks point to a file more
# 	# than once (xxx and for sparse files?).  In principle, find()
# 	# detects cycles (follow_fast), so whole directories shouldn't
# 	# be counted twice.
# 	# 
# 	# When visiting a node, we assume there are three cases.
# 	#  (a) We are at the same level as previously visited node, ie,
# 	#      current parent equals previous parent.
# 	#  (b) We just descended, ie, current parent extends previous
# 	#      parent.  Assume also that because of pre-order traversal,
# 	#      descent is "by one" but ascent blows thru prior levels to
# 	#      jump into next subtree (post-order would invert these).
# 	#  (c) We just exhausted the subtree we were in and jumped ((b)) to
# 	#      a new subtree that was on find()'s stack, ie, current parent
# 	#      neither equals nor extends the previous parent.  In this
# 	#      case we have to pop our own stack, reporting on all
# 	#      completed nodes along the way (the whole reason for doing
# 	#      this work) until reaching the first match against a subpath
# 	#      of the current parent.  Assume, by pre-order traversal,
# 	#      that we will be a "by one" descendant of a path that was
# 	#      on our stack, ie, that we can pop until we exactly match
# 	#      against the current parent.
# 	#
# 	# Roughly, nodes are either directories or non-directories.
# 	# Nodes are treated one way when descending (here, via visit())
# 	# and another way when ascending (via unvisit()).
# 	# 
# 	# Put top of stack in shorter name.
# 	$top = $ppstack[$#ppstack];		# xxx is this $#... safe?
# 
# 	# Because we push a directory onto the stack before we get here,
# 	# we don't distinguish here between case (a) and case (b).
# 	#
# 	#if ($pdname eq $top->{'pp'}) {		# Same level -- case (a)
# 	#	print "descendant or peer $_\n";	# xxx now what?
# 	#	#push(@{$top->{'items'}}, $_);
# 	#	#$top->{'flag'} |= 1;
# 	#}
# 	#elsif ($pdname =~ m@^$top->{'pp'}@) {
# 	#	die("find unexpectedly jumped more than one level deeper"
# 	#			. ": ppath=$top->{'pp'}, pdname=$pdname")
# 	#		if ($top->{'pp'} ne '');
# 	#	# else still initializing (first visit), so fall through
# 	#}
# 	if ($pdname ne $top->{'pp'} &&	# if we're not at same or lower level
# 		$top->{'pp'} ne '') {	# ... and it's not first node ever
# 		do {
# 			# XXXXX much reporting during "unvisit"
# 			unvisit(pop(@ppstack));
# 			$top = $ppstack[$#ppstack];	# xxx $#... safe?
# 			# xxx check for underflow
# 		} until ($pdname eq $top->{'pp'});
# 	}
# 
# 	# If we get here, the stack top's pp is the same as our parent
# 	# (or it's empty because we're at our first node ever).
# 	#
# 	if (-l _) {
# 		print "XXXX SYMLINK $_\n";
# 		# XXX what does this branch do when _not_ following links?
# 		($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $sze)
# 			= stat($tpname);		# get the real thing
# 			# get type that symlink points to
# 	}
# 
# # $in_item means we're in an item directory; only turn $in_item off when leaving
# # if (! $in_item && ! -d _) {
# #	then we have to count current node as part of something
# # }
# # if $in_item {
# #	if -f   add file stats
# #	elsif -d  add dir stats
# #	else    add other node stats
# # }
# #
# 	# If here, we've done stat or lstat for the actual file or dir,
# 	# therefore the filehandle '_' contains what we need.
# 	#
# 	if (-f _) {
# 
# 		# Regular File Branch.
# 		#
# 		# Every file belongs to some item.  Every item is either an
# 		# object or, if improperly encapsulated, part of an object.
# 		# If we encounter a file and we're not 'in_item', then
# 		# it's not properly encapsulated; otherwise, our file
# 		# gets counted as part of the current item's stats.
# 		#
# 		#xxxxx put this back in _after_ processing node (during
# 		# unvisit:  if ($wpname =~ m@^.*$R/(.*/)?pairtree.*$@) {
# 		#	-prune
# 		#}
# 		if ($in_item) {
# 			# yyy add size to stacked object
# 			$curobj{'bytes'} += (-s _);
# 			$curobj{'streams'}++;
# 			#print "cobjbytes=$curobj{'bytes'}, cobjstreams=",
# 			#	$curobj{'streams'}, "\n";
# 		#	-fprintf $altout 'IN %p %s\n'
# 		#	$noprune
# 		}
# 		else {
# 			# XXX create item, not properly encapsulated,
# 			#     in which to put the file
# 		 	print "$pdname UF $tpname\n";
# 		#if ($wpname =~ m@^.*$R/$P/[^/]+$@) {
# 		#	#print "m@.*$R/$P/[^/]+@: $_\n";
# 		#	# yyy add item to stacked object top level,
# 		#	#     flag encap err
# 		#	# yyy add size to stacked object
# 		#	-fprintf $altout 'UF %h %s\n'
# 		}
# 		return;
# 	}
# 	elsif (! -d _) {
# 
# 		# Non-regular file, non-directory Branch.
# 		#
# 		$irregularcount++;
# 		# xxxx can't under follow_fast, _ caches stat results; can't I
# 		# get the file types (to count)  without doing another stat?
# 		return;
# 	}
# 
# 	# Directory (or symlink) Branch.
# 	#
# 	# If we're here we know that we have a directory (-d _).
# 
# 	# Now, look at the form of pathname.
# 	#
# 	#xxxxx put this back in _after_ processing node (during
# 	# unvisit: if ($wpname =~ m@^.*$R/(.*/)?pairtree.*$@) {
# 	#	-prune
# 	#	$top = mkstackent($pdname);
# 	#	push(@ppstack, $top);
# 	#}
# 
# 	# XXX add re qualifier so Perl knows re's not changing
# 	# if we've hit what might be a regular object dir...
# 	if ($wpname =~ m@^.*$R/($P/)?[^/]{$pairp1,}$@) {
# 
# 		# We're at an item directory; hopefully it's a properly
# 		# encapsulated object, but we won't know until all of its
# 		# peers have been seen.  So we "start" new current item
# 		# after first closing any previously open item.  It is a
# 		# fatal error if any previous item is either not at the
# 		# same level or not closed (fatal because our assumptions
# 		# about the algorithm may be wrong).
# 		#
# 		if ($ci_ppath eq '') {		# previous item was closed
# 			$ci_ppath = $pdname;
# 		}
# 		elsif ($ci_ppath eq $pdname) {	# still open at the same level
# 
# 			# Need to close previous item and store on stack
# 			push(@{$top->{'items'}}, {	# push, later shift
# 				'ppath' => $ci_ppath,
# 				'wpname' => $ci_wpname,
# 				'octets' => $ci_octets,
# 				'streams' => $ci_streams,
# 			});
# 		}
# 		else {
# 			die("in $pdname, previous item '$ci_wpname' "
# 				. "wasn't closed");
# 		}
# 
# 		# Initialize new item.  $ci_ppath already set correctly.
# 		#
# 		$ci_wpname = $wpname;
# 		$ci_octets = $ci_streams = 0;
# 
# 		$top = mkstackent($wpname);	# xxx PM?
# 		push(@ppstack, $top);
# 
# 		# yyy compare pdname to stack top.
# 		#     if pdname is same as stack top, {add item
# 		#     to list contained in stack top, flag encaperr}
# 		#     elsif pdname is not superstring of stack top {
# 		#     we've just closed off a ppath and we need
# 		#     to pop the stack top and report (a) proper
# 		#     or improper encapsulation (#items > 1 or
# 		#     any file item) and (b) accumulated oxum (if
# 		#     no items, report EP empty ppath.}
# 		#     In any case, push curr ppath as new stack
# 		#     top and add item to list at stack top, but
# 		#     flag encap err if PM err)
# 		#     (at end, report stack top)
# 		# start new object; but end previous object first
# 		# form: ppath, EncapErr, bytes, streams
# 		print "$pdname NS $tpname\n";
# 		#	-fprintf $altout 'START %h 0\n'
# 		#	$noprune
# 	}
# 	elsif ($wpname =~ m@^.*$R/$P$@) {
# 
# 		# Extending the ppath, no item impact.
# 		#
# 		$top = mkstackent($wpname);
# 		push(@ppstack, $top);
# 
# 		# yyy see above
# 		#	-empty
# 		#	-printf '%p EP -\n'
# 	}
# 	# $pair, $pairm1, $pairp1
# 	elsif ($wpname =~
# 	    m@^.*$R/([^/]{$pair}/)*[^/]{1,$pairm1}/[^/]{1,$pair}$@) {
# 
# 		# We have a short directory following the end of a ppath.
# 		# This means a Post-Morty warning and starts a new item.
# 
# 		# yyy [combine with NS regexp and do similarly???]
# 		# xxx push dir node
# #	XXXXXXXXXXXXX check and close any current item
# 		print "$pdname PM $tpname\n";
# 		$top = mkstackent($wpname);
# 		#push(@{$top->{'items'}}, $_);
# 		push(@ppstack, $top);
# 		#	-fprintf $altout 'START %h 0\n'
# 		#	$noprune
# 	}
# 	else {
# 		$top = mkstackent($pdname);
# 		push(@ppstack, $top);
# 	}
# 
# 	return;
# }

=head1 OPTIONS

=over

=item B<-d>

Specify pairtree directory.

=item B<-h>, B<--help>

Print extended help documentation.

=item B<--man>

Print full documentation.

=item B<--version>

Print the current version number and exit.

=back

=head1 SEE ALSO

touch(1)

=head1 AUTHOR

John Kunze I<jak at ucop dot edu>

=head1 COPYRIGHT

  Copyright 2009 UC Regents.  Open source Apache License, Version 2.

=begin CPAN

=head1 README

=head1 SCRIPT CATEGORIES

=end CPAN

=cut

__END__

#!/usr/bin/perl -w -Ilib

# XXX to pairtree spec add appendix enumberating some named methods for
#   deriving objdir names
# XXX add to spec: two ways that a pairpath ends: 1) the form of the
# ppath (ie, ends in a morty) and 2) you run "aground" smack into
# a "longy" ("thingy") or a file

# xxx other stats to gather: total dir count, total count of all things
# that aren't either reg files or dirs; plus max and averages for all
# things like depth of ppaths (ids), depth of objects, sizes of objects,
# fanout; same numbers for "pairtree.*" branches

use strict;
use File::Find;
#use File::Pairtree qw( $pair $pairp1 $pairm1 );
use File::Pairtree qw( $pair $pairp1 $pairm1 );

my $R = $File::Pairtree::root;

#XXX check for bad char encodings?  (Cory S.)

# Set up a big "find" expression that depends on these features of GNU find:
#   -regex for high-functioning, wholepath matching
#   -printf to tag files/dirs found with certain characteristics
#
# The basic idea is to walk a given hierarchy and tag stuff that looks
# like an object.  Mainstream objects are encapsulated in directory names
# of three characters or more, but we still have to detect the edge cases.
# All candidate object cases are printed on a line with the pairpath
# (ppath) first (as primary sort field), the tagged case, and the file/dir
# name found at the end of the ppath.
#
# XXXXXXXX better tags needed
#	NS=Non-Shorty directory (normal object)
#	UF=Unencapsulated File (encaps. warning),
#	PM=Post-Morty Shorty or Morty encountered (encaps. warning)
#	UG=Unencapsulated Group (encaps. warning)
#       EP=Empty Pairpath (indicator)
#
# The output of the 'find' is sorted (important) so that leaves descending
# from a given ppath cluster in groups.  The resulting groups are used to
# figure out how best to detect and repair any encapsulation problems.
# We offer xxx to repair encapsulation problems because they're non-trivial
# to detect (ie, there will be pairtree walkers that don't detect them) and
# we want to encourage proper encapsulation for the sake of interoperability.
#
# One odd case is an object right at the root of a pairtree, which means
# an empty path, hence an empty identifier.  Because systems frequently
# reserve special meaning for an empty or root value, and they/we might
# want to put something at that special location (eg, an object describing
# the pairtree), we will detect and count it as an object; its meaning and
# (il)legality is up to the implementor.  This has the nice side-effect
# that we'll have no fatal errors in processing a pairtree.
#
# XXX do edge case of pairtree_root/foo.txt
# XXX what to do with symlinks? and unusual filenames?

# Set $verbosefind to '-print' to show everything that 'find' handles,
# but normally don't show by setting it to '-true'.
my $verbosefind='-print';
#my $verbosefind = '-true';

# Normally prune for speed.  Set $verbosefind='-print' and noprune='-true'
# to see what processing steps would happen if you don't prune. xxx
my $noprune='-true';
#my $noprune = '-prune';

# This matches the base ppath in 'find'.
my $PP = '\([^/][^/]/\)*[^/][^/]?';

# This matches the base ppath in 'perl'.
my $P = "([^/]{$pair}/)*[^/]{1,$pair}";

my $tree = $ARGV[0];

$| = 1;		# XXXX unbuffer output   

my $irregularcount = 0;		# non file, non dir fs items to report xxx
my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $sze);

my $in_object = 0;

my $wpname = '';		# whole pathname
my $tpname = '';		# tail of name
my $pdname = '';		# current directory name

my %curobj = ( 'ppath' => '', 'encaperr' => 0, 'octets' => 0, 'streams' => 0 );

my @ppstack = ();

sub mkstackent{ my( $ppath )=@_;
	return { 'pp' => $ppath, 'bytes' => 0, 'items' => [],
			'objtype' => 1, 'flag' => 0 };
}

my ($ci_state, $ci_wpname, $ci_ppath, $ci_octets, $ci_streams);
$ci_ppath = '';

push(@ppstack, mkstackent(''));
my $top;
my $oldpdname = '';
my $symlinks_followed = 1;			# to minimize lstat calls
my $follow_fast = 1;	# follow symlinks without rigorous checking
			# also means that (-X _) works without stat
#$symlinks_followed = $follow_fast = 0;		# xxx make option-controled

my $in_item = 0;		# we're either in an item or not

find({ wanted => \&visit, follow_fast => $follow_fast }, $tree);

# Using the find() routine is not exactly straightforward.  We cannot
# directly track find()'s stack operations because we may want to follow
# symlinks, in which case find()'s 'preprocess' and 'postprocess' options
# become no-ops.  Instead, the callbacks to 'wanted' (our visit())
# effectively present us with a sequence of node pathnames, p1, p2, ...,
# that are related, we hope, by the following assumptions:
#
#    1. One-step descent: if pN+1 has more path components than pN,
#       it has only one more component.
# ....

sub visit{	# receives no args

	$pdname = $File::Find::dir;		# current parent directory name
	$tpname = $_;				# current filename in that dir
	$wpname = $File::Find::name;		# whole pathname to file
	($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $sze) = lstat($tpname)
		unless ($symlinks_followed);	# else lstat done for us already
	print "NEXT: $pdname $_ $wpname\n";

	# Node invariants:
	#   1.  During main execution of a node visit, the stack top
	#       names the parent dir (pdname) of the current node.
	#   2.  To achieve this, before main execution our node's parent
	#       is compared to the stack top, from which we expect one of
	#       two outcomes.
	#            ab/cd/ef
	#            ab/cd/efg
	#   3.  Either our node is an immediate descendant of the stack top,
	#       or the stack top is from a completed subtree on a different
	#       branch.
	#   4.  In the latter case we "unvisit" each node in the stack top,
	#       popping the stack as we go.
	#   5.  Lstat will always have been called before the real work
	#       begins, regardless of whether symlinks are being followed.
	#   6.  Upon exit, if we are a directory, the current wpname is
	#       pushed on the stack in anticipation of descent into it;
	#       if we want to detect the case of an empty path or
	#       directory, it is necessary to push onto the stack now
	#       because we won't have a record of it (because there's
	#       no further descent into it if the directory is empty).
	# 
	# Check our current ancestory and pop the stack as needed
	# until stack top equals the parent for this (current) node.
	# If there's a current item (open), we have to check for item
	# boundaries; if we pop back through an item name, we need to
	# close it.

	# We may accumulate an item at any level.  We need to close an
	# item when (a) we pop out of it or (b) descend into a ppath
	# that extends from the same level.  If we pop out of it (a), a
	# common case is when its enclosing directory is the only thing
	# at the end of a ppath.  If we descend (b) into a ppath
	# extension, we'll have to save the current item info on the
	# stack first, as we might encounter other items before we pop
	# back up an know whether our item is properly encapsulated.
	#

	# Feb 16:
	# Modeling assumptions below.  If these are wrong then our theory
	# is wrong, and we bail with "broken model".
	# 
	# Search is a depth-first, pre-order traversal.  Because we want
	# to follow symlinks, we can't take advantage of the preprocess
	# and postprocess options, which become no-ops in this case.
	# This means we have to build our own stack.
	# 
	# We compute object sizes with a straightforward but naive use of
	# what stat() returns for files that we visit.  This means we will
	# be inaccurate when hard links or symlinks point to a file more
	# than once (xxx and for sparse files?).  In principle, find()
	# detects cycles (follow_fast), so whole directories shouldn't
	# be counted twice.
	# 
	# When visiting a node, we assume there are three cases.
	#  (a) We are at the same level as previously visited node, ie,
	#      current parent equals previous parent.
	#  (b) We just descended, ie, current parent extends previous
	#      parent.  Assume also that because of pre-order traversal,
	#      descent is "by one" and ascent blows past previous nodes
	#      to jump into next subtree (post-order would invert these).
	#  (c) We just exhausted the subtree we were in and jumped to a
	#      new subtree that was on find()'s stack, ie, current parent
	#      neither equanls nor extends the previous parent.  In this
	#      case we have to pop our own stack, reporting on all
	#      completed nodes along the way (the whole reason for doing
	#      this work) until reaching the first match against a subpath
	#      of the current parent.  Assume, by pre-order traversal,
	#      that we will be a "by one" descendant of a path that was
	#      on our stack, ie, that we can pop until we exactly match
	#      against the current parent.
	#
	# Roughly, nodes are either directories or non-directories.
	# Nodes are treated one way when descending (here, via visit())
	# and another way when ascending (via unvisit()).
	# 
	# Put top of stack in shorter name.
	$top = $ppstack[$#ppstack];		# xxx is this $#... safe?

	# Because we push a directory onto the stack before we get here,
	# we don't distinguish here between case (a) and case (b).
	#
	#if ($pdname eq $top->{'pp'}) {		# Same level -- case (a)
	#	print "descendant or peer $_\n";	# xxx now what?
	#	#push(@{$top->{'items'}}, $_);
	#	#$top->{'flag'} |= 1;
	#}
	#elsif ($pdname =~ m@^$top->{'pp'}@) {
	#	die("find unexpectedly jumped more than one level deeper"
	#			. ": ppath=$top->{'pp'}, pdname=$pdname")
	#		if ($top->{'pp'} ne '');
	#	# else still initializing (first visit), so fall through
	#}
	if ($pdname ne $top->{'pp'} &&	# if we're not at same or lower level
		$top->{'pp'} ne '') {	# ... and it's not first node ever
		do {
			# XXXXX much reporting during "unvisit"
			unvisit(pop(@ppstack));
			$top = $ppstack[$#ppstack];	# xxx $#... safe?
			# xxx check for underflow
		} until ($pdname eq $top->{'pp'});
	}

	# If we get here, the stack top's pp is the same as our parent
	# (or it's empty because we're at our first node ever).
	#
	if (-l _) {
		print "XXXX SYMLINK $_\n";
		# XXX what does this branch do when _not_ following links?
		($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $sze)
			= stat($tpname);		# get the real thing
			# get type that symlink points to
	}

# $in_item means we're in an item directory; only turn $in_item off when leaving
# if (! $in_item && ! -d _) {
#	then we have to count current node as part of something
# }
# if $in_item {
#	if -f   add file stats
#	elsif -d  add dir stats
#	else    add other node stats
# }
#
	# If here, we've done stat or lstat for the actual file or dir,
	# therefore the filehandle '_' contains what we need.
	#
	if (-f _) {

		# Regular File Branch.
		#
		# Every file belongs to some item.  Every item is either an
		# object or, if improperly encapsulated, part of an object.
		# If we encounter a file and we're not 'in_item', then
		# it's not properly encapsulated; otherwise, our file
		# gets counted as part of the current item's stats.
		#
		#xxxxx put this back in _after_ processing node (during
		# unvisit:  if ($wpname =~ m@^.*$R/(.*/)?pairtree.*$@) {
		#	-prune
		#}
		if ($in_item) {
			# yyy add size to stacked object
			$curobj{'bytes'} += (-s _);
			$curobj{'streams'}++;
			#print "cobjbytes=$curobj{'bytes'}, cobjstreams=",
			#	$curobj{'streams'}, "\n";
		#	-fprintf $altout 'IN %p %s\n'
		#	$noprune
		}
		else {
			# XXX create item, not properly encapsulated,
			#     in which to put the file
		 	print "$pdname UF $tpname\n";
		#if ($wpname =~ m@^.*$R/$P/[^/]+$@) {
		#	#print "m@.*$R/$P/[^/]+@: $_\n";
		#	# yyy add item to stacked object top level,
		#	#     flag encap err
		#	# yyy add size to stacked object
		#	-fprintf $altout 'UF %h %s\n'
		}
		return;
	}
	elsif (! -d _) {

		# Non-regular file, non-directory Branch.
		#
		$irregularcount++;
		# xxxx can't under follow_fast, _ caches stat results; can't I
		# get the file types (to count)  without doing another stat?
		return;
	}

	# Directory (or symlink) Branch.
	#
	# If we're here we know that we have a directory (-d _).

	# Now, look at the form of pathname.
	#
	#xxxxx put this back in _after_ processing node (during
	# unvisit: if ($wpname =~ m@^.*$R/(.*/)?pairtree.*$@) {
	#	-prune
	#	$top = mkstackent($pdname);
	#	push(@ppstack, $top);
	#}

	# XXX add re qualifier so Perl knows re's not changing
	# if we've hit what might be a regular object dir...
	if ($wpname =~ m@^.*$R/($P/)?[^/]{$pairp1,}$@) {

		# We're at an item directory; hopefully it's a properly
		# encapsulated object, but we won't know until all of its
		# peers have been seen.  So we "start" new current item
		# after first closing any previously open item.  It is a
		# fatal error if any previous item is either not at the
		# same level or not closed (fatal because our assumptions
		# about the algorithm may be wrong).
		#
		if ($ci_ppath eq '') {		# previous item was closed
			$ci_ppath = $pdname;
		}
		elsif ($ci_ppath eq $pdname) {	# still open at the same level

			# Need to close previous item and store on stack
			push(@{$top->{'items'}}, {	# push, later shift
				'ppath' => $ci_ppath,
				'wpname' => $ci_wpname,
				'octets' => $ci_octets,
				'streams' => $ci_streams,
			});
		}
		else {
			die("in $pdname, previous item '$ci_wpname' "
				. "wasn't closed");
		}

		# Initialize new item.  $ci_ppath already set correctly.
		#
		$ci_wpname = $wpname;
		$ci_octets = $ci_streams = 0;

		$top = mkstackent($wpname);	# xxx PM?
		push(@ppstack, $top);

		# yyy compare pdname to stack top.
		#     if pdname is same as stack top, {add item
		#     to list contained in stack top, flag encaperr}
		#     elsif pdname is not superstring of stack top {
		#     we've just closed off a ppath and we need
		#     to pop the stack top and report (a) proper
		#     or improper encapsulation (#items > 1 or
		#     any file item) and (b) accumulated oxum (if
		#     no items, report EP empty ppath.}
		#     In any case, push curr ppath as new stack
		#     top and add item to list at stack top, but
		#     flag encap err if PM err)
		#     (at end, report stack top)
		# start new object; but end previous object first
		# form: ppath, EncapErr, bytes, streams
		print "$pdname NS $tpname\n";
		#	-fprintf $altout 'START %h 0\n'
		#	$noprune
	}
	elsif ($wpname =~ m@^.*$R/$P$@) {

		# Extending the ppath, no item impact.
		#
		$top = mkstackent($wpname);
		push(@ppstack, $top);

		# yyy see above
		#	-empty
		#	-printf '%p EP -\n'
	}
	# $pair, $pairm1, $pairp1
	elsif ($wpname =~
	    m@^.*$R/([^/]{$pair}/)*[^/]{1,$pairm1}/[^/]{1,$pair}$@) {

		# We have a short directory following the end of a ppath.
		# This means a Post-Morty warning and starts a new item.

		# yyy [combine with NS regexp and do similarly???]
		# xxx push dir node
#	XXXXXXXXXXXXX check and close any current item
		print "$pdname PM $tpname\n";
		$top = mkstackent($wpname);
		#push(@{$top->{'items'}}, $_);
		push(@ppstack, $top);
		#	-fprintf $altout 'START %h 0\n'
		#	$noprune
	}
	else {
		$top = mkstackent($pdname);
		push(@ppstack, $top);
	}

	return;
}

use constant CI_CLOSED => 0;
use constant CI_OPEN => 1;

sub unvisit{ my( $top )=@_;

	die "can't unvisit undefined stack node"
		if (! defined($top));

	# if stack top eq current item, close out item
	# xxx maybe 'pp' should be 'wpname' for clarity
	if ($top->{'pp'} eq $ci_wpname) {
		$ci_state = CI_CLOSED;		# close
#		xxxxx flag parent so it knows there's an item, but try
#		      to avoid (optimistically) copying item onto stack
	}
	# xxxx print cur_item
	# xxxx if in item...
	print "unvisiting $top->{'pp'}, objtype=$top->{'objtype'}, ",
		"item(s)=", join(", ", @{$top->{'items'}}),
		", size=$top->{'bytes'}, ", "flag=$top->{'flag'}\n";
	for (@{$top->{'items'}}) {
		print $_->{'wpname'}, $_->{'octets'} . "." . $_->{'streams'};
	}
	return;
}

sub postnode{
	return;
}

sub newptobj{ my( $ppath, $encaperr, $bytes, $streams )=@_;

	if ($curobj{'ppath'}) {		# print record of previous obj
		print "id: $curobj{'ppath'}, $curobj{'encaperr'}, $curobj{'bytes'}.$curobj{'streams'}\n";
	}
	die("newptobj: all args must be defined")
		unless (defined($ppath) && defined($encaperr)
			&& defined($bytes) && defined($streams));
	$curobj{'ppath'} = $ppath;
	$curobj{'flag'} = $encaperr;
	$curobj{'bytes'} = $bytes;
	$curobj{'streams'} = $streams;
}

exit(0);

sub prenode{

	return () if (scalar(@_) == 0);		# no work if no items
	return @_ if ($in_object);		# no-op if inside object
	my @ground = ();
	my @objdirs = ();
	for (@_) {
		($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $sze)
			= stat($_);
		#if (m@^[^/]{$pairp1,}@ || S_ISREG($mode)) {	# xxx efficiency?
		if (m@^[^/]{$pairp1,}@ || -f $_) {
			push(@ground, $_);
		}
		elsif (-d $_)  {
			push(@objdirs, $_);
		}
		else {		# nothing else will be processed
			$irregularcount++;
		}
	}
	print("Ground files: ", join(", ", @ground), "\n")
		if (scalar(@ground) > 0);
	push @ground, sort(@objdirs);
	return @ground;
}

# /dev/stderr seems to be the only file name you can give to the fprintf
# action of 'find' so output from different clauses will be correctly
# interleaved.  We assume that stderr will be closed and all output
# flushed by the time the sort is finished, so when later we read
# both outputs, we won't get ahead of things. xxx say this better
#
my $altout = '/dev/stderr';

# Test for .*$R/(.*/)?pairtree.* must occur early.
#
# xxx report null: for pairtree.* case? and possibly size?
my $findexpr = qq@$verbosefind , \\
	-regex ".*$R/\\(.*/\\)?pairtree.*" \\
		-prune \\
	-o \\
	-type d \\
		-regex ".*$R/\\($PP/\\)?[^/][^/][^/]+" \\
		-printf '%h NS %f\\n' \\
		-fprintf $altout 'START %h 0\\n' \\
		$noprune \\
	-o \\
	-type d \\
		-regex ".*$R/$PP" \\
		-empty \\
		-printf '%p EP -\\n' \\
	-o \\
	-type f \\
		-regex ".*$R/$PP/[^/]+" \\
		-printf '%h UF %f\\n' \\
		-fprintf $altout 'UF %h %s\\n' \\
	-o \\
	-type d \\
		-regex ".*$R/\\([^/][^/]/\\)*[^/]/[^/][^/]?" \\
		-printf '%h PM %f\\n' \\
		-fprintf $altout 'START %h 0\\n' \\
		$noprune \\
	-o \\
	-type f \\
		-fprintf $altout 'IN %p %s\\n' \\
		$noprune \\
@;

#XXXXX yuck.  I may not be able to size improperly unencapsulated files
#  with 'find'

# The -type f test to get filesizes should occur after the UF file test
# XXX move up to first test? for efficiency?

#print "findexpr=$findexpr\n";

# xxx change pt_z to a mktemp, in case two scans are going at once
my $szfile = 'pt_z';

open(FIND, "find $tree $findexpr 2>$szfile | sort |")
	|| die("can't start find");

open(SIZES, "< $szfile") || die("can't open size file");

my $defsize = '(:unas)';		# xxx needed?
my ($sztype, $which, $size) = ('', '', 0);
my ($ptbcount, $ptfcount) = (0, 0);

sub getsizeline{
	$_ = <SIZES>;
	die("Error: unexpected size line format: $_")
		if (! /^(\S+) (\S+) (.*)/);
	return ($1, $2, $3);		# $sztype, $which, $size
}

sub getsize{ my( $ppath )=@_;

	my ($ppbcount, $ppfcount);

	# Much depends on the assumption that we're called
	# with a ppath that we are "at" in the sizes file due to
	# lookahead.  We initialize late (first call), since no input
	# will be ready for a while.  With luck the input stream will
	# be completely defined by the time we ask for the first line.
	# The line should be of type START or UF; lines of type IN we
	# should have read through until we encounter a line not of
	# type IN (always preceded by START).
	#
	if (! $sztype) {		# lazy initialization step
		($sztype, $which, $size) = getsizeline();
	}

	# Check that the $ppath we're called with matches the current
	# size line.  The check depends on the $sztype.  Remember:
	#	START %h 0	(for types NS and PM)
	#	UF %h %s	(our $ppath _is_ %h)
	#	IN %p %s	(our $ppath is contained in %p)
	# UF can be followed by START at same level (UG)
	# START can be followed by START at same level (UG)
	# xxx all these string comparisons... more efficient with ints?
	die("unexpected size line type: $sztype")
		unless ($sztype eq "START" || $sztype eq "UF");
	die("didn't find $ppath in triple: $sztype, $which, $size")
		if ($which ne $ppath);
	$ppbcount = $size;		# initialize
	$ppfcount = ($sztype eq "UF" ? 1 : 0);
	while (1) {
		($sztype, $which, $size) = getsizeline();

		if ($sztype eq "IN" && $which =~ /^$ppath/) {
			$ppbcount += $size;
		}
		elsif ($sztype eq "START") {
			last if ($which ne $ppath);
		}
		elsif ($sztype eq "UF") {
			last if ($which ne $ppath);
			$ppbcount += $size;
		}
		else {
			die("unexpected triple in size run for $ppath: "
				. "$sztype, $which, $size");
		}
		$ppfcount++;		# another file counted
	}

	# If we're here, we have total size for the given $ppath.
	# Before returning, update the overall byte and file counts
	# for the pairtree.
	#
	$ptbcount += $ppbcount;
	$ptfcount += $ppfcount;

	return "$ppbcount.$ppfcount";

	# xxxx
	#    find $f -type f | sed "s/.*/'&'/" | xargs stat -t | \
	#        awk -v f=$f '{s += $2} END {printf "%s.%s %s\n", s, NR, f}'
}

# xxx get the path right for this file
open(FIX, "> pt_fix") || warn("xxx can't open fix file");

my ($pp, $found, $type, $object);
$pp = $found = $type = $object = '';
my ($prevpp, $prevfound, $prevtype);
my $done = 0;
my $encaperrs = 0;
my $encapoks = 0;
my $emptyppaths = 0;
my $sizestr = '(:unas)';
my $msg = '';
my $verbose = 0;

# Process the 'find' output lines for objects and look for anomalies.
# Can't conclude about unencapsulated objects until we're past the
# object (this requires sort to cluster candidate objects), which means
# that we always know what the previous line and current line have on them.
#
while (1) {
	$prevpp = $pp;
	$prevfound = $found;
	$prevtype = $type;

	$_ = <FIND>;
	if (defined($_)) {
		chomp;
		if (! /^(\S+) (\S+) (.*)/) {
			# a "show all" line; pass thru
			#print "xxx: $_\n";
			next;
		}
		($pp, $type, $found) = ($1, $2, $3);
		print "Verbose: $_\n" if ($verbose);
		if ($type eq "EP") {
			# This is the only type of "found" item that doesn't
			# correspond to an object, so we can deal with it
			# without waiting for the next line to tell us what
			# it is.  We still have to fall through for the
			# sake of what encountering this item means for our
			# deduction about previous line's role, ie, we can't
			# just short cut to the next iteration with 'next;'
			#
			print "null: $pp\n";
			print FIX "null: $pp\n";
			$emptyppaths++;
		}
	}
	else {		# EOF reached -- this will be last time thru loop
		# When EOF is found, want $pp empty for one last run through
		# loop in order to properly eject final line.
		$pp = '';	# want $pp empty for last run
		$_ = '';	# want $_ defined in case of debug print
		$done = 1;
	}

	# Report is one-line per object.  Line format is one of two types
	# ok: id|filename|size|path
	# warn: id|something|size|path|message

	# This is the main part of the loop.  Normally, there would be
	# one line per object, but in the presence of encapsulation errors
	# there will be more than one line having the same ppath.  Because
	# the input was sorted first, we know that any such lines will be
	# clustered in a group, and all we have to do is detect when we
	# enter a group (sharing a ppath) and leave a group.  We do this
	# by processing the current line while remembering the previous
	# line.  There are two states: "in object" ($object ne '') or not
	# "in object" ($object eq '').
	#
	if ($object) {				# if "in object"
		if ($pp eq $prevpp) {		#    and ppath is same
			# stay "in object" and add to existing object
			$object .= " $found";
		}
		else {				# else leave object
			# dump and zero out object in preparation for another
			# xxx write fixit script to create temp dir, move
			# stuff into it, then rename to 'obj'
			$sizestr = getsize($prevpp);
			$msg = "warn: " . ppath2id($prevpp) .
				" | UG $object | " .
				$sizestr . " | $prevpp | " . 
				"unencapsulated file/dir group\n";
			print $msg;
			print FIX $msg;
			$object = "";
			$encaperrs++;
		}
	}
	else {					# if not "in object"
		#print "pp=$pp, prevpp=$prevpp, $_\n";
		if ($pp eq $prevpp) {		#    and ppath is same
			# then start new object
			$object = "$prevfound $found";
		}
		# else not entering an object; check UF and PM cases
		elsif ($prevtype eq "UF" || $prevtype eq "PM") {
			# offer to encapusulate a lone file
			$sizestr = getsize($prevpp);
			$msg = "warn: " . ppath2id($prevpp) .
				" | $prevtype $prevfound | " .
				$sizestr . " | $prevpp | " .
				($prevtype eq "UF" ? "unencapsulated file" :
				    "encapsulating directory name too short")
				. "\n";
			print $msg;
			print FIX $msg;
			$encaperrs++;
		}
		# else in mainstream case, except line 1 ($prevtype eq '')
		# XXX explain why EP needs to run through and can't
		# short cut "next" the loop
		elsif ($prevtype && $prevtype ne "EP") {
			$sizestr = getsize($prevpp);
			print "ok: ", ppath2id($prevpp), " | $prevfound | ",
				$sizestr, " | $prevpp\n";
			$encapoks++;
		}
	}
	last
		if ($done);
}

close(FIND);
close(FIX);
close(SIZES);

my $objcount = $encapoks + $encaperrs;

print "$objcount objects, including $encaperrs encapsulation warnings.  ";
print "There are $emptyppaths empty pairpaths\n";

# XXXX make sure to declare/catch /be/nt/o/r/ as improper encapsulation