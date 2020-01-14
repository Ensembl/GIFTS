=head1 LICENSE

# Copyright [2017-2020] EMBL-European Bioinformatics Institute
#
# Licensed under the Apache License,Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

=head1 NAME

Bio::EnsEMBL::GIFTS::BaseMapping -

=head1 DESCRIPTION

  This module implements the subroutines to run the muscle alignments, make cigar strings and print alignment information.

=cut

package Bio::EnsEMBL::GIFTS::BaseMapping;

use strict;
use warnings;
use Data::Dump qw(dump);
use Data::Dumper;
use DBI qw(:sql_types);
use LWP::UserAgent;
use File::Temp qw/ tempdir /;

use Exporter 'import';
our @EXPORT_OK = qw(make_cigar_string
                    make_cigar_plus_string
                    make_md_string
                    run_muscle
                    print_ensp2genomic_alignment
                    print_translation2genomic_alignment);

sub make_cigar_plus_string {

  my ($s1,$s2) = @_;
  my $cigar = "";

  my $c1 = substr($s1,0,1);
  my $c2 = substr($s2,0,1);
  my $previous_state = determine_cigar_plus_state($c1,$c2);
  my $state_count = 1;

  for (my $i=1; $i<length($s1); $i++) {
    $c1 = substr($s1,$i,1);
    $c2 = substr($s2,$i,1);
    my $this_state = determine_cigar_plus_state($c1,$c2);
    if ($this_state eq $previous_state) {
      $state_count++;
    }
    else {
      $cigar .= $state_count.$previous_state;
      $state_count=1;
      $previous_state = $this_state;
    }
  }
  $cigar .= $state_count.$previous_state;
  return $cigar;
}

sub determine_cigar_plus_state {
  my ($c1,$c2) = @_;
  if ($c1 eq $c2) {
    return "=";
  }
  if ($c1 eq '-') {
    return "I";
  }
  if ($c2 eq '-') {
    return "D";
  }
  if ($c2 ne $c1) {
    return "X";
  }
  return "-";
}

sub make_cigar_string {

  my ($s1,$s2) = @_;
  my $cigar = "";
  my $cigar_match_count = 0;
  my $cigar_insertion_count = 0;
  my $cigar_deletion_count = 0;
  my $in_cigar_match = 0;
  my $in_cigar_insertion = 0;
  my $in_cigar_deletion = 0;

  for (my $i=0; $i<length($s1); $i++) {
    my $c1 = substr($s1,$i,1);
    my $c2 = substr($s2,$i,1);

    unless($c1 eq '-' || $c2 eq '-') {
      $cigar_match_count++;
      if (!$in_cigar_match) {
        if ($in_cigar_insertion) {
          $cigar .= $cigar_insertion_count."I";
          $in_cigar_insertion = 0;
          $cigar_insertion_count = 0;
        } elsif ($in_cigar_deletion) {
          $cigar .= $cigar_deletion_count."D";
          $in_cigar_deletion = 0;
          $cigar_deletion_count = 0;
        }
        $in_cigar_match = 1;
      }

      next;
    }

    if ($c1 eq '-') {
      $cigar_insertion_count++;
      if (!$in_cigar_insertion) {
        if ($in_cigar_match) {
          $cigar .= $cigar_match_count."M";
          $in_cigar_match = 0;
          $cigar_match_count = 0;
        } elsif ($in_cigar_deletion) {
          $cigar .= $cigar_deletion_count."D";
          $in_cigar_deletion = 0;
          $cigar_deletion_count = 0;
        }
        $in_cigar_insertion = 1;
      }
    } elsif ($c2 eq '-') {
      $cigar_deletion_count++;
      if (!$in_cigar_deletion) {
        if ($in_cigar_match) {
          $cigar .= $cigar_match_count."M";
          $in_cigar_match = 0;
          $cigar_match_count = 0;
        } elsif ($in_cigar_insertion) {
          $cigar .= $cigar_insertion_count."D";
          $in_cigar_insertion = 0;
          $cigar_insertion_count = 0;
        }
        $in_cigar_deletion = 1;
      }
    }
  }

  if ($in_cigar_match) {
    $cigar .= $cigar_match_count."M";
  } elsif ($in_cigar_insertion) {
    $cigar .= $cigar_insertion_count."I";
  } elsif ($in_cigar_deletion) {
    $cigar .= $cigar_deletion_count."D";
  } else {
    die "Issue with creating the CIGAR string!";
  }

  return $cigar;
}

