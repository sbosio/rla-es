#!/usr/bin/perl

################################################################
#
# Aspell Word List Package proc script
# Copyright 2001,2002,2004 under the GNU Lesser General Public License (LGPL)
#
# 2004-08-10
#

use Data::Dumper;
use IO::File;

use Encode qw(is_utf8 decode_utf8 encode_utf8 decode encode resolve_alias);

use utf8;
use open ':utf8';

use strict;
use warnings;
no warnings qw(uninitialized utf8);
no locale;

my $VERSION = "0.60.3";

my $action     = 'create';
my $check_mode = 'safe';

my $UTF8 = resolve_alias 'utf-8';

foreach my $arg (@ARGV) {
  $arg =~ s/^-*//;
  if ($arg eq 'check' || $arg eq 'create') {
    $action=$arg;
  } elsif ($arg eq 'unsafe') {
    $check_mode = 'unsafe';
  }
}

################################################################
#
# helper functions
#

sub true ( ) {1}
sub false ( ) {0}

sub error ( $ ) {
  die \ $_[0]
}

my ($line_length,$error_count,$multi_errors);
sub line_length() {75}
sub error_message ($;$) {
  my $error;
  my $parms = $_[1];
  my $warn = defined $parms->{warn} ? $parms->{warn} : false;
  $error .= $warn ? "Warning" : "Error";
  $error .= " line $parms->{lineno}" if defined $parms->{lineno};
  $error .= ": $_[0]\n";
  my $line;
  $_ = $error;
  my $print_line = sub {print STDERR "$line\n" unless $line =~ /^\s*$/};
  while (s/(\s*?)(\S+|\n)//) {
    my ($a,$b) = ($1,$2);
    my $len = length($line) + length($a) + length($b);
    if (($line !~ /^\s*$/ && $len > line_length) || $b eq "\n") {
      &$print_line;
      $a    = "";
      $b    = "" if $b eq "\n";
      $line = "  ";
    } 
    $line .= $a;
    $line .= $b;
  }
  &$print_line;
  if (!$warn) {
    $error_count++;
    $multi_errors++ if defined $multi_errors;
  }
}
sub handle_error (;$) {
  return unless $@;
  if (ref $@) {
    error_message $ {$@}, {lineno=> $_[0]};
    $@ = undef;
  } else {
    die $@;
  }
}

sub memberof ( $ $ ) {
  foreach (@{$_[1]}) {return true if $_[0] eq $_;}
  return false;
}

sub indented_list ( @ ) {
  return join '', map {"  $_\n"} @_;
}

sub try_read ( $ ) {
  my $IN;
  my $res = open $IN, "$_[0]";
  close $IN;
  error_message ("Unable to read the file $_[0]") unless $res;
  return $res;
}

################################################################
#
# insr initialization
#

my ($key,$val,$info,$insr,@authors,%alt_encodings,%dicts,%copying,%files);
my $lang;
my $mode;
my $version;

sub lower()    {["[a-z]+",        
		 "must consist of only lowercase ASCII characters"]}
sub upper()    {["[A-Z]+",        
		 "must consist of only uppercase ASCII characters"]}
sub alpha()    {["[A-Za-z]+",     
		 "must consist of only alpha ASCII characters"]}
sub alphanum() {["[A-Za-z0-9-]+", 
		 "must consist of only alphanumeric ASCII characters or '-'"]}
sub ascii()    {["[\x20-\x7E]+",  
		 "must consist of only ASCII characters"]}
sub any()      {[".+","ERROR"]}
sub generic()  {"is not in the proper format"}

sub dict()     {return ["$lang(_[A-Z]{2}|)(|-[a-z0-9_-]+)(-[0-9]{2}|)", 
			generic]}

sub split_dict ( $ ) {my $dict = dict->[0]; 
		      my @data = $_[0] =~ /^$dict$/;
		      foreach (@data) {next unless $_;
				       $_ = substr $_, 1}
		      return @data}
sub form_dict ( @ )  {my $name = $lang;
		      $name .= "_$_[0]" if $_[0];
		      $name .= "-$_[1]" if $_[1];
		      $name .= "-$_[2]" if $_[2];
		      return $name}
sub README();

sub make_alias( $ $ $ );

