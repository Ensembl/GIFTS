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
use Data::Dumper;
use Bio::EnsEMBL::GIFTS::DB qw(get_gifts_dbc);

#options that the user can set
my $species = 'homo_sapiens';
my $user;
my $release;

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
        'user=s' => \$user,
        'species=s' => \$species,
        'release=s' => \$release,
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

if (!$giftsdb_name or !$giftsdb_schema or !$giftsdb_host or !$giftsdb_user or !$giftsdb_pass or !$giftsdb_port) {
  die("Please specify the GIFTS database details with --giftsdb_host, --giftsdb_user, --giftsdb_pass, --giftsdb_name, --giftsdb_schema and --giftsdb_port.");
}

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

# Connect to the GIFTS database
my $dbc = get_gifts_dbc($giftsdb_name,$giftsdb_schema,$giftsdb_host,$giftsdb_user,$giftsdb_pass,$giftsdb_port);

# Get the slice_adaptor
my ($chromosome,$region_accession);
my $slice_adaptor = $registry->get_adaptor($species,'core','Slice');
my $slices = $slice_adaptor->fetch_all('toplevel',undef,1);
my $meta_adaptor = $registry->get_adaptor($species,'core','MetaContainer');
my $ca = $registry->get_adaptor($species,'core','CoordSystem');
my $species_name = $meta_adaptor->get_scientific_name;
my $tax_id = $meta_adaptor->get_taxonomy_id;
my $assembly_name = $ca->fetch_all->[0]->version;

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $load_time = ($year+1900)."-".($mon+1)."-".$mday;

# Primary keys
my $gene_id;
my $transcript_id;

my $gene_count=0;
my $transcript_count=0;

# write out the history
print "Adding entry to the ensembl_species_history table\n";
my $sql_history = "INSERT INTO ensembl_species_history (species,assembly_accession,ensembl_tax_id,ensembl_release,status) VALUES (?,?,?,?,?)";
my $sth = $dbc->prepare($sql_history);
$sth->bind_param(1,$species_name);
$sth->bind_param(2,$assembly_name);
$sth->bind_param(3,$tax_id);
$sth->bind_param(4,$release);
$sth->bind_param(5,"LOAD_STARTED");
$sth->execute() or die "Could not add history entry to GIFTS database:\n".$dbc->errstr;
my $ensembl_species_history_id = $dbc->last_insert_id(undef,$giftsdb_schema,"ensembl_species_history","ensembl_species_history_id");
$sth->finish();
print("Added ensembl_species_history_id ".$ensembl_species_history_id."\n");

