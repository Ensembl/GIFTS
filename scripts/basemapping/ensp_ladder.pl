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

ensp_ladder.pl -

=head1 DESCRIPTION

  This script prints the location, transcript and genome for a given ENSP identifier.

=cut

use strict;
use warnings;


use Getopt::Long;
use Pod::Usage;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Mapper;

use Bio::EnsEMBL::TranscriptMapper qw(pep2genomic);
use Bio::EnsEMBL::GIFTS::BaseMapping qw(print_ensp2genomic_alignment);

my $ensp_id;
my $species = "homo_sapiens";
my $ens_release;

my $registry_host;
my $registry_user;
my $registry_pass;
my $registry_port;

GetOptions(
        'ensp_id=s' => \$ensp_id,
        'ens_release=s' => \$ens_release,
        'species=s' => \$species,
        'registry_host=s' => \$registry_host,
        'registry_user=s' => \$registry_user,
        'registry_pass=s' => \$registry_pass,
        'registry_port=s' => \$registry_port,
   );

if (!$registry_host or !$registry_user or !$registry_pass or !$registry_port) {
  die("Please specify the registry host details with --registry_host, --registry_user, --registry_pass and --registry_port.");
}

if (!$ensp_id) {
  die("Please specify the Ensembl Translation ID to process with --ensp_id");
}

# get the ENSP sequence from the ensembl database
my $registry = "Bio::EnsEMBL::Registry";
$registry->load_registry_from_db(
    -host => $registry_host,
    -user => $registry_user,
    -port => $registry_port,
    -pass => $registry_pass,
    -db_version => $ens_release
);

print_ensp2genomic_alignment($species,$ensp_id);
