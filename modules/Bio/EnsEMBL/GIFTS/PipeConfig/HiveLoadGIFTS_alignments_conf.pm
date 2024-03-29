=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

 Bio::EnsEMBL::GIFTS::PipeConfig::HiveLoadGIFTS_alignments_conf;

=head1 DESCRIPTION

 Alignment of Ensembl and UniProt data.
 
 Mandatory parameters without default values:
  -registry_vert     DB server containing vertebrate species, in url format
  -registry_nonvert  DB server containing non-vertebrate species, in url format
  -uniprot_dir      path to UniProt fasta files
  -base_output_dir  Location of output files

=cut

package Bio::EnsEMBL::GIFTS::PipeConfig::HiveLoadGIFTS_alignments_conf;

use warnings;
use strict;
use feature 'say';

use base ('Bio::EnsEMBL::GIFTS::PipeConfig::HiveLoadGIFTS_conf');

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'gifts_alignments_loading',

    pipeline_comment_perfect_match => 'Perfect matches between Ensembl and UniProt proteins.',
    pipeline_comment_blast_cigar   => 'Blasts and cigars between Ensembl and UniProt proteins.',

    enscode_root_dir             => $self->o('ensembl_cvs_root_dir'),
    prepare_uniprot_script       => $self->o('enscode_root_dir').'/GIFTS/scripts/uniprot_fasta_prep.sh',
    prepare_uniprot_index_script => $self->o('enscode_root_dir').'/GIFTS/scripts/uniprot_fasta_index_prep.pl',
    perfect_match_script         => $self->o('enscode_root_dir').'/GIFTS/scripts/eu_alignment_perfect_match.pl',
    blast_cigar_script           => $self->o('enscode_root_dir').'/GIFTS/scripts/eu_alignment_blast_cigar.pl',

    latest_release_mapping_history_url      => '/mappings/release_history/latest/assembly/',
    mappings_by_release_mapping_history_url => '/mappings/release_history/',
    alignment_run_url                       => '/alignments/alignment_run/',
    alignments_by_alignment_run_url         => '/alignments/alignment/alignment_run/',
    set_alignment_status_url                => '/ensembl/species_history/',
  };
}

sub pipeline_wide_parameters {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::pipeline_wide_parameters},
    'import_species_data_file'      => 'ensembl_import_species_data.out',
    'perfect_alignment_run_id_file' => 'perfect_alignment_run_id.out',
    'blast_alignment_run_id_file'   => 'blast_alignment_run_id.out',

    # These files will be created during the 'prepare_uniprot_files' analysis
    # from the uniprot_dir files and they will be used by the perfect match alignment script
    'uniprot_sp_file'         => 'uniprot_sp.cleaned.fa.gz',
    'uniprot_sp_isoform_file' => 'uniprot_sp_isoforms.cleaned.fa.gz',
    'uniprot_tr_dir'          => 'trembl20/',
  };
}

