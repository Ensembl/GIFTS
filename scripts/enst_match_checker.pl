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

enst_match_checker.pl -

=head1 DESCRIPTION

  This script takes a list of ensembl transcripts stable IDs and returns the status of Uniprot proteins associated with them.

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
use Bio::EnsEMBL::GIFTS::DB qw(get_gifts_dbc);

my $ensembl_release;
my $uniprot_release;
my $tidfile;

my $giftsdb_name;
my $giftsdb_schema;
my $giftsdb_host;
my $giftsdb_user;
my $giftsdb_pass;
my $giftsdb_port;

GetOptions(
        'tidfile=s' => \$tidfile,
        'e=i' => \$ensembl_release,
        'u=s' => \$uniprot_release,
        'giftsdb_host=s' => \$giftsdb_host,
        'giftsdb_user=s' => \$giftsdb_user,
        'giftsdb_pass=s' => \$giftsdb_pass,
        'giftsdb_name=s' => \$giftsdb_name,
        'giftsdb_schema=s' => \$giftsdb_schema,
        'giftsdb_port=s' => \$giftsdb_port,
   );

if (!$giftsdb_name or !$giftsdb_schema or !$giftsdb_host or !$giftsdb_user or !$giftsdb_pass or !$giftsdb_port) {
  die("Please specify the GIFTS database details with --giftsdb_host, --giftsdb_user, --giftsdb_pass, --giftsdb_name, --giftsdb_schema and --giftsdb_port.");
}

if (!$tidfile) {
  die("Please specify a transcript ID file (one per line) with --tidfile flag");
}

if (!$ensembl_release) {
  die("Please specify an EnsEMBL release with -e flag");
}

if (!$uniprot_release) {
  die("Please specify a UniProt release with -u flag");
}

if (! -e $tidfile) {
  die("Specified transcript ID file $tidfile does not exist. Exiting.");
}

open(TIDFILE,"$tidfile ") or die "Could not open $tidfile.";

# Write a header
print "ENST ID ($ensembl_release),match type,uniprot_acc,uniprot_seq_version ($uniprot_release),uniprot_can_status\n";

my $dbc = get_gifts_dbc($giftsdb_name,$giftsdb_schema,$giftsdb_host,$giftsdb_user,$giftsdb_pass,$giftsdb_port);

while (my $enst_id_full = <TIDFILE>) {
  chomp $enst_id_full;
  my ($enst_id,$enst_version) = split(/\./,$enst_id_full);
  my $enst_version_int = $enst_version + 0; # a hack to solve printing funnies
  my $perfect_match_found = 0;

  # find transcript_id
  my $transcript_id;
  my $sql_trans = "SELECT transcript_id FROM ensembl_transcript WHERE enst_id=? AND enst_version=? AND ensembl_release=?";
  my $sth = $dbc->prepare($sql_trans);
  $sth->bind_param(1,$enst_id,SQL_CHAR);
  $sth->bind_param(2,$enst_version,SQL_INTEGER);
  $sth->bind_param(3,$ensembl_release,SQL_INTEGER);
  $sth->execute() or die "Error fetching transcript ID:\n".$dbc->errstr;
  $sth->bind_col(1,\$transcript_id);
  $sth->fetch();
  $sth->finish();

  # find mapping id if it exists
  my $mapping_id;
  my $uniprot_id;
  my $uniprot_acc = "";
  my $uniprot_seq_version = 0;
  my $uniprot_ci = 0;
  my $sql_map = "SELECT mapping_id,uniprot_id FROM ensembl_uniprot WHERE transcript_id=?";
  $sth = $dbc->prepare($sql_map);
  $sth->bind_param(1,$transcript_id,SQL_INTEGER);
  $sth->execute() or die "Error fetching mapping ID:\n".$dbc->errstr;
  $sth->bind_col(1,\$mapping_id);
  $sth->bind_col(2,\$uniprot_id);

  while($sth->fetch) {
    # what UniProt accession goes with this
    my $sql_uniprot = "SELECT uniprot_acc,sequence_version,is_canonical FROM uniprot WHERE uniprot_id=? AND release_version=?";
    my $sth_uniprot = $dbc->prepare($sql_uniprot);
    $sth_uniprot->bind_param(1,$uniprot_id,SQL_INTEGER);
    $sth_uniprot->bind_param(2,$uniprot_release,SQL_CHAR);
    $sth_uniprot->execute();
    $sth_uniprot->bind_col(1,\$uniprot_acc);
    $sth_uniprot->bind_col(2,\$uniprot_seq_version);
    $sth_uniprot->bind_col(3,\$uniprot_ci);

    while($sth_uniprot->fetch) {
      # is this map a perfect match?
      my $alignment_run_id = 0;
      my $alignment_id = 0;
      my $sql_align = "SELECT alignment_id,alignment_run_id FROM alignment WHERE mapping_id=? AND score1=1";
      my $sth_align = $dbc->prepare($sql_align);
      $sth_align->bind_param(1,$mapping_id,SQL_INTEGER);
      $sth_align->execute() or die "Error fetching alignment result:\n".$dbc->errstr;
      $sth_align->bind_col(1,\$alignment_id);
      $sth_align->bind_col(2,\$alignment_run_id);

      while($sth_align->fetch) {
        # check the alignment run is a perfect match
        my $p;
        my $sql_align_type =
          "SELECT pipeline_name FROM alignment_run WHERE alignment_run_id=? AND score1_type='perfect_match'";
        my $sth_align_type = $dbc->prepare($sql_align_type);
        $sth_align_type->bind_param(1,$alignment_run_id,SQL_INTEGER);
        $sth_align_type->execute() or die "Error fetching alignment result:\n".$dbc->errstr;
        $sth_align_type->bind_col(1,\$p);

        while($sth_align_type->fetch) {
          $perfect_match_found = 1;
          goto PERFECT_MATCH_FOUND;
        }
        $sth_align_type->finish();
      }
      $sth_align->finish();
    }
    $sth_uniprot->finish();
  }
PERFECT_MATCH_FOUND:
  $sth->finish();

  # display a result
  my $perfect_match_type = "UNMAPPED";
  if ($uniprot_id) {
    $perfect_match_type = "MAPPED";
    if ($perfect_match_found) {
      $perfect_match_type = "MATCHED";
    }
  }

  print "$enst_id.$enst_version_int,$perfect_match_type,$uniprot_acc,$uniprot_seq_version,";
  if ($perfect_match_type eq "UNMAPPED") {
    print "NO_PROTEIN_MAP\n";
  }
  elsif ($uniprot_ci) {
    print "CANONICAL\n";
  }
  else {
    print "ISOFORM\n";
  }
}

$dbc->disconnect;