while (my $slice = shift @$slices) {
  # Fetch additional meta data on the slice
  $region_accession = $slice->seq_region_name;
  if ($slice->is_chromosome) {
    $chromosome = $slice->seq_region_name;
    if ($slice->get_all_synonyms('INSDC')->[0]) {
      $region_accession = $slice->get_all_synonyms('INSDC')->[0]->name;
    }
  }
  else {
    $chromosome = '';
  }

  #my $sql_gene = "INSERT INTO ensembl_gene (ensg_id,gene_name,chromosome,region_accession,deleted,seq_region_start,seq_region_end,seq_region_strand,biotype,time_loaded,ensg_version,gene_symbol,gene_accession) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)";
  my $sql_gene = "INSERT INTO ensembl_gene (ensg_id,gene_name,chromosome,region_accession,deleted,seq_region_start,seq_region_end,seq_region_strand,biotype,time_loaded,gene_symbol,gene_accession) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)";

  my $sql_transcript = "INSERT INTO ensembl_transcript (gene_id,enst_id,ccds_id,uniparc_accession,biotype,deleted,seq_region_start,seq_region_end,supporting_evidence,userstamp,time_loaded,enst_version,ensp_id,ensp_version,ensp_len,select) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) ";

  my $genes = $slice->get_all_Genes();
  while (my $gene = shift @$genes) {
    my $sth = $dbc->prepare($sql_gene);
    
    # fetch the "select" transcript for this gene
    my $select_transcript = "";
    if ($release <= 95) {
      $select_transcript = $gene->canonical_transcript()->stable_id();
    }# elsif (scalar(@{$gene->get_all_Attributes('select_transcript')}) > 0) {
    # $select_transcript = @{$gene->get_all_Attributes('select_transcript')}[0]->value();
    #}

    my $gene_accession = "";
    my $gene_name = "";
    if ($gene->description() =~ /(.+)\[.+Acc:(.+)\]/) {
      $gene_name = $1;
      $gene_accession = $2;
    }

    my $ensg = "";
    my $ensg_version = "";
    ($ensg,$ensg_version) = split(/\./,$gene->stable_id_version());
    
    $sth->bind_param(1,$ensg);
    $sth->bind_param(2,$gene_name);
    $sth->bind_param(3,$chromosome);
    $sth->bind_param(4,$region_accession);
    $sth->bind_param(5,0);
    $sth->bind_param(6,$gene->seq_region_start);
    $sth->bind_param(7,$gene->seq_region_end);
    $sth->bind_param(8,$gene->seq_region_strand);
    $sth->bind_param(9,$gene->biotype);
    $sth->bind_param(10,$load_time);
    #$sth->bind_param(11,$ensg_version);
    
    # gene_symbol
    if ($gene->display_xref) {
      #$sth->bind_param(12,$gene->display_xref()->display_id());
      $sth->bind_param(11,$gene->display_xref()->display_id());
    } else {
      #$sth->bind_param(12,"");
      $sth->bind_param(11,"");
    }
    
    #$sth->bind_param(13,$gene_accession);
    $sth->bind_param(12,$gene_accession);
    $sth->execute() or die "Could not add gene entry to GIFTS database for ".$gene->stable_id."\n".$dbc->errstr;
    $gene_id = $dbc->last_insert_id(undef,$giftsdb_schema,"ensembl_gene","gene_id");
    $sth->finish();

    # add entry to the gene_history table
    print "Adding entry to the gene_history table\n";
    my $gene_history = "INSERT INTO gene_history (ensembl_species_history_id,gene_id) VALUES (?,?)";
    $sth = $dbc->prepare($gene_history);
    $sth->bind_param(1,$ensembl_species_history_id);
    $sth->bind_param(2,$gene_id);
    $sth->execute() or die "Could not add gene history entry to GIFTS database:\n".$dbc->errstr;
    $sth->finish();

    $gene_count++;
    foreach my $transcript (@{$gene->get_all_Transcripts}) {
      my ($start_exon,$end_exon,$start_exon_seq_offset,$end_exon_seq_offset,$start_exon_id,$end_exon_id);

      my $ensp = "";
      my $ensp_version = "";
      my $ensp_len = 0;
      if ($transcript->translation()) {
        ($ensp,$ensp_version) = split(/\./,$transcript->translation()->stable_id_version());
        $ensp_len = $transcript->translation()->length();
      }

      my $ccds = "";
      if ($transcript->ccds) {
        $ccds = $transcript->ccds->display_id;
      }

      my $supporting_evidence;
      if (!$supporting_evidence) {
        $supporting_evidence = "";
      }
      my $uniparc = "";
      if (scalar(@{$transcript->get_all_DBLinks('UniParc')}) > 0) {
        $uniparc = $transcript->get_all_DBLinks('UniParc')->[0]->display_id;
      }

      my ($enst,$enst_version) = split(/\./,$transcript->stable_id_version);

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
      
      my $sth = $dbc->prepare($sql_transcript);
      $sth->bind_param(1,$gene_id);
      $sth->bind_param(2,$enst);
      $sth->bind_param(3,$ccds);
      $sth->bind_param(4,$uniparc);
      $sth->bind_param(5,$transcript->biotype);
      $sth->bind_param(6,0);
      $sth->bind_param(7,$transcript->seq_region_start);
      $sth->bind_param(8,$transcript->seq_region_end);
      $sth->bind_param(9,$supporting_evidence);
      $sth->bind_param(10,$user);
      $sth->bind_param(11,$load_time);
      $sth->bind_param(12,$enst_version);
      $sth->bind_param(13,$ensp);
      $sth->bind_param(14,$ensp_version);
      $sth->bind_param(15,$ensp_len);
      $sth->bind_param(16,$is_select_transcript);
      $sth->execute() or die "Could not add transcript entry to GIFTS database for ".$transcript->stable_id."\n".$dbc->errstr;
      #$transcript_id = $sth->{mysql_insertid};
      $transcript_id = $dbc->last_insert_id(undef,$giftsdb_schema,"ensembl_transcript","transcript_id");
      $sth->finish();

      # add entry to the transcript_history table
      print "Adding entry to the transcript_history table\n";
      my $transcript_history = "INSERT INTO transcript_history (ensembl_species_history_id,transcript_id) VALUES (?,?)";
      $sth = $dbc->prepare($transcript_history);
      $sth->bind_param(1,$ensembl_species_history_id);
      $sth->bind_param(2,$transcript_id);
      $sth->execute() or die "Could not add transcript history entry to GIFTS database:\n".$dbc->errstr;
      $sth->finish();

      $transcript_count++;
    }
  }
}

# display results
print "Genes:".$gene_count."\n.";
print "Transcripts:".$transcript_count."\n.";

# update the history
print "Updating entry to the ensembl_species_history table\n";
my $sql_history_status_update = "UPDATE ensembl_species_history SET status=? WHERE ensembl_species_history_id=?";
$sth = $dbc->prepare($sql_history_status_update);
$sth->bind_param(1,"LOAD_COMPLETE");
$sth->bind_param(2,$ensembl_species_history_id);
$sth->execute() or die "Could not update status for ensembl_species_history_id in GIFTS database:\n".$dbc->errstr;
$sth->finish();

my $sql_history_time_update = "UPDATE ensembl_species_history SET time_loaded=? WHERE ensembl_species_history_id=?";
$sth = $dbc->prepare($sql_history_time_update);
$sth->bind_param(1,"now()");
$sth->bind_param(2,$ensembl_species_history_id);
$sth->execute() or die "Could not update time_loaded for ensembl_species_history_id in GIFTS database:\n".$dbc->errstr;
$sth->finish();

print "Finished\n.";
