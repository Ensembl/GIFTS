=head1 LICENSE

# Copyright [2017-2018] EMBL-European Bioinformatics Institute
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

Bio::EnsEMBL::GIFTS::DB -

=head1 DESCRIPTION

  This module contains a set of methods to fetch data from and store data to the GIFTS database.

=cut


package Bio::EnsEMBL::GIFTS::DB;

use strict;
use warnings;

use Data::Dumper;
use DBI qw(:sql_types);
use LWP::UserAgent;
use Bio::DB::HTS::Faidx;

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(fetch_uniprot_accession
                  fetch_true_uniprot_accession
                  fetch_uniprot_info_for_id
                  store_alignment
                  store_pdb_ens
                  fetch_transcript_ids
                  get_gifts_dbc
                  get_info_from_perfect_match_alignment_run
                  fetch_cigarmdz
                  store_cigarmdz
                  is_perfect_eu_match_mapping_id
                  is_perfect_eu_match_accessions
                  is_perfect_eu_match_uniparcs
                  fetch_latest_uniprot_enst_perfect_matches
               );


# denotes if the values in the UniProt mapping pipeline has identified something as a perfect match
sub is_perfect_eu_match_mapping_id {
  my ($dbc,$mapping_id) = @_;

  my $sql_select = "SELECT mh.sp_ensembl_mapping_type FROM mapping m,mapping_history mh WHERE m.mapping_id=mh.mapping_id and m.mapping_id=?".
    " AND mh.sp_ensembl_mapping_type LIKE '%ONE2ONE%' ";
  my $sth = $dbc->prepare($sql_select);
  $sth->bind_param(1,$mapping_id,SQL_INTEGER);
  $sth->execute();
  my ($mapping_type) = $sth->fetchrow_array();
  $sth->finish();

  return $mapping_type;
}

# denotes if the values in the UniProt mapping pipeline has identified something as a perfect match
sub is_perfect_eu_match_accessions {
  my ($dbc,$uniprot_acc,$ensp_id,$uniprot_release,$ensembl_release) = @_;
  my $mapping_id = get_mapping_id_from_accs($dbc,$uniprot_acc,$ensp_id,$uniprot_release,$ensembl_release);
  if ($mapping_id) {
    return is_perfect_eu_match_mapping_id($dbc,$mapping_id);
  }
  return;
}

# Use the UniParc identifier as a comparison tool
sub is_perfect_eu_match_uniparcs {
  my ($dbc,$uniprot_id,$transcript_id) = @_;
  my $sql_select_e = "SELECT uniparc_accession  FROM ensembl_transcript WHERE transcript_id=?";
  my $sql_select_u = "SELECT upi  FROM uniprot_entry WHERE uniprot_id=?";

  my $sth = $dbc->prepare($sql_select_e);
  $sth->bind_param(1,$transcript_id,SQL_INTEGER);
  $sth->execute();
  my ($upi_e) = $sth->fetchrow_array();
  $sth->finish();

  $sth = $dbc->prepare($sql_select_u);
  $sth->bind_param(1,$uniprot_id,SQL_INTEGER);
  $sth->execute();
  my ($upi_u) = $sth->fetchrow_array();
  $sth->finish();

  if (!$upi_u || !$upi_e) {
    return 0;
  }

  if ($upi_u eq $upi_e) {
    return 1;
  }

  return 0;
}

# determine mapping ID
sub get_mapping_id_from_ids {
  my ($dbc,$uniprot_id,$transcript_id) = @_;
  my $sql_select_m = "SELECT mapping_id FROM mapping WHERE uniprot_id=? AND transcript_id=? ORDER BY mapping_id DESC LIMIT 1 ";
  my $sth = $dbc->prepare($sql_select_m);
  $sth->bind_param(1,$uniprot_id,SQL_INTEGER);
  $sth->bind_param(2,$transcript_id,SQL_INTEGER);
  $sth->execute();
  my ($mapping_id) = $sth->fetchrow_array();
  $sth->finish();
  return $mapping_id;
}