sub pipeline_analyses {
  my ($self) = @_;

  return [
    {
      -logic_name => 'submit',
      -module     => 'Bio::EnsEMBL::GIFTS::Submit',
      -parameters => {
                       registry_vert    => $self->o('registry_vert'),
                       registry_nonvert => $self->o('registry_nonvert'),
                       species_list     => $self->o('species_list'),
                       base_output_dir  => $self->o('base_output_dir'),
                       tag              => $self->o('tag'),
                       email            => $self->o('email'),
                       ensembl_release  => $self->o('ensembl_release'),
                       rest_server      => $self->o('rest_server'),
                       auth_token       => $self->o('auth_token'),
                       timestamp        => $self->o('timestamp'),
                     },
      -rc_name    => 'default',
      -flow_into  => {
                       '1'    => ['?table_name=gifts_submission'],
                       '2->A' => ['prepare_uniprot_files'],
                       'A->3' => ['notify'],
                     },
    },

    {
      -logic_name => 'prepare_uniprot_files',
      -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -parameters => {
                        use_bash_pipefail => 1, # Boolean. When true, the command will be run with "bash -o pipefail -c $cmd". Useful to capture errors in a command that contains pipes
                        use_bash_errexit  => 1, # When the command is composed of multiple commands (concatenated with a semi-colon), use "bash -o errexit" so that a failure will interrupt the whole script
                        cmd => 'mkdir -p #output_dir# ; sh '.$self->o('prepare_uniprot_script').' '.$self->o('uniprot_dir').' #output_dir#'
                     },
      -rc_name   => 'datamover',
      -flow_into => { 1 => ['prepare_uniprot_files_indexes'] },
    },

    {
      -logic_name => 'prepare_uniprot_files_indexes',
      -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -parameters => {
                        use_bash_pipefail => 1, # Boolean. When true, the command will be run with "bash -o pipefail -c $cmd". Useful to capture errors in a command that contains pipes
                        use_bash_errexit  => 1, # When the command is composed of multiple commands (concatenated with a semi-colon), use "bash -o errexit" so that a failure will interrupt the whole script
                        cmd =>
                               'perl '.$self->o('prepare_uniprot_index_script').
                               ' -uniprot_sp_file #output_dir#/#uniprot_sp_file#'.
                               ' -uniprot_sp_isoform_file #output_dir#/#uniprot_sp_isoform_file#'.
                               ' -uniprot_tr_dir #output_dir#/#uniprot_tr_dir#'
                     },
      -rc_name   => 'default_50GB',
      -flow_into => { 1 => ['insert_alignment_run_id_for_perfect'] },
    },

    {
      -logic_name => 'insert_alignment_run_id_for_perfect',
      -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -parameters => {
                        use_bash_pipefail => 1, # Boolean. When true, the command will be run with "bash -o pipefail -c $cmd". Useful to capture errors in a command that contains pipes
                        use_bash_errexit  => 1, # When the command is composed of multiple commands (concatenated with a semi-colon), use "bash -o errexit" so that a failure will interrupt the whole script
                        cmd =>
                               'RELEASEMAPPINGHISTORYID='.
                               '$(wget -O - -o /dev/null '.
                               '#rest_server#'.$self->o('latest_release_mapping_history_url').'#assembly#/'.
                               ' | jq -r ".release_mapping_history_id");'.

                               'PERFECTMATCHALIGNMENTRUNID='.
                               '$(wget -O - -o /dev/null --post-data="$(jq -n -r --arg rmh "$RELEASEMAPPINGHISTORYID" \'{ '.
                                 'score1_type: "perfect_match", '.
                                 'score2_type: "sp mapping ONE2ONE", '.
                                 'pipeline_name: "'.$self->o('pipeline_name').'", '.
                                 'pipeline_comment: "'.$self->o('pipeline_comment_perfect_match').'", '.
                                 'pipeline_script: "GIFTS/scripts/eu_alignment_perfect_match.pl", '.
                                 'userstamp: "'.$self->o('userstamp').'", '.
                                 'release_mapping_history: $rmh, '.
                                 'logfile_dir: "#output_dir#", '.
                                 'uniprot_file_swissprot: "#output_dir#/#uniprot_sp_file#", '.
                                 'uniprot_file_isoform: "#output_dir#/#uniprot_sp_isoform_file#", '.
                                 'uniprot_dir_trembl: "#output_dir#/#uniprot_tr_dir#", '.
                                 'ensembl_release: #ensembl_release# }\')'.
                               '" --header="Authorization:Bearer #auth_token#" --header=Content-Type:application/json '.'#rest_server#'.$self->o('alignment_run_url').
                               ' | jq -r \'.alignment_run_id\');'. # wget should return a json containing the alignment_run_id created
                               
                               'echo $PERFECTMATCHALIGNMENTRUNID > #output_dir#/#perfect_alignment_run_id_file#'
                     },
      -rc_name   => 'default',
      -flow_into => { 1 => ['make_perfect_mapping_input_ids'] },
    },

    {
      -logic_name => 'make_perfect_mapping_input_ids',
      -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
      -parameters => {
                        inputcmd =>

                        'RELEASEMAPPINGHISTORYID='.
                               '$(wget -O - -o /dev/null '.
                               '#rest_server#'.$self->o('latest_release_mapping_history_url').'#assembly#/'.
                               ' | jq -r ".release_mapping_history_id");'.

                        'NUMMAPPINGS=$(wget -O - -o /dev/null '.
                        '#rest_server#'.$self->o('mappings_by_release_mapping_history_url').'$RELEASEMAPPINGHISTORYID'.
                          ' | jq -r ".count");'.
                        
                        'for PAGENUM in $(seq 1 $(((NUMMAPPINGS+19)/20)));'. # (NUMMAPPINGS+19/20 is the number of pages of 20 elements returned by the REST API 
                        'do '.
                          'echo $PAGENUM;'.
                        'done',

                        column_names => ['page'],
                        step => 200,
                     },
      -flow_into  => { '2->A' => [ 'perfect_match_alignments' ],
                      'A->1' => [ 'insert_alignment_run_id_for_blast' ]}
    },

    {
      -logic_name => 'perfect_match_alignments',
      -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -parameters => {
                        use_bash_pipefail => 1, # Boolean. When true, the command will be run with "bash -o pipefail -c $cmd". Useful to capture errors in a command that contains pipes
                        use_bash_errexit  => 1, # When the command is composed of multiple commands (concatenated with a semi-colon), use "bash -o errexit" so that a failure will interrupt the whole script
                        cmd =>
                               'RELEASEMAPPINGHISTORYID='.
                               '$(wget -O - -o /dev/null '.
                               '#rest_server#'.$self->o('latest_release_mapping_history_url').'#assembly#/'.
                               ' | jq -r ".release_mapping_history_id");'.
                               
                               'PERFECTMATCHALIGNMENTRUNID=$(head -n1 #output_dir#/#perfect_alignment_run_id_file# | awk \'{print $1}\');'.
                               
                               'perl '.$self->o('perfect_match_script').
                               ' -output_dir #output_dir#'.
                               ' -registry_vert #registry_vert#'.
                               ' -registry_nonvert #registry_nonvert#'.
                               ' -user '.$self->o('userstamp').
                               ' -species #species#'.
                               ' -release #ensembl_release#'.
                               ' -release_mapping_history_id $RELEASEMAPPINGHISTORYID'.
                               ' -uniprot_sp_file #output_dir#/#uniprot_sp_file#'.
                               ' -uniprot_sp_isoform_file #output_dir#/#uniprot_sp_isoform_file#'.
                               ' -uniprot_tr_dir #output_dir#/#uniprot_tr_dir#'.
                               ' -pipeline_name '.$self->o('pipeline_name').
                               ' -pipeline_comment "'.$self->o('pipeline_comment_perfect_match').'"'.
                               ' -rest_server #rest_server#'.
                               ' -auth_token #auth_token#'.
                               ' -alignment_run_id $PERFECTMATCHALIGNMENTRUNID'.
                               ' -page "#expr(join(",",@{#_range_list#}))expr#"'
                     },
      -rc_name    => 'default_50GB',
      -analysis_capacity => 25,
      -max_retry_count => 2,
    },

    {
      -logic_name => 'insert_alignment_run_id_for_blast',
      -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -parameters => {
                        use_bash_pipefail => 1, # Boolean. When true, the command will be run with "bash -o pipefail -c $cmd". Useful to capture errors in a command that contains pipes
                        use_bash_errexit  => 1, # When the command is composed of multiple commands (concatenated with a semi-colon), use "bash -o errexit" so that a failure will interrupt the whole script
                        cmd =>
                               'RELEASEMAPPINGHISTORYID='.
                               '$(wget -O - -o /dev/null '.
                               '#rest_server#'.$self->o('latest_release_mapping_history_url').'#assembly#/'.
                               ' | jq -r ".release_mapping_history_id");'.

                               'wget -O - -o /dev/null --post-data="$(jq -n -r --arg rmh "$RELEASEMAPPINGHISTORYID" \'{ '.
                                 'score1_type: "identity", '.
                                 'score2_type: "coverage", '.
                                 'pipeline_name: "'.$self->o('pipeline_name').'", '.
                                 'pipeline_comment: "'.$self->o('pipeline_comment_blast_cigar').'", '.
                                 'pipeline_script: "GIFTS/scripts/eu_alignment_blast_cigar.pl", '.
                                 'userstamp: "'.$self->o('userstamp').'", '.
                                 'release_mapping_history: $rmh, '.
                                 'logfile_dir: "#output_dir#", '.
                                 'uniprot_file_swissprot: "#output_dir#/#uniprot_sp_file#", '.
                                 'uniprot_file_isoform: "#output_dir#/#uniprot_sp_isoform_file#", '.
                                 'uniprot_dir_trembl: "#output_dir#/#uniprot_tr_dir#", '.
                                 'ensembl_release: #ensembl_release# }\')'.
                               '" --header="Authorization:Bearer #auth_token#" --header=Content-Type:application/json '.'#rest_server#'.$self->o('alignment_run_url').
                               ' | jq -r \'.alignment_run_id\''. # wget should return a json containing the alignment_run_id created
                               
                               ' > #output_dir#/#blast_alignment_run_id_file#'
                     },
      -rc_name    => 'default',
      -flow_into  => { 1 => ['make_blast_mapping_input_ids'] },
      -analysis_capacity => 125,
    },

    {
      -logic_name => 'make_blast_mapping_input_ids',
      -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
      -parameters => {
                        inputcmd =>

                        'PERFECTMATCHALIGNMENTRUNID=$(head -n1 #output_dir#/#perfect_alignment_run_id_file# | awk \'{print $1}\');'.
                        'NUMALIGNMENTS=$(wget -O - -o /dev/null '.
                        '#rest_server#'.$self->o('alignments_by_alignment_run_url').'$PERFECTMATCHALIGNMENTRUNID'. # alignment_type parameter by default is "perfect_match"
                          ' | jq -r ".count");'.

                        'for PAGENUM in $(seq 1 $(((NUMALIGNMENTS+19)/20)));'. # (NUMALIGNMENTS+9/10 is the number of pages of 10 elements returned by the REST API 
                        'do '.
                          'wget -O - -o /dev/null '.
                        '#rest_server#'.$self->o('alignments_by_alignment_run_url').'$PERFECTMATCHALIGNMENTRUNID/?page=$PAGENUM'.
                          ' | jq -r ".results[] | select(.score1 == 0)"'.
                          ' | jq -r ".mapping";'.
                        'done',

                        column_names => ['mapping_id'],
                        step => 25,
      },
      -flow_into => { '2->A' => [ 'blast_cigar_alignments' ],
                      'A->1' => [ 'set_alignment_completed' ]}
    },

    {
      -logic_name => 'blast_cigar_alignments',
      -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -parameters => {
                        use_bash_pipefail => 1, # Boolean. When true, the command will be run with "bash -o pipefail -c $cmd". Useful to capture errors in a command that contains pipes
                        use_bash_errexit  => 1, # When the command is composed of multiple commands (concatenated with a semi-colon), use "bash -o errexit" so that a failure will interrupt the whole script
                        cmd =>
                               'PERFECTMATCHALIGNMENTRUNID=$(head -n1 #output_dir#/#perfect_alignment_run_id_file# | awk \'{print $1}\');'.

                               'ALIGNMENTRUNID=$(head -n1 #output_dir#/#blast_alignment_run_id_file# | awk \'{print $1}\');'.

                               'perl '.$self->o('blast_cigar_script').
                               ' -user '.$self->o('userstamp').
                               ' -species #species#'.
                               ' -perfect_match_alignment_run_id $PERFECTMATCHALIGNMENTRUNID'.
                               ' -registry_vert #registry_vert#'.
                               ' -registry_nonvert #registry_nonvert#'.
                               ' -pipeline_name '.$self->o('pipeline_name').
                               ' -pipeline_comment "'.$self->o('pipeline_comment_blast_cigar').'"'.
                               ' -rest_server #rest_server#'.
                               ' -auth_token #auth_token#'.
                               ' -output_dir #output_dir#'.
                               ' -alignment_run_id $ALIGNMENTRUNID'.
                               ' -mapping_id "#expr(join(",",@{#_range_list#}))expr#"'
                     },
      -rc_name    => 'default_25GB',
      -analysis_capacity => 100,
      -max_retry_count => 8,
      -flow_into  => { -1 => ['blast_cigar_alignments_himem'] },
    },
    
    {
      -logic_name => 'blast_cigar_alignments_himem',
      -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -parameters => {
                        use_bash_pipefail => 1, # Boolean. When true, the command will be run with "bash -o pipefail -c $cmd". Useful to capture errors in a command that contains pipes
                        use_bash_errexit  => 1, # When the command is composed of multiple commands (concatenated with a semi-colon), use "bash -o errexit" so that a failure will interrupt the whole script
                        cmd =>
                               'PERFECTMATCHALIGNMENTRUNID=$(head -n1 #output_dir#/#perfect_alignment_run_id_file# | awk \'{print $1}\');'.

                               'ALIGNMENTRUNID=$(head -n1 #output_dir#/#blast_alignment_run_id_file# | awk \'{print $1}\');'.

                               'perl '.$self->o('blast_cigar_script').
                               ' -user '.$self->o('userstamp').
                               ' -species #species#'.
                               ' -perfect_match_alignment_run_id $PERFECTMATCHALIGNMENTRUNID'.
                               ' -registry_vert #registry_vert#'.
                               ' -registry_nonvert #registry_nonvert#'.
                               ' -pipeline_name '.$self->o('pipeline_name').
                               ' -pipeline_comment "'.$self->o('pipeline_comment_blast_cigar').'"'.
                               ' -rest_server #rest_server#'.
                               ' -auth_token #auth_token#'.
                               ' -output_dir #output_dir#'.
                               ' -alignment_run_id $ALIGNMENTRUNID'.
                               ' -mapping_id "#expr(join(",",@{#_range_list#}))expr#"'
                     },
      -rc_name    => 'default_50GB',
      -analysis_capacity => 100,
      -max_retry_count => 8,
    },
    
    {
      -logic_name => 'set_alignment_completed',
      -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -parameters => {
                        use_bash_pipefail => 1, # Boolean. When true, the command will be run with "bash -o pipefail -c $cmd". Useful to capture errors in a command that contains pipes
                        use_bash_errexit  => 1, # When the command is composed of multiple commands (concatenated with a semi-colon), use "bash -o errexit" so that a failure will interrupt the whole script
                        cmd => 'ENSEMBLSPECIESHISTORYID='.
                               '$(wget -O - -o /dev/null '.
                               '#rest_server#'.$self->o('latest_release_mapping_history_url').'#assembly#/'.
                               ' | jq -r ".ensembl_species_history" | jq -r ".ensembl_species_history_id");'.
                               
                               'wget -O- --post-data="" '.
                               '--header="Authorization:Bearer #auth_token#" --header=Content-Type:application/json '.
                               '#rest_server#'.$self->o('set_alignment_status_url').
                               '$ENSEMBLSPECIESHISTORYID/alignment_status/ALIGNMENT_COMPLETED/ '
                     },
      -rc_name    => 'default',
    },
    
    {
      -logic_name => 'notify',
      -module     => 'Bio::EnsEMBL::GIFTS::Notify',
      -rc_name    => 'default',
      -flow_into  => {
                       '1' => ['?table_name=result'],
                     },
    },

  ];
}

1;

