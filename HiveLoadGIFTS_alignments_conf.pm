=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package HiveLoadGIFTS_alignments_conf;

use warnings;
use strict;
use feature 'say';
use File::Spec::Functions;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');
use base ('Bio::EnsEMBL::Analysis::Hive::Config::HiveBaseConfig_conf');

use Bio::EnsEMBL::ApiVersion qw/software_version/;

sub default_options {
  my ($self) = @_;
  return {
    # inherit other stuff from the base class
	  %{ $self->SUPER::default_options() },

'pipeline_name' => 'gifts_alignments_loading',
'pipeline_comment_perfect_match' => 'Perfect matches between Ensembl and UniProt proteins.',
'pipeline_comment_blast_cigar' => 'Blasts and cigars between Ensembl and UniProt proteins.',

'enscode_root_dir' => '/path/to/enscode/',
'userstamp' => 'ensembl_gifts_loading_pipeline', # username to be registered as the one loading the Ensembl data
#'user_r' => '', # read-only user
'user_w' => '', # write user for the pipeline db
'password' => '', # write password for the pipeline db
'driver' => 'mysql',

# no need to modify this
'prepare_uniprot_script' => $self->o('enscode_root_dir').'/GIFTS/scripts/uniprot_fasta_prep.sh',
'prepare_uniprot_index_script' => $self->o('enscode_root_dir').'/GIFTS/scripts/uniprot_fasta_index_prep.pl',
'perfect_match_script' => $self->o('enscode_root_dir').'/GIFTS/scripts/eu_alignment_perfect_match.pages.pl',
'blast_cigar_script' => $self->o('enscode_root_dir').'/GIFTS/scripts/eu_alignment_blast_cigar.pl',

'rest_server' => '', # GIFTS REST API server URL
'latest_release_mapping_history_url' => $self->o('rest_server').'mappings/release_history/latest/assembly/',
'mappings_by_release_mapping_history_url' => $self->o('rest_server').'/mappings/release_history/',
'alignment_run_url' => $self->o('rest_server').'alignments/alignment_run/',
'alignments_by_alignment_run_url' => $self->o('rest_server').'alignments/alignment/alignment_run/',

'release' => 95, # ensembl release corresponding to the Ensembl gene set in GIFTS to be used

# server containing the Ensembl core databases containing the gene sets to be used
'registry_host' => '',
'registry_user' => '', # read-only user 
'registry_pass' => '', # read-only password
'registry_port' => '',

'uniprot_dir' => '/path/to/uniprot/knowledgebase/', # path where the UniProt fasta files are stored

# database details for the eHive pipe database
'server1' => '',
'port1' => '',
'pipeline_dbname' => 'USERNAME_'.$self->o('pipeline_name'), # this db will be created

'pipeline_db' => {
                    -dbname => $self->o('pipeline_dbname'),
                    -host   => $self->o('server1'),
                    -port   => $self->o('port1'),
                    -user   => $self->o('user_w'),
                    -pass   => $self->o('password'),
                    -driver => $self->o('driver'),
                 },

  };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
      # inheriting database and hive tables' creation
	    @{$self->SUPER::pipeline_create_commands},
    ];
  }


