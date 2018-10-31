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

package HiveLoadGIFTS_conf;

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

'enscode_root_dir' => '/path/to/enscode/',

'release' => ,              # Ensembl release number corresponding to the species gene sets to be imported
'registry_host' => '',      # Ensembl databases server
'registry_port' => '',      # Ensembl databases port
'registry_user' => '',      # Ensembl databases read-only user
'registry_pass' => '',      # Ensembl databases read-only password

# GIFTS database details including read-only (r) and write (w) credentials
'giftsdb_host' => '',
'giftsdb_r_user' => '',
'giftsdb_r_pass' => '',
'giftsdb_w_user' => '',
'giftsdb_w_pass' => '',
'giftsdb_name' => '',
'giftsdb_schema' => '',
'giftsdb_port' => '',

'uniprot_dir' => '/path/to/uniprot/knowledgebase/', # path where the UniProt fasta files are stored

# database details for the eHive pipe database
'server1' => '',
'port1' => '',
'user_w' => '',      # write user for the pipeline db
'password' => '',    # write password for the pipeline db
'driver' => 'mysql', # driver for the pipeline db

# no need to modify anything below this line EXCEPT FOR the 'output_dir' in the 'input_ids' section 
'userstamp' => 'ensembl_gifts_loading_pipeline', # username to be registered as the one loading the Ensembl data
'pipeline_name' => 'gifts_loading',
'pipeline_dbname' => $self->o('pipeline_name'), # this db will be created

'pipeline_comment_perfect_match' => 'Perfect matches between Ensembl and UniProt proteins.',
'pipeline_comment_blast_cigar' => 'Blasts and cigars between Ensembl and UniProt proteins.',

'pipeline_db' => {
                    -dbname => $self->o('pipeline_dbname'),
                    -host   => $self->o('server1'),
                    -port   => $self->o('port1'),
                    -user   => $self->o('user_w'),
                    -pass   => $self->o('password'),
                    -driver => $self->o('driver'),
                 },
  };
  