sub get_mapping_id_from_accs {
  my ($dbc,$uniprot_acc,$ensp_id,$uniprot_release,$ensembl_release) = @_;
  # determine a uniprot ID
  my $sql_select_u = "SELECT ue.uniprot_id,mh.mapping_history_id FROM uniprot_entry ue,mapping m,mapping_history mh WHERE ue.uniprot_id=m.uniprot_id AND m.mapping_id=mh.mapping_id AND ue.uniprot_acc=? ".
    "ORDER BY mapping_history_id DESC LIMIT 1 ";
  if ($uniprot_release) {
    $sql_select_u = "SELECT ue.uniprot_id,mh.mapping_history_id FROM uniprot_entry ue,mapping m,mapping_history mh WHERE ue.uniprot_id=m.uniprot_id AND m.mapping_id=mh.mapping_id AND ue.uniprot_acc=? ".
      "AND $uniprot_release=".$uniprot_release;
  }
  my $sth = $dbc->prepare($sql_select_u);
  $sth->bind_param(1,$uniprot_acc,SQL_CHAR);
  $sth->execute();
  my ($uniprot_id,$mapping_history_id_db) = $sth->fetchrow_array();
  $sth->finish();

  # determine an EnsEMBL transcript ID
  my $sql_select_e = "SELECT et.transcript_id,esh.ensembl_release FROM ensembl_transcript et,transcript_history th,ensembl_species_history esh WHERE et.enst_id=? AND et.transcript_id=th.transcript_id AND th.ensembl_species_history_id=esh.ensembl_species_history_id ORDER BY esh.ensembl_release DESC LIMIT 1 ";
  if ($ensembl_release) {
    $sql_select_e = "SELECT et.transcript_id,esh.ensembl_release FROM ensembl_transcript et,transcript_history th,ensembl_species_history esh WHERE et.enst_id=? AND et.transcript_id=th.transcript_id AND th.ensembl_species_history_id=esh.ensembl_species_history_id ".
      " AND esh.ensembl_release=".$ensembl_release." ORDER BY esh.ensembl_release DESC LIMIT 1 ";
  }
  $sth = $dbc->prepare($sql_select_e);
  $sth->bind_param(1,$ensp_id,SQL_CHAR);
  $sth->execute();
  my ($transcript_id,$ensembl_release_db) = $sth->fetchrow_array();
  $sth->finish();

  my $mapping_id = get_mapping_id_from_ids($dbc,$uniprot_id,$transcript_id);
  return $mapping_id;
}

sub fetch_uniprot_info_for_id {
  my ($dbc,$uniprot_id,@uniprot_archive_parsers) = @_;

  my $uniprot_seq = undef;
  my ($uniprot_true_acc,$uniprot_seq_version) = fetch_true_uniprot_accession($dbc,$uniprot_id);
  foreach my $ui (@uniprot_archive_parsers) {
    if ($ui->has_sequence($uniprot_true_acc)) {
      $uniprot_seq = $ui->get_sequence_no_length($uniprot_true_acc);
      return($uniprot_seq,$uniprot_true_acc,$uniprot_seq_version);
    }
  }
  my ($uniprot_acc,$uniprot_seq_version2) = fetch_uniprot_accession($dbc,$uniprot_id);
  if ($uniprot_acc ne $uniprot_true_acc) {
    foreach my $ui (@uniprot_archive_parsers) {
      if ($ui->has_sequence($uniprot_acc)) {
        $uniprot_seq = $ui->get_sequence_no_length($uniprot_acc);
        return($uniprot_seq,$uniprot_acc,$uniprot_seq_version2);
      }
    }
  }
  return;
}

sub fetch_uniprot_accession {
  my ($dbc,$uniprot_id) = @_;
  my $sql_select_uniprot_acc = "SELECT uniprot_acc,sequence_version FROM uniprot_entry WHERE uniprot_id=?";
  my $sth = $dbc->prepare($sql_select_uniprot_acc);
  $sth->bind_param(1,$uniprot_id,SQL_INTEGER);
  $sth->execute();
  my ($uniprot_acc,$sequence_version) = $sth->fetchrow_array();
  $sth->finish();

  # strip a preceding $ from the accession - this may be stored in GIFTS
  # redundant entries are special cases,but they still can be mapped
  $uniprot_acc =~ s/\$//g;

  # strip -1 at the end of uniprot accessions. These are added to the uniprot entries
  # but these are not present in the downloaded swissprot files
  $uniprot_acc =~ s/-1//;

  return ($uniprot_acc,$sequence_version);
}

