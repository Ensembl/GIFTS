=head1 LICENSE
Copyright [2018-2022] EMBL-European Bioinformatics Institute

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

use File::Spec::Functions qw(catdir);
use JSON qw(encode_json);
use Time::Piece;

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
    output_dir => $self->param('base_output_dir'),
    timestamp  => localtime->cdate
  };

  my $result = {
    job_id => $self->param('job_id'),
    output => encode_json($output),
  };

  $self->dataflow_output_id($result, 1);
}

sub set_email_parameters {
  my $self = shift;

  my $tag             = $self->param('tag');
  my $email           = $self->param('email');
  my $ensembl_release = $self->param('ensembl_release');
  my $submitted       = $self->param('submitted');
  my $base_output_dir = $self->param('base_output_dir');

  my $subject = "GIFTS pipeline submission completed";

  my $text = "Submitted: $submitted\n";
  $text   .= "Ensembl Release: $ensembl_release\n";

  if (defined $tag) {
    $subject .= " ($tag)";
    $text    .= "Submission tag: $tag\n";
  }

  $text .= "Output directory: ".catdir($base_output_dir, $ensembl_release)."\n";

  $self->param('subject', $subject);
  $self->param('text', $text);
}

1;
