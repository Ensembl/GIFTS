=head1 LICENSE

# Copyright [2017] EMBL-European Bioinformatics Institute
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
                    retrieve_muscle_info_uniprot
                    print_ladder
                    print_ensp2genomic_alignment
                    print_translation2genomic_alignment);

sub retrieve_muscle_info_uniprot {
  my ($dbc,$uniprot_acc,$uniprot_release,$verbose) = @_;
  my @cigarplus_hashes;

  if (!$uniprot_acc) {
    die "No uniprot accession passed in";
  }

  if (!$uniprot_release) {
    die "No uniprot release passed in";
  }

  # Get the protein information
  my $sql_string = "SELECT ue.uniprot_id,ue.sequence_version ".
                   "FROM uniprot_entry ue,uniprot_entry_history ueh ".
                   "WHERE ue.uniprot_id=ueh.uniprot_id AND".
                   "      ue.uniprot_acc=? AND ".
                   "      ueh.release_version=? ".
                   " ORDER BY ue.uniprot_id DESC LIMIT 1";

  my $sth = $dbc->prepare($sql_string);
  $sth->bind_param(1,$uniprot_acc,SQL_CHAR);
  $sth->bind_param(2,$uniprot_release,SQL_CHAR);
  $sth->execute();
  my ($uniprot_id,$uniprot_seq_version) = $sth->fetchrow_array();
  $sth->finish();

  if (!$uniprot_id) {
    return;
  }

  if ($verbose) {
    print("retrieve_muscle_info:\n".
      "\tUniprotID $uniprot_id - $uniprot_seq_version found for accession $uniprot_acc/$uniprot_release\n");
  }


  # Get the mapping information
  # GIFTS supports multiple protein to transcript mappings,so loop through the results
  $sql_string = "SELECT mapping_id,mapping_history_id,transcript_id FROM ensembl_uniprot WHERE uniprot_id=?";
  $sth = $dbc->prepare($sql_string);
  $sth->bind_param(1,$uniprot_id,SQL_INTEGER);
  $sth->execute();
  my $mapping_id;
  my $mapping_history_id;
  my $transcript_id;
  $sth->bind_col(1,\$mapping_id);
  $sth->bind_col(2,\$mapping_history_id);
  $sth->bind_col(3,\$transcript_id);

  # First cycle through the mapping IDs for the uniprot acc and find each perfect match
  my $perfect_match_found = 0;
  while ($sth->fetch()) {
    if ($verbose) {
      print("\tmapping $mapping_id found to $transcript_id\n");
    }

    # get the Ensembl transcript ID
    my $sql_enst = "SELECT enst_id FROM ensembl_transcript WHERE transcript_id=?";
    my $sth_enst = $dbc->prepare($sql_enst);
    $sth_enst->bind_param(1,$transcript_id,SQL_INTEGER);
    $sth_enst->execute();
    my $enst_id;
    $sth_enst->bind_col(1,\$enst_id);
    $sth_enst->fetch();

    # search for perfect match alignments for this mapping ID
    my $sql_align = "SELECT alignment_id,alignment_run_id FROM alignment WHERE uniprot_id=? AND transcript_id=? AND mapping_id=? AND score1=1";
    if ($verbose) {
      print("\t$sql_align\n");
    }
    my $sth_align = $dbc->prepare($sql_align);
    $sth_align->bind_param(1,$uniprot_id,SQL_INTEGER);
    $sth_align->bind_param(2,$transcript_id,SQL_INTEGER);
    $sth_align->bind_param(3,$mapping_id,SQL_INTEGER);
    $sth_align->execute();
    my $alignment_id;
    my $alignment_run_id;
    $sth_align->bind_col(1,\$alignment_id);
    $sth_align->bind_col(2,\$alignment_run_id);
    while($sth_align->fetch()) {
      if ($verbose) {
        print "\tAlignment $alignment_id found in Alignment Run $alignment_run_id\n";
      }
      # the perfect score alignment run type check
      my $sql_perfect_score_check = "SELECT score1_type FROM alignment_run WHERE alignment_run_id=?";
      my $sth_perfect_score_check = $dbc->prepare($sql_perfect_score_check);
      $sth_perfect_score_check->bind_param(1,$alignment_run_id,SQL_INTEGER);
      $sth_perfect_score_check->execute();
      my $s1_type;
      $sth_perfect_score_check->bind_col(1,\$s1_type);
      $sth_perfect_score_check->fetch();

      if ($s1_type eq "perfect_match") {
        # we have a perfect match
        my %cigar_md5_hash;
        $cigar_md5_hash{cigarplus} = "PERFECT";
        $cigar_md5_hash{mdz} = "PERFECT";
        $cigar_md5_hash{enst_id} = $enst_id;
        $cigar_md5_hash{uniprot_acc} = $uniprot_acc;
        $cigar_md5_hash{uniprot_seq_version} = $uniprot_seq_version;
        push @cigarplus_hashes,\%cigar_md5_hash;
        $perfect_match_found = 1;

        if ($verbose) {
          print "\tPerfect Match found\n";
          dump(%cigar_md5_hash);
        }
      }
    }
  }


  # If sequences are available for non-perfect matches they will live in the cigar table directly
  my $sql_cigar = "SELECT cigarplus,mdz,ensp_id FROM ensp_u_cigar WHERE uniprot_acc=? AND uniprot_seq_version=?";
  my $sth_cigar = $dbc->prepare($sql_cigar);
  $sth_cigar->bind_param(1,$uniprot_acc,SQL_CHAR);
  $sth_cigar->bind_param(2,$uniprot_seq_version,SQL_INTEGER);
  $sth_cigar->execute();
  my $cigarplus;
  my $mdz;
  my $ensp_id;
  $sth_cigar->bind_col(1,\$cigarplus);
  $sth_cigar->bind_col(2,\$mdz);
  $sth_cigar->bind_col(3,\$ensp_id);
  my %cigar_md5_hash;

  while($sth_cigar->fetch()) {
    $cigar_md5_hash{cigarplus} = $cigarplus;
    $cigar_md5_hash{mdz} = $mdz;
    $cigar_md5_hash{ensp_id} = $ensp_id;
    $cigar_md5_hash{uniprot_acc} = $uniprot_acc;
    $cigar_md5_hash{uniprot_seq_version} = $uniprot_seq_version;
    push @cigarplus_hashes,\%cigar_md5_hash;
  }
  $sth_cigar->finish();

  return \@cigarplus_hashes;
}