sub fetch_true_uniprot_accession {
  my ($dbc,$uniprot_id) = @_;
  my $sql_select_uniprot_acc = "SELECT uniprot_acc,sequence_version FROM uniprot_entry WHERE uniprot_id=?";
  my $sth = $dbc->prepare($sql_select_uniprot_acc);
  $sth->bind_param(1,$uniprot_id,SQL_INTEGER);
  $sth->execute();
  my ($uniprot_acc,$sequence_version) = $sth->fetchrow_array();
  $sth->finish();

  return ($uniprot_acc,$sequence_version);
}

sub fetch_transcript_ids {
  my ($dbc,$gifts_transcript_id) = @_;
  my $sql_select_enst = "SELECT enst_id FROM ensembl_transcript WHERE transcript_id=?";
  my $sth = $dbc->prepare($sql_select_enst);
  $sth->bind_param(1,$gifts_transcript_id,SQL_INTEGER);
  $sth->execute();
  my ($enst_id) = $sth->fetchrow_array();
  $sth->finish();

  return $enst_id;
}

sub store_alignment {
  my ($dbc,$alignment_run_id,$uniprot_id,$transcript_id,$mapping_id,$score1,$score2,$report) = @_;

  my $sql_select_arun = "SELECT * FROM alignment_run WHERE alignment_run_id=?";
  my $sth_arun = $dbc->prepare($sql_select_arun);
  $sth_arun->bind_param(1,$alignment_run_id,SQL_INTEGER);
  $sth_arun->execute();

  my $sql_alignment_add =
    "INSERT INTO alignment (alignment_run_id,uniprot_id,transcript_id,mapping_id,score1,score2,report) VALUES (?,?,?,?,?,?,?)";

  my $sth = $dbc->prepare($sql_alignment_add);
  $sth->bind_param(1,$alignment_run_id);
  $sth->bind_param(2,$uniprot_id);
  $sth->bind_param(3,$transcript_id);
  $sth->bind_param(4,$mapping_id);
  $sth->bind_param(5,$score1);
  $sth->bind_param(6,$score2);
  $sth->bind_param(7,$report);
  $sth->execute() or die "Could not add the alignment:\n".$dbc->errstr;
  $sth->finish();
}

sub store_pdb_ens {
  my ($dbc,$pdb_acc,$pdb_release,$uniprot_acc,$enst_id,$enst_version,$ensp_id,$ensp_start,$ensp_end,$pdb_start,$pdb_end,$pdb_chain) = @_;

  my $sql_insert =
    "INSERT INTO pdb_ens (pdb_acc,pdb_release,uniprot_acc,enst_id,enst_version,ensp_id,ensp_start,ensp_end,pdb_start,pdb_end,pdb_chain) VALUES (?,?,?,?,?,?,?,?,?,?,?)";

  my $sth = $dbc->prepare($sql_insert);
  $sth->bind_param(1,$pdb_acc);
  $sth->bind_param(2,$pdb_release);
  $sth->bind_param(3,$uniprot_acc);
  $sth->bind_param(4,$enst_id);
  $sth->bind_param(5,$enst_version);
  $sth->bind_param(6,$ensp_id);
  $sth->bind_param(7,$ensp_start);
  $sth->bind_param(8,$ensp_end);
  $sth->bind_param(9,$pdb_start);
  $sth->bind_param(10,$pdb_end);
  $sth->bind_param(11,$pdb_chain);
  $sth->execute() or die "GIFTS DB error: Could not store pdb_ens:\n".$dbc->errstr;
  $sth->finish();
}

