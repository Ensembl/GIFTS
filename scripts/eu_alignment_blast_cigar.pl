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

eu_alignment_blast_cigar.pl -

=head1 DESCRIPTION

  This script maps Ensembl gene sets on to Uniprot proteins by using blastp and makes
  the cigar plus and md strings by using muscle.

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
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::Analysis::Runnable;
use Bio::EnsEMBL::GIFTS::Runnable::BlastP;
use Bio::EnsEMBL::Analysis::Tools::BPliteWrapper;
use Bio::EnsEMBL::GIFTS::DB qw(rest_get rest_post store_alignment fetch_transcript_enst fetch_cigarmdz store_cigarmdz fetch_uniprot_info_for_id);
use Bio::EnsEMBL::GIFTS::BaseMapping qw(make_cigar_plus_string make_md_string run_muscle);

# Set options

my $output_dir = ".";
my $output_prefix = "alignment_blast_";

my $registry_host;
my $registry_user;
my $registry_pass;
my $registry_port;

my $user;

my $pipeline_name = "alignment pipeline BLAST";
my $pipeline_comment = "production run";
my $pipeline_invocation = join " ",$0,@ARGV;
my $species; # ie "homo_sapiens"
my $perfect_match_alignment_run_id;
my $write_blast = 1;
my $write_cigar = 1;

my $mapping_id = "";
my $alignment_run_id = 0;

my $cigar_id_count=0;

my $rest_server;
my $auth_token;

GetOptions(
        'output_dir=s' => \$output_dir,
        'output_prefix=s' => \$output_prefix,
        'registry_host=s' => \$registry_host,
        'registry_user=s' => \$registry_user,
        'registry_pass=s' => \$registry_pass,
        'registry_port=s' => \$registry_port,
        'user=s' => \$user,
        'species=s' => \$species,
        'perfect_match_alignment_run_id=i' => \$perfect_match_alignment_run_id,
        'pipeline_name=s' => \$pipeline_name,
        'pipeline_comment=s' => \$pipeline_comment,
        'write_cigar=i' => \$write_cigar,
        'write_blast=i' => \$write_blast,
        'mapping_id=s' => \$mapping_id,
        'alignment_run_id=i' => \$alignment_run_id,
        'rest_server=s' => \$rest_server,
	'auth_token=s' => \$auth_token
   );

if (!$registry_host or !$registry_user or !$registry_port) {
  die("Please specify the registry host details with --registry_host, --registry_user and --registry_port.");
}

if (!$user) {
  die("Please specify user with --user flag");
}

if (!$rest_server) {
  die "Please specify a rest server URL with --rest_server\n";
}

if (!$auth_token) {
  die "Please specify an authorization token for the rest server with --auth_token\n";
}

if (!$species) {
  die("Please specify species with the --species parameter (ie. --species homo_sapiens");
}

if (!$perfect_match_alignment_run_id) {
  die("Please specify perfect_match_alignment_run_id with --perfect_match_alignment_run_id flag\n".
      "This should be the alignment_run_id in the GIFTs database of a run of the eu_alignment_perfect_match script.");
}

# remove trailing comma and duplicate commas if any
$mapping_id =~ s/,$//;
$mapping_id =~ s/,,/,/;

my ($first_mapping_id) = $mapping_id =~ /(\d+)/;

# Process options for the output files

mkdir($output_dir) unless(-d $output_dir);
my $output_file_debug = $output_dir."/".$output_prefix.$first_mapping_id."-debug.txt";
my $output_file_noseqs = $output_dir."/".$output_prefix.$first_mapping_id."-no_seqs.txt";

open DEBUG_INFO,">".$output_file_debug or die print "Can't open output debug file ".$output_file_debug."\n";
open UNIPROT_NOSEQS,">".$output_file_noseqs or die print "Can't open output no sequence file ".$output_file_noseqs."\n";

# The file for uniprot sequences to be written to (will change when parallelized)
my $useq_file = $output_dir."/uniprot_seq_".$first_mapping_id.".fa";

# Set the OPTIONS for the GIFTS database