sub make_md_string {

  my ($s1,$s2) = @_;
  my $md = "MD:Z:";
  my $in_deletion = 0;
  my $previous_match_count = 0;
  for(my $i=0; $i<length($s1); $i++) {
    my $c1 = substr($s1,$i,1);
    my $c2 = substr($s2,$i,1);
    if ($c1 eq $c2) {
      $previous_match_count++;
      $in_deletion = 0;
    } elsif ($c1 ne $c2 && $c1 ne '-' && $c2 ne '-') {
      $md .= $previous_match_count.$c1;
      $previous_match_count = 0;
      $in_deletion = 0;
    } elsif ($c1 eq '-') {
      $in_deletion = 0;
    } elsif ($c2 eq '-') {
      if ($in_deletion) {
        $md .= $c1;
      } else {
        $md .= $previous_match_count."^".$c1;
        $in_deletion = 1;
      }
      $previous_match_count = 0;
    }
  }

  if ($previous_match_count) {
    $md .= $previous_match_count;
  }

  return $md;
}

# run muscle on one pair of Bio::Seq objects
sub run_muscle {
  my ($seqobj_u,$seqobj_e,$folder_muscle) = @_;

  my $file_id_string = $seqobj_u->display_id()."_".$seqobj_e->display_id();

  # write out and process a file with the pair of sequences to be compared
  my $muscle_source_filename =  "$folder_muscle/for_muscle_".$file_id_string.".fasta";
  my $muscle_output_filename =  "$folder_muscle/from_muscle_".$file_id_string.".fasta";
  my $muscle_source = Bio::SeqIO->new(-file => ">$muscle_source_filename",'-format' => 'fasta');
  $muscle_source->write_seq($seqobj_u);
  $muscle_source->write_seq($seqobj_e);
  $muscle_source->close();

  system("muscle -in $muscle_source_filename -out $muscle_output_filename -quiet");

  # open the muscle file for processing
  my $compared =  Bio::SeqIO->new(-file => $muscle_output_filename,-format => "fasta");
  my $seqobj_compu = $compared->next_seq();
  my $seqobj_compe = $compared->next_seq();

  unlink $muscle_source_filename or die ("Could not delete $muscle_source_filename");
  unlink $muscle_output_filename or die ("Could not delete $muscle_output_filename");

  return ($seqobj_compu,$seqobj_compe);
}

#
sub print_uniprot_ensp_genomic_alignment {
  my($species,$ensp_id) = @_;
}

sub unravel_cigarplus() {
  my($cigarplus,$mdz,$seq1,$seq2) = @_;
}

# print the genomic alignment for a specified ENSP identifier
sub print_ensp2genomic_alignment {
  my($species,$ensp_id) = @_;
  my $ens_db_adaptor = Bio::EnsEMBL::Registry->get_DBAdaptor($species,"core");
  my $translation_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species,"core","translation");
  my $translation = $translation_adaptor->fetch_by_stable_id($ensp_id);
  print_translation2genomic_alignment($species,$translation);
}

# print the genomic alignment for a specified Ensembl translation object
sub print_translation2genomic_alignment {
  my($species,$translation) = @_;

  my $slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species,"core","Slice");

  my $transcript = $translation->transcript();
  my $seq_region_name = $transcript->seq_region_name();
  my $transcript_slice =  $transcript->slice();
  my $trmapper = Bio::EnsEMBL::TranscriptMapper->new($transcript);

  my @gen_coords = $trmapper->pep2genomic(0,$translation->length());
  print "seq_region_name=".$transcript->seq_region_name."\nWHOLE LENGTH\n";
  my $ep_line = "";
  my $match_line = "";
  my $genome_line = "";

  foreach my $g (@gen_coords) {
    if ($g->isa("Bio::EnsEMBL::Mapper::Gap")) {
      # GAP is not a common thing so deal with it if it comes up
      print "GAP\n";
    }
    elsif ($g->isa("Bio::EnsEMBL::Mapper::Coordinate")) {
      print "\nCOORD:";
      print "Range=".$g->start.":".$g->end.":".$g->strand." ";
      print "length=".$g->length." ";
      print "rank=".$g->rank." ";
      print "id=".$g->id." ";
      #   print "system=".$g->coord_system."\n";
    }
  }

  # Now the ladder display
  my $ensp_seq = $translation->seq();
  # first pass is an inefficient item - process on a base by base basis
  my @ensp_chars = split(//,$ensp_seq);
  my $ep_position=0;
  foreach my $ep (@ensp_chars) {
    $ep_position++;
    $ep_line = $ep_line."$ep  ";
    $match_line = $match_line."$ep_position";
    my @base_coords = $trmapper->pep2genomic($ep_position,$ep_position);
    print "\n$ep\t$ep_position\n";
    foreach my $b (@base_coords) {
      my $slice = $slice_adaptor->fetch_by_region('toplevel',$seq_region_name,$b->start,$b->end,$b->strand);
      print "\t".$b->start.":".$b->end.":".$b->strand.":".$slice->seq."\n";
    }
    print "\n";
  }
}

1;
