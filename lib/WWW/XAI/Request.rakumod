unit module WWW::XAI::Request;

use JSON::Fast;
use HTTP::Tiny;

proto sub tiny-post(Str :$url!, |) is export {*}

sub tiny-get(Str :$url!, Str :api-key(:$auth-key)!, UInt :$timeout = 10) is export {
    my $response = HTTP::Tiny.get: $url,
        headers => { Authorization => "Bearer $auth-key" };
    response-content($response, $url);
}

multi sub tiny-post(Str :$url!, Str :$body!, Str :api-key(:$auth-key)!, UInt :$timeout = 10) {
    my $response = HTTP::Tiny.post: $url,
        headers => {
            Authorization => "Bearer $auth-key",
            Content-Type => 'application/json',
        },
        content => $body;

    response-content($response, $url);
}

multi sub tiny-post(Str :$url!, :$body! where * ~~ Map, Str :api-key(:$auth-key)!, UInt :$timeout = 10) {
    tiny-post(:$url, body => to-json($body), :$auth-key, :$timeout);
}

sub response-content(%response, Str $url --> Str) {
    my $content = %response<content> // '';
    my $status = %response<status> // 0;

    if $status < 200 || $status >= 300 {
        my $error = try { from-json($content) } // %(
            error => %(
                message => $content || "xAI request failed with HTTP status $status.",
                code => $status,
            )
        );
        if $! {
            $error = $content.decode;
        }
        fail $error;
    }

    $content ~~ Blob ?? $content.decode !! $content.Str;
}

proto sub xai-request(Str :$url!, :$body!, |) is export {*}

multi sub xai-request(Str:D :$url!,
                      :$body!,
                      :api-key(:$auth-key) is copy = Whatever,
                      UInt:D :$timeout = 10,
                      :$format = Whatever,
                      Str:D :$method = 'tiny',
                      Str:D :$http-method = 'POST',
                      Bool:D :$echo = False) {
    if $auth-key.isa(Whatever) {
        $auth-key = %*ENV<XAI_API_KEY> // %*ENV<GROKXAI_API_KEY> // Whatever;
    }

    fail %(
        error => %(
            message => 'Cannot find xAI authorization key. Please provide auth-key or set XAI_API_KEY.',
            code => 401,
            status => 'NO_API_KEY',
        )
    ) if $auth-key.isa(Whatever);

    die "The argument auth-key is expected to be a string."
        unless $auth-key ~~ Str:D && $auth-key.chars;
    die "The argument method is expected to be 'tiny'."
        unless $method.lc eq 'tiny';

    my $response = $http-method.uc eq 'GET'
        ?? tiny-get(:$url, :$auth-key, :$timeout)
        !! tiny-post(:$url, body => $body ~~ Map ?? $body !! $body.Str, :$auth-key, :$timeout);
    return $response if $format.isa(Whatever) || $format.lc ∈ <asis as-is as_is>;

    my $decoded = try { from-json($response) };

    note (decoded => $decoded.raku) if $echo;

    return $response unless $decoded.defined;
    if $decoded ~~ Map {
        fail $decoded if $decoded<error>;
    }

    given $format.lc {
        when 'json' { to-json($decoded) }
        when 'values' { xai-values($decoded) }
        default { $decoded }
    }
}

sub xai-values(Mu $response --> Mu) is export {
    if $response ~~ Map {
        return $response<output_text> if $response<output_text>:exists;

        if $response<data>:exists {
            # Assuming models rere requested
            my @ids = $response<data>.grep(* ~~ Map).map(*<id>).grep(*.defined);
            return @ids.join("\n") if @ids;
        }
    }

    my @texts = gather {
        if $response ~~ Map {
            if $response<output>:exists {
                for $response<output>.grep({ $_<type> eq 'message' }) -> %item {
                    for |%item<content> -> %content {
                        take %content<text> if %content<text>:exists;
                    }
                }
            } elsif $response<data>:exists {
                # Assuming images were generated
                for |$response<data> -> %item {
                    take %item<b64_json> // %item<url>
                }
            }
        }
    };

    return @texts[0] if @texts.elems == 1;
    return @texts.Array if @texts;
    $response;
}
