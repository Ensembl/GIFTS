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

eu_alignment_perfect_match.pl -

=head1 DESCRIPTION

  This script stores perfect matches found between Ensembl and UniProt proteins.

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
use Bio::DB::HTS::Faidx;
use Bio::EnsEMBL::GIFTS::DB qw(rest_get rest_post fetch_uniprot_info_for_id store_alignment fetch_transcript_enst is_perfect_eu_match_uniparcs);

#
# Set options
#

my $output_dir = "";
my $output_prefix = "alignment_log";

my $registry_host;
my $registry_user;
my $registry_pass;
my $registry_port;

my $user;
my $species = "homo_sapiens";
my $release;

my $uniprot_sp_file;
my $uniprot_sp_isoform_file;
my $uniprot_tr_dir = "";

my $pipeline_name = "perfect match compare";
my $pipeline_comment;
my $pipeline_invocation = join " ",$0,@ARGV;
my $release_mapping_history_id;
my $mapping_id_only;

my $rest_server;

my $alignment_run_id = 0;
my $page = 0;

GetOptions(
        'output_dir=s' => \$output_dir,
        'output_prefix=s' => \$output_prefix,
        'registry_host=s' => \$registry_host,
        'registry_user=s' => \$registry_user,
        'registry_pass=s' => \$registry_pass,
        'registry_port=s' => \$registry_port,
        'user=s' => \$user,
        'species=s' => \$species,
        'release=i' => \$release,
        'release_mapping_history_id=i' => \$release_mapping_history_id,
        'uniprot_sp_file=s' => \$uniprot_sp_file,
        'uniprot_sp_isoform_file=s' => \$uniprot_sp_isoform_file,
        'uniprot_tr_dir=s' => \$uniprot_tr_dir,
        'pipeline_name=s' => \$pipeline_name,
        'pipeline_comment=s' => \$pipeline_comment,
        'mapping_id_only=i' => \$mapping_id_only,
        'rest_server=s' => \$rest_server,
        'alignment_run_id=i' => \$alignment_run_id, # optional alignment_run_id to use for the alignments (it must be an existing one) 
        'page=s' => \$page
   );

if (!$registry_host or !$registry_user or !$registry_port) {
  die("Please specify the registry host details with --registry_host, --registry_user and --registry_port.");
}

if (!$user) {
  die("Please specify user with --user flag");
}

if (!$release) {
  die("Please specify release with --release flag");
}

if (!$rest_server) {
  die "Please specify a rest server URL with --rest_server\n";
}

if (!$release_mapping_history_id) {
  die("Please specify mapping_history_id with $release_mapping_history_id flag");
}

if (!$pipeline_comment) {
  $pipeline_comment = "perfect match compare for $species $release";
}

# remove trailing comma and duplicate commas if any
$page =~ s/,$//;
$page =~ s/,,/,/;

my ($first_page) = $page =~ /(\d+)/;

#
# Process options for the output files
#
mkdir($output_dir) unless(-d $output_dir);
my $output_file_noseqs = $output_dir."/".$output_prefix.$first_page."-no_seqs.txt";
my $output_file_seqs = $output_dir."/".$output_prefix.$first_page."-_seqs.txt";
open UNIPROT_NOSEQS,">".$output_file_noseqs or die print "Can't open output no sequence file ".$output_file_noseqs."\n";
open UNIPROT_SEQS,">".$output_file_seqs or die print "Can't open output sequence match file ".$output_file_noseqs."\n";

#
# Set the OPTIONS for the GIFTS database
#

# expects a set of fasta files in block gzipped format (use bgzip on the fasta file)
my @uniprot_archives = ($uniprot_sp_file);
push(@uniprot_archives,$uniprot_sp_isoform_file);

# contains all the chunks from the trembl file
if ($uniprot_tr_dir) {
  opendir(TDIR,$uniprot_tr_dir) or die "Couldnt find trembl files";
  while (my $tfile = readdir(TDIR)) {
    next unless ($tfile =~ m/\.fa_chunk/);
    next unless ($tfile =~ m/\.gz$/);
    push(@uniprot_archives,$uniprot_tr_dir."/".$tfile);
  }
  closedir(TDIR);
}

# open uniprot fasta files
print "Opening uniprot archives\n";
my @uniprot_archive_parsers;
foreach my $u (@uniprot_archives) {
  print "Checking/Generating index for Uniprot Sequence source file $u\n";
  my $ua = Bio::DB::HTS::Faidx->new($u);
  push @uniprot_archive_parsers,$ua;
}
print "Opened uniprot archives\n";

# Create the registry
my $registry = "Bio::EnsEMBL::Registry";
$registry->load_registry_from_db(
    -host => $registry_host,
    -user => $registry_user,
    -port => $registry_port,
    -pass => $registry_pass,
    -db_version => ''.$release
);

