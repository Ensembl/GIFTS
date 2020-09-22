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

package Bio::EnsEMBL::GIFTS::PipeConfig::HiveLoadGIFTS_conf;

use warnings;
use strict;
use feature 'say';

use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    # Username to be registered as the one loading the Ensembl data
    # Must not exceed 15 characters in length
    userstamp => 'gifts_pipeline',

    # In order to seed the database multiple times, we need the
    # species list here, rather than specified via 'input_id'.
    species_list => [
      {
        assembly   => 'GRCh38',
        species    => 'homo_sapiens',
      },
      {
        assembly => 'GRCm38',
        species  => 'mus_musculus',
      }
    ],

    # Parameters to track submissions
    tag             => undef,
    email           => undef,
    ensembl_release => undef,
    rest_server     => undef,
    auth_token      => undef,
    timestamp       => undef,

    # Switch off automatic retries
    hive_default_max_retry_count => 0,

  };
}

# Implicit parameter propagation throughout the pipeline.
sub hive_meta_table {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack' => 1,
  };
}

sub pipeline_create_commands {
  my ($self) = @_;

  my $submission_table_sql = q/
    CREATE TABLE gifts_submission (
      job_id INT PRIMARY KEY,
      tag VARCHAR(255) NULL,
      email VARCHAR(255) NULL,
      ensembl_release INT NOT NULL,
      submitted VARCHAR(255) NULL
    );
  /;

  my $result_table_sql = q/
    CREATE TABLE result (
      job_id INT PRIMARY KEY,
      output TEXT
    );
  /;

  my $drop_input_id_index = q/
    ALTER TABLE job DROP KEY input_id_stacks_analysis;
  /;

  my $extend_input_id = q/
    ALTER TABLE job MODIFY input_id TEXT;
  /;

  return [
    @{$self->SUPER::pipeline_create_commands},
    $self->db_cmd($submission_table_sql),
    $self->db_cmd($result_table_sql),
    $self->db_cmd($drop_input_id_index),
    $self->db_cmd($extend_input_id),
  ];
}

sub resource_classes {
  my $self = shift;
  return {
    'default'      => { LSF => '-q production-rh74 -M1900 -R"select[mem>1900] rusage[mem=1900]"' },
    'default_25GB' => { LSF => '-q production-rh74 -M20000 -R"select[mem>25000] rusage[mem=25000]"' },
    'default_50GB' => { LSF => '-q production-rh74 -M35000 -R"select[mem>50000] rusage[mem=50000]"' },
  }
}

1;
