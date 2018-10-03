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

eu_length_compare.pl -

=head1 DESCRIPTION

  This script stores the alignment length comparison result between Ensembl and UniProt proteins.

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
use Bio::EnsEMBL::GIFTS::DB qw(fetch_uniprot_accession store_alignment fetch_transcript_ids get_gifts_dbc);

#
# Set options
#

my $output_dir = "";
my $output_prefix = "alignment_log";

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
my $species = "homo_sapiens";
my $release;

my $uniprot_sp_file;
my $uniprot_sp_isoform_file;
my $uniprot_tr_dir;

my $pipeline_name = "length compare";
my $pipeline_comment = "development run";
my $pipeline_invocation = join " ",$0,@ARGV;
my $mapping_history_id;

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
        'species=s' => \$species,
        'release=i' => \$release,
        'mapping_history_id=i' => \$mapping_history_id,
        'uniprot_sp_file=s' => \$uniprot_sp_file,
        'uniprot_sp_isoform_file=s' => \$uniprot_sp_isoform_file,
        'uniprot_tr_dir=s' => \$uniprot_tr_dir,
        'pipeline_name=s' => \$pipeline_name,
        'pipeline_comment=s' => \$pipeline_comment,
   );

if (!$giftsdb_name or !$giftsdb_schema or !$giftsdb_host or !$giftsdb_user or !$giftsdb_pass or !$giftsdb_port) {
  die("Please specify the GIFTS database details with --giftsdb_host, --giftsdb_user, --giftsdb_pass, --giftsdb_name, --giftsdb_schema and --giftsdb_port.");
}

if (!$registry_host or !$registry_user or !$registry_pass or !$registry_port) {
  die("Please specify the registry host details with --registry_host, --registry_user, --registry_pass and --registry_port.");
}

if (!$user) {
  die("Please specify user with --user flag");
}

if (!$release) {
  die("Please specify release with --release flag");
}

if (!$mapping_history_id) {
  die("Please specify mapping_history_id with $mapping_history_id flag");
}

#
# Process options for the output files
#
mkdir($output_dir) unless(-d $output_dir);
my $output_file_debug = $output_dir."/".$output_prefix."-debug.txt";
my $output_file_noseqs = $output_dir."/".$output_prefix."-no_seqs.txt";

open DEBUG_INFO,">".$output_file_debug or die print "Can't open output debug file ".$output_file_debug."\n";
open UNIPROT_NOSEQS,">".$output_file_noseqs or die print "Can't open output no sequence file ".$output_file_noseqs."\n";

#
# Set the OPTIONS for the GIFTS database
#

# expects a set of fasta files,in block gzipped format (use bgzip on the fasta file)
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
my $ens_db_adaptor = Bio::EnsEMBL::Registry->get_DBAdaptor($species,"core");
my $transcript_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species,"core","transcript");
my $translation_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species,"core","translation");
print("Database adaptors opened\n");

# GIFTS database connection
my $dbc = get_gifts_dbc($giftsdb_name,$giftsdb_schema,$giftsdb_host,$giftsdb_user,$giftsdb_pass,$giftsdb_port);

# fetch the items we want to update
my $sql_gifts_mapped = "SELECT mapping_id,uniprot_id,transcript_id FROM ensembl_uniprot WHERE mapping_history_id=".$mapping_history_id;
my $sth_gifts_mapped = $dbc->prepare($sql_gifts_mapped);
$sth_gifts_mapped->execute() or die "Could not fetch the mapping list:\n".$dbc->errstr;


# Add the alignment run into the database
my $alignment_run_id = -1;
my $sql_alignment_run = "INSERT INTO alignment_run (score1_type,pipeline_name,pipeline_comment,pipeline_script,userstamp,mapping_history_id,logfile_dir,uniprot_file_swissprot,uniprot_file_isoform,uniprot_dir_trembl,ensembl_release,score2_type,report_type) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)";
my $sth = $dbc->prepare($sql_alignment_run);
$sth->bind_param(1,'uniprot protein length');
$sth->bind_param(2,$pipeline_name);
$sth->bind_param(3,$pipeline_comment);
$sth->bind_param(4,"GIFTS/scripts/eu_length_compare.pl");
$sth->bind_param(5,$user);
$sth->bind_param(6,$mapping_history_id);
$sth->bind_param(7,$output_dir);
if ($uniprot_sp_file) {
  $sth->bind_param(8,$uniprot_sp_file);
}
if ($uniprot_sp_isoform_file) {
  $sth->bind_param(9,$uniprot_sp_isoform_file);
}
if ($uniprot_tr_dir) {
  $sth->bind_param(10,$uniprot_tr_dir);
}
$sth->bind_param(11,$release);
$sth->bind_param(12,'ensembl translation length');
$sth->bind_param(13,'longer entry');

$sth->execute() or die "Could not add the alignment run:\n".$dbc->errstr;
$alignment_run_id = $sth->{mysql_insertid};
$sth->finish();
print("Alignment run $alignment_run_id\n");


# The main loop
while(my @row = $sth_gifts_mapped->fetchrow_array) {
  my $mapping_id = $row[0];
  my $uniprot_id = $row[1];
  my $gifts_transcript_id = $row[2];

  print(DEBUG_INFO "PROCESSING mapping_id:$mapping_id,uniprot_id:$uniprot_id,gifts_transcript_id:$gifts_transcript_id\n");
  # get the uniprot accession,sequence
  my $uniprot_acc = fetch_uniprot_accession($uniprot_id);
  print(DEBUG_INFO "uniprot id=$uniprot_id acc=$uniprot_acc\n");
  my $uniprot_seq = undef;
  foreach my $ui (@uniprot_archive_parsers) {
    if ($ui->has_sequence($uniprot_acc)) {
       $uniprot_seq = $ui->get_sequence_no_length($uniprot_acc);
       goto UNIPROT_SEQUENCE_FOUND;
    }
  }
  UNIPROT_SEQUENCE_FOUND:

  # Get the Ensembl transcript ID and translated sequence
  my $enst_id = fetch_transcript_ids($dbc,$gifts_transcript_id);
  print(DEBUG_INFO "transcript id=$gifts_transcript_id enst_id=$enst_id\n");
  my $transcript = $transcript_adaptor->fetch_by_stable_id($enst_id);
  my $translation_seq = undef;
  if ($transcript->translate) {
    my $translation = $transcript->translate();
    $translation_seq = $translation->seq();
  }

  # perform the length comparison
  if ($uniprot_seq && $translation_seq) {
    my $longest = "UNIPROT";
    if (length($uniprot_seq) == length($translation_seq)) {
      $longest = "EQUAL";
    }
    elsif (length($uniprot_seq) < length($translation_seq)) {
      my $longest = "ENSEMBL";
    }
    # store the result
    store_alignment($dbc,$alignment_run_id,
                     $uniprot_id,$gifts_transcript_id,$mapping_id,
                     length($uniprot_seq),length($translation_seq),$longest);
  } else {
    if ($translation_seq) {
      print(UNIPROT_NOSEQS "UNIPROT,$mapping_id,$uniprot_acc,\n");
    } elsif ($uniprot_seq) {
      print(UNIPROT_NOSEQS "ENSP,$mapping_id,,$enst_id\n");
    } else {
      print(UNIPROT_NOSEQS "BOTH,$mapping_id,$uniprot_acc accession,$enst_id\n");
    }
  }
}
CLOSE:
$dbc->disconnect;
close DEBUG_INFO;
close UNIPROT_NOSEQS;