sub store_cigarmdz {
  my ($dbc,$alignment_id,$cigar_plus_string,$md_string) = @_;
  my $sql_insert =
    "INSERT INTO ensp_u_cigar (alignment_id,cigarplus,mdz) VALUES (?,?,?)";

  my $sth = $dbc->prepare($sql_insert);
  $sth->bind_param(1,$alignment_id);
  $sth->bind_param(2,$cigar_plus_string);
  $sth->bind_param(3,$md_string);
  $sth->execute() or die "GIFTS DB error: Could not store cigar/mdz:\n".$dbc->errstr;
  $sth->finish();
  
  # update the "alignment_difference" column in the "mapping" table
  # alignment_difference is the sum of I, D and X in the cigarplus string
  my $alignment_difference = 0;
  while ($cigar_plus_string =~ /([0-9]+)(.)/g) {
    if ($2 eq "I" or
        $2 eq "D" or
        $2 eq "X") {
      $alignment_difference += $1;
    }
  }

  # get uniprot_id and transcript_id by alignment_id
  my $sql_select_alignment = "SELECT uniprot_id,transcript_id FROM alignment WHERE alignment_id=?";
  my $sth = $dbc->prepare($sql_select_alignment);
  $sth->bind_param(1,$alignment_id,SQL_INTEGER);
  $sth->execute();
  my ($uniprot_id,$transcript_id) = $sth->fetchrow_array();
  $sth->finish();

  # update the mapping table with the alignment_difference value
  my $sql_mapping_update = "UPDATE mapping SET alignment_difference=? WHERE uniprot_id=? AND transcript_id=?"; 
  $sth = $dbc->prepare($sql_mapping_update);
  $sth->bind_param(1,$alignment_difference);
  $sth->bind_param(2,$uniprot_id);
  $sth->bind_param(3,$transcript_id);
  $sth->execute() or die "Could not update the mapping alignment difference:\n".$dbc->errstr;
  $sth->finish();
}

sub fetch_cigarmdz {
  my ($dbc,$alignment_id) = @_;

  my $sql_select_uniprot_acc = "SELECT cigarplus,mdz FROM ensp_u_cigar ".
    "WHERE alignment_id=?";
  my $sth = $dbc->prepare($sql_select_uniprot_acc);
  $sth->bind_param(1,$alignment_id,SQL_INTEGER);
  $sth->execute();
  my ($cigar_plus_string,$md_string) = $sth->fetchrow_array();
  $sth->finish();
  return ($cigar_plus_string,$md_string);
}

sub get_gifts_dbc {
  my ($giftsdb_name,$giftsdb_schema,$giftsdb_host,$giftsdb_user,$giftsdb_pass,$giftsdb_port) = @_;

  my $dsn = "dbi:Pg:dbname=".$giftsdb_name.";host=".$giftsdb_host.";port=".$giftsdb_port;
  my $dbc = DBI->connect($dsn,$giftsdb_user,$giftsdb_pass) or die "Unable to connect to GIFTS DB with $dsn";
  
  # PostgreSQL schemas are not supported by DBI but I can set the search_path variable at this point
  # because we are going to use one db schema only
  $dbc->do("SET search_path TO ".$giftsdb_schema.", public");
  return $dbc;
}

