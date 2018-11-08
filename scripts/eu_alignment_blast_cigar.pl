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

eu_alignment_blast_cigar.pl -

=head1 DESCRIPTION

  This script maps Ensembl gene sets on to Uniprot proteins by using blastp and makes
  the cigar plus and md strings.

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
use Bio::EnsEMBL::GIFTS::DB qw(fetch_uniprot_accession store_alignment fetch_transcript_ids fetch_cigarmdz store_cigarmdz fetch_uniprot_info_for_id get_gifts_dbc);
use Bio::EnsEMBL::GIFTS::BaseMapping qw(make_cigar_plus_string make_md_string run_muscle);

# Set options

my $output_dir = ".";
my $output_prefix = "alignment_blast_";

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

my $user;

my $pipeline_name = "alignment pipeline BLAST";
my $pipeline_comment = "development run";
my $pipeline_invocation = join " ",$0,@ARGV;
my $perfect_match_alignment_run_id;
my $write_blast = 1;
my $write_cigar = 1;
my $mapping_id = 0;

my $cigar_id_count=0;

GetOptions(
        'output_dir=s' => \$output_dir,
        'output_prefix=s' => \$output_prefix,
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
        'user=s' => \$user,
        'perfect_match_alignment_run_id=i' => \$perfect_match_alignment_run_id,
        'pipeline_name=s' => \$pipeline_name,
        'pipeline_comment=s' => \$pipeline_comment,
        'write_cigar=i' => \$write_cigar,
        'write_blast=i' => \$write_blast,
        'mapping_id=i' => \$mapping_id,
   );

if (!$giftsdb_name or !$giftsdb_host or !$giftsdb_user or !$giftsdb_pass or !$giftsdb_port) {
  die("Please specify the GIFTS database details with --giftsdb_host, --giftsdb_user, --giftsdb_pass, --giftsdb_name, --giftsdb_schema and --giftsdb_port.");
}

if (!$registry_host or !$registry_user or !$registry_port) {
  die("Please specify the registry host details with --registry_host, --registry_user and --registry_port.");
}

if (!$user) {
  die("Please specify user with --user flag");
}

if (!$perfect_match_alignment_run_id) {
  die("Please specify perfect_match_alignment_run_id with --perfect_match_alignment_run_id flag\n".
      "This should be the alignment_run_id in the GIFTs database of a run of the eu_alignment_perfect_match script.");
}

# Process options for the output files

mkdir($output_dir) unless(-d $output_dir);
my $output_file_debug = $output_dir."/".$output_prefix."-debug.txt";
my $output_file_noseqs = $output_dir."/".$output_prefix."-no_seqs.txt";

open DEBUG_INFO,">".$output_file_debug or die print "Can't open output debug file ".$output_file_debug."\n";
open UNIPROT_NOSEQS,">".$output_file_noseqs or die print "Can't open output no sequence file ".$output_file_noseqs."\n";

# The file for uniprot sequences to be written to (will change when parallelized)
my $useq_file = $output_dir."/uniprot_seq.fa";

# Set the OPTIONS for the GIFTS database

# GIFTS database connection
my $dbc = get_gifts_dbc($giftsdb_name,$giftsdb_schema,$giftsdb_host,$giftsdb_user,$giftsdb_pass,$giftsdb_port);

# retrieve values used from the previous alignment run
#        'uniprot_sp_file=s' => \$uniprot_sp_file,
#        'uniprot_sp_isoform_file=s' => \$uniprot_sp_isoform_file,
#        'uniprot_tr_dir=s' => \$uniprot_tr_dir,
# species
# mapping history run
# ensembl release
my $sql_gifts_alignment_run = "SELECT * FROM alignment_run WHERE alignment_run_id=".$perfect_match_alignment_run_id;
my $sth_gifts_pmar = $dbc->prepare($sql_gifts_alignment_run);
$sth_gifts_pmar->execute() or die "Could not fetch the previous alignment run:\n".$dbc->errstr;

my @alignrow = $sth_gifts_pmar->fetchrow_array;
$sth_gifts_pmar->finish;

my $release_mapping_history_id = $alignrow[7];
my $release = $alignrow[8];
my $uniprot_sp_file = $alignrow[9];
my $uniprot_sp_isoform_file = $alignrow[10];
my $uniprot_tr_dir = $alignrow[11];

# Set the species up
my $sql_gifts_mapping_history = "SELECT rmh.ensembl_species_history_id FROM mapping_history mh,release_mapping_history rmh WHERE mh.release_mapping_history_id=rmh.release_mapping_history_id AND mh.release_mapping_history_id=".$release_mapping_history_id;
my $sth_gifts_mapping_history = $dbc->prepare($sql_gifts_mapping_history);
$sth_gifts_mapping_history->execute() or die "Could not fetch the mapping history with ID :".$release_mapping_history_id."\n".$dbc->errstr;
my @mhrow = $sth_gifts_mapping_history->fetchrow_array;
my $ensembl_species_history_id = $mhrow[0];
my $sql_gifts_species = "SELECT species FROM ensembl_species_history  WHERE ensembl_species_history_id=".$ensembl_species_history_id;
my $sth_gifts_species = $dbc->prepare($sql_gifts_species);
$sth_gifts_species->execute() or die "Could not fetch the ensembl species history with ID :".$ensembl_species_history_id."\n".$dbc->errstr;
my @srow = $sth_gifts_species->fetchrow_array;
my $species = $srow[0];