'import_species_script'  => $self->o('enscode_root_dir').'/GIFTS/scripts/ensembl_import_species_data.pl', # no need to modify this
'prepare_uniprot_script' => $self->o('enscode_root_dir').'/GIFTS/scripts/uniprot_fasta_prep.sh',          # no need to modify this
'perfect_match_script'   => $self->o('enscode_root_dir').'/GIFTS/scripts/eu_alignment_perfect_match.pl',  # no need to modify this
'blast_cigar_script'     => $self->o('enscode_root_dir').'/GIFTS/scripts/eu_alignment_blast_cigar.pl',    # no need to modify this
  
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
                            species => 'homo_sapiens',
                            output_dir => '/path/to/GIFTS_#species#/',
                            # output files
                            'import_species_data_output_file' => '#output_dir#/ensembl_import_species_data.out',
                            'perfect_match_alignments_output_file' => '#output_dir#/perfect_match_alignments.out',

                            # these files will be created during the 'prepare_uniprot_files' analysis
                            # from the uniprot_dir files above and they will be used by the perfect match alignment script
                            'uniprot_sp_file' => '#output_dir#/uniprot_sp.cleaned.fa.gz',
                            'uniprot_sp_isoform_file' => '#output_dir#/uniprot_sp_isoforms.cleaned.fa.gz',
                            'uniprot_tr_dir' => '#output_dir#/trembl20/',
                         },
                         {
                            species => 'mus_musculus',
                            output_dir => '/path/to/GIFTS_#species#/',
                            # output files
                            'import_species_data_output_file' => '#output_dir#/ensembl_import_species_data.out',
                            'perfect_match_alignments_output_file' => '#output_dir#/perfect_match_alignments.out',

                            # these files will be created during the 'prepare_uniprot_files' analysis
                            # from the uniprot_dir files above and they will be used by the perfect match alignment script
                            'uniprot_sp_file' => '#output_dir#/uniprot_sp.cleaned.fa.gz',
                            'uniprot_sp_isoform_file' => '#output_dir#/uniprot_sp_isoforms.cleaned.fa.gz',
                            'uniprot_tr_dir' => '#output_dir#/trembl20/',
                         }
        ],

        -logic_name => 'import_species_data',
        -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        -parameters => {
                          cmd => 'mkdir -p #output_dir#;'.
                                 'perl '.$self->o('import_species_script').
                                 ' -user '.$self->o('userstamp').
                                 ' -species #species#'.
                                 ' -release '.$self->o('release').
                                 ' -registry_host '.$self->o('registry_host').
                                 ' -registry_user '.$self->o('registry_user').
                                 ' -registry_port '.$self->o('registry_port').
                                 ' -giftsdb_host '.$self->o('giftsdb_host').
                                 ' -giftsdb_user '.$self->o('giftsdb_w_user').
                                 ' -giftsdb_pass '.$self->o('giftsdb_w_pass').
                                 ' -giftsdb_name '.$self->o('giftsdb_name').
                                 ' -giftsdb_schema '.$self->o('giftsdb_schema').
                                 ' -giftsdb_port '.$self->o('giftsdb_port').
                                 ' > #import_species_data_output_file#'
                       },
        -rc_name    => 'default',
        -max_retry_count => 0,
        -flow_into => { 1 => ['wait_for_uniprot_mappings'] },
      },

      # Loop for 7 days maximum to detect if the UniProt mappings have been loaded into
      # the GIFTS database for the given ensembl_species_history_id.
      {
        -logic_name => 'wait_for_uniprot_mappings',
        -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        -parameters => {
                          # 7 days (604800s) max checking every 10 minutes (600s)
                          cmd => 'ENSEMBLSPECIESHISTORYID=$(grep "Added ensembl_species_history_id" #import_species_data_output_file#'.
                                 ' | awk \'{print $3}\');'.
                                 'end=$((SECONDS+604800));'.
                                 'while [[ ( $SECONDS -lt $end ) && ( $RELEASEMAPPINGHISTORYID -eq "0" ) ]]; do '.
                                 
                                 'echo "Fetching release_mapping_history_id for ensembl_species_history_id $ENSEMBLSPECIESHISTORYID ...";'.
                                 'RELEASEMAPPINGHISTORYID='.
                                 '$(PGPASSWORD='.$self->o('giftsdb_r_pass').
                                 ' psql -h '.$self->o('giftsdb_host').
                                 '      -p '.$self->o('giftsdb_port').
                                 '      -d '.$self->o('giftsdb_name').
                                 '      -U '.$self->o('giftsdb_r_user').
                                 '   -t -c "SET search_path TO '.$self->o('giftsdb_schema').'; '.
                                 '          SELECT release_mapping_history_id '.
                                 '          FROM release_mapping_history '.
                                 '          WHERE release_mapping_history_id NOT IN (SELECT release_mapping_history_id '.
                                 '                                                   FROM alignment_run) '.
                                 '                AND ensembl_species_history_id=$ENSEMBLSPECIESHISTORYID'.
                                 '                AND status=\'MAPPING_COMPLETED\''.
                                 '          ORDER BY time_mapped DESC LIMIT 1;'.
                                 '         ");'.

                                 'sleep 600;'.
                                 'done;'.
                                 'if [ $RELEASEMAPPINGHISTORYID -eq "0" ]; then exit -1;fi'
                       },
        -rc_name          => 'default',
        -max_retry_count => 0,
        -flow_into => { 1 => ['prepare_uniprot_files'] },
      },

      {
        -logic_name => 'prepare_uniprot_files',
        -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        -parameters => {
                          cmd => 'sh '.$self->o('prepare_uniprot_script').' '.$self->o('uniprot_dir').' #output_dir#'
                       },
        -rc_name          => 'default',
        -max_retry_count => 0,
        -flow_into => { 1 => ['perfect_match_alignments'] },
      },

      {
        -logic_name => 'perfect_match_alignments',
        -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        -parameters => {
                          cmd => 'ENSEMBLSPECIESHISTORYID=$(grep "Added ensembl_species_history_id" #import_species_data_output_file#'.
                                 ' | awk \'{print $3}\');'.
                                 
                                 'RELEASEMAPPINGHISTORYID='.
                                 '$(PGPASSWORD='.$self->o('giftsdb_r_pass').
                                 ' psql -h '.$self->o('giftsdb_host').
                                 '      -p '.$self->o('giftsdb_port').
                                 '      -d '.$self->o('giftsdb_name').
                                 '      -U '.$self->o('giftsdb_r_user').
                                 '   -t -c "SET search_path TO '.$self->o('giftsdb_schema').'; '.
                                 '          SELECT release_mapping_history_id '.
                                 '          FROM release_mapping_history '.
                                 '          WHERE release_mapping_history_id NOT IN (SELECT release_mapping_history_id '.
                                 '                                                   FROM alignment_run) '.
                                 '                AND ensembl_species_history_id=$ENSEMBLSPECIESHISTORYID'.
                                 '                AND status=\'MAPPING_COMPLETED\''.
                                 '          ORDER BY time_mapped DESC LIMIT 1;'.
                                 '         ");'.
                                 
                                 'perl '.$self->o('perfect_match_script').
                                 ' -output_dir #output_dir#'.
                                 ' -giftsdb_host '.$self->o('giftsdb_host').
                                 ' -giftsdb_user '.$self->o('giftsdb_w_user').
                                 ' -giftsdb_pass '.$self->o('giftsdb_w_pass').
                                 ' -giftsdb_name '.$self->o('giftsdb_name').
                                 ' -giftsdb_schema '.$self->o('giftsdb_schema').
                                 ' -giftsdb_port '.$self->o('giftsdb_port').
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
                                 ' -pipeline_comment '.$self->o('pipeline_comment_perfect_match').
                                 ' > #perfect_match_alignments_output_file#'
                       },
        -rc_name    => 'default_10GB',
        -max_retry_count => 0,
        -flow_into => { 1 => ['blast_cigar_alignments'] },
      },

      {
        -logic_name => 'blast_cigar_alignments',
        -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        -parameters => {
                          cmd => 'PERFECTMATCHALIGNMENTRUNID=$(grep "Alignment run" #perfect_match_alignments_output_file#'.
                                 ' | awk \'{print $3}\');'.
                                 
                                 'perl '.$self->o('blast_cigar_script').
                                 ' -user '.$self->o('userstamp').
                                 ' -perfect_match_alignment_run_id $PERFECTMATCHALIGNMENTRUNID'.
                                 ' -giftsdb_host '.$self->o('giftsdb_host').
                                 ' -giftsdb_user '.$self->o('giftsdb_w_user').
                                 ' -giftsdb_pass '.$self->o('giftsdb_w_pass').
                                 ' -giftsdb_name '.$self->o('giftsdb_name').
                                 ' -giftsdb_schema '.$self->o('giftsdb_schema').
                                 ' -giftsdb_port '.$self->o('giftsdb_port').
                                 ' -registry_host '.$self->o('registry_host').
                                 ' -registry_user '.$self->o('registry_user').
                                 ' -registry_port '.$self->o('registry_port').
                                 ' -pipeline_name '.$self->o('pipeline_name').
                                 ' -pipeline_comment '.$self->o('pipeline_comment_blast_cigar').
                                 ' -output_dir #output_dir#'
                       },
        -rc_name    => 'default_10GB',
        -max_retry_count => 0,
        -flow_into => { 1 => ['blast_cigar_alignments'] },
      }
    ];
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
      'default_10GB' => { LSF => '-M10000 -R"select[mem>10000] rusage[mem=10000]"' },
    }
  }

1;