sub print_ladder {
  # may need to pass in a sequence parameter as well
  my ($cigar,$mdz,$seq1,$seq2) = @_;

  # All mdz strings stored in the database have MD:Z: at the start
  my($m,$z,$md) = split(/:/,$mdz);

  if ($cigar eq "PERFECT") {
    print $seq1."\n";
    for (my $i=0; $i<length($seq1); $i++) {
      print "|";
    }
    print "\n".$seq2."\n";
    return;
  }

  my @counts = split(/\D/,$cigar);
  my @types = split(/\d+/,$cigar);
  my $junk = shift(@types);

  print "SEQ1:$seq1\nSEQ2:$seq2\n";

  my @seq1chars = split(//,$seq1);
  my @seq2chars = split(//,$seq2);

  my $line = 0;

  foreach my $c (@counts) {
    my $type = shift(@types);
    print "TYPE $type $c\n";
    if ($type eq '=') {
      for(my $i=0; $i<$c; $i++) {
        $line++;
        print "$line\t".shift(@seq1chars)."=".shift(@seq2chars)."\n";
      }
    }
    elsif ($type eq 'I') {
      for (my $i=0; $i<$c; $i++) {
        $line++;
        print "$line\t-i".shift(@seq2chars)."\n";
      }
    }
    elsif ($type eq 'D') {
      for(my $i=0; $i<$c; $i++) {
        $line++;
        print "$line\t".shift(@seq1chars)."d-\n";
      }
    }
    elsif ($type eq 'X') {
      for(my $i=0; $i<$c; $i++) {
        $line++;
        print "$line\t".shift(@seq1chars)."x".shift(@seq2chars)."\n";
      }
    }
  } # foreach my $c

  print "\n\n$cigar\n\n";
}

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