sub get_info_from_perfect_match_alignment_run {
  my ($dbc,$perfect_match_alignment_run_id) = @_;
  # retrieve values used from the previous alignment run
  #        'uniprot_sp_file=s' => \$uniprot_sp_file,
  #        'uniprot_sp_isoform_file=s' => \$uniprot_sp_isoform_file,
  #        'uniprot_tr_dir=s' => \$uniprot_tr_dir,
  # species
  # mapping history run
  # ensembl release
  my $sql_gifts_alignment_run = "SELECT * FROM alignment_run WHERE alignment_run_id=".$perfect_match_alignment_run_id;
  my $sth_gifts_pmar = $dbc->prepare($sql_gifts_alignment_run);
  $sth_gifts_pmar->execute() or die "Could not fetch the previous alignment run:\n".$dbc->errstr;

  my @alignrow = $sth_gifts_pmar->fetchrow_array;
  $sth_gifts_pmar->finish;

  my $release_mapping_history_id = $alignrow[7];
  my $release = $alignrow[8];
  my $uniprot_sp_file = $alignrow[9];
  my $uniprot_sp_isoform_file = $alignrow[10];
  my $uniprot_tr_dir = $alignrow[11];

  # Set the species up
  my $sql_gifts_release_mapping_history = "SELECT ensembl_species_history_id FROM release_mapping_history WHERE release_mapping_history_id=".$release_mapping_history_id;
  my $sth_gifts_release_mapping_history = $dbc->prepare($sql_gifts_release_mapping_history);
  $sth_gifts_release_mapping_history->execute() or die "Could not fetch the mapping history with ID :".$release_mapping_history_id."\n".$dbc->errstr;
  my @mhrow = $sth_gifts_release_mapping_history->fetchrow_array;
  my $ensembl_species_history_id = $mhrow[0];
  my $sql_gifts_species = "SELECT species FROM ensembl_species_history  WHERE ensembl_species_history_id=".$ensembl_species_history_id;
  my $sth_gifts_species = $dbc->prepare($sql_gifts_species);
  $sth_gifts_species->execute() or die "Could not fetch the ensembl species history with ID :".$ensembl_species_history_id."\n".$dbc->errstr;
  my @srow = $sth_gifts_species->fetchrow_array;
  my $species = $srow[0];

  $sth_gifts_release_mapping_history->finish;
  $sth_gifts_species->finish;

  #
  # Open the Uniprot archives that were used previously
  #
  my @uniprot_archives = ($uniprot_sp_file);
  push(@uniprot_archives,$uniprot_sp_isoform_file);

  # contains all the chunks from the trembl file
  if ($uniprot_tr_dir) {
    opendir(TDIR,$uniprot_tr_dir) or die "Couldnt find trembl files";
    while (my $tfile = readdir(TDIR)) {
      next unless ($tfile =~ m/\.fa_chunk/);
      next unless ($tfile =~ m/\.gz$/);
      push(@uniprot_archives,$uniprot_tr_dir."/".$tfile);
    }
    closedir(TDIR);
  }

  # open uniprot fasta files
  my @uniprot_archive_parsers;
  foreach my $u (@uniprot_archives) {
    print "Checking/Generating index for Uniprot Sequence source file $u\n";
    my $ua = Bio::DB::HTS::Faidx->new($u);
    push @uniprot_archive_parsers,$ua;
  }
  print "Opened uniprot archives\n";
  return($species,$release,$release_mapping_history_id,@uniprot_archive_parsers);
}

sub fetch_latest_uniprot_enst_perfect_matches {
# It returns a reference to a hash containing Uniprot protein accessions as keys
# and the corresponding Ensembl transcript stable IDs as an array of values for a given
# species name (ie 'Homo sapiens') and assembly accession (ie 'GRCh38').

  my ($dbc,$species,$assembly) = @_;

  my $sql_select = "SELECT uniprot_acc,enst_id
                    FROM ensembl_species_history esh,
                         mapping_history mh,
                         mapping m,
                         release_mapping_history rmh,
                         uniprot_entry ue,
                         ensembl_transcript et,
                         alignment_run ar,
                         alignment a
                    WHERE esh.ensembl_species_history_id=rmh.ensembl_species_history_id
                    AND m.mapping_id=mh.mapping_id
                    AND rmh.release_mapping_history_id=mh.release_mapping_history_id
                    AND ue.uniprot_id=m.uniprot_id
                    AND et.transcript_id=m.transcript_id
                    AND ar.alignment_run_id=a.alignment_run_id
                    AND rmh.release_mapping_history_id=ar.release_mapping_history_id
                    AND rmh.status='MAPPING_COMPLETED'
                    AND esh.species=?
                    AND assembly_accession=?
                    AND m.mapping_id=a.mapping_id
                    AND a.score1=1
                    AND esh.ensembl_release=92";

  my $sth = $dbc->prepare($sql_select);
  $sth->bind_param(1,$species,SQL_CHAR);
  $sth->bind_param(2,$assembly,SQL_CHAR);
  #$sth->bind_param(3,$species,SQL_CHAR);
  #$sth->bind_param(4,$assembly,SQL_CHAR);
  #$sth->bind_param(5,$species,SQL_CHAR);
  #$sth->bind_param(6,$assembly,SQL_CHAR);
  #$sth->bind_param(7,$species,SQL_CHAR);
  #$sth->bind_param(8,$assembly,SQL_CHAR);
  $sth->execute();

  my $uniprot_acc;
  my $enst_id;
  my %perfect_matches;

  while (($uniprot_acc,$enst_id) = $sth->fetchrow_array()) {
    push(@{$perfect_matches{$uniprot_acc}},$enst_id);
  }

  $sth->finish();

  return \%perfect_matches;
}

1;
