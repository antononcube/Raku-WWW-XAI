unit module WWW::XAI;

use JSON::Fast;
use WWW::XAI::Request;

#==========================================================
# Utilities
#==========================================================

sub process_input($text, $role) {
    return $text unless $role ~~ Str:D;
    [{ role => $role, content => $text.Str },];
}


#==========================================================
#
#==========================================================
sub xai-models(
        :api-key(:$auth-key) = Whatever,
        Str:D :$method = 'tiny',
        UInt:D :$timeout = 10,
        Bool:D :$echo = False) is export {
    xai-console('', path => 'models', :$auth-key, :$method, :$timeout, :$echo)
}

#==========================================================
# XAI console
#==========================================================

#| Access the XAI responses, images, videos, and text-to-speech APIs.
our proto xai-console($text = '', Str:D :$path = 'chat', *%args) is export {*}

multi sub xai-console(*%args) {
    xai-console('', |%args);
}

multi sub xai-console(@texts, *%args) {
    @texts.map({ xai-console($_, |%args) }).Array;
}

multi sub xai-console(Str:D $text,
                      Str:D :$path = 'chat',
                      :api-key(:$auth-key) = Whatever,
                      UInt:D :$timeout = 10,
                      :$format = Whatever,
                      Str:D :$method = 'tiny',
                      :$model is copy = Whatever,
                      :$role = Whatever,
                      :max-tokens(:$max-output-tokens) = Whatever,
                      :$temperature = Whatever,
                      :$top-p = Whatever,
                      :@tools = Empty,
                      :$input = Whatever,
                      *%args) {
    if $model.isa(Whatever) { $model = 'grok-3' }
    my $echo = %args<echo> // False;
    my $endpoint = $path.lc;
    my $url = 'https://api.x.ai/v1';
    my %body;

    given $endpoint {
        when $_ ∈ <chat code responses> {
            $url ~= '/responses';
            %body<model> = $model;
            %body<input> = $input.isa(Whatever) ?? process_input($text, $role) !! $input;
            %body<max_output_tokens> = $max-output-tokens unless $max-output-tokens.isa(Whatever);
            %body<temperature> = $temperature unless $temperature.isa(Whatever);
            %body<top_p> = $top-p unless $top-p.isa(Whatever);
            %body<tools> = @tools.Array if @tools;
            %body{$_} = %args{$_} for %args.keys.grep(* ∈ <instructions stream store reasoning_effort stop>);
        }
        when $_ ∈ <image images images/generations> {
            $url ~= '/images/generations';
            %body = :$model, prompt => $text.Str;
            %body{$_} = %args{$_} for %args.keys.grep(* ∈ <n response_format aspect_ratio>);
        }
        when $_ ∈ <models> {
            $url ~= '/models';
        }
        when $_ ∈ <video videos videos/generations> {
            $url ~= '/videos/generations';
            %body = :$model, prompt => $text.Str;
            %body{$_} = %args{$_} for %args.keys.grep(* ∈ <duration aspect_ratio resolution>);
        }
        when $_ ∈ <voice tts> {
            $url ~= '/tts';
            %body = text => $text.Str, voice_id => (%args<voice-id> // %args<voice_id> // 'eve'),
                     language => (%args<language> // 'en');
        }
        default { die "Unknown xAI path '$path'. Expected chat, code, image, video, or voice." }
    }

    note (:%body) if $echo;

    xai-request(:$url, body => to-json(%body), :$auth-key, :$timeout, :$format, :$method,
                http-method => $endpoint eq 'models' ?? 'GET' !! 'POST', :$echo);
}
