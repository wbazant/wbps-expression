use strict;
use warnings;
package Production::Analysis::DataFiles;
use File::Slurp qw/read_dir/;

use LWP;
my $CAN_SEE_EBI_FILESYSTEM = -d "/nfs/ftp";

sub open_read_fh {
  my ($path) = @_;
  print STDERR "open_read_fh $path\n" if $ENV{ANALYSIS_VERBOSE};
  my $fh;
  if (not ref $path and $path =~ m{ftp://ftp.ebi.ac.uk}) {
    if( $CAN_SEE_EBI_FILESYSTEM ) {
       $path =~ s{ftp://ftp.ebi.ac.uk}{/nfs/ftp};
       open ($fh, "<", $path) or die "$path: $!";
    } else {
       my $response = LWP::UserAgent->new->get($path);
       die "$path error:".$response->status_line."\n" unless $response->is_success;
       my $body = $response->decoded_content;
       open ($fh, "<", \$body) or die "$path: $!";
    }
  } else {
    open ($fh, "<", $path) or die "$path: $!";
  }
  return $fh;
}

sub read_file_into_hash {
  my ($path) = @_;
  my %result;
  my $fh = open_read_fh($path);
  my $header = <$fh>;
  while(<$fh>){
    chomp;
    my ($k, $v) = split "\t";
    $result{$k} = $v;
  }
  close $fh;
  return \%result;
}

sub read_files_into_averaged_hash {
  my (@paths) = @_;
  my %result;
  for my $path (@paths) {
	my $fh = open_read_fh($path);
	my $header = <$fh>;
	while(<$fh>){
      chomp;
	  my ($k, $v) = split "\t";
	  push @{$result{$k}},$v;
	}
    close $fh;
  }
  for my $k (keys %result){
    $result{$k} = sprintf("%.1f", calculate_median($result{$k})); 
  }
  return \%result;
}

#Adapted from: https://metacpan.org/source/SHLOMIF/Statistics-Descriptive-3.0612/lib/Statistics/Descriptive.pm#L237
sub calculate_median {
    my ( $expressions ) = @_;
    my @expressionsSorted = sort {$a <=> $b} @$expressions;
    my $count = @expressionsSorted;
    ##Even or odd
    if ($count % 2){
        return @expressionsSorted[($count-1)/2];
    } else {
        return (
            (@expressionsSorted[($count)/2] + @expressionsSorted[($count-2)/2] ) / 2
        );
    }
}
sub write_named_hashes {
  my ($name_to_data_pairs, $out_path, @frontmatter) = @_;
  print STDERR sprintf("write_named_hashes %s -> %s\n", scalar @{$name_to_data_pairs}, $out_path) if $ENV{ANALYSIS_VERBOSE};
  my %row_labels;
  for my $p (@{$name_to_data_pairs}){
    for my $label(keys %{$p->[1]}){
      $row_labels{$label}++;
    }
  }
  open(my $fh, ">", $out_path) or die "$out_path: $!";
  print $fh "# $_\n" for @frontmatter;
  print $fh join ("\t", "", map {$_->[0]} @{$name_to_data_pairs})."\n";
  for my $row (sort keys %row_labels){
     print $fh join ("\t",$row, map {$_->[1]->{$row} // ""} @{$name_to_data_pairs})."\n";
  }
  close $fh;
}
sub aggregate {
  my ($name_to_path_pairs, $out_path, @frontmatter) = @_;
  my @name_to_data_pairs = map {
   my $name = $_->[0];
   my $data = read_file_into_hash($_->[1]);
   [$name, $data]
  }  @{$name_to_path_pairs};
  write_named_hashes(\@name_to_data_pairs, $out_path, @frontmatter);
}
sub average_and_aggregate {
  my ($name_to_pathlist_pairs, $out_path, @frontmatter) = @_;
  my @name_to_data_pairs =  map {
    my $name = $_->[0];
    my $data = read_files_into_averaged_hash(@{$_->[1]});
    [$name, $data]
  } @{$name_to_pathlist_pairs};
  write_named_hashes(\@name_to_data_pairs, $out_path, @frontmatter);
}
1;
