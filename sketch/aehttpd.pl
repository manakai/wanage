use strict;
use warnings;
use AnyEvent::HTTPD;
use Data::Dumper;
use Wanage::Interface::AnyEventHTTPD;

  my $httpd = AnyEvent::HTTPD->new (port => 9090);

    $httpd->reg_cb (
        request => sub {
          my ($httpd, $req) = @_;

          my $if = Wanage::Interface::AnyEventHTTPD->new_from_httpd_and_req($httpd, $req);
          
          warn Dumper [
              $req->url,
              $req->headers,
              $req->content,
              $if->get_meta_variable('REQUEST_URI'),
              $if->get_meta_variable('CONTENT_TYPE'),
              $if->get_meta_variable('HTTP_ACCEPT'),
              ${$if->get_request_body_as_ref || \''},
          ];

          $if->send_response_headers(
              status => 205,
              status_text => 'Hoge',
              headers => [
                  ['Content-Type' => 'image/png'],
                  ['Content-Type', 'text/html'],
              ],
          );
          $if->send_response(onready => sub {
              $if->send_response_body("hoge");
              $if->send_response_body(' fuga');
              $if->close_response_body;
          });
       },
    );

    $httpd->run;
