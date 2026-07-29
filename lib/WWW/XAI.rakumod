unit module WWW::XAI;

use JSON::Fast;
use Image::Markup::Utilities;
use WWW::XAI::Request;

#==========================================================
# Utilities
#==========================================================
our sub xai-base-url() is export {
    return 'https://api.x.ai/v1';
}

sub process_input($text, $role) {
    return $text unless $role ~~ Str:D;
    [{ role => $role, content => $text.Str },];
}

sub is-message($message --> Bool) {
    if $message ~~ Map {
        return False unless $message<role>:exists;
        return $message<content>:exists;
    }
    if $message ~~ Pair {
        return False unless $message.key ~~ Str:D;
        return $message.value.defined;
    }
    False;
}

sub process_messages(@messages) {
    return Nil unless @messages.elems;

    my $all-messages = [&&] @messages.map(*.&is-message);
    return Nil unless $all-messages;

    @messages.map({
        if $_ ~~ Map {
            $_
        } else {
            %(role => $_.key.Str, content => $_.value.Str)
        }
    }).Array;
}


#==========================================================
# Models
#==========================================================
sub xai-models(
        :api-key(:$auth-key) = Whatever,
        Str:D :$method = 'tiny',
        :$format = 'values',
        UInt:D :$timeout = 10,
        Bool:D :$echo = False) is export {
    xai-console('', path => 'models', :$auth-key, :$method, :$timeout, :$format, :$echo)
}

#==========================================================
# Get video
#==========================================================
sub xai-video-record(Str:D $video-id, *%args) is export {
    xai-console('', path => 'video', :$video-id, |%args)
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
    my $messages = process_messages(@texts);
    return xai-console('', input => $messages, |%args) if $messages.defined;
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
                      :$video-id = Whatever,
                      :$base-url = xai-base-url(),
                      *%args) {
    my $echo = %args<echo> // False;
    my $endpoint = $video-id.isa(Whatever) ?? $path.lc !! 'video';
    my $url = $base-url;
    my %body;

    given $endpoint {
        when $_ ∈ <chat code responses> {
            if $model.isa(Whatever) { $model = 'grok-4.3' }
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
            if $model.isa(Whatever) { $model = 'grok-imagine-image-quality' }
            my $response-format = %args<response-format> // 'url';
            die "For images the argment \$response-format is expected to be one of 'b64_json', 'url', or Whatever."
            unless $response-format ∈ <b64_json url>;
            $url ~= '/images/generations';
            %body = :$model, prompt => $text.Str, response_format => $response-format;
            %body{$_} = %args{$_} for %args.keys.grep(* ∈ <n aspect_ratio>);
        }

        when $_ ∈ <image-edit images-edits images/edits> {
            die 'For image edits the argument "image" have to be specified.'
            unless %args<image>;

            if $model.isa(Whatever) { $model = 'grok-imagine-image-quality' }
            my $response-format = %args<response-format> // 'url';

            # Regex for Base64 string
            my $re-base64-start = /^ [ 'data:image/' <[a..zA..Z0..9.+-]>+ ';base64,' ] /;
            my $re-base64 = /^ [ 'data:image/' <[a..zA..Z0..9.+-]>+ ';base64,' ]? [ <[A..Za..z0..9+/_\-] > ** 4 ]* [ <[A..Za..z0..9+/_\-] > ** 2 '==' | <[A..Za..z0..9+/_\-] > ** 3 '=' ]? $/;

            # TBD
            my $image = do given %args<image> {
                # check if image is a URL
                when $_ ~~ / ^ 'http' .? '://' / { %( url => $_, type => 'image_url') }

                # check if image is a file path
                when $_ ~~ Str:D && $_.chars ≤ 2000 && $_.IO.f {
                    my $ext = do with $_ ~~ / '.' (.+) / { $0.Str } // 'png';
                    my $img = image-encode($_.IO, type => $ext);
                    %( url => $img, type => 'image_url')
                }

                # check if it is a Base64 string
                when $_ ~~ $re-base64 {
                    %( url => $_ ~~ $re-base64-start ?? $_ !! 'data:image/png;base64,' ~ $_,
                       type => 'image_url')
                }

                default {
                    die 'The value of the argument image is expected to be a URL, file path, or Base64 string.'
                }
            }

            $url ~= '/images/edits';
            %body = :$model, prompt => $text.Str, response_format => $response-format, :$image;
            %body{$_} = %args{$_} for %args.keys.grep(* ∈ <n aspect_ratio>);
        }

        when $_ ∈ <models> {
            $url ~= '/models';
        }

        when $_ ∈ <video videos videos/generations> {
            if $model.isa(Whatever) { $model = 'grok-imagine-video' }
            if $video-id.isa(Whatever) {
                $url ~= '/videos/generations';
                %body = :$model, prompt => $text.Str;
                %body{$_} = %args{$_} for %args.keys.grep(* ∈ <duration aspect_ratio resolution>);
            } else {
                $url ~= "/videos/$video-id";
            }
        }

        when $_ ∈ <voice tts> {
            $url ~= '/tts';
            %body = text => $text.Str, voice_id => (%args<voice-id> // %args<voice_id> // 'eve'),
                     language => (%args<language> // 'en');
        }
        default { die "Unknown xAI path '$path'. Expected chat, code, image, video, or voice." }
    }

    note (:$url) if $echo;
    note (:%body) if $echo;

    xai-request(:$url, body => to-json(%body), :$auth-key, :$timeout, :$format, :$method,
                http-method => ($endpoint eq 'models' || $endpoint eq 'video') ?? 'GET' !! 'POST', :$echo);
}
