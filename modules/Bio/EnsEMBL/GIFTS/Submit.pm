=head1 LICENSE
Copyright [2018] EMBL-European Bioinformatics Institute

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
Bio::EnsEMBL::GIFTS::Submit

=head1 DESCRIPTION
Perform housekeeping tasks that make it easier to seed jobs.

=cut

package Bio::EnsEMBL::GIFTS::Submit;

use strict;
use warnings;
use feature 'say';

use JSON;
use Path::Tiny;
use Time::Piece;

use base ('Bio::EnsEMBL::Hive::Process');

sub write_output {
  my $self = shift;

  # This module is a single point of entry into the pipeline, to enable
  # an eternal beekeeper to be seeded with multiple runs.
  # Pipeline-wide parameter propagation is switched on, so we just need
  # to pass on all the input parameters in order for subsequent modules
  # to have the data they need. There's no way in hive to get all the
  # parameters in a data structure, so need to do it the long-winded way,
  # which does at least make it explicit what we're doing...
  # We also add the job_id for this analysis, in order to be able to
  # associate results summaries with the relevant submission.

  unless (defined $self->param('timestamp')) {
    $self->param('timestamp', localtime->cdate);
  }

  # A subset of the input parameters are stored in the 'gifts_submission'
  # table, for easier subsequent retrieval than querying the native hive tables.
  my %submission_output = (
    job_id    => $self->input_job->dbID,
    tag       => $self->param('tag'),
    email     => $self->param('email'),
    submitted => $self->param('timestamp'),
  );
  $self->dataflow_output_id(\%submission_output, 1);

  my $species_list = $self->param('species_list');
  foreach (@$species_list) {
    my $assembly   = $$_{'assembly'};
    my $species    = $$_{'species'};
    my $output_dir = $self->param('base_output_dir')."/$species";

    my $species_output = {
      assembly   => $assembly,
      species    => $species,
      output_dir => $output_dir,
    };
    $self->dataflow_output_id($species_output, 2);
  }

  my %notify_output = (
    %submission_output,
    base_output_dir => $self->param('base_output_dir'),
  );
  $self->dataflow_output_id(\%notify_output, 3);
}

1;
