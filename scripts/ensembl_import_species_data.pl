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

ensembl_import_species_data.pl -

=head1 DESCRIPTION

  This script imports Ensembl gene, transcript and metadata data into the GIFTS database tables
  'ensembl_gene', 'ensembl_transcript' and 'ensembl_species_history'.

=cut

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Mapper;
use Data::Dumper;

#options that the user can set
my $species = 'homo_sapiens';
my $user;
my $release;

my $registry_host;
my $registry_user;
my $registry_pass;
my $registry_port;

GetOptions(
        'user=s' => \$user,
        'species=s' => \$species,
        'release=s' => \$release,
        'registry_host=s' => \$registry_host,
        'registry_user=s' => \$registry_user,
        'registry_pass=s' => \$registry_pass,
        'registry_port=s' => \$registry_port,
);

if (!$registry_host or !$registry_user or !$registry_port) {
  die("Please specify the registry host details with --registry_host, --registry_user and --registry_port.");
}

if (!$release) {
  die "Please specify a release with --release\n";
}

print "Fetching $species,e$release\n";
print "Run by $user\n";

# Connect to the Ensembl database
my $registry = "Bio::EnsEMBL::Registry";
$registry->load_registry_from_db(
    -host => $registry_host,
    -user => $registry_user,
    -port => $registry_port,
    -pass => $registry_pass,
    -db_version => ''.$release
);

# Get the slice_adaptor
my $slice_adaptor = $registry->get_adaptor($species,'core','Slice');
my $slices = $slice_adaptor->fetch_all('toplevel',undef,1);
my $meta_adaptor = $registry->get_adaptor($species,'core','MetaContainer');
my $ca = $registry->get_adaptor($species,'core','CoordSystem');
my $species_name = $meta_adaptor->get_scientific_name();
my $tax_id = $meta_adaptor->get_taxonomy_id();
my $assembly_name = $ca->fetch_all()->[0]->version();

my $gene_count = 0;
my $transcript_count = 0;

my $chromosome = "";
my $region_accession;
while (my $slice = shift(@$slices)) {
  # Fetch additional meta data on the slice
  $region_accession = $slice->seq_region_name();
  if ($slice->is_chromosome()) {
    $chromosome = $slice->seq_region_name();
    if ($slice->get_all_synonyms('INSDC')->[0]) {
      $region_accession = $slice->get_all_synonyms('INSDC')->[0]->name();
    }
  }
  
  my @json_genes = ();
  my $genes = $slice->get_all_Genes();
  while (my $gene = shift(@$genes)) {

    my ($ensg,$ensg_version) = split(/\./,$gene->stable_id_version());

    my $gene_name = "";
    if ($gene->display_xref()) {
      $gene_name = $gene->display_xref()->display_id();
    }

    # fetch the "select" transcript for this gene
    my $select_transcript = "";
    if (scalar(@{$gene->get_all_Attributes('select_transcript')}) > 0) {
      $select_transcript = @{$gene->get_all_Attributes('select_transcript')}[0]->value();
    }
    

    my $json_gene = {
                       ensg_id => $ensg,
                       ensg_version => $ensg_version,
                       gene_name => $gene_name,
                       chromosome => $chromosome,
                       region_accession => $region_accession,
                       deleted => 0,
                       seq_region_start => $gene->seq_region_start(),
                       seq_region_end => $gene->seq_region_end(),
                       seq_region_strand => $gene->seq_region_strand(),
                       biotype => $gene->biotype(),
                       transcripts => ()
    };

    foreach my $transcript (@{$gene->get_all_Transcripts}) {
     
      my ($enst,$enst_version) = split(/\./,$transcript->stable_id_version());
      
      my $ccds = "";
      if ($transcript->ccds()) {
        $ccds = $transcript->ccds()->display_id();
      }
      
      my $uniparc = "";
      if (scalar(@{$transcript->get_all_DBLinks('UniParc')}) > 0) {
        $uniparc = $transcript->get_all_DBLinks('UniParc')->[0]->display_id();
      }

      my $supporting_evidence;
      if (!$supporting_evidence) {
        $supporting_evidence = "";
      }

      # if this is the "select" transcript for this gene then "select_transcript" will be 1
      # otherwise it will be 0
      my $is_select_transcript = 0;
      if ($select_transcript eq $enst) {
        $is_select_transcript = 1;
      }

      my $json_transcript = {
                               enst_id => $enst,
                               enst_version => $enst_version,
                               ccds_id => $ccds,
                               uniparc_accession => $uniparc,
                               biotype => $transcript->biotype(),
                               deleted => 0,
                               seq_region_start => $transcript->seq_region_start(),
                               seq_region_end => $transcript->seq_region_end(),
                               supporting_evidence => $supporting_evidence,
                               userstamp => $user,
                               'select' => $is_select_transcript
      };
      push($json_transcript,@{$json_gene->{'transcripts'}});
      $transcript_count++;
    }
    push($json_gene,@json_genes);
    $gene_count++;
  }
  rest_post("/ensembl/load/".$species_name."/".$assembly_name."/".$tax_id."/".$release."/",\@json_genes);
}

# display counts
print "Genes:".$gene_count."\n.";
print "Transcripts:".$transcript_count."\n.";
print "Finished\n.";
