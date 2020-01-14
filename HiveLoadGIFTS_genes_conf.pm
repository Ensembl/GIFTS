=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

package HiveLoadGIFTS_genes_conf;

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

'pipeline_name' => 'gifts_genes_loading',

'enscode_root_dir' => '/path/to/enscode/',
'userstamp' => 'ensembl_gifts_loading_pipeline', # username to be registered as the one loading the Ensembl data
'user_w' => '', # write user for the pipeline db
'password' => '', # write password for the pipeline db
'driver' => 'mysql',

'import_species_script' => $self->o('enscode_root_dir').'/GIFTS/scripts/ensembl_import_species_data.pl', # no need to modify this

'rest_server' => '', # GIFTS REST API server URL

'release' => 95, # ensembl release corresponding to the Ensembl gene set in GIFTS to be used

# server containing the Ensembl core databases containing the gene sets to be used
'registry_host' => '',
'registry_user' => '', # read-only user 
'registry_pass' => '', # read-only password
'registry_port' => '',

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
                         },
                         {
                            assembly => 'GRCm38',
                            species => 'mus_musculus',
                            output_dir => '/path/to/output_dir/#species#/',
                            # output files
                            'import_species_data_output_file' => '#output_dir#/ensembl_import_species_data.out',
                         }
        ],

        -logic_name => 'import_species_data',
        -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        -parameters => {
                          use_bash_pipefail => 1, # Boolean. When true, the command will be run with "bash -o pipefail -c $cmd". Useful to capture errors in a command that contains pipes
                          use_bash_errexit  => 1, # When the command is composed of multiple commands (concatenated with a semi-colon), use "bash -o errexit" so that a failure will interrupt the whole script
                          cmd => 'mkdir -p #output_dir#;'.
                                 'perl '.$self->o('import_species_script').
                                 ' -user '.$self->o('userstamp').
                                 ' -species #species#'.
                                 ' -release '.$self->o('release').
                                 ' -registry_host '.$self->o('registry_host').
                                 ' -registry_user '.$self->o('registry_user').
                                 ' -registry_port '.$self->o('registry_port').
                                 ' -rest_server '.$self->o('rest_server').
                                 ' > #import_species_data_output_file#'
                       },
        -rc_name    => 'default_20GB',
        -max_retry_count => 0,
        #-flow_into => { 1 => ['wait_for_uniprot_mappings'] },
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
      'default_20GB' => { LSF => '-M20000 -R"select[mem>20000] rusage[mem=20000]"' },
    }
  }

1;