my $line;
my %aliases_from;
my %aliases_to;
my %global_info;
my %global_insr = 
  (default_fill_order => [qw (name_ascii name_native strip_accents doc_encoding mode)],
   mode => {required=>false, 
            oneof=>['aspell5', 'aspell6'], 
            default=>'aspell6'},
   author =>
   {
     singular => false,
     name => {check=>any},
     name_native => {check=>any, required=>false},
     email => {required=>false, check=>[".+ at .+",generic]},
     maintainer => {required=>false,
                    oneof=>['true', 'false'], default=>'false'},
     pre => sub {},
     post => sub {
       push @authors, $info;
     }
   },
   copyright => {oneof => ["LGPL", "GPL", "FDL", "LGPL/GPL", # FSF Licenses
			   "Artistic", # Perl Artistic Licence
			   "Copyrighted", # Copyright message must remain
			   "Open Source", # Meets OSI defination
			   "Public Domain", # ie none
			   "Other", "Unknown"] },
    version => {
      check => ['\d[a-z\d\.-]+', generic],
      code => sub {$version="$val"},
      store => true,
    },
    date => {required=>false, check=>['\d\d\d\d-\d\d-\d\d', 'YYYY-MM-DD']},
    url => {required=>false},
    source_url => {required=>false},
    source_version => {required=>false},
    name_english => {check=>["[A-Z][a-z]+([ -]+[A-Z][a-z]+)*",generic]},
    name_ascii => {default => "=name_english"}, 
    name_native => {default => "=name_ascii", check=>any},
    lang => {check => ["[a-z]{2,3}(|_[A-Z]{2})(|-[a-z0-9]+)",
		      "must consist of two or three lowercase ASCII characters"],
             code => sub {
               $lang = $val;
               try_read "$lang.dat";
               push @{$files{data}}, "$lang.dat";
             },
             store => true
            },
   doc_encoding => {default => $UTF8, store=>true,
                    code => sub {
                      my $enc = resolve_alias $val;
                      error "The encoding \"$val\" is not known" unless $enc;
                    }},
   alt_encoding => {required => false,
                    check=> ['\S+ \S+', generic],
                    code => sub {
                      $val =~ /^(\S+) (\S+)/ or die;
                      my $enc = resolve_alias $1;
                      error "The encoding \"$1\" is not known" unless $enc;
                      $alt_encodings{$enc} = $2;
                    }},
   data_file => {required => false,
                 code => sub {
                   try_read $val;
                   push @{$files{data}}, $val;
                 }},
   readme_file => {required => false, check=> upper,
                   normal=>"README", generate => sub {README}},
   readme_extra => {required => false, store=> true,
                    code => sub {
                      my ($file) = $val =~ /^(.+?)(| .+)$/;
                      try_read "doc/$file";
                    }},
   copying_file => {required=>false, check=> upper, normal=>"COPYING",
		    generate => sub {$copying{$info->{copyright}}}},
   copyright_file => {required=>false, check=> upper,
		      normal=>"Copyright"},
   complete => {oneof => [qw(true almost false unknown)]},
   accurate => {oneof => [qw(true false unknown)]},
   notes => {required => false},
   alias =>
   {check => any,
    code => sub {
      error "The \"lang\" entry must be defined before any global aliases."
	unless exists $global_info{lang};
      my @d = split /\s+/, $val;
      foreach (@d[1..$#d]) {
	my $awli = s/:awli$// ? true : false;
	error ("The alias $_ already exits in the \"$aliases_to{$_}\" "
	       ."entry.")
	    if exists $aliases_to{$_};
	$aliases_to{$_} = $d[0];
	$_ = {name => $_, awli => $awli};
      }
      push @{$aliases_from{$d[0]}}, @d[1..$#d];
    }
   },
   dict => 
   {
    default_fill_order => ['awli'],
    singular => false, name => {check=>\&dict},
    awli => {default=>'true', oneof=>['true','false']},
    strip_accents => 
    {
     oneof => ["true", "false"],
     code => sub {push @{$info->{insr}}, "strip-accents $val";}
   },
   add => 
   {
     check=>\&dict,
     code => sub 
     {
       my ($inf, $v) = @_ ? @_ : ($info, $val);
       push @{$inf->{insr}}, "add $v";
       push @{$inf->{dicts}}, {name => $v, add => \$inf->{insr}->[-1]};
     }
    },
    alias => 
    {
     check=>any,
     code => sub
     {
       error "The name entry must be defined before any aliases or defined"
	 unless exists $info->{name};
       my $awli = $val =~ s/:awli$//;
       &{$insr->{post}}( make_alias $val, $info->{name}, $awli );
     }
    },
    pre => sub
    {
      my ($inf) = @_ ? @_ : ($info);
      $inf->{insr} = [];
      $inf->{dicts} = [];
      error "The \"lang\" entry must be defined before any dicts."
	unless exists $global_info{lang};
    },
    post => sub 
    {
      my ($inf) = @_ ? @_ : ($info);
      error "Must provide at least one word list for \"$info->{name}\" dict entry."
	if (@{$inf->{dicts}} == 0);
      error "The dict or alias \"$info->{name}\" is already defined."
	if exists $dicts{$inf->{name}};
      $dicts{$inf->{name}} = $inf;
      return $inf;
    }
   }
  );

sub doc_entries() {qw (readme_file copying_file copyright_file)}

################################################################
#
# Add default values to insr                                   
#

my @defaults = (["singular", true],
		["check", ascii],
		["required", true]);

sub add_defaults ( $ ) {
  my $v = $_[0];
  foreach my $d (@defaults) {
    $v->{$d->[0]} = $d->[1] unless exists $v->{$d->[0]};
  }
  $v->{required} = false if exists $v->{code} || !$v->{singular};
  $v->{store} = true unless exists $v->{store} || exists $v->{code};
  $v->{store} = false unless exists $v->{store};
}
foreach my $v (values %global_insr) {
  next unless ref $v eq 'HASH';
  add_defaults $v;
  if (!$v->{singular}) {
    foreach my $vv (values %$v) {
      next unless ref $vv eq 'HASH';
      add_defaults $vv
    }
  }
}

################################################################
#
# Read in info file
#

open IN, "info" or die "Unable to open info file\n";

sub handle_key();
sub begin_multi();
sub possibly_end_multi();
sub add_defaults_and_check_mandatory();

my ($key_insr,$multi_val,$multi_line,$multi_message);
$info = \%global_info;
$insr = \%global_insr;
$line = 0;

while (<IN>) {
  ++$line;
  
  chop;
  s/\#.*$//;
  s/\s*$//;
  
  next if $_ eq '';
  
  eval {
    my ($lsp,$col);
    ($lsp, $key, $col, $val) 
      = /^(\s*)([\w-]*)\s*(:?)\s*(.*)$/ or error "Syntax Error.";
    $key =~ tr/-/_/;
    if ($col eq ':' && $lsp ne '') {
      error_message "This line should not be indented.  Assuming its not."
	, {lineno => $line};
      $lsp = '';
    }
    
    if ($lsp eq '') {

      possibly_end_multi;
      
      $key_insr = $insr->{$key} or error "Unknown Key: $key";
      error "Expecting value after $key"
	if $key_insr->{singular} && ($col ne '' || $val eq '');
      error "Expecting \":\" after $key"
	if !$key_insr->{singular} && $col ne ':';
      
      if ($key_insr->{singular}) {
	
	handle_key;
	
      } else {

	begin_multi;
	
      }
      
    } else {

      error "This line is indented yet I can not find a line of the form "
	."\"<key>:\" before it" if !defined $multi_val; 
      
      $key_insr = $insr->{$key} or error "Unknown Key \"$key\"$multi_message.";
      error "Expecting value after $key$multi_message." if $col ne '' || $val eq '';
      
      handle_key;

    }
    
  };
  handle_error $line;
}

possibly_end_multi;

close IN;

die "There were $error_count errors with the info file, aborting.\n" if $error_count > 0;

sub handle_key() {
  my $check = $key_insr->{check};
  error "The value \"$val\" for $key is not valid UTF-8."
    unless is_utf8($val, 1);
  $check = &$check if ref $check eq 'CODE';
  error "The value for $key $check->[1]$multi_message."
    if $val !~ /^$check->[0]$/;
  error "The value for $key is not one of: ".join(', ',@{$key_insr->{oneof}})
	 if exists $key_insr->{oneof} && !memberof($val, $key_insr->{oneof});
  if ($key_insr->{store}) {
    error "A value for $key already defined$multi_message."
      if exists $info->{$key};
    $info->{$key} = $val;
  }
  if (exists $key_insr->{code}) {
    &{$key_insr->{code}};
  }
}

sub begin_multi() {
  $info = {};
  $insr = $key_insr;
  $multi_val = $key;
  $multi_line = $line;
  $multi_errors = 0;

  $multi_message = " for the group \"$multi_val\" which starts at line $multi_line";
  
  &{$insr->{pre}};
}

sub possibly_end_multi() {
  return unless defined $multi_val;

  if ($multi_errors == 0) {
    add_defaults_and_check_mandatory;
  }

  if ($multi_errors == 0) {
    eval {
      &{$insr->{post}};
    };
    handle_error $multi_line;
  }

  $info = \%global_info;
  $insr = \%global_insr;
  $multi_val = undef;
  $multi_line = undef;
  $multi_errors = undef;
  $multi_message = '';
}

################################################################
#
# Add defaults and check for mandatory fields
#

add_defaults_and_check_mandatory;

sub add_defaults_and_check_mandatory() {
  my ($key, $val);

  # add defaults

  foreach my $key (@{$insr->{default_fill_order}}) {
    next if exists $info->{$key};
    my $def = $insr->{$key}->{default};
    if ($def =~ /^\=(.+)$/) {
      $info->{$key} = $info->{$1};
    } else {
      $info->{$key} = $def;
    }
  }

  # check mandatory fields

  while (my ($key,$val) = each %$insr) {
    next unless ref $val eq 'HASH';
    next unless $val->{required};
    next if exists $info->{$key};
    error_message "The required field $key is missing$multi_message.";
  }
}

$info = \%global_info;
$insr = \%global_insr;

error_message "You must provide at least one author."
  if (@authors == 0);

my ($date, %date);

if (exists $info->{date}) {
  $date = $info->{date};
  ($date{year}, $date{month}, $date{day}) = $info->{date} =~ /(....)-(..)-(..)/ or die;
} else {
  (undef,undef,undef,$date{day},$date{month},$date{year}) = localtime(time);
  $date{year} += 1900;
  $date = sprintf "%04d-%02d-%02d",$date{year},$date{month}+1,$date{day};
}

$mode = $info->{mode};

my ($prezip, $prezip_c, $prezip_d, $aspell_version, $cwl_note);
if ($mode eq 'aspell5') {
  $prezip = "word-list-compress";
  $prezip_c = " c";
  $prezip_d = " d";
  $aspell_version = '0.50';
  $cwl_note = <<"---";
The individual word lists have an extension of ".cwl" and are
compressed to save space.  To uncompress a word list use
"word-list-compress < BASE.cwl > BASE.wl" or simply
"word-list-compress < BASE.cwl" to dump it to standard output.
---
} else {
  $prezip = "prezip-bin";
  $prezip_c = " -z";
  $prezip_d = " -d";
  $aspell_version = '0.60';
  $cwl_note = <<"---";
The individual word lists have an extension of ".cwl" and are
compressed to save space.  To uncompress a word list use 
"preunzip BASE.cwl" which will uncompress it and rename the file 
to "BASE.wl".  To dump a compressed word list to standard output use
"precat BASE.cwl".  To uncompress all word lists in the current
directory use "preunzip *.cwl".  For more help on "preunzip" use
"preunzip --help".
---
}
chop $cwl_note;

################################################################
#
# Finish processing
#

my (%word_lists);
my (%already_warned);

sub make_alias ( $ $ $ ) {
  my ($from, $to, $awli) = @_;
  my $inf = {};
  my $insr = $global_insr{dict};
  &{$insr->{pre}}($inf);
  $inf->{name} = $from;
  $inf->{awli} = $awli ? 'true' : 'false';
  &{$insr->{add}{code}}($inf, $to);
  return $inf;
}


# Traverse performs a depth first circle looking for cycles and information
# included twice
# Parms 
# 1st (array reference) The list of all nodes
# 2nd (sub ( $ )) A function which returnes all the children of a given node
sub traverse ( $ $ );

traverse 
  [keys %aliases_from], 
  sub {
    my $r = $aliases_from{$_[0]};
    return () unless defined $r;
    return map {$_->{name}} @$r;
  };

my @toproc = keys %dicts;
while (my $key = shift @toproc) {
  my $val = $dicts{$key};

  my @d = split_dict $key;
  
  next unless @d;

  $d[0] = $lang . ($d[0] ? '_' : ''). $d[0];

  my $get_aliases = sub {
    my @a;
    @a = @{$aliases_from{$_[0]}} if exists $aliases_from{$_[0]};
    return ({name=>$_[0], awli=>$val->{awli}}, @a);
  };
  
  foreach my $l0 (&$get_aliases($d[0])) {
    foreach my $l1 (&$get_aliases($d[1])) {
      foreach my $l2 (&$get_aliases($d[2])) {
	my $dict = $l0->{name};
	$dict .= '-'.$l1->{name} if $l1->{name};
	$dict .= '-'.$l2->{name} if $l2->{name};
	next if exists $dicts{$dict};
	my $awli = $l0->{awli} && $l1->{awli} && $l2->{awli};
	$dicts{$dict} = make_alias $dict, $key, $awli;
	$dicts{$dict}->{auto} = true;
	push @toproc, $dict;
      }
    }
  }
  
  next unless $val->{awli};

  # If the dictionaries have a size associated with it than find
  # the size closest to the default size and make an awli alias for
  # that dictionary without the size in its name

  @d = split_dict $key;
  my $l = pop @d;
  my $n = form_dict @d;
  
  if ($l) {
    if (exists $dicts{$n} && ! exists $dicts{$n}{auto}) {
      if (!$already_warned{$n}) {
	my $error;
	$error .= "Since the awli-dict \"$key\" exists ";
	$error .= "the dict $n should also have a size.";
	error_message $error;
	$already_warned{$n} = true;
      }
    } else {
      # create a special alias
      my $rank = $l - 60;
      if ($rank <= 0) {
	$rank = - $rank;
	$rank <<= 1;
	$rank +=  1;
      } else {
	$rank <<= 1;
      }
      push @toproc,$n unless exists $dicts{$n};
      my $old_rank = $dicts{$n}->{rank};
      if (! defined $old_rank || $rank < $old_rank) {
	my $inf = make_alias $n, $key, true;
	$inf->{rank} = $rank;
	$inf->{auto} = true;
	$dicts{$n} = $inf;
      }
    }
  }
}

foreach my $key (sort keys %dicts) {
  # sorting it guarantees that the more general dictionaries are
  # processed first
  my $val = $dicts{$key};

  if ($val->{awli} eq 'true') {

    my @d = split_dict $key;
    pop @d; # ignore the size part as it is already handled above
    my $l = pop @d;
    my $n = form_dict @d;
    while (@d) {
      $l = pop @d;
      $n = form_dict @d;
      next unless $l;
      next if exists $dicts{$n}{rank};
      next if exists $already_warned{$n};
      my $error;
      if (!exists $dicts{$n} || $dicts{$n}{awli} eq 'false') {
	$error .= "The more specific awli-dict \"$key\" exists yet ";
	if (!exists $dicts{$n}) {
	  $error .= "\"$n\" does not."
	} elsif ($dicts{$n}->{awli} eq 'false') {
	  $error .= "the \"$n\" dict has the awli entry set to false."
	}
      }
      error_message $error if defined $error; 
      $already_warned{$n} = true;
    }
  }

  foreach my $n (@{$val->{dicts}}) {
    if ($n->{name} eq $key && @{$val->{insr}} != 1) {
      
      my $error;
      $error .= "The $key dictionary can not add a word list ";
      $error .= "of the same name unless it is the only entry.";
      error_message $error;
      
    } else {
      
      if ($n->{name} eq $key || !exists $dicts{$n->{name}}) {
	$n->{type} = 'rws';
	push @{$word_lists{$n->{name}}}, $key;
      } else {
	$n->{type} = 'multi';
	#$n->{link} = $dicts{$n->{name}};
      }
      $ {$n->{add}} .= ".$n->{type}";
      
    }

    $val->{is_alias} = (@{$val->{insr}} == 1 
			&& $val->{dicts}[0]{type} eq 'multi');
    
    $val->{ext} = $val->{awli} eq 'true' ? 'multi' : 'alias';
    #$val->{ext} = ($mode eq 'aspell5' 
    #               ? ($val->{awli} eq 'true' ? 'multi' : 'alias')
    #               : $val->{is_alias} ? 'alias' : 'multi');
  }
  
  unshift @{$val->{insr}}, "strip-accents true" 
    if $global_info{strip_accents} eq 'true' && $val->{insr}->[0] !~ /^strip-accents /;
}

sub find_equivalent_to {
  my $val = $dicts{$_[0]};
  return $val->{equivalent_to} if exists $val->{equivalent_to};
  if (@{$val->{insr}} == 1 && $val->{dicts}[0]{type} eq 'multi') {
    $val->{equivalent_to} = &find_equivalent_to($val->{dicts}[0]{name});
    push @{$val->{equivalent_to}}, $_[0];
  } else {
    $val->{equivalent_to} = [];
  }
  return $val->{equivalent_to};
}
foreach my $key (sort keys %dicts) {
  &find_equivalent_to($key);
}


traverse
  [map {"$_->{name}.$_->{ext}"} values %dicts],
  sub {
    my ($id) = @_;
    my ($name,$type) = $id =~ /^(.+)\.(.+)$/;
    return () unless $type eq 'multi';
    return map {"$_->{name}.$_->{type}"} @{$dicts{$name}->{dicts}};
  };

my $word_list_compress_working = 
  system("$prezip > /dev/null 2> /dev/null") != -1 ? true : false;
error_message("Unable to execute prezip-bin.  I will not be able "
	      ."to check the integrity of the *.cwl files.")
  unless $word_list_compress_working;

if ($check_mode ne 'unsafe' && $word_list_compress_working) {
  foreach my $wl (keys %word_lists) {
    next unless -e "$wl.cwl";
    open IN, "$prezip$prezip_d < $wl.cwl|" or die;
    if (eof IN) {
      error_message "No data received from $prezip.";
      last;
    }
    my $prev = '';
    while (<IN>) {
      chop;
      if ($prev gt $_) {
        error_message ("The file $wl.cwl is not in the proper format. "
                       ."Did you remember to set LC_COLLATE to C before sorting "
                       ."and compressing with \"$prezip\".");
        last;
      } elsif ($prev eq $_) {
        print "'$prev' eq '$_'";
        error_message ("The file $wl.cwl contains duplicates. "
                       ."Sort with \"sort -u\" to remove them.");
        last;
      }
      $prev = $_;
    }
  }
}

foreach my $key (doc_entries) {
  my $file;
  if (exists $info->{$key}) {
    $file = $info->{$key};
  } elsif (!exists $insr->{$key}->{generate}) {
    $file = $insr->{$key}->{normal};
  } else {
    next;
  }
  try_read $file;
}

close IN;

die "$error_count Error(s), aborting\n" if $error_count != 0;

exit 0 if $action eq 'check';

sub traverse ( $ $ ) {
  my ($nodes, $get_children)  = @_;
  my %processed;

  my $t;
  $t = sub {
    my ($id,$visited) = @_;
    
    my %paths = ($id => [$id]);

    return \%paths         if exists $visited->{$id};

    #print STDERR "  $id\n";
    
    $visited->{$id} = true;

    if ($processed{$id}) {
      foreach (@{$processed{$id}->{visited}}) {
	$visited->{$_} = true; 
      }
      return $processed{$id}->{paths};
    }
    
    foreach my $val (&$get_children( $id ) ) {

      my $child_paths = &$t( $val, $visited );

      while (my ($k,$v) = each %$child_paths) {
	if ($k eq $id) {
	  error_message 
	    "Ciculer dependence found: ".join(" -> ", $id, @$v);
	} elsif (exists $paths{$k}) {
	  error_message
	    ("$v->[-1] is included twice by $id via the following paths:\n"
	     ."  ".join(" -> ", $id, @$v)."\n"
	     ."  ".join(" -> ", @{$paths{$k}})
	     ,{warn => true} );
	} else {
	  $paths{$k} = [$id, @$v];
	}
      }
    }
    
    $processed{$id} = {visited => [keys %$visited],
		       paths => \%paths};
    return \%paths;
  };

  foreach my $k (@$nodes) {
    #print STDERR "$k:\n";
    &$t( $k,{} );
  }
}

################################################################
#
# Create files
#

my $make;

$files{extra} = ['configure', 'info', 'Makefile.pre'];

$info->{name} = $lang;

my $doc_encoding = resolve_alias $info->{doc_encoding};
die unless $doc_encoding; # FIXME
delete $alt_encodings{$doc_encoding};
$alt_encodings{$UTF8}='utf8' if $doc_encoding ne $UTF8;

foreach my $key (doc_entries) {

  my $specific = $info->{$key};
  my $normal   = $insr->{$key}{normal};

  if (defined $specific && $specific ne $normal) {

    system "cp $specific $normal" or die;

    push @{$files{doc}}, $specific, $normal;

  } elsif (defined $specific) {

    push @{$files{doc}}, $normal;

  } elsif (exists $insr->{$key}{generate}) {

    my $data = &{$insr->{$key}{generate}};

    next unless defined $data;
    
    open OUT, ">:encoding($doc_encoding)", "$normal";
    print OUT $data;
    close OUT;
    push @{$files{doc}}, $normal;

    while (my ($enc, $ext) = each %alt_encodings) {
      my $d = encode($enc, $data);
      my $d2 = encode($doc_encoding, $data);
      next if $d eq $d2;
      open OUT, ">:bytes", "$normal.$ext";
      print OUT $d;
      close OUT;
      push @{$files{doc}}, "$normal.$ext";
    }

  } else {

    push @{$files{doc}}, $normal;

  }
} 


foreach my $key (sort keys %dicts) {
  my $val = $dicts{$key};

  open OUT, ">$val->{name}.$val->{ext}\n";
  print OUT "# Generated with Aspell Dicts \"proc\" script version $VERSION\n";
  foreach (@{$val->{insr}}) {
    print OUT "$_\n";
  }
  close OUT;
  push @{$files{multi}}, "$val->{name}.$val->{ext}";
}

foreach my $key (sort keys %word_lists) {
  $make .= "$key.rws: $key.cwl\n\n";
  push @{$files{cwl}}, "$key.cwl";
  push @{$files{rws}}, "$key.rws";
}

$make .= <<"---";

.SUFFIXES: .cwl .rws .wl

.cwl.rws:
	\${PREZIP}$prezip_d < \$< | \${ASPELL} \${ASPELL_FLAGS} --lang=$lang create master ./\$@

.wl.cwl:
	cat \$< | LC_COLLATE=C sort -u | \${PREZIP}$prezip_c > \$@

.pz:
	\${PREZIP}$prezip_d < \$< > \$@

---

open OUT, ">Makefile.pre";
print OUT <<"---";	
# Generated with Aspell Dicts "proc" script version $VERSION

lang = $lang
version = $version
---
print OUT "\n";
foreach (sort keys %files) {
  print OUT "${_}_files = ", join(' ', @{$files{$_}}), "\n";
}
print OUT "\n";
print OUT "distdir=$mode-\${lang}-\${version}\n\n";

print OUT << '---';
all: ${rws_files} ${data_files}

install: all
	mkdir -p ${DESTDIR}${dictdir}/
	cp ${rws_files} ${multi_files} ${DESTDIR}${dictdir}/
	cd ${DESTDIR}${dictdir}/ && chmod 644 ${rws_files} ${multi_files}
	mkdir -p ${DESTDIR}${datadir}/
	cp ${data_files} ${DESTDIR}${datadir}/
	cd ${DESTDIR}${datadir}/ && chmod 644 ${data_files}

clean:
	rm -f ${rws_files}

distclean: clean
	rm -f Makefile

maintainer-clean: distclean
	rm -f ${multi_files} configure Makefile.pre

uninstall:
	-cd ${DESTDIR}${dictdir}/ && rm ${rws_files} ${multi_files} ${link_files}
	-cd ${DESTDIR}${datadir}/ && rm ${data_files}

dist: ${cwl_files}
	perl proc
	./configure
	@make dist-nogen

dist-nogen:
	-rm -r ${distdir}.tar.bz2 ${distdir}
	mkdir ${distdir}
	cp -p ${extra_files} ${cwl_files} ${multi_files} ${doc_files} ${data_files} ${distdir}/
	-test -e doc  && mkdir ${distdir}/doc  && chmod 755 ${distdir}/doc  && cp -pr doc/* ${distdir}/doc/
	-test -e misc && mkdir ${distdir}/misc && chmod 755 ${distdir}/misc && cp -pr misc/* ${distdir}/misc/
	tar cf ${distdir}.tar ${distdir}/
	bzip2 -9 ${distdir}.tar
	rm -r ${distdir}/

distcheck:
	tar xfj ${distdir}.tar.bz2
	cd ${distdir} && ./configure && make

rel:
	mv ${distdir}.tar.bz2 ../rel


---

print OUT $make;

open OUT, ">configure";

print OUT <<"---";
#!/bin/sh

# Note: future version will have a syntax something like
#   ./configure [OPTIONS]
#   Where OPTIONS is any of:
#     --help
#     --codes CODE1 ...
#     --sizes SIZE1 ...
#     --jargons JARGON1 ...
#     --extras EXTRA1 ...
#     --vars VAR1=VAL1 ...
# which is why I warn when --vars is not used before VAR1=VAL1

# Avoid depending upon Character Ranges.
# Taken from autoconf 2.50
cr_az='abcdefghijklmnopqrstuvwxyz'
cr_AZ='ABCDEFGHIJKLMNOPQRSTUVWXYZ'
cr_09='0123456789'
cr_alnum=\$cr_az\$cr_AZ\$cr_09

# also taken form autoconf
case `echo "testing\\c"; echo 1,2,3`,`echo -n testing; echo 1,2,3` in
  *c*,-n*) ECHO_N= ECHO_C='
' ECHO_T='	' ;;
  *c*,*  ) ECHO_N=-n ECHO_C= ECHO_T= ;;
  *)       ECHO_N= ECHO_C='\\c' ECHO_T= ;;
esac


mode=none
for option
do
  case \$option in
    --vars) 
      mode=vars
      ;;
    *=*)
      if test \$mode != vars; then
        echo "Warning: future versions will require --vars before variables are set"
        mode=vars
      fi	
      # Taken from autoconf 2.50
      envvar=`expr "x\$option" : 'x\\([^=]*\\)='`
      optarg=`expr "x\$option" : 'x[^=]*=\\(.*\\)'`
      # Reject names that are not valid shell variable names.
      expr "x\$envvar" : ".*[^_\$cr_alnum]" >/dev/null &&
        { echo "\$as_me: error: invalid variable name: \$envvar" >&2
      { (exit 1); exit 1; }; }
      #echo \$envvar \$optarg
      optarg=`echo "\$optarg" | sed "s/'/'\\\\\\\\\\\\\\\\''/g"`
      eval "\$envvar='\$optarg'"
      export \$envvar
      ;;
    --help)
      echo "Usage: ./configure [--help | --vars VAR1=VAL1 ...]"
      echo "  Note: Variables may also be set in the environment brefore running config"
      echo "  Useful vars: ASPELL ASPELL_PARMS PREZIP DESTDIR"
      exit 0
      ;;
    *)
      echo "Error: unrecognized option \$option";
      exit 1 
    ;;
  esac
done

#echo \$ASPELL
if test x = "x\$ASPELL"
  then ASPELL=aspell; fi
if test x = "x\$PREZIP"
  then PREZIP=$prezip; fi
#echo \$ASPELL

echo \$ECHO_N "Finding Dictionary file location ... \$ECHO_C"
dictdir=`\$ASPELL dump config dict-dir`
echo \$dictdir

echo \$ECHO_N "Finding Data file location ... \$ECHO_C"
datadir=`\$ASPELL dump config data-dir`
echo \$datadir

echo "ASPELL = `which \$ASPELL`" > Makefile
echo "ASPELL_FLAGS = \$ASPELL_FLAGS" >> Makefile
echo "PREZIP = `which \$PREZIP`" >> Makefile
echo "DESTDIR = \$DESTDIR" >> Makefile
echo "dictdir = \$dictdir" >> Makefile
echo "datadir = \$datadir" >> Makefile
echo                      >> Makefile
cat Makefile.pre >> Makefile
---

close OUT;
chmod 0755, 'configure';


sub README() {
  my $lang_name = $info->{name_english};
  $lang_name .= " ($info->{name_native})" if $info->{name_native} ne $info->{name_english};
  my $maintainer_list;
  my $author_list;
  foreach (@authors) {
    my $which = $_->{maintainer} eq 'true' ? \$maintainer_list : \$author_list;
    $$which .= "  $_->{name}";
    $$which .= " ($_->{name_native})" if exists $_->{name_native};
    $$which .= " <$_->{email}>" if exists $_->{email};
    $$which .= "\n";
  }
  my $author_info;
  if ($maintainer_list) {
    $author_info  = "Maintained By:\n$maintainer_list";
    $author_info .= "Original Word List Also By:\n$author_list" if $author_list;
  } else {
    $author_info = "Original Word List By:\n$author_list";
  }
  chop $author_info;
  my $dict_list;
  foreach my $key (sort keys %dicts) {
    my $val = $dicts{$key};
    next if $val->{is_alias};
    $dict_list .= "  $key";
    if (@{$val->{equivalent_to}}) {
      $dict_list .= ' (';
      my $len = length($key) + 4;
      my $indent = $len;
      foreach (sort @{$val->{equivalent_to}}) {
	if ($len + length($_) > 70 && $len != $indent) {
	  $dict_list .= "\n";
	  $dict_list .= ' 'x$indent;
	  $len = $indent;
	}
	$dict_list .= "$_ ";
	$len += length($_) + 1;
      }
      chop $dict_list;
      $dict_list .= ')';
    }
    $dict_list .= "\n";
  }
  chop $dict_list;
  my $extra_info;
  $extra_info .= "Wordlist URL: $info->{url}\n" if exists $info->{url};
  $extra_info .= "Source Verson: $info->{source_version}\n" if exists $info->{source_version};
  $extra_info .= "Source URL: $info->{source_url}\n" if exists $info->{source_url};

  if ($info->{complete} eq 'true' && $info->{accurate} eq 'true') {
    $extra_info .= "This word list is considered both complete and accurate.\n";
  } elsif ($info->{complete} eq 'true' && $info->{accurate} eq 'false') {
    $extra_info .= "This word list is considered complete but inaccurate.\n";
  } elsif ($info->{complete} eq 'false' && $info->{accurate} eq 'true') {
    $extra_info .= "This word list is considered accurate but incomplete.\n";
  } elsif ($info->{complete} eq 'true') {
    $extra_info .= "This word list is considered complete.\n";
  } elsif ($info->{accurate} eq 'true') {
    $extra_info .= "This word list is considered accurate.\n";
  }

  my $readme = <<"---";
GNU Aspell $aspell_version $lang_name Dictionary Package
Version $version
$date
$author_info
Copyright Terms: $info->{copyright} (see the file Copyright for the exact terms)
$extra_info
This is the $info->{name_english} dictionary for Aspell.  It requires Aspell 
version $aspell_version or better.

If Aspell is installed and aspell and $prezip are all
in the path first do a:

  ./configure

Which should output something like:

  Finding Dictionary file location ... /usr/local/lib/aspell
  Finding Data file location ... /usr/local/share/aspell

if it did not something likely went wrong.

After that build the package with:
  make
and then install it with
  make install

If any of the above mentioned programs are not in your path than the
variables, ASPELL and/or PREZIP need to be set to the
commands (with path) to run the utilities.  These variables may be set
in the environment before configure is run or specified at the command
line using the following syntax
  ./configure --vars VAR1=VAL1 ...
Other useful variables configure recognizes are ASPELL_PARMS, and DESTDIR.

To clean up after the build:
  make clean

To uninstall the files:
  make uninstall

After the dictionaries are installed you can use the main one ($lang) by
setting the LANG environmental variable to $lang or running Aspell
with "--lang=$lang".  You may also chose the dictionary directly
with the "-d" or "--master" option of Aspell.  You can chose from any of
the following dictionaries:
$dict_list
Whereas the names in parentheses are alternate names for the
dictionary preceding the parentheses.

$cwl_note

If you have any problem with installing or using the word lists please
let the Aspell maintainer, Kevin Atkinson, know at kevina\@gnu.org.

If you have problems with the actual word lists please contact one of
the Word lists authors as the Aspell maintainer does not maintain the
actual Word Lists.

Any additional documentation that came with the original word list can
be found in the doc/ directory.

---
  if (exists $info->{readme_extra}) {
    #$readme .= "A $info->{name_english} version of the above follows ";
    #$readme .= "with any special instructions:\n\n";
    my ($file, $enc) = $info->{readme_extra} =~ /^(.+?)(?:| (.+))$/;
    $enc = $UTF8 unless length $enc > 0;
    open RF, '<:bytes', "doc/$file";
    while (<RF>) {
      if ($enc eq $UTF8) {
        if (!is_utf8($_, 1)) {
          error_message "The file $file contains an invalid UTF-8 sequence.";
          last;
        }
        $readme .= $_;
      } else {
        $readme .= decode($enc, $_);
      }
    }
    close RF;
  }
  return $readme;
}

INIT {

%copying = 
  (GPL => <<'---',
		    GNU GENERAL PUBLIC LICENSE
		       Version 2, June 1991

 Copyright (C) 1989, 1991 Free Software Foundation, Inc.
                       59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 Everyone is permitted to copy and distribute verbatim copies
 of this license document, but changing it is not allowed.

			    Preamble

  The licenses for most software are designed to take away your
freedom to share and change it.  By contrast, the GNU General Public
License is intended to guarantee your freedom to share and change free
software--to make sure the software is free for all its users.  This
General Public License applies to most of the Free Software
Foundation's software and to any other program whose authors commit to
using it.  (Some other Free Software Foundation software is covered by
the GNU Library General Public License instead.)  You can apply it to
your programs, too.

  When we speak of free software, we are referring to freedom, not
price.  Our General Public Licenses are designed to make sure that you
have the freedom to distribute copies of free software (and charge for
this service if you wish), that you receive source code or can get it
if you want it, that you can change the software or use pieces of it
in new free programs; and that you know you can do these things.

  To protect your rights, we need to make restrictions that forbid
anyone to deny you these rights or to ask you to surrender the rights.
These restrictions translate to certain responsibilities for you if you
distribute copies of the software, or if you modify it.

  For example, if you distribute copies of such a program, whether
gratis or for a fee, you must give the recipients all the rights that
you have.  You must make sure that they, too, receive or can get the
source code.  And you must show them these terms so they know their
rights.

  We protect your rights with two steps: (1) copyright the software, and
(2) offer you this license which gives you legal permission to copy,
distribute and/or modify the software.

  Also, for each author's protection and ours, we want to make certain
that everyone understands that there is no warranty for this free
software.  If the software is modified by someone else and passed on, we
want its recipients to know that what they have is not the original, so
that any problems introduced by others will not reflect on the original
authors' reputations.

  Finally, any free program is threatened constantly by software
patents.  We wish to avoid the danger that redistributors of a free
program will individually obtain patent licenses, in effect making the
program proprietary.  To prevent this, we have made it clear that any
patent must be licensed for everyone's free use or not licensed at all.

  The precise terms and conditions for copying, distribution and
modification follow.

		    GNU GENERAL PUBLIC LICENSE
   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION

  0. This License applies to any program or other work which contains
a notice placed by the copyright holder saying it may be distributed
under the terms of this General Public License.  The "Program", below,
refers to any such program or work, and a "work based on the Program"
means either the Program or any derivative work under copyright law:
that is to say, a work containing the Program or a portion of it,
either verbatim or with modifications and/or translated into another
language.  (Hereinafter, translation is included without limitation in
the term "modification".)  Each licensee is addressed as "you".

Activities other than copying, distribution and modification are not
covered by this License; they are outside its scope.  The act of
running the Program is not restricted, and the output from the Program
is covered only if its contents constitute a work based on the
Program (independent of having been made by running the Program).
Whether that is true depends on what the Program does.

  1. You may copy and distribute verbatim copies of the Program's
source code as you receive it, in any medium, provided that you
conspicuously and appropriately publish on each copy an appropriate
copyright notice and disclaimer of warranty; keep intact all the
notices that refer to this License and to the absence of any warranty;
and give any other recipients of the Program a copy of this License
along with the Program.

You may charge a fee for the physical act of transferring a copy, and
you may at your option offer warranty protection in exchange for a fee.

  2. You may modify your copy or copies of the Program or any portion
of it, thus forming a work based on the Program, and copy and
distribute such modifications or work under the terms of Section 1
above, provided that you also meet all of these conditions:

    a) You must cause the modified files to carry prominent notices
    stating that you changed the files and the date of any change.

    b) You must cause any work that you distribute or publish, that in
    whole or in part contains or is derived from the Program or any
    part thereof, to be licensed as a whole at no charge to all third
    parties under the terms of this License.

    c) If the modified program normally reads commands interactively
    when run, you must cause it, when started running for such
    interactive use in the most ordinary way, to print or display an
    announcement including an appropriate copyright notice and a
    notice that there is no warranty (or else, saying that you provide
    a warranty) and that users may redistribute the program under
    these conditions, and telling the user how to view a copy of this
    License.  (Exception: if the Program itself is interactive but
    does not normally print such an announcement, your work based on
    the Program is not required to print an announcement.)

These requirements apply to the modified work as a whole.  If
identifiable sections of that work are not derived from the Program,
and can be reasonably considered independent and separate works in
themselves, then this License, and its terms, do not apply to those
sections when you distribute them as separate works.  But when you
distribute the same sections as part of a whole which is a work based
on the Program, the distribution of the whole must be on the terms of
this License, whose permissions for other licensees extend to the
entire whole, and thus to each and every part regardless of who wrote it.

Thus, it is not the intent of this section to claim rights or contest
your rights to work written entirely by you; rather, the intent is to
exercise the right to control the distribution of derivative or
collective works based on the Program.

In addition, mere aggregation of another work not based on the Program
with the Program (or with a work based on the Program) on a volume of
a storage or distribution medium does not bring the other work under
the scope of this License.

  3. You may copy and distribute the Program (or a work based on it,
under Section 2) in object code or executable form under the terms of
Sections 1 and 2 above provided that you also do one of the following:

    a) Accompany it with the complete corresponding machine-readable
    source code, which must be distributed under the terms of Sections
    1 and 2 above on a medium customarily used for software interchange; or,

    b) Accompany it with a written offer, valid for at least three
    years, to give any third party, for a charge no more than your
    cost of physically performing source distribution, a complete
    machine-readable copy of the corresponding source code, to be
    distributed under the terms of Sections 1 and 2 above on a medium
    customarily used for software interchange; or,

    c) Accompany it with the information you received as to the offer
    to distribute corresponding source code.  (This alternative is
    allowed only for noncommercial distribution and only if you
    received the program in object code or executable form with such
    an offer, in accord with Subsection b above.)

The source code for a work means the preferred form of the work for
making modifications to it.  For an executable work, complete source
code means all the source code for all modules it contains, plus any
associated interface definition files, plus the scripts used to
control compilation and installation of the executable.  However, as a
special exception, the source code distributed need not include
anything that is normally distributed (in either source or binary
form) with the major components (compiler, kernel, and so on) of the
operating system on which the executable runs, unless that component
itself accompanies the executable.

If distribution of executable or object code is made by offering
access to copy from a designated place, then offering equivalent
access to copy the source code from the same place counts as
distribution of the source code, even though third parties are not
compelled to copy the source along with the object code.

  4. You may not copy, modify, sublicense, or distribute the Program
except as expressly provided under this License.  Any attempt
otherwise to copy, modify, sublicense or distribute the Program is
void, and will automatically terminate your rights under this License.
However, parties who have received copies, or rights, from you under
this License will not have their licenses terminated so long as such
parties remain in full compliance.

  5. You are not required to accept this License, since you have not
signed it.  However, nothing else grants you permission to modify or
distribute the Program or its derivative works.  These actions are
prohibited by law if you do not accept this License.  Therefore, by
modifying or distributing the Program (or any work based on the
Program), you indicate your acceptance of this License to do so, and
all its terms and conditions for copying, distributing or modifying
the Program or works based on it.

  6. Each time you redistribute the Program (or any work based on the
Program), the recipient automatically receives a license from the
original licensor to copy, distribute or modify the Program subject to
these terms and conditions.  You may not impose any further
restrictions on the recipients' exercise of the rights granted herein.
You are not responsible for enforcing compliance by third parties to
this License.

  7. If, as a consequence of a court judgment or allegation of patent
infringement or for any other reason (not limited to patent issues),
conditions are imposed on you (whether by court order, agreement or
otherwise) that contradict the conditions of this License, they do not
excuse you from the conditions of this License.  If you cannot
distribute so as to satisfy simultaneously your obligations under this
License and any other pertinent obligations, then as a consequence you
may not distribute the Program at all.  For example, if a patent
license would not permit royalty-free redistribution of the Program by
all those who receive copies directly or indirectly through you, then
the only way you could satisfy both it and this License would be to
refrain entirely from distribution of the Program.

If any portion of this section is held invalid or unenforceable under
any particular circumstance, the balance of the section is intended to
apply and the section as a whole is intended to apply in other
circumstances.

It is not the purpose of this section to induce you to infringe any
patents or other property right claims or to contest validity of any
such claims; this section has the sole purpose of protecting the
integrity of the free software distribution system, which is
implemented by public license practices.  Many people have made
generous contributions to the wide range of software distributed
through that system in reliance on consistent application of that
system; it is up to the author/donor to decide if he or she is willing
to distribute software through any other system and a licensee cannot
impose that choice.

This section is intended to make thoroughly clear what is believed to
be a consequence of the rest of this License.

  8. If the distribution and/or use of the Program is restricted in
certain countries either by patents or by copyrighted interfaces, the
original copyright holder who places the Program under this License
may add an explicit geographical distribution limitation excluding
those countries, so that distribution is permitted only in or among
countries not thus excluded.  In such case, this License incorporates
the limitation as if written in the body of this License.

  9. The Free Software Foundation may publish revised and/or new versions
of the General Public License from time to time.  Such new versions will
be similar in spirit to the present version, but may differ in detail to
address new problems or concerns.

Each version is given a distinguishing version number.  If the Program
specifies a version number of this License which applies to it and "any
later version", you have the option of following the terms and conditions
either of that version or of any later version published by the Free
Software Foundation.  If the Program does not specify a version number of
this License, you may choose any version ever published by the Free Software
Foundation.

  10. If you wish to incorporate parts of the Program into other free
programs whose distribution conditions are different, write to the author
to ask for permission.  For software which is copyrighted by the Free
Software Foundation, write to the Free Software Foundation; we sometimes
make exceptions for this.  Our decision will be guided by the two goals
of preserving the free status of all derivatives of our free software and
of promoting the sharing and reuse of software generally.

			    NO WARRANTY

  11. BECAUSE THE PROGRAM IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE PROGRAM, TO THE EXTENT PERMITTED BY APPLICABLE LAW.  EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED
OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE ENTIRE RISK AS
TO THE QUALITY AND PERFORMANCE OF THE PROGRAM IS WITH YOU.  SHOULD THE
PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING,
REPAIR OR CORRECTION.

  12. IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE PROGRAM AS PERMITTED ABOVE, BE LIABLE TO YOU FOR DAMAGES,
INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING
OUT OF THE USE OR INABILITY TO USE THE PROGRAM (INCLUDING BUT NOT LIMITED
TO LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY
YOU OR THIRD PARTIES OR A FAILURE OF THE PROGRAM TO OPERATE WITH ANY OTHER
PROGRAMS), EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGES.

		     END OF TERMS AND CONDITIONS

	    How to Apply These Terms to Your New Programs

  If you develop a new program, and you want it to be of the greatest
possible use to the public, the best way to achieve this is to make it
free software which everyone can redistribute and change under these terms.

  To do so, attach the following notices to the program.  It is safest
to attach them to the start of each source file to most effectively
convey the exclusion of warranty; and each file should have at least
the "copyright" line and a pointer to where the full notice is found.

    <one line to give the program's name and a brief idea of what it does.>
    Copyright (C) <year>  <name of author>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


Also add information on how to contact you by electronic and paper mail.

If the program is interactive, make it output a short notice like this
when it starts in an interactive mode:

    Gnomovision version 69, Copyright (C) year name of author
    Gnomovision comes with ABSOLUTELY NO WARRANTY; for details type `show w'.
    This is free software, and you are welcome to redistribute it
    under certain conditions; type `show c' for details.

The hypothetical commands `show w' and `show c' should show the appropriate
parts of the General Public License.  Of course, the commands you use may
be called something other than `show w' and `show c'; they could even be
mouse-clicks or menu items--whatever suits your program.

You should also get your employer (if you work as a programmer) or your
school, if any, to sign a "copyright disclaimer" for the program, if
necessary.  Here is a sample; alter the names:

  Yoyodyne, Inc., hereby disclaims all copyright interest in the program
  `Gnomovision' (which makes passes at compilers) written by James Hacker.

  <signature of Ty Coon>, 1 April 1989
  Ty Coon, President of Vice

This General Public License does not permit incorporating your program into
proprietary programs.  If your program is a subroutine library, you may
consider it more useful to permit linking proprietary applications with the
library.  If this is what you want to do, use the GNU Library General
Public License instead of this License.
---
   LGPL => <<'---',
		  GNU LESSER GENERAL PUBLIC LICENSE
		       Version 2.1, February 1999

 Copyright (C) 1991, 1999 Free Software Foundation, Inc.
     59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 Everyone is permitted to copy and distribute verbatim copies
 of this license document, but changing it is not allowed.

[This is the first released version of the Lesser GPL.  It also counts
 as the successor of the GNU Library Public License, version 2, hence
 the version number 2.1.]

			    Preamble

  The licenses for most software are designed to take away your
freedom to share and change it.  By contrast, the GNU General Public
Licenses are intended to guarantee your freedom to share and change
free software--to make sure the software is free for all its users.

  This license, the Lesser General Public License, applies to some
specially designated software packages--typically libraries--of the
Free Software Foundation and other authors who decide to use it.  You
can use it too, but we suggest you first think carefully about whether
this license or the ordinary General Public License is the better
strategy to use in any particular case, based on the explanations below.

  When we speak of free software, we are referring to freedom of use,
not price.  Our General Public Licenses are designed to make sure that
you have the freedom to distribute copies of free software (and charge
for this service if you wish); that you receive source code or can get
it if you want it; that you can change the software and use pieces of
it in new free programs; and that you are informed that you can do
these things.

  To protect your rights, we need to make restrictions that forbid
distributors to deny you these rights or to ask you to surrender these
rights.  These restrictions translate to certain responsibilities for
you if you distribute copies of the library or if you modify it.

  For example, if you distribute copies of the library, whether gratis
or for a fee, you must give the recipients all the rights that we gave
you.  You must make sure that they, too, receive or can get the source
code.  If you link other code with the library, you must provide
complete object files to the recipients, so that they can relink them
with the library after making changes to the library and recompiling
it.  And you must show them these terms so they know their rights.

  We protect your rights with a two-step method: (1) we copyright the
library, and (2) we offer you this license, which gives you legal
permission to copy, distribute and/or modify the library.

  To protect each distributor, we want to make it very clear that
there is no warranty for the free library.  Also, if the library is
modified by someone else and passed on, the recipients should know
that what they have is not the original version, so that the original
author's reputation will not be affected by problems that might be
introduced by others.

  Finally, software patents pose a constant threat to the existence of
any free program.  We wish to make sure that a company cannot
effectively restrict the users of a free program by obtaining a
restrictive license from a patent holder.  Therefore, we insist that
any patent license obtained for a version of the library must be
consistent with the full freedom of use specified in this license.

  Most GNU software, including some libraries, is covered by the
ordinary GNU General Public License.  This license, the GNU Lesser
General Public License, applies to certain designated libraries, and
is quite different from the ordinary General Public License.  We use
this license for certain libraries in order to permit linking those
libraries into non-free programs.

  When a program is linked with a library, whether statically or using
a shared library, the combination of the two is legally speaking a
combined work, a derivative of the original library.  The ordinary
General Public License therefore permits such linking only if the
entire combination fits its criteria of freedom.  The Lesser General
Public License permits more lax criteria for linking other code with
the library.

  We call this license the "Lesser" General Public License because it
does Less to protect the user's freedom than the ordinary General
Public License.  It also provides other free software developers Less
of an advantage over competing non-free programs.  These disadvantages
are the reason we use the ordinary General Public License for many
libraries.  However, the Lesser license provides advantages in certain
special circumstances.

  For example, on rare occasions, there may be a special need to
encourage the widest possible use of a certain library, so that it becomes
a de-facto standard.  To achieve this, non-free programs must be
allowed to use the library.  A more frequent case is that a free
library does the same job as widely used non-free libraries.  In this
case, there is little to gain by limiting the free library to free
software only, so we use the Lesser General Public License.

  In other cases, permission to use a particular library in non-free
programs enables a greater number of people to use a large body of
free software.  For example, permission to use the GNU C Library in
non-free programs enables many more people to use the whole GNU
operating system, as well as its variant, the GNU/Linux operating
system.

  Although the Lesser General Public License is Less protective of the
users' freedom, it does ensure that the user of a program that is
linked with the Library has the freedom and the wherewithal to run
that program using a modified version of the Library.

  The precise terms and conditions for copying, distribution and
modification follow.  Pay close attention to the difference between a
"work based on the library" and a "work that uses the library".  The
former contains code derived from the library, whereas the latter must
be combined with the library in order to run.

		  GNU LESSER GENERAL PUBLIC LICENSE
   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION

  0. This License Agreement applies to any software library or other
program which contains a notice placed by the copyright holder or
other authorized party saying it may be distributed under the terms of
this Lesser General Public License (also called "this License").
Each licensee is addressed as "you".

  A "library" means a collection of software functions and/or data
prepared so as to be conveniently linked with application programs
(which use some of those functions and data) to form executables.

  The "Library", below, refers to any such software library or work
which has been distributed under these terms.  A "work based on the
Library" means either the Library or any derivative work under
copyright law: that is to say, a work containing the Library or a
portion of it, either verbatim or with modifications and/or translated
straightforwardly into another language.  (Hereinafter, translation is
included without limitation in the term "modification".)

  "Source code" for a work means the preferred form of the work for
making modifications to it.  For a library, complete source code means
all the source code for all modules it contains, plus any associated
interface definition files, plus the scripts used to control compilation
and installation of the library.

  Activities other than copying, distribution and modification are not
covered by this License; they are outside its scope.  The act of
running a program using the Library is not restricted, and output from
such a program is covered only if its contents constitute a work based
on the Library (independent of the use of the Library in a tool for
writing it).  Whether that is true depends on what the Library does
and what the program that uses the Library does.
  
  1. You may copy and distribute verbatim copies of the Library's
complete source code as you receive it, in any medium, provided that
you conspicuously and appropriately publish on each copy an
appropriate copyright notice and disclaimer of warranty; keep intact
all the notices that refer to this License and to the absence of any
warranty; and distribute a copy of this License along with the
Library.

  You may charge a fee for the physical act of transferring a copy,
and you may at your option offer warranty protection in exchange for a
fee.

  2. You may modify your copy or copies of the Library or any portion
of it, thus forming a work based on the Library, and copy and
distribute such modifications or work under the terms of Section 1
above, provided that you also meet all of these conditions:

    a) The modified work must itself be a software library.

    b) You must cause the files modified to carry prominent notices
    stating that you changed the files and the date of any change.

    c) You must cause the whole of the work to be licensed at no
    charge to all third parties under the terms of this License.

    d) If a facility in the modified Library refers to a function or a
    table of data to be supplied by an application program that uses
    the facility, other than as an argument passed when the facility
    is invoked, then you must make a good faith effort to ensure that,
    in the event an application does not supply such function or
    table, the facility still operates, and performs whatever part of
    its purpose remains meaningful.

    (For example, a function in a library to compute square roots has
    a purpose that is entirely well-defined independent of the
    application.  Therefore, Subsection 2d requires that any
    application-supplied function or table used by this function must
    be optional: if the application does not supply it, the square
    root function must still compute square roots.)

These requirements apply to the modified work as a whole.  If
identifiable sections of that work are not derived from the Library,
and can be reasonably considered independent and separate works in
themselves, then this License, and its terms, do not apply to those
sections when you distribute them as separate works.  But when you
distribute the same sections as part of a whole which is a work based
on the Library, the distribution of the whole must be on the terms of
this License, whose permissions for other licensees extend to the
entire whole, and thus to each and every part regardless of who wrote
it.

Thus, it is not the intent of this section to claim rights or contest
your rights to work written entirely by you; rather, the intent is to
exercise the right to control the distribution of derivative or
collective works based on the Library.

In addition, mere aggregation of another work not based on the Library
with the Library (or with a work based on the Library) on a volume of
a storage or distribution medium does not bring the other work under
the scope of this License.

  3. You may opt to apply the terms of the ordinary GNU General Public
License instead of this License to a given copy of the Library.  To do
this, you must alter all the notices that refer to this License, so
that they refer to the ordinary GNU General Public License, version 2,
instead of to this License.  (If a newer version than version 2 of the
ordinary GNU General Public License has appeared, then you can specify
that version instead if you wish.)  Do not make any other change in
these notices.

  Once this change is made in a given copy, it is irreversible for
that copy, so the ordinary GNU General Public License applies to all
subsequent copies and derivative works made from that copy.

  This option is useful when you wish to copy part of the code of
the Library into a program that is not a library.

  4. You may copy and distribute the Library (or a portion or
derivative of it, under Section 2) in object code or executable form
under the terms of Sections 1 and 2 above provided that you accompany
it with the complete corresponding machine-readable source code, which
must be distributed under the terms of Sections 1 and 2 above on a
medium customarily used for software interchange.

  If distribution of object code is made by offering access to copy
from a designated place, then offering equivalent access to copy the
source code from the same place satisfies the requirement to
distribute the source code, even though third parties are not
compelled to copy the source along with the object code.

  5. A program that contains no derivative of any portion of the
Library, but is designed to work with the Library by being compiled or
linked with it, is called a "work that uses the Library".  Such a
work, in isolation, is not a derivative work of the Library, and
therefore falls outside the scope of this License.

  However, linking a "work that uses the Library" with the Library
creates an executable that is a derivative of the Library (because it
contains portions of the Library), rather than a "work that uses the
library".  The executable is therefore covered by this License.
Section 6 states terms for distribution of such executables.

  When a "work that uses the Library" uses material from a header file
that is part of the Library, the object code for the work may be a
derivative work of the Library even though the source code is not.
Whether this is true is especially significant if the work can be
linked without the Library, or if the work is itself a library.  The
threshold for this to be true is not precisely defined by law.

  If such an object file uses only numerical parameters, data
structure layouts and accessors, and small macros and small inline
functions (ten lines or less in length), then the use of the object
file is unrestricted, regardless of whether it is legally a derivative
work.  (Executables containing this object code plus portions of the
Library will still fall under Section 6.)

  Otherwise, if the work is a derivative of the Library, you may
distribute the object code for the work under the terms of Section 6.
Any executables containing that work also fall under Section 6,
whether or not they are linked directly with the Library itself.

  6. As an exception to the Sections above, you may also combine or
link a "work that uses the Library" with the Library to produce a
work containing portions of the Library, and distribute that work
under terms of your choice, provided that the terms permit
modification of the work for the customer's own use and reverse
engineering for debugging such modifications.

  You must give prominent notice with each copy of the work that the
Library is used in it and that the Library and its use are covered by
this License.  You must supply a copy of this License.  If the work
during execution displays copyright notices, you must include the
copyright notice for the Library among them, as well as a reference
directing the user to the copy of this License.  Also, you must do one
of these things:

    a) Accompany the work with the complete corresponding
    machine-readable source code for the Library including whatever
    changes were used in the work (which must be distributed under
    Sections 1 and 2 above); and, if the work is an executable linked
    with the Library, with the complete machine-readable "work that
    uses the Library", as object code and/or source code, so that the
    user can modify the Library and then relink to produce a modified
    executable containing the modified Library.  (It is understood
    that the user who changes the contents of definitions files in the
    Library will not necessarily be able to recompile the application
    to use the modified definitions.)

    b) Use a suitable shared library mechanism for linking with the
    Library.  A suitable mechanism is one that (1) uses at run time a
    copy of the library already present on the user's computer system,
    rather than copying library functions into the executable, and (2)
    will operate properly with a modified version of the library, if
    the user installs one, as long as the modified version is
    interface-compatible with the version that the work was made with.

    c) Accompany the work with a written offer, valid for at
    least three years, to give the same user the materials
    specified in Subsection 6a, above, for a charge no more
    than the cost of performing this distribution.

    d) If distribution of the work is made by offering access to copy
    from a designated place, offer equivalent access to copy the above
    specified materials from the same place.

    e) Verify that the user has already received a copy of these
    materials or that you have already sent this user a copy.

  For an executable, the required form of the "work that uses the
Library" must include any data and utility programs needed for
reproducing the executable from it.  However, as a special exception,
the materials to be distributed need not include anything that is
normally distributed (in either source or binary form) with the major
components (compiler, kernel, and so on) of the operating system on
which the executable runs, unless that component itself accompanies
the executable.

  It may happen that this requirement contradicts the license
restrictions of other proprietary libraries that do not normally
accompany the operating system.  Such a contradiction means you cannot
use both them and the Library together in an executable that you
distribute.

  7. You may place library facilities that are a work based on the
Library side-by-side in a single library together with other library
facilities not covered by this License, and distribute such a combined
library, provided that the separate distribution of the work based on
the Library and of the other library facilities is otherwise
permitted, and provided that you do these two things:

    a) Accompany the combined library with a copy of the same work
    based on the Library, uncombined with any other library
    facilities.  This must be distributed under the terms of the
    Sections above.

    b) Give prominent notice with the combined library of the fact
    that part of it is a work based on the Library, and explaining
    where to find the accompanying uncombined form of the same work.

  8. You may not copy, modify, sublicense, link with, or distribute
the Library except as expressly provided under this License.  Any
attempt otherwise to copy, modify, sublicense, link with, or
distribute the Library is void, and will automatically terminate your
rights under this License.  However, parties who have received copies,
or rights, from you under this License will not have their licenses
terminated so long as such parties remain in full compliance.

  9. You are not required to accept this License, since you have not
signed it.  However, nothing else grants you permission to modify or
distribute the Library or its derivative works.  These actions are
prohibited by law if you do not accept this License.  Therefore, by
modifying or distributing the Library (or any work based on the
Library), you indicate your acceptance of this License to do so, and
all its terms and conditions for copying, distributing or modifying
the Library or works based on it.

  10. Each time you redistribute the Library (or any work based on the
Library), the recipient automatically receives a license from the
original licensor to copy, distribute, link with or modify the Library
subject to these terms and conditions.  You may not impose any further
restrictions on the recipients' exercise of the rights granted herein.
You are not responsible for enforcing compliance by third parties with
this License.

  11. If, as a consequence of a court judgment or allegation of patent
infringement or for any other reason (not limited to patent issues),
conditions are imposed on you (whether by court order, agreement or
otherwise) that contradict the conditions of this License, they do not
excuse you from the conditions of this License.  If you cannot
distribute so as to satisfy simultaneously your obligations under this
License and any other pertinent obligations, then as a consequence you
may not distribute the Library at all.  For example, if a patent
license would not permit royalty-free redistribution of the Library by
all those who receive copies directly or indirectly through you, then
the only way you could satisfy both it and this License would be to
refrain entirely from distribution of the Library.

If any portion of this section is held invalid or unenforceable under any
particular circumstance, the balance of the section is intended to apply,
and the section as a whole is intended to apply in other circumstances.

It is not the purpose of this section to induce you to infringe any
patents or other property right claims or to contest validity of any
such claims; this section has the sole purpose of protecting the
integrity of the free software distribution system which is
implemented by public license practices.  Many people have made
generous contributions to the wide range of software distributed
through that system in reliance on consistent application of that
system; it is up to the author/donor to decide if he or she is willing
to distribute software through any other system and a licensee cannot
impose that choice.

This section is intended to make thoroughly clear what is believed to
be a consequence of the rest of this License.

  12. If the distribution and/or use of the Library is restricted in
certain countries either by patents or by copyrighted interfaces, the
original copyright holder who places the Library under this License may add
an explicit geographical distribution limitation excluding those countries,
so that distribution is permitted only in or among countries not thus
excluded.  In such case, this License incorporates the limitation as if
written in the body of this License.

  13. The Free Software Foundation may publish revised and/or new
versions of the Lesser General Public License from time to time.
Such new versions will be similar in spirit to the present version,
but may differ in detail to address new problems or concerns.

Each version is given a distinguishing version number.  If the Library
specifies a version number of this License which applies to it and
"any later version", you have the option of following the terms and
conditions either of that version or of any later version published by
the Free Software Foundation.  If the Library does not specify a
license version number, you may choose any version ever published by
the Free Software Foundation.

  14. If you wish to incorporate parts of the Library into other free
programs whose distribution conditions are incompatible with these,
write to the author to ask for permission.  For software which is
copyrighted by the Free Software Foundation, write to the Free
Software Foundation; we sometimes make exceptions for this.  Our
decision will be guided by the two goals of preserving the free status
of all derivatives of our free software and of promoting the sharing
and reuse of software generally.

			    NO WARRANTY

  15. BECAUSE THE LIBRARY IS LICENSED FREE OF CHARGE, THERE IS NO
WARRANTY FOR THE LIBRARY, TO THE EXTENT PERMITTED BY APPLICABLE LAW.
EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR
OTHER PARTIES PROVIDE THE LIBRARY "AS IS" WITHOUT WARRANTY OF ANY
KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE.  THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE
LIBRARY IS WITH YOU.  SHOULD THE LIBRARY PROVE DEFECTIVE, YOU ASSUME
THE COST OF ALL NECESSARY SERVICING, REPAIR OR CORRECTION.

  16. IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN
WRITING WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY
AND/OR REDISTRIBUTE THE LIBRARY AS PERMITTED ABOVE, BE LIABLE TO YOU
FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL OR
CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE
LIBRARY (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE LIBRARY TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH
DAMAGES.

		     END OF TERMS AND CONDITIONS

           How to Apply These Terms to Your New Libraries

  If you develop a new library, and you want it to be of the greatest
possible use to the public, we recommend making it free software that
everyone can redistribute and change.  You can do so by permitting
redistribution under these terms (or, alternatively, under the terms of the
ordinary General Public License).

  To apply these terms, attach the following notices to the library.  It is
safest to attach them to the start of each source file to most effectively
convey the exclusion of warranty; and each file should have at least the
"copyright" line and a pointer to where the full notice is found.

    <one line to give the library's name and a brief idea of what it does.>
    Copyright (C) <year>  <name of author>

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

Also add information on how to contact you by electronic and paper mail.

You should also get your employer (if you work as a programmer) or your
school, if any, to sign a "copyright disclaimer" for the library, if
necessary.  Here is a sample; alter the names:

  Yoyodyne, Inc., hereby disclaims all copyright interest in the
  library `Frob' (a library for tweaking knobs) written by James Random Hacker.

  <signature of Ty Coon>, 1 April 1990
  Ty Coon, President of Vice

That's all there is to it!
---
   FDL => <<'---',
		GNU Free Documentation License
		   Version 1.1, March 2000

 Copyright (C) 2000  Free Software Foundation, Inc.
     59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 Everyone is permitted to copy and distribute verbatim copies
 of this license document, but changing it is not allowed.


0. PREAMBLE

The purpose of this License is to make a manual, textbook, or other
written document "free" in the sense of freedom: to assure everyone
the effective freedom to copy and redistribute it, with or without
modifying it, either commercially or noncommercially.  Secondarily,
this License preserves for the author and publisher a way to get
credit for their work, while not being considered responsible for
modifications made by others.

This License is a kind of "copyleft", which means that derivative
works of the document must themselves be free in the same sense.  It
complements the GNU General Public License, which is a copyleft
license designed for free software.

We have designed this License in order to use it for manuals for free
software, because free software needs free documentation: a free
program should come with manuals providing the same freedoms that the
software does.  But this License is not limited to software manuals;
it can be used for any textual work, regardless of subject matter or
whether it is published as a printed book.  We recommend this License
principally for works whose purpose is instruction or reference.


1. APPLICABILITY AND DEFINITIONS

This License applies to any manual or other work that contains a
notice placed by the copyright holder saying it can be distributed
under the terms of this License.  The "Document", below, refers to any
such manual or work.  Any member of the public is a licensee, and is
addressed as "you".

A "Modified Version" of the Document means any work containing the
Document or a portion of it, either copied verbatim, or with
modifications and/or translated into another language.

A "Secondary Section" is a named appendix or a front-matter section of
the Document that deals exclusively with the relationship of the
publishers or authors of the Document to the Document's overall subject
(or to related matters) and contains nothing that could fall directly
within that overall subject.  (For example, if the Document is in part a
textbook of mathematics, a Secondary Section may not explain any
mathematics.)  The relationship could be a matter of historical
connection with the subject or with related matters, or of legal,
commercial, philosophical, ethical or political position regarding
them.

The "Invariant Sections" are certain Secondary Sections whose titles
are designated, as being those of Invariant Sections, in the notice
that says that the Document is released under this License.

The "Cover Texts" are certain short passages of text that are listed,
as Front-Cover Texts or Back-Cover Texts, in the notice that says that
the Document is released under this License.

A "Transparent" copy of the Document means a machine-readable copy,
represented in a format whose specification is available to the
general public, whose contents can be viewed and edited directly and
straightforwardly with generic text editors or (for images composed of
pixels) generic paint programs or (for drawings) some widely available
drawing editor, and that is suitable for input to text formatters or
for automatic translation to a variety of formats suitable for input
to text formatters.  A copy made in an otherwise Transparent file
format whose markup has been designed to thwart or discourage
subsequent modification by readers is not Transparent.  A copy that is
not "Transparent" is called "Opaque".

Examples of suitable formats for Transparent copies include plain
ASCII without markup, Texinfo input format, LaTeX input format, SGML
or XML using a publicly available DTD, and standard-conforming simple
HTML designed for human modification.  Opaque formats include
PostScript, PDF, proprietary formats that can be read and edited only
by proprietary word processors, SGML or XML for which the DTD and/or
processing tools are not generally available, and the
machine-generated HTML produced by some word processors for output
purposes only.

The "Title Page" means, for a printed book, the title page itself,
plus such following pages as are needed to hold, legibly, the material
this License requires to appear in the title page.  For works in
formats which do not have any title page as such, "Title Page" means
the text near the most prominent appearance of the work's title,
preceding the beginning of the body of the text.


2. VERBATIM COPYING

You may copy and distribute the Document in any medium, either
commercially or noncommercially, provided that this License, the
copyright notices, and the license notice saying this License applies
to the Document are reproduced in all copies, and that you add no other
conditions whatsoever to those of this License.  You may not use
technical measures to obstruct or control the reading or further
copying of the copies you make or distribute.  However, you may accept
compensation in exchange for copies.  If you distribute a large enough
number of copies you must also follow the conditions in section 3.

You may also lend copies, under the same conditions stated above, and
you may publicly display copies.


3. COPYING IN QUANTITY

If you publish printed copies of the Document numbering more than 100,
and the Document's license notice requires Cover Texts, you must enclose
the copies in covers that carry, clearly and legibly, all these Cover
Texts: Front-Cover Texts on the front cover, and Back-Cover Texts on
the back cover.  Both covers must also clearly and legibly identify
you as the publisher of these copies.  The front cover must present
the full title with all words of the title equally prominent and
visible.  You may add other material on the covers in addition.
Copying with changes limited to the covers, as long as they preserve
the title of the Document and satisfy these conditions, can be treated
as verbatim copying in other respects.

If the required texts for either cover are too voluminous to fit
legibly, you should put the first ones listed (as many as fit
reasonably) on the actual cover, and continue the rest onto adjacent
pages.

If you publish or distribute Opaque copies of the Document numbering
more than 100, you must either include a machine-readable Transparent
copy along with each Opaque copy, or state in or with each Opaque copy
a publicly-accessible computer-network location containing a complete
Transparent copy of the Document, free of added material, which the
general network-using public has access to download anonymously at no
charge using public-standard network protocols.  If you use the latter
option, you must take reasonably prudent steps, when you begin
distribution of Opaque copies in quantity, to ensure that this
Transparent copy will remain thus accessible at the stated location
until at least one year after the last time you distribute an Opaque
copy (directly or through your agents or retailers) of that edition to
the public.

It is requested, but not required, that you contact the authors of the
Document well before redistributing any large number of copies, to give
them a chance to provide you with an updated version of the Document.


4. MODIFICATIONS

You may copy and distribute a Modified Version of the Document under
the conditions of sections 2 and 3 above, provided that you release
the Modified Version under precisely this License, with the Modified
Version filling the role of the Document, thus licensing distribution
and modification of the Modified Version to whoever possesses a copy
of it.  In addition, you must do these things in the Modified Version:

A. Use in the Title Page (and on the covers, if any) a title distinct
   from that of the Document, and from those of previous versions
   (which should, if there were any, be listed in the History section
   of the Document).  You may use the same title as a previous version
   if the original publisher of that version gives permission.
B. List on the Title Page, as authors, one or more persons or entities
   responsible for authorship of the modifications in the Modified
   Version, together with at least five of the principal authors of the
   Document (all of its principal authors, if it has less than five).
C. State on the Title page the name of the publisher of the
   Modified Version, as the publisher.
D. Preserve all the copyright notices of the Document.
E. Add an appropriate copyright notice for your modifications
   adjacent to the other copyright notices.
F. Include, immediately after the copyright notices, a license notice
   giving the public permission to use the Modified Version under the
   terms of this License, in the form shown in the Addendum below.
G. Preserve in that license notice the full lists of Invariant Sections
   and required Cover Texts given in the Document's license notice.
H. Include an unaltered copy of this License.
I. Preserve the section entitled "History", and its title, and add to
   it an item stating at least the title, year, new authors, and
   publisher of the Modified Version as given on the Title Page.  If
   there is no section entitled "History" in the Document, create one
   stating the title, year, authors, and publisher of the Document as
   given on its Title Page, then add an item describing the Modified
   Version as stated in the previous sentence.
J. Preserve the network location, if any, given in the Document for
   public access to a Transparent copy of the Document, and likewise
   the network locations given in the Document for previous versions
   it was based on.  These may be placed in the "History" section.
   You may omit a network location for a work that was published at
   least four years before the Document itself, or if the original
   publisher of the version it refers to gives permission.
K. In any section entitled "Acknowledgements" or "Dedications",
   preserve the section's title, and preserve in the section all the
   substance and tone of each of the contributor acknowledgements
   and/or dedications given therein.
L. Preserve all the Invariant Sections of the Document,
   unaltered in their text and in their titles.  Section numbers
   or the equivalent are not considered part of the section titles.
M. Delete any section entitled "Endorsements".  Such a section
   may not be included in the Modified Version.
N. Do not retitle any existing section as "Endorsements"
   or to conflict in title with any Invariant Section.

If the Modified Version includes new front-matter sections or
appendices that qualify as Secondary Sections and contain no material
copied from the Document, you may at your option designate some or all
of these sections as invariant.  To do this, add their titles to the
list of Invariant Sections in the Modified Version's license notice.
These titles must be distinct from any other section titles.

You may add a section entitled "Endorsements", provided it contains
nothing but endorsements of your Modified Version by various
parties--for example, statements of peer review or that the text has
been approved by an organization as the authoritative definition of a
standard.

You may add a passage of up to five words as a Front-Cover Text, and a
passage of up to 25 words as a Back-Cover Text, to the end of the list
of Cover Texts in the Modified Version.  Only one passage of
Front-Cover Text and one of Back-Cover Text may be added by (or
through arrangements made by) any one entity.  If the Document already
includes a cover text for the same cover, previously added by you or
by arrangement made by the same entity you are acting on behalf of,
you may not add another; but you may replace the old one, on explicit
permission from the previous publisher that added the old one.

The author(s) and publisher(s) of the Document do not by this License
give permission to use their names for publicity for or to assert or
imply endorsement of any Modified Version.


5. COMBINING DOCUMENTS

You may combine the Document with other documents released under this
License, under the terms defined in section 4 above for modified
versions, provided that you include in the combination all of the
Invariant Sections of all of the original documents, unmodified, and
list them all as Invariant Sections of your combined work in its
license notice.

The combined work need only contain one copy of this License, and
multiple identical Invariant Sections may be replaced with a single
copy.  If there are multiple Invariant Sections with the same name but
different contents, make the title of each such section unique by
adding at the end of it, in parentheses, the name of the original
author or publisher of that section if known, or else a unique number.
Make the same adjustment to the section titles in the list of
Invariant Sections in the license notice of the combined work.

In the combination, you must combine any sections entitled "History"
in the various original documents, forming one section entitled
"History"; likewise combine any sections entitled "Acknowledgements",
and any sections entitled "Dedications".  You must delete all sections
entitled "Endorsements."


6. COLLECTIONS OF DOCUMENTS

You may make a collection consisting of the Document and other documents
released under this License, and replace the individual copies of this
License in the various documents with a single copy that is included in
the collection, provided that you follow the rules of this License for
verbatim copying of each of the documents in all other respects.

You may extract a single document from such a collection, and distribute
it individually under this License, provided you insert a copy of this
License into the extracted document, and follow this License in all
other respects regarding verbatim copying of that document.


7. AGGREGATION WITH INDEPENDENT WORKS

A compilation of the Document or its derivatives with other separate
and independent documents or works, in or on a volume of a storage or
distribution medium, does not as a whole count as a Modified Version
of the Document, provided no compilation copyright is claimed for the
compilation.  Such a compilation is called an "aggregate", and this
License does not apply to the other self-contained works thus compiled
with the Document, on account of their being thus compiled, if they
are not themselves derivative works of the Document.

If the Cover Text requirement of section 3 is applicable to these
copies of the Document, then if the Document is less than one quarter
of the entire aggregate, the Document's Cover Texts may be placed on
covers that surround only the Document within the aggregate.
Otherwise they must appear on covers around the whole aggregate.


8. TRANSLATION

Translation is considered a kind of modification, so you may
distribute translations of the Document under the terms of section 4.
Replacing Invariant Sections with translations requires special
permission from their copyright holders, but you may include
translations of some or all Invariant Sections in addition to the
original versions of these Invariant Sections.  You may include a
translation of this License provided that you also include the
original English version of this License.  In case of a disagreement
between the translation and the original English version of this
License, the original English version will prevail.


9. TERMINATION

You may not copy, modify, sublicense, or distribute the Document except
as expressly provided for under this License.  Any other attempt to
copy, modify, sublicense or distribute the Document is void, and will
automatically terminate your rights under this License.  However,
parties who have received copies, or rights, from you under this
License will not have their licenses terminated so long as such
parties remain in full compliance.


10. FUTURE REVISIONS OF THIS LICENSE

The Free Software Foundation may publish new, revised versions
of the GNU Free Documentation License from time to time.  Such new
versions will be similar in spirit to the present version, but may
differ in detail to address new problems or concerns.  See
http://www.gnu.org/copyleft/.

Each version of the License is given a distinguishing version number.
If the Document specifies that a particular numbered version of this
License "or any later version" applies to it, you have the option of
following the terms and conditions either of that specified version or
of any later version that has been published (not as a draft) by the
Free Software Foundation.  If the Document does not specify a version
number of this License, you may choose any version ever published (not
as a draft) by the Free Software Foundation.


ADDENDUM: How to use this License for your documents

To use this License in a document you have written, include a copy of
the License in the document and put the following copyright and
license notices just after the title page:

      Copyright (c)  YEAR  YOUR NAME.
      Permission is granted to copy, distribute and/or modify this document
      under the terms of the GNU Free Documentation License, Version 1.1
      or any later version published by the Free Software Foundation;
      with the Invariant Sections being LIST THEIR TITLES, with the
      Front-Cover Texts being LIST, and with the Back-Cover Texts being LIST.
      A copy of the license is included in the section entitled "GNU
      Free Documentation License".

If you have no Invariant Sections, write "with no Invariant Sections"
instead of saying which ones are invariant.  If you have no
Front-Cover Texts, write "no Front-Cover Texts" instead of
"Front-Cover Texts being LIST"; likewise for Back-Cover Texts.

If your document contains nontrivial examples of program code, we
recommend releasing these examples in parallel under your choice of
free software license, such as the GNU General Public License,
to permit their use in free software.
---
   Artistic => <<'---',
		     The Clarified Artistic License

				Preamble

The intent of this document is to state the conditions under which a
Package may be copied, such that the Copyright Holder maintains some
semblance of artistic control over the development of the package,
while giving the users of the package the right to use and distribute
the Package in a more-or-less customary fashion, plus the right to make
reasonable modifications.

Definitions:

	"Package" refers to the collection of files distributed by the
	Copyright Holder, and derivatives of that collection of files
	created through textual modification.

	"Standard Version" refers to such a Package if it has not been
	modified, or has been modified in accordance with the wishes
	of the Copyright Holder as specified below.

	"Copyright Holder" is whoever is named in the copyright or
	copyrights for the package.

	"You" is you, if you're thinking about copying or distributing
	this Package.

	"Distribution fee" is a fee you charge for providing a copy
        of this Package to another party.

	"Freely Available" means that no fee is charged for the right to
        use the item, though there may be fees involved in handling the
        item.  It also means that recipients of the item may redistribute
        it under the same conditions they received it.

1. You may make and give away verbatim copies of the source form of the
Standard Version of this Package without restriction, provided that you
duplicate all of the original copyright notices and associated disclaimers.

2. You may apply bug fixes, portability fixes and other modifications
derived from the Public Domain, or those made Freely Available, or from
the Copyright Holder.  A Package modified in such a way shall still be
considered the Standard Version.

3. You may otherwise modify your copy of this Package in any way, provided
that you insert a prominent notice in each changed file stating how and
when you changed that file, and provided that you do at least ONE of the
following:

    a) place your modifications in the Public Domain or otherwise make them
    Freely Available, such as by posting said modifications to Usenet or an
    equivalent medium, or placing the modifications on a major network
    archive site allowing unrestricted access to them, or by allowing the
    Copyright Holder to include your modifications in the Standard Version
    of the Package.

    b) use the modified Package only within your corporation or organization.

    c) rename any non-standard executables so the names do not conflict
    with standard executables, which must also be provided, and provide
    a separate manual page for each non-standard executable that clearly
    documents how it differs from the Standard Version.

    d) make other distribution arrangements with the Copyright Holder.

    e) permit and encourge anyone who receives a copy of the modified Package
       permission to make your modifications Freely Available
       in some specific way.


4. You may distribute the programs of this Package in object code or
executable form, provided that you do at least ONE of the following:

    a) distribute a Standard Version of the executables and library files,
    together with instructions (in the manual page or equivalent) on where
    to get the Standard Version.

    b) accompany the distribution with the machine-readable source of
    the Package with your modifications.

    c) give non-standard executables non-standard names, and clearly
    document the differences in manual pages (or equivalent), together
    with instructions on where to get the Standard Version.

    d) make other distribution arrangements with the Copyright Holder.

    e) offer the machine-readable source of the Package, with your
       modifications, by mail order.

5. You may charge a distribution fee for any distribution of this Package.
If you offer support for this Package, you may charge any fee you choose
for that support.  You may not charge a license fee for the right to use
this Package itself.  You may distribute this Package in aggregate with
other (possibly commercial and possibly nonfree) programs as part of a
larger (possibly commercial and possibly nonfree) software distribution,
and charge license fees for other parts of that software distribution,
provided that you do not advertise this Package as a product of your own.
If the Package includes an interpreter, You may embed this Package's
interpreter within an executable of yours (by linking); this shall be
construed as a mere form of aggregation, provided that the complete
Standard Version of the interpreter is so embedded.

6. The scripts and library files supplied as input to or produced as
output from the programs of this Package do not automatically fall
under the copyright of this Package, but belong to whoever generated
them, and may be sold commercially, and may be aggregated with this
Package.  If such scripts or library files are aggregated with this
Package via the so-called "undump" or "unexec" methods of producing a
binary executable image, then distribution of such an image shall
neither be construed as a distribution of this Package nor shall it
fall under the restrictions of Paragraphs 3 and 4, provided that you do
not represent such an executable image as a Standard Version of this
Package.

7. C subroutines (or comparably compiled subroutines in other
languages) supplied by you and linked into this Package in order to
emulate subroutines and variables of the language defined by this
Package shall not be considered part of this Package, but are the
equivalent of input as in Paragraph 6, provided these subroutines do
not change the language in any way that would cause it to fail the
regression tests for the language.

8. Aggregation of the Standard Version of the Package with a commercial
distribution is always permitted provided that the use of this Package
is embedded; that is, when no overt attempt is made to make this Package's
interfaces visible to the end user of the commercial distribution.
Such use shall not be construed as a distribution of this Package.

9. The name of the Copyright Holder may not be used to endorse or promote
products derived from this software without specific prior written permission.

10. THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
WARRANTIES OF MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

				The End
---
  );
}
