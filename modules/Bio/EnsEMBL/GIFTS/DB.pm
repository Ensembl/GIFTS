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

Bio::EnsEMBL::GIFTS::DB -

=head1 DESCRIPTION

  This module contains a set of methods to fetch data from and store data to the GIFTS database.

=cut


package Bio::EnsEMBL::GIFTS::DB;

use strict;
use warnings;

use Data::Dumper;
use DBI qw(:sql_types);
use LWP::UserAgent;
use Bio::DB::HTS::Faidx;
use HTTP::Tiny;
use JSON;

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(rest_get
                  rest_post
                  fetch_uniprot_accession
                  fetch_true_uniprot_accession
                  fetch_uniprot_info_for_id
                  store_alignment
                  fetch_transcript_enst
                  fetch_cigarmdz
                  store_cigarmdz
                  is_perfect_eu_match_uniparcs
                  fetch_latest_uniprot_enst_perfect_matches
               );

# send a get request to the GIFTS REST server
sub rest_get {
  my $endpoint = shift;
  
  my $server = "";
  
  my $http = HTTP::Tiny->new();
  my $response = $http->get($server.$endpoint,{headers => { 'Content-type' => 'application/json' }});

  if (!($response->{'success'} or $response->{'status'} == 301 or $response->{'status'} == 404)) { # the endpoints return 404 if something is not found but this is successful
    print STDERR Dumper($response);
    die("REST server GET failed at endpoint: ".$server.$endpoint."\n".Dumper($response));
  }
  
  if (length($response->{'content'}) > 0) {
    # return reference to hash containing data in json format
    return (decode_json($response->{'content'}));
  } else {
    print STDERR Dumper($response);
    die("REST server GET response length is 0. Failed at endpoint: ".$server.$endpoint."\n");
  }
}

# send a post request to the GIFTS REST server
sub rest_post {
  my ($auth_token,$endpoint,$content_hash_ref) = @_;

  my $http = HTTP::Tiny->new();
  my $response;

  if ($content_hash_ref) {
    $response = $http->post($endpoint,{headers => { 'Authorization' => 'Bearer '.$auth_token,
                                                    'Content-type' => 'application/json',
                                                    'Accept' => 'application/json' },
                                                content => encode_json($content_hash_ref)});
  } else { # some POST don't require content
    $response = $http->post($endpoint,{headers => {'Authorization' => 'Bearer '.$auth_token,
                                                   'Content-type' => 'application/json',
                                                   'Accept' => 'application/json'}});
  }

  if (!($response->{'success'} or $response->{'task_id'})) {
    print STDERR Dumper($response);
    die("REST server POST failed at endpoint: ".$endpoint."\n");
  }
  
  if (length($response->{'content'}) > 0) {
    # return reference to hash containing data in json format
    return (decode_json($response->{'content'}));
  } else {
    print STDERR Dumper($response);
    die("REST server POST response length is 0. Failed at endpoint: ".$endpoint."\n");
  }
}

# Use the UniParc identifier as a comparison tool
sub is_perfect_eu_match_uniparcs {
  my ($rest_server,$uniprot_id,$transcript_id) = @_;

  my $uniprot_entry = rest_get($rest_server."/uniprot/entry/".$uniprot_id);
  my $transcript = rest_get($rest_server."/ensembl/transcript/".$transcript_id);

  return $uniprot_entry->{'upi'} eq $transcript->{'uniparc_accession'};
}

sub fetch_uniprot_info_for_id {
  my ($rest_server,$uniprot_id,@uniprot_archive_parsers) = @_;

  my $uniprot_seq = undef;
  my ($uniprot_true_acc,$uniprot_seq_version) = fetch_true_uniprot_accession($rest_server,$uniprot_id);
  foreach my $ui (@uniprot_archive_parsers) {
    if ($ui->has_sequence($uniprot_true_acc)) {
      $uniprot_seq = $ui->get_sequence_no_length($uniprot_true_acc);
      return($uniprot_seq,$uniprot_true_acc,$uniprot_seq_version);
    }
  }

  my ($uniprot_acc,$uniprot_seq_version2) = fetch_uniprot_accession($rest_server,$uniprot_id);
  if ($uniprot_acc ne $uniprot_true_acc) {
    foreach my $ui (@uniprot_archive_parsers) {
      if ($ui->has_sequence($uniprot_acc)) {
        $uniprot_seq = $ui->get_sequence_no_length($uniprot_acc);
        return($uniprot_seq,$uniprot_acc,$uniprot_seq_version2);
      }
    }
  }
  return;
}

