=head1 LICENSE

# Copyright [2017-2022] EMBL-European Bioinformatics Institute
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

cigars_from_ids.pl -

=head1 DESCRIPTION

  This script makes the cigars from Ensembl and UniProt identifiers.

=cut

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use DBI qw(:sql_types);
use LWP::UserAgent;
use Bio::DB::HTS::Faidx;

use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::Analysis::Runnable;
use Bio::EnsEMBL::GIFTS::DB qw(store_alignment);
use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Mapper;

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

my $species; # for example: homo_sapiens
my $release; # for example: 87

my $registry_host;
my $registry_user;
my $registry_pass;
my $registry_port;

GetOptions(
        'output_dir=s' => \$output_dir,
        'output_prefix=s' => \$output_prefix,
        'uniprot_acc=s' => \$uniprot_acc,
        'ensp_id=s' => \$ensp_id,
        'species=s' => \$species,
        'release=s' => \$release,
        'uniprot_sp_file=s' => \$uniprot_sp_file,
        'uniprot_isoform_file=s' => \$uniprot_isoform_file,
        'registry_host=s' => \$registry_host,
        'registry_user=s' => \$registry_user,
        'registry_pass=s' => \$registry_pass,
        'registry_port=s' => \$registry_port,
   );

if (!$registry_host or !$registry_user or !$registry_pass or !$registry_port) {
  die("Please specify the registry host details with --registry_host, --registry_user, --registry_pass and --registry_port.");
}

if (!$species) {
  die("Please specify the species to process with --species");
}

if (!$release) {
  die("Please specify the Ensembl release number to process with --release");
}

if (!$uniprot_acc) {
  die("Please specify the uniprot_acc to process with --uniprot_acc");
}

if (!$ensp_id) {
  die("Please specify the ENSP Stable Identifier to process with --ensp_id");
}

unless(-d $output_dir) {
  mkdir $output_dir;
}

# get the uniprot sequence from the FASTA file (downloaded and block gzipped)
my $uniprot_sp = Bio::DB::HTS::Faidx->new($uniprot_sp_file);
my $uniprot_iso = Bio::DB::HTS::Faidx->new($uniprot_isoform_file);
my $uniprot_seq;

if ($uniprot_sp->has_sequence($uniprot_acc)) {
  $uniprot_seq = $uniprot_sp->get_sequence_no_length($uniprot_acc);
}
elsif ($uniprot_iso->has_sequence($uniprot_acc)) {
  $uniprot_seq = $uniprot_iso->get_sequence_no_length($uniprot_acc);
}
else {
  die "Sequence not found for Uniprot Accession ".$uniprot_acc;
}

my $muscle_source_filename =  "$output_dir/$uniprot_acc.for_muscle.fasta";
my $muscle_output_filename =  "$output_dir/$uniprot_acc.from_muscle.fasta";
my $muscle_source_fh;
open($muscle_source_fh,'>',"$muscle_source_filename") || die "Could not open muscle source file $muscle_source_filename for writing";
print $muscle_source_fh ">$uniprot_acc\n$uniprot_seq\n";


# get the ENSP sequence from the ensembl database
my $registry = "Bio::EnsEMBL::Registry";
$registry->load_registry_from_db(
    -host => $registry_host,
    -user => $registry_user,
    -port => $registry_port,
    -pass => $registry_pass,
    -db_version => $release
);
my $ens_db_adaptor = Bio::EnsEMBL::Registry->get_DBAdaptor($species,"core");
my $transcript_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species,"core","transcript");
my $translation_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species,"core","translation");
my $translation = $translation_adaptor->fetch_by_stable_id($ensp_id);
unless($translation) {
  die "ENSP ID not found for $ensp_id\nUsing Ensembl DB $species $release\n";
}
my $ensp_seq = $translation->seq();
print $muscle_source_fh ">$ensp_id\n$ensp_seq\n";
close ($muscle_source_fh);

# run the muscle alignment
system("muscle -in $muscle_source_filename -out $muscle_output_filename -quiet");
my $compared =  Bio::SeqIO->new(-file => $muscle_output_filename,-format => "fasta");
my $seqobj_compu = $compared->next_seq;
my $seqobj_compe = $compared->next_seq;
my $compu = $seqobj_compu->seq;
my $compe = $seqobj_compe->seq;

# now determine the location
my $transcript = $translation->transcript();

# print out the base by base with positioning
my $location_output_filename =  "$output_dir/$uniprot_acc.base_maps";
my $location_output_fh;
open($location_output_fh,'>',"$location_output_filename") ||
  die "Could not open $location_output_filename for writing";

print $location_output_fh "$uniprot_acc,$ensp_id,".$transcript->seq_region_name.$transcript->seq_region_strand.",genomic codon\n";

for (my $i=0; $i<length($compu); $i++) {
  my $c1 = substr($compu,$i,1);
  my $c2 = substr($compe,$i,1);
  my $location = 0;
  print $location_output_fh "$c1,$c2,".$location."\n";
}
$compared->close();
close($location_output_fh);