## See diagram for pipeline structure
sub pipeline_analyses {
    my ($self) = @_;

    return [
       {
         -input_ids  => [
                          {
                            assembly => 'GRCh38',
                            species => 'homo_sapiens',
                            output_dir => '/path/to/output_dir/#species#/',
                            # output files
                            'import_species_data_output_file' => '#output_dir#/ensembl_import_species_data.out',
                            'perfect_match_alignments_output_file' => '#output_dir#/perfect_match_alignments.out',
                            'perfect_alignment_run_id_output_file' => '#output_dir#/perfect_alignment_run_id.out',
                            'blast_alignment_run_id_output_file' => '#output_dir#/blast_alignment_run_id.out',

                            # these files will be created during the 'prepare_uniprot_files' analysis
                            # from the uniprot_dir files above and they will be used by the perfect match alignment script
                            'uniprot_sp_file' => '#output_dir#/uniprot_sp.cleaned.fa.gz',
                            'uniprot_sp_isoform_file' => '#output_dir#/uniprot_sp_isoforms.cleaned.fa.gz',
                            'uniprot_tr_dir' => '#output_dir#/trembl20/',
                          },
                          {
                            assembly => 'GRCm38',
                            species => 'mus_musculus',
                            output_dir => '/path/to/output_dir/#species#/',
                            # output files
                            'import_species_data_output_file' => '#output_dir#/ensembl_import_species_data.out',
                            'perfect_match_alignments_output_file' => '#output_dir#/perfect_match_alignments.out',
                            'perfect_alignment_run_id_output_file' => '#output_dir#/perfect_alignment_run_id.out',
                            'blast_alignment_run_id_output_file' => '#output_dir#/blast_alignment_run_id.out',

                            # these files will be created during the 'prepare_uniprot_files' analysis
                            # from the uniprot_dir files above and they will be used by the perfect match alignment script
                            'uniprot_sp_file' => '#output_dir#/uniprot_sp.cleaned.fa.gz',
                            'uniprot_sp_isoform_file' => '#output_dir#/uniprot_sp_isoforms.cleaned.fa.gz',
                            'uniprot_tr_dir' => '#output_dir#/trembl20/',
                          }
         ],
       

      # Loop for 7 days maximum to detect if the UniProt mappings have been loaded into
      # the GIFTS database for the given ensembl_species_history_id.

        -logic_name => 'wait_for_uniprot_mappings',
        -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        -parameters => {
                          use_bash_pipefail => 1, # Boolean. When true, the command will be run with "bash -o pipefail -c $cmd". Useful to capture errors in a command that contains pipes
                          use_bash_errexit  => 1, # When the command is composed of multiple commands (concatenated with a semi-colon), use "bash -o errexit" so that a failure will interrupt the whole script

                          # 7 days (604800s) max checking every 10 minutes (600s)
                          cmd => 'ENSEMBLSPECIESHISTORYID=$(grep "Added ensembl_species_history_id" #import_species_data_output_file#'.
                                 ' | awk \'{print $3}\');'.
                                 'end=$((SECONDS+604800));'.
                                 'while [[ ( $SECONDS -lt $end ) && '.
                                 '         ( $ENSEMBLSPECIESHISTORYID != $ENSEMBLSPECIESHISTORYID_IN_RMH ) && '.
                                 '         ( $STATUS != "MAPPING_COMPLETED" ) ]]; do '.
                                 
                                 'echo "Fetching release_mapping_history_id for ensembl_species_history_id $ENSEMBLSPECIESHISTORYID ...";'.
                                 'ENSEMBLSPECIESHISTORYID_IN_RMH='.
                                 '$(wget -O - -o /dev/null '.
                                 $self->o('latest_release_mapping_history_url').'#assembly#/'.
                                 ' | jq -r ".ensembl_species_history.ensembl_species_history_id");'.

                                 'STATUS='.
                                 '$(wget -O - -o /dev/null '.
                                 $self->o('latest_release_mapping_history_url').'#assembly#/'.
                                 ' | jq -r ".status");'.
                                 'sleep 600;'.
                                 'done;'.
                                 'if [[ $ENSEMBLSPECIESHISTORYID != $ENSEMBLSPECIESHISTORYID_IN_RMH ]] && '.
                                 '   [[ $STATUS != "MAPPING_COMPLETED" ]]; then exit -1;fi'
                       },
        -rc_name          => 'default',
        -max_retry_count => 0,
        -flow_into => { 1 => ['prepare_uniprot_files'] },
      },

      {
        -logic_name => 'prepare_uniprot_files',
        -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        -parameters => {
                          use_bash_pipefail => 1, # Boolean. When true, the command will be run with "bash -o pipefail -c $cmd". Useful to capture errors in a command that contains pipes
                          use_bash_errexit  => 1, # When the command is composed of multiple commands (concatenated with a semi-colon), use "bash -o errexit" so that a failure will interrupt the whole script
                          cmd => 'sh '.$self->o('prepare_uniprot_script').' '.$self->o('uniprot_dir').' #output_dir#'
                       },
        -rc_name          => 'default',
        -max_retry_count => 0,
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
                                 ' -uniprot_sp_file #uniprot_sp_file#'.
                                 ' -uniprot_sp_isoform_file #uniprot_sp_isoform_file#'.
                                 ' -uniprot_tr_dir #uniprot_tr_dir#'
                       },
        -rc_name    => 'default_30GB',
        -max_retry_count => 0,
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
                                 $self->o('latest_release_mapping_history_url').'#assembly#/'.
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
                                   'uniprot_file_swissprot: "#uniprot_sp_file#", '.
                                   'uniprot_file_isoform: "#uniprot_sp_isoform_file#", '.
                                   'uniprot_dir_trembl: "#uniprot_tr_dir#", '.
                                   'ensembl_release: '.$self->o('release').' }\')'.
                                 '" --header=Content-Type:application/json '.$self->o('alignment_run_url').
                                 ' | jq -r \'.alignment_run_id\');'. # wget should return a json containing the alignment_run_id created
                                 
                                 'echo $PERFECTMATCHALIGNMENTRUNID > #perfect_alignment_run_id_output_file#'
                       },
        -rc_name    => 'default',
        -max_retry_count => 0,
        -flow_into => { 1 => ['make_perfect_mapping_input_ids'] },
      },

      {
        -logic_name => 'make_perfect_mapping_input_ids',
        -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
        -parameters => {
                          inputcmd =>

                          'RELEASEMAPPINGHISTORYID='.
                                 '$(wget -O - -o /dev/null '.
                                 $self->o('latest_release_mapping_history_url').'#assembly#/'.
                                 ' | jq -r ".release_mapping_history_id");'.

                          'NUMMAPPINGS=$(wget -O - -o /dev/null '.
                          $self->o('mappings_by_release_mapping_history_url').'$RELEASEMAPPINGHISTORYID'.
                            ' | jq -r ".count");'.
                          
                          'for PAGENUM in $(seq 1 $(((NUMMAPPINGS+9)/10)));'. # (NUMMAPPINGS+9/10 is the number of pages of 10 elements returned by the REST API 
                          'do '.
                            'echo $PAGENUM;'.
                          'done',

                          column_names => ['page'],
                          step => 200,
        },
        -flow_into => { '2->A' => [ 'perfect_match_alignments' ],
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
                                 $self->o('latest_release_mapping_history_url').'#assembly#/'.
                                 ' | jq -r ".release_mapping_history_id");'.
                                 
                                 'PERFECTMATCHALIGNMENTRUNID=$(head -n1 #perfect_alignment_run_id_output_file# | awk \'{print $1}\');'.
                                 
                                 'perl '.$self->o('perfect_match_script').
                                 ' -output_dir #output_dir#'.
                                 ' -registry_host '.$self->o('registry_host').
                                 ' -registry_user '.$self->o('registry_user').
                                 ' -registry_port '.$self->o('registry_port').
                                 ' -user '.$self->o('userstamp').
                                 ' -species #species#'.
                                 ' -release '.$self->o('release').
                                 ' -release_mapping_history_id $RELEASEMAPPINGHISTORYID'.
                                 ' -uniprot_sp_file #uniprot_sp_file#'.
                                 ' -uniprot_sp_isoform_file #uniprot_sp_isoform_file#'.
                                 ' -uniprot_tr_dir #uniprot_tr_dir#'.
                                 ' -pipeline_name '.$self->o('pipeline_name').
                                 ' -pipeline_comment "'.$self->o('pipeline_comment_perfect_match').'"'.
                                 ' -rest_server '.$self->o('rest_server').
                                 ' -alignment_run_id $PERFECTMATCHALIGNMENTRUNID'.
                                 ' -page "#expr(join(",",@{#_range_list#}))expr#"'
                       },
        -rc_name    => 'default_35GB',

        -max_retry_count => 0,
        -analysis_capacity => 50,
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
                                 $self->o('latest_release_mapping_history_url').'#assembly#/'.
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
                                   'uniprot_file_swissprot: "#uniprot_sp_file#", '.
                                   'uniprot_file_isoform: "#uniprot_sp_isoform_file#", '.
                                   'uniprot_dir_trembl: "#uniprot_tr_dir#", '.
                                   'ensembl_release: '.$self->o('release').' }\')'.
                                 '" --header=Content-Type:application/json '.$self->o('alignment_run_url').
                                 ' | jq -r \'.alignment_run_id\''. # wget should return a json containing the alignment_run_id created
                                 
                                 ' > #blast_alignment_run_id_output_file#'
                       },
        -rc_name    => 'default',
        -max_retry_count => 0,
        -flow_into => { 1 => ['make_blast_mapping_input_ids'] },
        -analysis_capacity => 125,
      },

      {
        -logic_name => 'make_blast_mapping_input_ids',
        -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
        -parameters => {
                          inputcmd =>

                          'PERFECTMATCHALIGNMENTRUNID=$(head -n1 #perfect_alignment_run_id_output_file# | awk \'{print $1}\');'.
                          'NUMALIGNMENTS=$(wget -O - -o /dev/null '.
                          $self->o('alignments_by_alignment_run_url').'$PERFECTMATCHALIGNMENTRUNID'. # alignment_type parameter by default is "perfect_match"
                            ' | jq -r ".count");'.

                          'for PAGENUM in $(seq 1 $(((NUMALIGNMENTS+9)/10)));'. # (NUMALIGNMENTS+9/10 is the number of pages of 10 elements returned by the REST API 
                          'do '.
                            'wget -O - -o /dev/null '.
                          $self->o('alignments_by_alignment_run_url').'$PERFECTMATCHALIGNMENTRUNID/?page=$PAGENUM'.
                            ' | jq -r ".results[] | select(.score1 == 0)"'.
                            ' | jq -r ".mapping";'.
                          'done',

                          column_names => ['mapping_id'],
                          step => 100,
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
                                 'PERFECTMATCHALIGNMENTRUNID=$(grep "Alignment run" #perfect_match_alignments_output_file#'.
                                 ' | awk \'{print $3}\');'.

                                 'ALIGNMENTRUNID=$(head -n1 #blast_alignment_run_id_output_file# | awk \'{print $1}\');'.

                                 'perl '.$self->o('blast_cigar_script').
                                 ' -user '.$self->o('userstamp').
                                 ' -perfect_match_alignment_run_id $PERFECTMATCHALIGNMENTRUNID'.
                                 ' -registry_host '.$self->o('registry_host').
                                 ' -registry_user '.$self->o('registry_user').
                                 ' -registry_port '.$self->o('registry_port').
                                 ' -pipeline_name '.$self->o('pipeline_name').
                                 ' -pipeline_comment "'.$self->o('pipeline_comment_blast_cigar').'"'.
                                 ' -rest_server '.$self->o('rest_server').
                                 ' -output_dir #output_dir#'.
                                 ' -alignment_run_id $ALIGNMENTRUNID'.
                                 ' -mapping_id "#expr(join(",",@{#_range_list#}))expr#"'
                       },
        -rc_name    => 'default_30GB',
        -max_retry_count => 0,
        -analysis_capacity => 50,
      },
      
      {
        -logic_name => 'set_alignment_completed',
        -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        -parameters => {
                          use_bash_pipefail => 1, # Boolean. When true, the command will be run with "bash -o pipefail -c $cmd". Useful to capture errors in a command that contains pipes
                          use_bash_errexit  => 1, # When the command is composed of multiple commands (concatenated with a semi-colon), use "bash -o errexit" so that a failure will interrupt the whole script
                          cmd =>  'echo "DONE"'
                       },
        -rc_name    => 'default',
        -max_retry_count => 0,
      },
    ];
  }

sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class
        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    };
}

sub pipeline_wide_parameters {
    my ($self) = @_;

    return {
	    %{ $self->SUPER::pipeline_wide_parameters() },  # inherit other stuff from the base class
    };
  }

sub resource_classes {
    my $self = shift;
    return {
      'default' => { LSF => '-M1900 -R"select[mem>1900] rusage[mem=1900]"' },
      'default_20GB' => { LSF => '-M20000 -R"select[mem>20000] rusage[mem=20000]"' },
      'default_30GB' => { LSF => '-M30000 -R"select[mem>30000] rusage[mem=30000]"' },
    }
  }

1;
