package Test::Wanage::Envs;
use strict;
use warnings;
use Exporter::Lite;

our @EXPORT;

push @EXPORT, qw(with_cgi_env);
sub with_cgi_env (&;$$$) {
  my ($code, $env, $stdin_data, $stdout_data) = @_;
  local %ENV = %{$env or {}};
  local *STDIN;
  local *STDOUT;
  open STDIN, '<', \($_[2]) if defined $stdin_data;
  open STDOUT, '>', \($_[3]) if defined $stdout_data;
  return $code->();
} # with_cgi_env

push @EXPORT, qw(new_psgi_env);
sub new_psgi_env (;$%) {
  my ($env, %args) = @_;
  $env ||= {};
  open $env->{'psgi.input'}, '<', \($args{input_data})
    if defined $args{input_data};
  return $env;
} # new_psgi_env

{
  package Test::Wanage::Envs::PSGI::Writer;

  sub new {
    return bless {data => []}, $_[0];
  }
  
  sub write {
    push @{$_[0]->{data}}, $_[1];
  }

  sub close {
    $_[0]->{closed}++;
  }

  sub data { $_[0]->{data} }
  sub closed { $_[0]->{closed} }
}

1;
