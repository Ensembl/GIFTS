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

ensembl_import_species_data.pl -

=head1 DESCRIPTION

  This script imports Ensembl gene, transcript and metadata data into the GIFTS database tables
  'ensembl_gene', 'ensembl_transcript' and 'ensembl_species_history'. It also populates the
  'gene_history' and 'transcript_history' tables accordingly.

=cut

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Mapper;
use Bio::EnsEMBL::GIFTS::DB qw(rest_post rest_get);
use URI::Escape;

#options that the user can set
my $species = 'homo_sapiens';
my $user;
my $release;

my $registry_vert;
my $registry_nonvert;

my $rest_server;
my $auth_token;

GetOptions(
        'user=s' => \$user,
        'species=s' => \$species,
        'release=s' => \$release,
        'registry_vert=s' => \$registry_vert,
        'registry_nonvert=s' => \$registry_nonvert,
        'rest_server=s' => \$rest_server,
        'auth_token=s' => \$auth_token,
);

if (!$registry_vert) {
  die("Please specify a vertebrate registry file with --registry_vert");
}

if (!$registry_nonvert) {
  die("Please specify a non-vertebrate registry file with --registry_nonvert");
}

if (!$release) {
  die "Please specify a release with --release\n";
}

if (!$rest_server) {
  die "Please specify a rest server URL with --rest_server\n";
}

if (!$auth_token) {
  die "Please specify an authorization token for the rest server with --auth_token\n";
}

print "Fetching $species,e$release\n";
print "Run by $user\n";

# Connect to the Ensembl database
my $registry = "Bio::EnsEMBL::Registry";
$registry->load_registry_from_url($registry_vert);
$registry->load_registry_from_url($registry_nonvert);

# Get the slice_adaptor
my $slice_adaptor = $registry->get_adaptor($species,'core','Slice');
my $slices = $slice_adaptor->fetch_all('toplevel',undef,1);
my $meta_adaptor = $registry->get_adaptor($species,'core','MetaContainer');
my $ca = $registry->get_adaptor($species,'core','CoordSystem');

my $species_name = $meta_adaptor->get_scientific_name();
my $escaped_species_name = uri_escape($species_name); # to replace space with %20

my $tax_id = $meta_adaptor->get_taxonomy_id();
my $assembly_name = $ca->fetch_all()->[0]->version();

my $gene_count = 0;
my $transcript_count = 0;

my $chromosome = "";
my $region_accession;

my @json_genes = ();

while (my $slice = shift(@$slices)) {

  # Fetch additional meta data on the slice
  $region_accession = $slice->seq_region_name();
  if ($slice->is_chromosome()) {
    $chromosome = $slice->seq_region_name();
    if ($slice->get_all_synonyms('INSDC')->[0]) {
      $region_accession = $slice->get_all_synonyms('INSDC')->[0]->name();
    }
  }

  my $genes = $slice->get_all_Genes();

  while (my $gene = shift(@$genes)) {

    my ($ensg,$ensg_version) = split(/\./,$gene->stable_id_version());
    
    # fetch the "select" transcript for this gene
    my $select_transcript = "";
    if ($release <= 95) {
      $select_transcript = $gene->canonical_transcript()->stable_id();
    }

    my $gene_name = "";
    my $gene_symbol = "";
    my $gene_accession = "";

    if ($gene->description()) {
      if ($gene->description() =~ /(.+)\[.+Acc:(.+)\]/) {
        $gene_name = $1;
        $gene_accession = $2;
      }
    }
    
    if ($gene->display_xref()) {
      $gene_symbol = $gene->display_xref()->display_id();
    }

    my $json_gene = {
                       ensg_id => $ensg,
                       ensg_version => $ensg_version,
                       gene_name => $gene_name,
                       gene_symbol => $gene_symbol,
                       gene_accession => $gene_accession,
                       chromosome => $chromosome,
                       region_accession => $region_accession,
                       deleted => 0,
                       seq_region_start => $gene->seq_region_start(),
                       seq_region_end => $gene->seq_region_end(),
                       seq_region_strand => $gene->seq_region_strand(),
                       biotype => $gene->biotype(),
                       source => $gene->source(),
                       #transcripts => ()
    };

    foreach my $key (keys %$json_gene) {
      if ($key eq 'deleted') {
        next;     
      }
      if (!($json_gene->{$key})) {
        delete($json_gene->{$key});
      }
    }

    foreach my $transcript (@{$gene->get_all_Transcripts}) {
  
      my ($enst,$enst_version) = split(/\./,$transcript->stable_id_version());

      my $ensp = "";
      my $ensp_version = "";
      my $ensp_len = 0;
      if ($transcript->translation()) {
        ($ensp,$ensp_version) = split(/\./,$transcript->translation()->stable_id_version());
        $ensp_len = $transcript->translation()->length();
      }
      
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
      if ($release >= 96) {
        $is_select_transcript = 0;
        foreach my $transcript_attrib (@{$transcript->get_all_Attributes('remark')}) {
          if ($transcript_attrib->value() eq "MANE_select") {
            $is_select_transcript = 1;
          }
        }
      } else {
       if ($select_transcript eq $enst) {
        $is_select_transcript = 1;
        }
      }

      my $json_transcript = {
                               enst_id => $enst,
                               enst_version => $enst_version,
                               ensp_id => $ensp,
                               ensp_version => $ensp_version,
                               ensp_len => $ensp_len,
                               ccds_id => $ccds,
                               uniparc_accession => $uniparc,
                               biotype => $transcript->biotype(),
                               source => $transcript->source(),
                               deleted => 0,
                               seq_region_start => $transcript->seq_region_start(),
                               seq_region_end => $transcript->seq_region_end(),
                               supporting_evidence => $supporting_evidence,
                               userstamp => $user,
                               select => $is_select_transcript
      };
      
      foreach my $key (keys %$json_transcript) {
        if ($key eq 'deleted') {
          next;     
        }
        if (!($json_transcript->{$key})) {
          delete($json_transcript->{$key});
        }
      }
      push(@{$json_gene->{'transcripts'}},$json_transcript);
      $transcript_count++;
    }
    push(@json_genes,$json_gene);
    $gene_count++;
  }
}

if (scalar(@json_genes)) {
  my $initial_load_response = rest_post($auth_token,$rest_server."/ensembl/load/".$escaped_species_name."/".$assembly_name."/".$tax_id."/".$release."/",\@json_genes);
  my $task_id = $initial_load_response->{'task_id'};
  my $load_response = $initial_load_response;
  while ($load_response->{'status'} ne 'SUCCESS') {

    if ($load_response->{'status'} eq 'FAILURE') {
      die("REST API server returned FAILURE while loading the Ensembl genes.");
    }

    $load_response = rest_get($rest_server."/job/".$task_id);
    sleep(60);
  }
}

# display counts
print "Genes:".$gene_count."\n";
print "Transcripts:".$transcript_count."\n";
print "Finished\n";

