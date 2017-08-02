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

eu_alignment_blast_cigar.pl -

=head1 DESCRIPTION

  This script counts the number of Ensembl genes with at least one perfectly matching Uniprot protein.

=cut

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use DBI qw(:sql_types);
use LWP::UserAgent;
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::Analysis::Runnable;
use Bio::EnsEMBL::GIFTS::DB qw(fetch_uniprot_accession store_alignment fetch_transcript_ids get_gifts_dbc);

#
# Set options
#

my $output_dir = ".";
my $output_prefix = "gene_matched_";

my $giftsdb_name;
my $giftsdb_host;
my $giftsdb_user;
my $giftsdb_pass;
my $giftsdb_port;

my $ensembl_species_history_id;
my $alignment_run_id;
my $idcoverage_run_id;

GetOptions(
        'output_dir=s' => \$output_dir,
        'output_prefix=s' => \$output_prefix,
        'giftsdb_host=s' => \$giftsdb_host,
        'giftsdb_user=s' => \$giftsdb_user,
        'giftsdb_pass=s' => \$giftsdb_pass,
        'giftsdb_name=s' => \$giftsdb_name,
        'giftsdb_port=s' => \$giftsdb_port,
        'e=i' => \$ensembl_species_history_id,
        'a=i' => \$alignment_run_id,
        'i=i' => \$idcoverage_run_id,
   );

if (!$giftsdb_name or !$giftsdb_host or !$giftsdb_user or !$giftsdb_pass or !$giftsdb_port) {
  die("Please specify the GIFTS database details with --giftsdb_host, --giftsdb_user, --giftsdb_pass, --giftsdb_name and --giftsdb_port.");
}

if (!$ensembl_species_history_id) {
  die("Please specify the ensembl_species_history_id from the GIFTS database with -e.");
}

if (!$alignment_run_id) {
  die("Please specify the alignment_run_id from the GIFTS database with -a.");
}

# GIFTS database connection
my $dbc = get_gifts_dbc($giftsdb_name,$giftsdb_host,$giftsdb_user,$giftsdb_pass,$giftsdb_port);

# Retrieve the load details for the ensembl_species_history_id and ensure the mapping has occured
my $sql_gifts_history = "SELECT species,assembly_accession,ensembl_tax_id,ensembl_release FROM ensembl_species_history WHERE ensembl_species_history_id=".$ensembl_species_history_id;
my $sth_gifts_history = $dbc->prepare($sql_gifts_history);
$sth_gifts_history->execute() or die "Could not fetch a history for $ensembl_species_history_id:\n".$dbc->errstr;
my @history_row = $sth_gifts_history->fetchrow_array;
if (!@history_row) {
  print "ERROR: Could not fetch a history for $ensembl_species_history_id:\n";
  exit;
}

my $species = $history_row[0];
my $assembly_acc = $history_row[1];
my $ens_tax_id = $history_row[2];
my $ens_release = $history_row[3];
$sth_gifts_history->finish();
print "Counting genes with matching proteins for $species - $ens_tax_id for $assembly_acc in e$ens_release\n";

# For the  matching genes,can we find a perfectly matching uniprot for one of its transcripts
my $sql_gifts_genes = "SELECT gene_id,ensg_id FROM ensembl_gene WHERE ensembl_tax_id=$ens_tax_id AND ensembl_release=$ens_release AND assembly_accession='$assembly_acc' AND biotype='protein_coding'";
my $sth_gifts_genes = $dbc->prepare($sql_gifts_genes);
$sth_gifts_genes->execute() or die "Could not fetch gene list:\n".$dbc->errstr;
my $gene_count=0;
my $gene_with_match_count = 0;
my $transcript_count=0;
my $transcripts_with_match_count = 0;
my $gene90_count=0;

while (my @g_row = $sth_gifts_genes->fetchrow_array) {
  my $gene_id_gifts = $g_row[0];
  my $gene_id_ens = $g_row[1];
  $gene_count++;

  my $sql_gifts_transcripts = "SELECT transcript_id,enst_id FROM ensembl_transcript WHERE gene_id=$gene_id_gifts AND ensembl_release=$ens_release";
  my $sth_gifts_transcripts = $dbc->prepare($sql_gifts_transcripts);
  $sth_gifts_transcripts->execute() or die "Could not fetch transcript list:\n".$dbc->errstr;
  my $perfect_match_found = 0;
  while (my @t_row = $sth_gifts_transcripts->fetchrow_array) {
    $transcript_count++;
    my $transcript_id_gifts = $t_row[0];
    my $transcript_id_ens = $t_row[1];

    # Find the perfect match alignment run for this species
    my $sql_gifts_match = "SELECT uniprot_id FROM alignment WHERE alignment_run_id=$alignment_run_id AND transcript_id=$transcript_id_gifts AND score1=1";
    my $sth_gifts_match = $dbc->prepare($sql_gifts_match);
    $sth_gifts_match->execute() or die "Could not fetch match list:\n".$dbc->errstr;
    my @a_row = $sth_gifts_match->fetchrow_array;
    if (@a_row) {
      my $uid = $a_row[0];
      if (!$perfect_match_found) {
        $gene_with_match_count++;
        $perfect_match_found = 1;
      }
      $transcripts_with_match_count++;
    }
  }

  # is more coverage count stuff needed
  if ($idcoverage_run_id && $perfect_match_found==0) {
    $sth_gifts_transcripts = $dbc->prepare($sql_gifts_transcripts);
    $sth_gifts_transcripts->execute() or die "Could not fetch transcript list:\n".$dbc->errstr;
    while(my @t_row = $sth_gifts_transcripts->fetchrow_array) {
      my $transcript_id_gifts = $t_row[0];
      my $transcript_id_ens = $t_row[1];
      my $sql_gifts_match =
        "SELECT uniprot_id,score1,score2 FROM alignment WHERE alignment_run_id=$idcoverage_run_id AND transcript_id=$transcript_id_gifts";
      my $sth_gifts_match = $dbc->prepare($sql_gifts_match);
      $sth_gifts_match->execute() or die "Could not fetch idcoverage list:\n".$dbc->errstr;
      my @a_row = $sth_gifts_match->fetchrow_array;
      my $good_match90_found= 0;
      if (@a_row) {
        my $uniprot_id = $a_row[0];
        my $id = $a_row[1];
        my $coverage = $a_row[2];
        if (!$good_match90_found && $id>90 && $coverage>0.9) {
          $gene90_count++;
          $good_match90_found = 1;
        }
      }
    }
  }
  $sth_gifts_transcripts->finish();
}

$sth_gifts_genes->finish();
$dbc->disconnect;

print "NUM_GENES=$gene_count\n";
print "NUM_PERFECTLY_MATCHED_GENES=$gene_with_match_count\n";
print "NUM_90PERCENT_MATCHED_GENES=$gene90_count\n";

print "NUM_TRANSCRIPTS=$transcript_count\n";
print "NUM_PERFECTLY_MATCHED_TRANSCRIPTS=$transcripts_with_match_count\n";
