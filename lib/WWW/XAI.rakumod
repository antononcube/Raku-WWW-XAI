unit module WWW::XAI;

use JSON::Fast;
use WWW::XAI::Request;

#| Access the xAI Responses, image, video, and text-to-speech APIs.
our proto xai-console($text = '', Str :$path = 'chat', *%args) is export {*}

multi sub xai-console(*%args) {
    xai-console('', |%args);
}

multi sub xai-console(@texts, *%args) {
    @texts.map({ xai-console($_, |%args) }).Array;
}

multi sub xai-console($text,
                      Str :$path = 'chat',
                      :api-key(:$auth-key) = Whatever,
                      UInt :$timeout = 10,
                      :$format = Whatever,
                      Str :$method = 'tiny',
                      Str :$model = 'grok-4.5',
                      :$role = Whatever,
                      :max-tokens(:$max-output-tokens) = Whatever,
                      :$temperature = Whatever,
                      :$top-p = Whatever,
                      :@tools = Empty,
                      :$input = Whatever,
                      *%args) {
    my $echo = %args<echo> // False;
    my $endpoint = $path.lc.subst(/^ 'generate' /, '').subst(/^ '/' /, '');
    my $url = 'https://api.x.ai/v1';
    my %body;

    given $endpoint {
        when $_ ∈ <chat code responses> {
            $url ~= '/responses';
            %body<model> = $model;
            %body<input> = $input.isa(Whatever) ?? _input($text, $role) !! $input;
            %body<max_output_tokens> = $max-output-tokens unless $max-output-tokens.isa(Whatever);
            %body<temperature> = $temperature unless $temperature.isa(Whatever);
            %body<top_p> = $top-p unless $top-p.isa(Whatever);
            %body<tools> = @tools.Array if @tools;
            %body{$_} = %args{$_} for %args.keys.grep(* ∈ <instructions stream store reasoning_effort stop>);
        }
        when $_ eq 'image' {
            $url ~= '/images/generations';
            %body = :$model, prompt => $text.Str;
            %body{$_} = %args{$_} for %args.keys.grep(* ∈ <n response_format aspect_ratio>);
        }
        when $_ eq 'video' {
            $url ~= '/videos/generations';
            %body = :$model, prompt => $text.Str;
            %body{$_} = %args{$_} for %args.keys.grep(* ∈ <duration aspect_ratio resolution>);
        }
        when $_ eq 'voice' {
            $url ~= '/tts';
            %body = text => $text.Str, voice_id => (%args<voice-id> // %args<voice_id> // 'eve'),
                     language => (%args<language> // 'en');
        }
        default { die "Unknown xAI path '$path'. Expected chat, code, image, video, or voice." }
    }

    xai-request(:$url, body => to-json(%body), :$auth-key, :$timeout, :$format, :$method, :$echo);
}

sub _input($text, $role) {
    return $text unless $role ~~ Str:D;
    [{ role => $role, content => $text.Str }];
}
