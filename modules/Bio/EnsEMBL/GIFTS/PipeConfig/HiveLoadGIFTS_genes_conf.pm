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

 Bio::EnsEMBL::GIFTS::PipeConfig::HiveLoadGIFTS_genes_conf

=head1 DESCRIPTION

 Export Ensembl genes from core databases.
 
 Mandatory parameters without default values:
  -registry_vert     DB server containing vertebrate species, in url format
  -registry_nonvert  DB server containing non-vertebrate species, in url format
  -base_output_dir   Path for output files

=cut

package Bio::EnsEMBL::GIFTS::PipeConfig::HiveLoadGIFTS_genes_conf;

use warnings;
use strict;
use feature 'say';

use base ('Bio::EnsEMBL::GIFTS::PipeConfig::HiveLoadGIFTS_conf');

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'gifts_genes_loading',

    enscode_root_dir      => $self->o('ensembl_cvs_root_dir'),
    import_species_script => $self->o('enscode_root_dir').'/GIFTS/scripts/ensembl_import_species_data.pl',

  };
}

sub pipeline_wide_parameters {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::pipeline_wide_parameters},
    'import_species_data_file' => 'ensembl_import_species_data.out',
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
                       '2->A' => ['import_species_data'],
                       'A->3' => ['notify'],
                     },
    },

    {
      -logic_name => 'import_species_data',
      -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -parameters => {
                        use_bash_pipefail => 1, # Boolean. When true, the command will be run with "bash -o pipefail -c $cmd". Useful to capture errors in a command that contains pipes
                        use_bash_errexit  => 1, # When the command is composed of multiple commands (concatenated with a semi-colon), use "bash -o errexit" so that a failure will interrupt the whole script
                        cmd => 'mkdir -p #output_dir#;'.
                               'perl '.$self->o('import_species_script').
                               ' -user '.$self->o('userstamp').
                               ' -species #species#'.
                               ' -release #ensembl_release#'.
                               ' -registry_vert #registry_vert#'.
                               ' -registry_nonvert #registry_nonvert#'.
                               ' -rest_server #rest_server#'.
                               ' -auth_token #auth_token#'.
                               ' > #output_dir#/#import_species_data_file#'
                     },
      -rc_name    => 'default_20GB',
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