# EnsEMBL database connection
my $transcript_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species,"core","transcript");
print("Database adaptors opened\n");

## Add the alignment run into the database
#my $alignment_run = {
#                         score1_type => "perfect_match",
#                         score2_type => "sp mapping ONE2ONE",
#                         pipeline_name => $pipeline_name,
#                         pipeline_comment => $pipeline_comment,
#                         pipeline_script => "GIFTS/scripts/eu_alignment_perfect_match.pl",
#                         userstamp => $user,
#                         #release_mapping_history_id => $release_mapping_history_id,
#                         release_mapping_history => $release_mapping_history_id,
#                         logfile_dir => $output_dir,
#                         uniprot_file_swissprot => $uniprot_sp_file,
#                         uniprot_file_isoform => $uniprot_sp_isoform_file,
#                         uniprot_dir_trembl => $uniprot_tr_dir,
#                         ensembl_release => $release,
#                         report => "sp mapping value"
#};

#my $alignment_run_response_ = rest_post($rest_server."/alignments/alignment_run/",$alignment_run);
#my $alignment_run_id = $alignment_run_response_->{'alignment_run_id'};
print("Alignment run $alignment_run_id\n");

# The main loop

my @page_array = split(/,/,$page);

my $next_url = $rest_server."/mappings/release_history/".$release_mapping_history_id."/?";
if ($page) {
  my $first_page = shift(@page_array);
  $next_url .= "page=".$first_page;
}

my $mappings;
while ($next_url) {
  
  print STDERR "Fetching the mappings from $next_url ...\n";
  $mappings = rest_get($next_url);
  print STDERR scalar(@{$mappings->{'results'}})." mappings fetched out of ".$mappings->{'count'}.".\n";

  foreach my $mapping (@{$mappings->{'results'}}) {

    my $mapping_id = $mapping->{'mapping_id'};
    my $uniprot_id = $mapping->{'uniprot'};

    if ($mapping_id_only and $mapping_id_only != $mapping_id) {
      next;
    }
    my $gifts_transcript_id = $mapping->{'transcript'};

    my $mapping_type;
    foreach my $mapping_history_entry (@{$mapping->{'mapping_history'}}) {
      if ($mapping_history_entry->{'release_mapping_history'} == $release_mapping_history_id) {
        $mapping_type = $mapping_history_entry->{'sp_ensembl_mapping_type'};
        last;
      }
    }

    my $score1 = 0;
    my $score2 = 0;
    # can we use existing UniParc information stored to make a storage call
    my $is_uniparc_match = is_perfect_eu_match_uniparcs($rest_server,$uniprot_id,$gifts_transcript_id);
    if ($is_uniparc_match) {
      $score1 = 1;
    }
    if ($mapping_type) {
      if ($mapping_type =~ /ONE2ONE/) {
        $score2 = 1;
      }
    }
    else {
      $mapping_type = "";
    }

    # do we have sequences for both items
    # get the uniprot accession,sequence version,sequence
    my ($uniprot_seq,$uniprot_acc,$uniprot_seq_version) = fetch_uniprot_info_for_id($rest_server,$uniprot_id,@uniprot_archive_parsers);
    # Get the Ensembl transcript ID and translated sequence
    my $enst_id = fetch_transcript_enst($rest_server,$gifts_transcript_id);
    my $transcript = $transcript_adaptor->fetch_by_stable_id($enst_id);
    my $translation_seq = undef;
    if ($transcript) {
      if ($transcript->translate) {
        my $translation = $transcript->translate();
        $translation_seq = $translation->seq();
      }
    } else {
      print("Transcript $enst_id could not be fetched.\n");
    }
    # store the result if sequences are found or if a UniParc match was made
    if ($translation_seq && $uniprot_seq) {
      store_alignment($rest_server,$alignment_run_id,$uniprot_id,$gifts_transcript_id,$mapping_id,$score1,$score2,$mapping_type);
    }
    elsif ($score1==1) {
      store_alignment($rest_server,$alignment_run_id,$uniprot_id,$gifts_transcript_id,$mapping_id,$score1,$score2,$mapping_type);
    }
  }
  
  if ($page) {
    $next_url = $rest_server."/mappings/release_history/".$release_mapping_history_id."/?";
    if (scalar(@page_array) > 0) {
      my $next_page = shift(@page_array);
      $next_url .= "page=".$next_page;
    } else {
      $next_url = undef;
    }
  } else {
    $next_url = $mappings->{'next'};
  }
}
CLOSE:
close UNIPROT_SEQS;
close UNIPROT_NOSEQS;
