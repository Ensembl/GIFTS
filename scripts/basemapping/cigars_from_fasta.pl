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

cigars_from_fasta.pl -

=head1 DESCRIPTION

  This script compares two fasta files and runs muscle on the output.

=cut

use strict;
use warnings;

use Bio::SeqIO;
use Bio::EnsEMBL::GIFTS::BaseMapping qw(make_cigar_string  make_cigar_plus_string make_md_string);
use Getopt::Long;

my $file_uniprot;
my $file_ensp;
my $folder_muscle;

GetOptions(
        'f1=s' => \$file_uniprot,
        'f2=s' => \$file_ensp,
        'outdir=s' => \$folder_muscle,
         );

if (!$file_uniprot || !$file_ensp || !$folder_muscle) {
  print "Error: Usage\n\tperl cigars_from_fasta.pl -f1 [fasta_file_1] -f2 [fasta_file_2] -outdir [output_dir]";
  exit -1;
}

unless(-d $folder_muscle) {
  mkdir $folder_muscle;
}

my $uniprots = Bio::SeqIO->new(-file => $file_uniprot,-format => "fasta");
my $ensps = Bio::SeqIO->new(-file => $file_ensp,-format => "fasta");
my $count = 0;

while (my $seqobj_u = $uniprots->next_seq) {
  $count++;
  my $seqobj_e = $ensps->next_seq;

  # write out and process a file with the pair of sequences to be compared
  my $muscle_source_filename =  "$folder_muscle/$count.for_muscle.fasta";
  my $muscle_output_filename =  "$folder_muscle/$count.from_muscle.fasta";
  my $muscle_source = Bio::SeqIO->new(-file => ">$muscle_source_filename",'-format' => 'fasta');
  $muscle_source->write_seq($seqobj_u);
  $muscle_source->write_seq($seqobj_e);
  $muscle_source->close;

  system("muscle -in $muscle_source_filename -out $muscle_output_filename -quiet");

  # open the muscle file for processing
  my $compared =  Bio::SeqIO->new(-file => $muscle_output_filename,-format => "fasta");
  my $seqobj_compu = $compared->next_seq;
  my $seqobj_compe = $compared->next_seq;

  # make the cigar string
  my $cigar_string = make_cigar_string($seqobj_compu->seq,$seqobj_compe->seq);
  my $cigar_plus_string = make_cigar_plus_string($seqobj_compu->seq,$seqobj_compe->seq);
  my $md_string = make_md_string($seqobj_compu->seq,$seqobj_compe->seq);
  printf("------------ NEXT SEQUENCE ".$seqobj_u->id."-----------------\n");
  printf($seqobj_compu->seq."\n");
  printf($cigar_string."(CIGAR)\n");
  printf($cigar_plus_string."(CIGAR+)\n");
  printf($md_string."\n");
  printf($seqobj_compe->seq."\n");
  printf("------------ END SEQUENCE ".$seqobj_u->id."-----------------\n");
}

exit 0;