# retrieve values used from the previous alignment run
#        'uniprot_sp_file=s' => \$uniprot_sp_file,
#        'uniprot_sp_isoform_file=s' => \$uniprot_sp_isoform_file,
#        'uniprot_tr_dir=s' => \$uniprot_tr_dir,
# species
# mapping history run
# ensembl release

my $alignment_run = rest_get($rest_server."/alignments/alignment_run/".$perfect_match_alignment_run_id);

my $release_mapping_history_id = $alignment_run->{'release_mapping_history'};
my $release = $alignment_run->{'ensembl_release'};
my $uniprot_sp_file = $output_dir.'/'.$alignment_run->{'uniprot_file_swissprot'};
my $uniprot_sp_isoform_file = $output_dir.'/'.$alignment_run->{'uniprot_file_isoform'};
my $uniprot_tr_dir = $output_dir.'/'.$alignment_run->{'uniprot_dir_trembl'};

print("Using previous alignment run values\n");
print("Species=$species\n");
print("Ensembl Release=$release\n");
print("Release mapping history ID=$release_mapping_history_id\n");
print("perfect_match_alignment_run_id=$perfect_match_alignment_run_id\n");
print("File=$uniprot_sp_file\n");
print("File=$uniprot_sp_isoform_file\n");
if ($uniprot_tr_dir) {
  print("File=$uniprot_tr_dir\n");
}

if ($release==0) {
  die ("Release is 0 (you may need to choose a later perfect alignment_run)");
}

# Create the registry
my $registry = "Bio::EnsEMBL::Registry";
$registry->load_registry_from_db(
    -host => $registry_host,
    -user => $registry_user,
    -port => $registry_port,
    -pass => $registry_pass,
    -db_version => ''.$release
);
$registry->set_reconnect_when_lost();

# EnsEMBL database connection
my $transcript_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species,"core","transcript");
print("Database adaptors opened\n");

# Open the Uniprot archives that were used previously

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

# Print the alignment run
print("Alignment run $alignment_run_id\n");

# Objects to support the blast call
my $bplitewrapper = Bio::EnsEMBL::Analysis::Tools::BPliteWrapper-> new
  (
   -query_type => 'pep',
   -database_type => 'pep',
 );

my $analysis_obj = new Bio::EnsEMBL::Analysis(
      -id              => 1,
      -logic_name      => 'eu_blastp',
      -db              => "GIFTS perfect match run",
      -db_version      => $perfect_match_alignment_run_id,
      -db_file         => $useq_file,
      -program         => "blastp",
      -program_version => "",
      -program_file    => "blastp",
      -module          => "Bio::EnsEMBL::Analysis::Runnable::Blast",
      -description     => 'GIFTS blast',
      -display_label   => 'GIFTS blast',
      -displayable     => '1',
      -web_data        => 'eu_blastp'
   );

my %mapping_id_hash = {};
$mapping_id_hash{$_}++ for (split(/,/,$mapping_id));

# the main loop

# fetch the items we want to update
my $next_url = $rest_server."/alignments/alignment/alignment_run/".$perfect_match_alignment_run_id;

