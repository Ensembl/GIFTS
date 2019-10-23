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
Bio::EnsEMBL::GIFTS::Notify

=head1 DESCRIPTION
Store result in hive database, and optionally send email notification.

=cut

package Bio::EnsEMBL::GIFTS::Notify;

use strict;
use warnings;
use feature 'say';

use JSON;

use base ('Bio::EnsEMBL::Hive::RunnableDB::NotifyByEmail');

sub run {
  my $self = shift;

  if ($self->param_is_defined('email')) {
    $self->set_email_parameters();
    $self->SUPER::run();
  }
}

sub write_output {
  my $self = shift;

  my $output = {
    job_id => $self->param('job_id'),
    output => $self->param('base_output_dir'),
  };

  $self->dataflow_output_id($output, 1);
}

sub set_email_parameters {
  my $self = shift;

  my $subject = "GIFTS pipeline submission completed";

  my $text = "Submitted: ".$self->param('submitted')."\n";
  $text   .= "Ensembl Release: ".$self->param('release')."\n";

  my $tag = $self->param('tag');
  if (defined $tag) {
    $subject .= " ($tag)";
    $text    .= "Submission tag: $tag\n";
  }

  $text .= "Output directory: ".$self->param('base_output_dir')."/".$self->param('release')."\n";

  $self->param('subject', $subject);
  $self->param('text', $text);
}

1;
