#!/usr/bin/env perl
use warnings;
use strict;
use Data::Dumper;
use List::Util qw(min max);
use List::MoreUtils qw(uniq all any);
use Text::CSV;
use SVG;

use constant FONT_ASPECT => 0.8;

my(@Options, $verbose, $taxacol, $width, $height, $panonly, $consensus, $border, $colour);
setOptions();

# read gene_presence_absence.csv from stdin
# "Gene","Non-unique Gene name","Annotation","No. isolates","No. sequences","Avg sequences per isolate","Genome Fragment","Order within Fragment","Accessory Fragment","Accessory Order with Fragment","QC","SRR2352235","SRR2352236","SRR2352237","SRR2352238","SRR2352239","SRR2352240","SRR2352241","SRR2352242","SRR2352243","SRR2352244","SRR2352245","SRR2352246","SRR2352247","SRR2352248","SRR2352249","SRR2352250","SRR2352251","SRR2352252"
my $csv = Text::CSV->new() or die $!;
my $count=0;
my @matrix;
my @id;
my $N;
my $C=0;
while (my $row = $csv->getline(\*ARGV) ) {
  if ($count == 0) {
    @id = splice @$row, $taxacol;
    $N = scalar(@id);
    print STDERR "Found $N taxa: @id\n";    
  }
  else {
    my @present = map { $row->[$taxacol+$_] ? 1 : 0 } (0 .. $N-1);
    next if $panonly and all { $_==1 } @present;
    push @{ $matrix[$_] }, $present[$_] for (0 .. $N-1);
    $C++;
  }
  $count++;
}
print STDERR "Found $C clusters.\n";

my $real_height = $height*($N+1);
my $svg = SVG->new(width=>$width, height=>$real_height);
my $dy = $height;
my $fontsize = 0.75 * $dy;
my $lchars = max( map { length($_) } @id );
my $llen =  $fontsize * (1 + $lchars) * FONT_ASPECT;
my $width2 = $width - $llen;
my $dx = $width2 / $C;
print STDERR "Box = $dx x $dy px\n";
print STDERR "Label width = $lchars chr x $fontsize px\n";

for my $j (0 .. $N-1) {
  for my $i (0 .. $C-1) {
#    print STDERR "$j $i $matrix[$j][$i]\n";
    if ($matrix[$j][$i]) {
      # box for each present gene
      $svg->rectangle( 
          'x' => $llen+$i*$dx, 'y' => $j*$dy, 'width' => $dx,'height' => $dy-1, 
          'style' => { fill=>$colour },
      );      
    }
  }
  # label for each row
  $svg->text(
    x=>$fontsize, y=>($j+0.75)*$dy, -cdata=>$id[$j],
    style=>{ 'font-family'=>'sans-serif', 'fill'=>'black', 'font-size'=>$fontsize },
  );
}

# bottom label
$svg->text(
  x=>$llen, y=>($N+0.75)*$dy, -cdata=>"$N taxa, $C clusters",
  style=>{ 'font-family'=>'sans-serif', 'fill'=>'black', 'font-size'=>$fontsize },
);

# border
if ($border) {
  $svg->rectangle( 
    'x' => 0, 'y' => 0, 'width' => $width, 'height' => $real_height, 
    'style' => { stroke=>'black', fill=>'none' },
  );      
}

print STDERR "Writing SVG file\n";
print STDOUT $svg->xmlify;

print STDERR "Done.\n";

#----------------------------------------------------------------------
# Option setting routines

sub setOptions {
  use Getopt::Long;

  @Options = (
    {OPT=>"help",    VAR=>\&usage,             DESC=>"This help"},
    {OPT=>"verbose!",  VAR=>\$verbose, DEFAULT=>0, DESC=>"Verbose output"},
    {OPT=>"width=i",  VAR=>\$width, DEFAULT=>1024, DESC=>"Canvas width"},
    {OPT=>"height=i",  VAR=>\$height, DEFAULT=>20, DESC=>"Row height (and ~ font height)"},
    {OPT=>"taxacolumn=i",  VAR=>\$taxacol, DEFAULT=>14, DESC=>"Column in gpa.csv where taxa begin"},
    {OPT=>"colour=s",  VAR=>\$colour, DEFAULT=>'gray', DESC=>"Colour of pan genome cells"},
    {OPT=>"panonly!",  VAR=>\$panonly, DEFAULT=>0, DESC=>"Only non-core genes"},
#    {OPT=>"consensus!",  VAR=>\$consensus, DEFAULT=>0, DESC=>"Add consensus row"},
    {OPT=>"border!",  VAR=>\$border, DEFAULT=>0, DESC=>"Add outline border"},
  );

  (!@ARGV) && (usage());

  &GetOptions(map {$_->{OPT}, $_->{VAR}} @Options) || usage();

  # Now setup default values.
  foreach (@Options) {
    if (defined($_->{DEFAULT}) && !defined(${$_->{VAR}})) {
      ${$_->{VAR}} = $_->{DEFAULT};
    }
  }
}

sub usage {
  print "Usage: $0 [options] gene_presence_absence.csv > pan_genome.svg\n";
  foreach (@Options) {
    printf "  --%-13s %s%s.\n",$_->{OPT},$_->{DESC},
           defined($_->{DEFAULT}) ? " (default '$_->{DEFAULT}')" : "";
  }
  exit(1);
}
 
#----------------------------------------------------------------------
