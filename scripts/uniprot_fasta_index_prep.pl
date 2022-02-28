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

uniprot_fasta_index_prep.pl -

=head1 DESCRIPTION

  This script creates the uniprot fasta files index files required by the alignment scripts.

=cut

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Mapper;
use DBI qw(:sql_types);
use LWP::UserAgent;
use Bio::DB::HTS::Faidx;

#
# Set options
#

my $uniprot_sp_file;
my $uniprot_sp_isoform_file;
my $uniprot_tr_dir = "";


GetOptions(
        'uniprot_sp_file=s' => \$uniprot_sp_file,
        'uniprot_sp_isoform_file=s' => \$uniprot_sp_isoform_file,
        'uniprot_tr_dir=s' => \$uniprot_tr_dir,
   );

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