sub fetch_uniprot_accession {
  my ($rest_server,$uniprot_id) = @_;

  my $uniprot_entry = rest_get($rest_server."/uniprot/entry/".$uniprot_id);
  my $uniprot_acc = $uniprot_entry->{'uniprot_acc'};
  my $sequence_version = $uniprot_entry->{'sequence_version'};

  # strip a preceding $ from the accession - this may be stored in GIFTS
  # redundant entries are special cases,but they still can be mapped
  $uniprot_acc =~ s/\$//g;

  # strip -1 at the end of uniprot accessions. These are added to the uniprot entries
  # but these are not present in the downloaded swissprot files
  $uniprot_acc =~ s/-1//;

  return ($uniprot_acc,$sequence_version);
}

sub fetch_true_uniprot_accession {
  my ($rest_server,$uniprot_id) = @_;
  
  my $uniprot_entry = rest_get($rest_server."/uniprot/entry/".$uniprot_id);
  my $uniprot_acc = $uniprot_entry->{'uniprot_acc'};
  my $sequence_version = $uniprot_entry->{'sequence_version'};

  return ($uniprot_acc,$sequence_version);
}

sub fetch_transcript_enst {
  my ($rest_server,$gifts_transcript_id) = @_;
  
  my $transcript = rest_get($rest_server."/ensembl/transcript/".$gifts_transcript_id);

  return $transcript->{'enst_id'};
}

sub store_alignment {
  my ($auth_token,$rest_server,$alignment_run_id,$uniprot_id,$transcript_id,$mapping_id,$score1,$score2,$report) = @_;

  my $alignment = {
                     alignment_run => $alignment_run_id,
                     uniprot_id => $uniprot_id,
                     transcript => $transcript_id,
                     mapping => $mapping_id,
                     score1 => $score1,
                     score2 => $score2,
                     report => $report
  };
  my $alignment_response = rest_post($auth_token,$rest_server."/alignments/alignment/",$alignment); 
  return $alignment_response->{'alignment_id'};
}

sub store_cigarmdz {
  my ($auth_token,$rest_server,$alignment_id,$cigar_plus_string,$md_string) = @_;

  my $cigar = {
                 alignment => $alignment_id,
                 cigarplus => $cigar_plus_string,
                 mdz => $md_string
  };
  my $cigar_response = rest_post($auth_token,$rest_server."/ensembl/cigar/",$cigar);

  # update the "alignment_difference" column in the "mapping" table
  # alignment_difference is the sum of I, D and X in the cigarplus string
  my $alignment_difference = 0;
  while ($cigar_plus_string =~ /([0-9]+)(.)/g) {
    if ($2 eq "I" or
        $2 eq "D" or
        $2 eq "X") {
      $alignment_difference += $1;
    }
  }

  my $alignment = rest_get($rest_server."/alignments/alignment/".$alignment_id);
  my $old_mapping = rest_get($rest_server."/mapping/".$alignment->{'mapping'});
  my $alignment_difference_response = rest_post($auth_token,$rest_server."/mapping/".$old_mapping->{'mapping'}->{'mappingId'}."/alignment_difference/".$alignment_difference."/");
}

sub fetch_cigarmdz {
  my ($rest_server,$alignment_id) = @_;

  my $cigar = rest_get($rest_server."/ensembl/cigar/alignment/".$alignment_id);
  my $cigar_plus_string = $cigar->{'cigarplus'};
  my $md_string = $cigar->{'mdz'};

  return ($cigar_plus_string,$md_string);
}

sub fetch_latest_uniprot_enst_perfect_matches {
# It returns a reference to a hash containing Uniprot protein accessions as keys
# and the corresponding Ensembl transcript stable IDs as an array of values for a given
# species name (ie 'Homo sapiens') and assembly accession (ie 'GRCh38').

  my ($rest_server,$assembly) = @_;

  my $latest_alignments = rest_get($rest_server."/alignments/alignment/latest/assembly/".$assembly."?alignment_type=perfect_match");
  
  my %perfect_matches;
  foreach my $alignment (@{$latest_alignments}) { # hash to array here?
    my $uniprot_acc = fetch_true_uniprot_accession($rest_server,$alignment->{'uniprot_id'});
    my $enst_id = fetch_transcript_enst($rest_server,$alignment->{'transcript'});
    push(@{$perfect_matches{$uniprot_acc}},$enst_id);
  }

  return \%perfect_matches;
}

1;
