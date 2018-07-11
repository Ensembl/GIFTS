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

test_fetchcigarmdz.pl -

=head1 DESCRIPTION

  This script is just a quick test for 'fetch_cigarmdz'.

=cut

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Mapper;
use Data::Dumper;
use DBI qw(:sql_types);
use LWP::UserAgent;
use Bio::DB::HTS::Faidx ;
use Bio::EnsEMBL::Analysis ;
use Bio::EnsEMBL::Analysis::Runnable;
use Bio::EnsEMBL::GIFTS::Runnable::BlastP ;
use Bio::EnsEMBL::Analysis::Tools::BPliteWrapper;
use Bio::EnsEMBL::GIFTS::DB qw(get_gifts_dbc fetch_cigarmdz) ;

my $giftsdb_name;
my $giftsdb_schema;
my $giftsdb_host;
my $giftsdb_user;
my $giftsdb_pass;
my $giftsdb_port;

GetOptions(
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

my $dbc = get_gifts_dbc($giftsdb_name,$giftsdb_schema,$giftsdb_host,$giftsdb_user,$giftsdb_pass,$giftsdb_port);
my $uniprot_acc = "P28332";
my $uniprot_seq_version = "2";
my $ensp_id = "ENSP00000237653Z";

my ($existing_cigar,$existing_mdz) = fetch_cigarmdz($dbc,$uniprot_acc,$uniprot_seq_version,$ensp_id);

if ($existing_cigar) {
  print("$existing_cigar $existing_mdz\n");
}
else {
  print("Match not found\n");
}
$dbc->disconnect();
