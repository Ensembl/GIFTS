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

enst_version_setter.pl -

=head1 DESCRIPTION

  This is a one-off script to set the unset versions for transcripts associated with them.

=cut

use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
use DBI qw(:sql_types);
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::Analysis::Runnable;
use Bio::EnsEMBL::GIFTS::DB qw(get_gifts_dbc);

my $release = 87;

my $species;
my $prefix;
my $select_suffix;

my $giftsdb_name;
my $giftsdb_host;
my $giftsdb_user;
my $giftsdb_pass;
my $giftsdb_port;

my $registry_host;
my $registry_user;
my $registry_pass;
my $registry_port;

GetOptions(
        'species=s' => \$species,
        'prefix=s' => \$prefix,
        'ss=s' => \$select_suffix,
        'giftsdb_host=s' => \$giftsdb_host,
        'giftsdb_user=s' => \$giftsdb_user,
        'giftsdb_pass=s' => \$giftsdb_pass,
        'giftsdb_name=s' => \$giftsdb_name,
        'giftsdb_port=s' => \$giftsdb_port,
        'registry_host=s' => \$registry_host,
        'registry_user=s' => \$registry_user,
        'registry_pass=s' => \$registry_pass,
        'registry_port=s' => \$registry_port,
   );

if (!$giftsdb_name or !$giftsdb_host or !$giftsdb_user or !$giftsdb_pass or !$giftsdb_port) {
  die("Please specify the GIFTS database details with --giftsdb_host, --giftsdb_user, --giftsdb_pass, --giftsdb_name and --giftsdb_port.");
}

if (!$registry_host or !$registry_user or !$registry_pass or !$registry_port) {
  die("Please specify the registry host details with --registry_host, --registry_user, --registry_pass and --registry_port.");
}

if (!$species || !$prefix) {
  die ("Specify parameters\nspecies given as$species\nprefix given as $prefix\n");
}

# Create the EnsEMBL registry
my $registry = "Bio::EnsEMBL::Registry";
$registry->load_registry_from_db(
    -host => $registry_host,
    -user => $registry_user,
    -port => $registry_port,
    -pass => $registry_pass,
    -db_version => ''.$release
);

# setup the gifts connection
my $gifts_dbc = get_gifts_dbc($giftsdb_name,$giftsdb_host,$giftsdb_user,$giftsdb_pass,$giftsdb_port);

my $ens_db_adaptor = Bio::EnsEMBL::Registry->get_DBAdaptor($species,"core");
my $ens_transcript_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species,"core","transcript");


# Get the transcripts to be updated
my $sql_trans =
  "SELECT enst_id FROM ensembl_transcript WHERE ensembl_release=87 AND enst_id LIKE '".$prefix."%' AND enst_version IS NULL";
if ($select_suffix) {
  $sql_trans = $sql_trans." ".$select_suffix;
}

print $sql_trans;
my $sth_trans = $gifts_dbc->prepare($sql_trans);
my $enst_id;
$sth_trans->execute() or die "Could not execute $sql_trans";
$sth_trans->bind_col(1,\$enst_id);

my $sql_update = "UPDATE ensembl_transcript SET enst_version=? WHERE enst_id=?";
my $sth_update = $gifts_dbc->prepare($sql_update);

while ($sth_trans->fetch) {
  my $transcript = $ens_transcript_adaptor->fetch_by_stable_id($enst_id);

  if ($transcript) {
    my ($enst_id,$version) = split(/\./,$transcript->stable_id_version);
    $sth_update->bind_param(1,$version);
    $sth_update->bind_param(2,$enst_id);
    $sth_update->execute() or die "Could not update $enst_id with $version:\n".$gifts_dbc->errstr;
  } else {
    print "Warning: No transcript found in Ensembl for $enst_id\n";
  }
}
$sth_update->finish;
$sth_trans->finish;

