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

eu_ladder.pl -

=head1 DESCRIPTION

  This script works in three ways:

  If just a uniprot accession (and release version) is specified it will run through and find all existing matches for that accession

  If a ENSP identifier is specified it will first look in the database for the ENSP-UniProt match, and if it cannot find a match, run a muscle alignment, and then display.

=cut

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use DBI qw(:sql_types);
use LWP::UserAgent;
use Bio::DB::HTS::Faidx;
use Data::Dump qw(dump);

use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::Analysis::Runnable;
use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Mapper;

use Bio::EnsEMBL::GIFTS::DB qw(store_alignment fetch_transcript_ids get_gifts_dbc);
use Bio::EnsEMBL::GIFTS::BaseMapping qw(retrieve_muscle_info_uniprot print_ladder);

#
# Set options
#

my $output_dir = ".";
my $output_prefix = "ul_";

my $uniprot_acc;
my $uniprot_acc_file;
my $ensp_id;
my $ensp_id_file;

my $uniprot_sp_file;
my $uniprot_isoform_file;

my $species = "homo_sapiens";
my $ens_release;
my $uniprot_release;

my $giftsdb_name;
my $giftsdb_schema;
my $giftsdb_host;
my $giftsdb_user;
my $giftsdb_pass;
my $giftsdb_port;

my $registry_host;
my $registry_user;
my $registry_pass;
my $registry_port;

GetOptions(
        'uniprot_acc=s' => \$uniprot_acc,
        'uniprot_release=s' => \$uniprot_release,
        'species=s' => \$species,
        'uniprot_sp_file=s' => \$uniprot_sp_file,
        'uniprot_isoform_file=s' => \$uniprot_isoform_file,
        'giftsdb_host=s' => \$giftsdb_host,
        'giftsdb_user=s' => \$giftsdb_user,
        'giftsdb_pass=s' => \$giftsdb_pass,
        'giftsdb_name=s' => \$giftsdb_name,
        'giftsdb_schema=s' => \$giftsdb_schema,
        'giftsdb_port=s' => \$giftsdb_port,
        'registry_host=s' => \$registry_host,
        'registry_user=s' => \$registry_user,
        'registry_pass=s' => \$registry_pass,
        'registry_port=s' => \$registry_port,
   );

if (!$registry_host or !$registry_user or !$registry_pass or !$registry_port) {
  die("Please specify the registry host details with --registry_host, --registry_user, --registry_pass and --registry_port.");
}

if (!$giftsdb_name or !$giftsdb_schema or !$giftsdb_host or !$giftsdb_user or !$giftsdb_pass or !$giftsdb_port) {
  die("Please specify the GIFTS database details with --giftsdb_host, --giftsdb_user, --giftsdb_pass, --giftsdb_name, --giftsdb_schema and --giftsdb_port.");
}

if (!$uniprot_acc) {
  die("Please specify the uniprot_acc to process with --uniprot_acc");
}

if (!$uniprot_release) {
  die("Please specify the uniprot release to process with --uniprot_release");
}

my $gifts_dbc = get_gifts_dbc($giftsdb_name,$giftsdb_schema,$giftsdb_host,$giftsdb_user,$giftsdb_pass,$giftsdb_port);

my @cigarplus_hash_refs = @{retrieve_muscle_info_uniprot($gifts_dbc,$uniprot_acc,$uniprot_release,0)};

#
# Now we fetch the sequences from the databases so we can display the ladders
#

# get the ENSP sequence from the ensembl database
my $registry = "Bio::EnsEMBL::Registry";
$registry->load_registry_from_db(
    -host => $registry_host,
    -user => $registry_user,
    -port => $registry_port,
    -pass => $registry_pass,
    -db_version => $ens_release
);
my $ens_db_adaptor = Bio::EnsEMBL::Registry->get_DBAdaptor($species,"core");
my $transcript_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species,"core","transcript");
my $translation_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species,"core","translation");

# get the UNIPROT sequence from Uniprot
my $ua = LWP::UserAgent->new;
my $response = $ua->get("http://www.uniprot.org/uniprot/".$uniprot_acc.".fasta");
my ($uniprot_header,$uniprot_seq);
if ($response->is_success) {
  print $response->content;
  ($uniprot_header,$uniprot_seq) = split("\n",$response->content);
}
else {
  die("UniProt sequence not found\n");
}

for my $h (@cigarplus_hash_refs) {
  print($$h{cigarplus}."\n");
  print($$h{mdz}."\n");

  # the href will either contain enst_ids for perfect matches or ensp_ids where a
  #    cigar line was explicitly made before
  my $ensp_seq;
  my $ensp_id;
  if ($$h{'ensp_id'}) {
    my $translation = $translation_adaptor->fetch_by_stable_id($$h{'ensp_id'});
    $ensp_id = $translation->stable_id_version();
    $ensp_seq = $translation->seq();
  }
  elsif ($$h{'enst_id'}) {
    my $transcript = $transcript_adaptor->fetch_by_stable_id($$h{'enst_id'});
    my $translation = $translation_adaptor->fetch_by_Transcript($transcript);
    $ensp_id = $translation->stable_id_version();
    $ensp_seq = $translation->seq();
  }

  if ($ensp_seq) {
    print("# $uniprot_acc vs $ensp_id\n");
    print_ladder($$h{cigarplus},$$h{mdz},$ensp_seq,$uniprot_seq);
  }
  else {
    print "ERROR: ENSP ID not found for $ensp_id - Using Ensembl DB $species $ens_release - SKIPPING\n";
  }
}

#
# Add location info to what's displayed
#
#print_uniprot_ensp_genomic_alignment();