$sth_gifts_mapping_history->finish;
$sth_gifts_species->finish;

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

# EnsEMBL database connection
my $ens_db_adaptor = Bio::EnsEMBL::Registry->get_DBAdaptor($species,"core");
my $transcript_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species,"core","transcript");
my $translation_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species,"core","translation");
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

# fetch the items we want to update
my $sql_gifts_process_list = "SELECT mapping_id,uniprot_id,transcript_id FROM alignment WHERE alignment_run_id=".$perfect_match_alignment_run_id.
  " AND score1=0";
$sql_gifts_process_list .= " AND mapping_id=".$mapping_id if ($mapping_id); # given a mapping id the blast will be run for it only instead of for all the mappings

my $sth_gifts_process_list = $dbc->prepare($sql_gifts_process_list);
$sth_gifts_process_list->execute() or die "Could not fetch the list or alignments to process:\n".$dbc->errstr;

# Add the alignment run into the database
my $alignment_run_id = -1;
if ($write_blast) {
  my $sql_alignment_run = "INSERT IGNORE INTO alignment_run (score1_type,score2_type,pipeline_name,pipeline_comment,pipeline_script,userstamp,release_mapping_history_id,logfile_dir,uniprot_file_swissprot,uniprot_file_isoform,uniprot_dir_trembl,ensembl_release) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)";
  my $sth = $dbc->prepare($sql_alignment_run);
  $sth->bind_param(1,'identity');
  $sth->bind_param(2,'coverage');
  $sth->bind_param(3,$pipeline_name);
  $sth->bind_param(4,$pipeline_comment);
  $sth->bind_param(5,"GIFTS/scripts/eu_alignment_blast_cigar.pl");
  $sth->bind_param(6,$user);
  $sth->bind_param(7,$release_mapping_history_id);
  $sth->bind_param(8,$output_dir);
  if ($uniprot_sp_file) {
    $sth->bind_param(9,$uniprot_sp_file);
  }
  if ($uniprot_sp_isoform_file) {
    $sth->bind_param(10,$uniprot_sp_isoform_file);
  }
  $sth->bind_param(11,$uniprot_tr_dir);
  $sth->bind_param(12,$release);

  $sth->execute() or die "Could not add the alignment run:\n".$dbc->errstr;
  $alignment_run_id = $dbc->last_insert_id(undef,undef,"alignment_run","alignment_run_id");
  $sth->finish();
  print("Alignment run $alignment_run_id\n");
}

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

# the main loop
while (my @row = $sth_gifts_process_list->fetchrow_array) {
  my $mapping_id = $row[0];
  my $uniprot_id = $row[1];
  my $gifts_transcript_id = $row[2];
  my $alignment_id = 0;

  print(DEBUG_INFO "PROCESSING mapping_id:$mapping_id,uniprot_id:$uniprot_id,gifts_transcript_id:$gifts_transcript_id\n");

  # get the uniprot accession,sequence version,sequence
  my ($uniprot_seq,$uniprot_acc,$uniprot_seq_version) =
    fetch_uniprot_info_for_id($dbc,$uniprot_id,@uniprot_archive_parsers);

  # Get the Ensembl transcript ID and translated sequence
  my $enst_id = fetch_transcript_ids($dbc,$gifts_transcript_id);
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
        store_alignment($dbc,$alignment_run_id,
                     $uniprot_id,$gifts_transcript_id,$mapping_id,$r->percent_id,$coverage,undef);
        $alignment_id = $dbc->last_insert_id(undef,undef,"alignment","alignment_id");
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
      my ($existing_cigar,$existing_mdz) = fetch_cigarmdz($dbc,$alignment_id);
      if (!$existing_cigar) {
        # run muscle
        my ($seqobj_compu,$seqobj_compe) = run_muscle($target_u,$translation,$output_dir);

        # store the results
        my $cigar_plus_string = make_cigar_plus_string($seqobj_compu->seq,$seqobj_compe->seq);
        my $md_string = make_md_string($seqobj_compu->seq,$seqobj_compe->seq);
        store_cigarmdz($dbc,$alignment_id,$cigar_plus_string,$md_string) if ($alignment_id != 0);
        $cigar_id_count++;
      }
    }

    # TODO clean up the index files

  }
  else {
    if ($transcript->translate) {
      print(UNIPROT_NOSEQS "UNIPROT,$mapping_id,$uniprot_acc,\n");
    }
    elsif ($uniprot_seq) {
      print(UNIPROT_NOSEQS "ENSP,$mapping_id,,$enst_id\n");
    }
    else {
      print(UNIPROT_NOSEQS "BOTH,$mapping_id,$uniprot_acc accession,$enst_id\n");
    }
  }
}
CLOSE:
$sth_gifts_process_list->finish();
$dbc->disconnect();
close DEBUG_INFO;
close UNIPROT_NOSEQS;

if ($write_cigar) {
  print "$cigar_id_count cigars written to ensp_u_cigar table\n";
}