my $alignments;
while ($next_url) {

  print STDERR "Fetching the alignments from $next_url ...\n";
  $alignments = rest_get($next_url);
  print STDERR scalar(@{$alignments->{'results'}})." alignments fetched out of ".$alignments->{'count'}.".\n";

ALIGNMENT: foreach my $alignment (@{$alignments->{'results'}}) {

    my $alignment_mapping_id = $alignment->{'mapping'};

    if ($alignment->{'score1'} or ($mapping_id and !exists($mapping_id_hash{$alignment_mapping_id}))) {
      # we want to loop through the aligments whose score1 is 0
      # score1 = 0 means there was not perfect match
      # score1 = 1 means there was a perfect match
      next ALIGNMENT;
    }

    my $uniprot_id = $alignment->{'uniprot_id'};
    my $gifts_transcript_id = $alignment->{'transcript'};
    my $alignment_id = $alignment->{'alignment_id'};

    print(DEBUG_INFO "PROCESSING alignment_mapping_id:$alignment_mapping_id,uniprot_id:$uniprot_id,gifts_transcript_id:$gifts_transcript_id\n");

    # get the uniprot accession,sequence version,sequence
    my ($uniprot_seq,$uniprot_acc,$uniprot_seq_version) = fetch_uniprot_info_for_id($rest_server,$uniprot_id,@uniprot_archive_parsers);

    # Get the Ensembl transcript ID and translated sequence
    my $enst_id = fetch_transcript_enst($rest_server,$gifts_transcript_id);
    print(DEBUG_INFO "transcript id=$gifts_transcript_id enst_id=$enst_id\n");
    my $transcript = $transcript_adaptor->fetch_by_stable_id($enst_id);

    # perform the alignment
    if ($uniprot_seq && $transcript->translate) {
      my $ens_translation = $transcript->translation();

      my $score = 0;
      # align - in this case it's about running blastp
      my $target_u = Bio::Seq->new(
			      '-display_id' => $uniprot_acc,
			      '-seq'        => $uniprot_seq,
			     );
      my $translation = Bio::Seq->new(
			      '-display_id' => $ens_translation->stable_id,
			      '-seq'        => $ens_translation->seq,
			     );

      if ($write_blast) {
        # set the uniprot as the target and create index for the run
        open UNIPROT_SEQ_FILE,">".$useq_file or die $!;
        print UNIPROT_SEQ_FILE ">".$uniprot_acc."\n";
        print UNIPROT_SEQ_FILE $uniprot_seq."\n";
        close UNIPROT_SEQ_FILE;
        system("makeblastdb -in $useq_file -dbtype prot");

        my $blast =  Bio::EnsEMBL::GIFTS::Runnable::BlastP->new
          ('-query'     => $translation,
           '-program'   => 'blastp',
           '-database'  => $useq_file,
           '-threshold' => 1e-6,
           '-parser'    => $bplitewrapper,
           '-options'   => '-num_threads=1',
           '-analysis'  => $analysis_obj,
         );

        $blast->run();
        my $r = @{$blast->output}[0];

        if ($r) {
          my $coverage = ($r->length) / length($translation->seq);
          $alignment_id = store_alignment($auth_token,$rest_server,$alignment_run_id,$uniprot_id,$gifts_transcript_id,$alignment_mapping_id,$r->percent_id,$coverage,undef);
        }
        else {
          print UNIPROT_NOSEQS "ERROR: NO BLASTP RESULTS PARSED\n";
          print UNIPROT_NOSEQS ">".$translation->id."\n";
          print UNIPROT_NOSEQS $translation->seq."\n";
          print UNIPROT_NOSEQS ">$uniprot_acc\n";
          print UNIPROT_NOSEQS "$uniprot_seq\n";
        }
        # delete the created file
        unlink $useq_file or die ("Could not delete $useq_file");
      }
      if ($write_cigar) {
        # check for an existing entry in the cigar table
        my ($existing_cigar,$existing_mdz) = fetch_cigarmdz($rest_server,$alignment_id);
        if (!$existing_cigar) {

          # run muscle
          my ($seqobj_compu,$seqobj_compe) = run_muscle($target_u,$translation,$output_dir);

          # store the results
          my $cigar_plus_string = make_cigar_plus_string($seqobj_compu->seq,$seqobj_compe->seq);
          my $md_string = make_md_string($seqobj_compu->seq,$seqobj_compe->seq);
          store_cigarmdz($auth_token,$rest_server,$alignment_id,$cigar_plus_string,$md_string) if ($alignment_id != 0);
          $cigar_id_count++;
        }
      }
    }
    else {
      if ($transcript->translate) {
        print(UNIPROT_NOSEQS "UNIPROT,$alignment_mapping_id,$uniprot_acc,\n");
      }
      elsif ($uniprot_seq) {
        print(UNIPROT_NOSEQS "ENSP,$alignment_mapping_id,$enst_id\n");
      }
      else {
        print(UNIPROT_NOSEQS "BOTH,$alignment_mapping_id,$uniprot_acc accession,$enst_id\n");
      }
    }
  } # foreach alignment
  
  $next_url = $alignments->{'next'};
  
} # while next_url
CLOSE:

close DEBUG_INFO;
close UNIPROT_NOSEQS;

if ($write_cigar) {
  print "$cigar_id_count cigars written to ensp_u_cigar table\n";
}
