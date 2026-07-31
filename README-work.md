# WWW::XAI

## In brief

This Raku package provides API access to the Large Language Models (LLMs) service [(Space)XAI](https://console.x.ai/), [XAI1].
For more details of the XAI's API usage see [the documentation](https://docs.x.ai/overview), [XAI2].

**Remark:** To use XAI'1 API one has to register and obtain authorization key.

This package is very similar to the packages 
["WWW::OpenAI"](https://github.com/antononcube/Raku-WWW-OpenAI), [AAp1], and 
["WWW::Gemini"](https://github.com/antononcube/Raku-WWW-Gemini), [AAp2]. 

"WWW::XAI" can be used with (is integrated with) 
["LLM::Functions"](https://github.com/antononcube/Raku-LLM-Functions), [AAp3], and
["Jupyter::Chatbook"](https://github.com/antononcube/Raku-Jupyter-Chatbook), [AAp5].

Also, of course, prompts from 
["LLM::Prompts"](https://github.com/antononcube/Raku-LLM-Prompts), [AAp4],
can be used with XAI's functions.

-----

## Installation

Package installations from both sources use [zef installer](https://github.com/ugexe/zef)
(which should be bundled with the "standard" Rakudo installation file.)

To install the package from [Zef ecosystem](https://raku.land/) use the shell command:

```
zef install WWW::XAI
```

To install the package from the GitHub repository use the shell command:

```
zef install https://github.com/antononcube/Raku-WWW-XAI.git
```

----

## Universal "front-end"

The package has an universal "front-end" function `xai-console` for the 
[different functionalities provided by XAI](https://docs.x.ai/overview).

Here is a simple call for a "chat completion":

```raku
use WWW::XAI;
my $ans = xai-console('Where is Roger Rabbit?');
to-json(from-json($ans), :pretty)
```

**Remark:** By default `xai-console` returns just a compact JSON string of XAI's response. That is why above, in order to get a pretty JSON display, is used line `to-json(from-json($ans), :pretty)`.

Another one using Bulgarian:

```raku
xai-console('Колко групи могат да се намерят в този облак от точки.', max-tokens => 1024, format => 'values');
```

**Remark:** When the authorization key, `auth-key`, is specified to be `Whatever`
then the functions `xai-*` attempt to use the env variable `XAI_API_KEY`.

----

## Models

The current XlAI models can be found with the function `xai-models`:

```raku
.say for |xai-models;
```

----

## Code generation

XAI'API provides a special endpoint for code generation which is used if `xai-console`'s argument "path" is set to "code". Here is a Raku code generation example:

```raku, results=asis, output-prompt=>
xai-console(
        'generate Raku code for making a loop over a list',
        path => 'code',
        max-tokens => 1024,
        format => 'values');
```

----

## Images

Images can be generated with the sub `xai-console` with the argument "path" being set to "image". 
For example, here an image is generated and a URL to is returned: 

```raku, eval=FALSE
my $res = xai-console('Generate an image of a raccoon chasing a butterfly.', path => 'image', format => 'values');
```

Here is an example in which a Base64 string is returned and then rendered as an image:

```raku, eval=FALSE
use Image::Markup::Utilities;
my $img = xai-console(
    'Sketches of butterfly themed playing cards (for bridge, etc.)', 
    path => 'image', 
    response-format => 'b64_json',
    format => 'values');
image-from-base64($img);
```

----

## Chat completions with engineered prompts

Here is a prompt for "emojification" (see the
[Wolfram Prompt Repository](https://resources.wolframcloud.com/PromptRepository/)
entry
["Emojify"](https://resources.wolframcloud.com/PromptRepository/resources/Emojify/)):

```raku
my $preEmojify = q:to/END/;
Rewrite the following text and convert some of it into emojis.
The emojis are all related to whatever is in the text.
Keep a lot of the text, but convert key words into emojis.
Do not modify the text except to add emoji.
Respond only with the modified text, do not include any summary or explanation.
Do not respond with only emoji, most of the text should remain as normal words.
END
```

Here is an example of a chat completion with emojification:

```raku
xai-console([ system => $preEmojify, user => 'Python sucks, Raku rocks, and Perl is annoying'], max-tokens => 1024, format => 'values')
```

-------

## Command Line Interface

The package provides a Command Line Interface (CLI) script:

```shell
xai-console --help
```

**Remark:** When the authorization key argument "auth-key" is specified set to "Whatever"
then `xai-console` attempts to use the env variable `XAI_API_KEY`.


**Remark:** When the authorization key argument "auth-key" is specified set to `Whatever` then `xai-console` attempts to use the env variable `XAI_API_KEY`.

Here we submit a video request via the CLI script:

```
xai-console --path=video 'An otter swimming to boat and offering a fish.' --format='asis'
```

```
# {request_id => 938fe8b9-86b9-9b8d-9cfc-3f740e8c4bd7}
```

**Remark:** It takes awhile to create the video, hence we just get a video identifier as a response.

Here we get the URL (and other metadata) of the created video:

```
xai-console --video-id=938fe8b9-86b9-9b8d-9cfc-3f740e8c4bd7
```

```
# {model => grok-imagine-video, progress => 100, status => done, usage => {cost_in_usd_ticks => 4000000000}, video => {duration => 8, respect_moderation => True, url => https://vidgen.x.ai/xai-vidgen-bucket/xai-video-938fe8b9-86b9-9b8d-9cfc-3f740e8c4bd7.mp4}}
```

--------

## Mermaid diagram

The following flowchart corresponds to the steps in the package function `xai-console`:

```mermaid
graph TD
	UI[/Some natural language text/]
	TO[/"XAI<br/>Processed output"/]
	WR[[Web request]]
	XAI{{https://api.x.ai/}}
	PJ[Parse JSON]
	Q{Return<br>hash?}
	MSTC[Compose query]
	MURL[[Make URL]]
	TTC[Process]
	QAK{Auth key<br>supplied?}
	EAK[["Try to find<br>XAI_API_KEY<br>in %*ENV"]]
	QEAF{Auth key<br>found?}
	NAK[/Cannot find auth key/]
	UI --> QAK
	QAK --> |yes|MSTC
	QAK --> |no|EAK
	EAK --> QEAF
	MSTC --> TTC
	QEAF --> |no|NAK
	QEAF --> |yes|TTC
	TTC -.-> MURL -.-> WR -.-> TTC
	WR -.-> |URL|XAI 
	XAI -.-> |JSON|WR
	TTC --> Q 
	Q --> |yes|PJ
	Q --> |no|TO
	PJ --> TO
```


----

## Integration with "LLM::Functions"

Since XAI's API does not provide embeddings, for now XAI is not by _default_ integrated with ["LLM::Functions"](https://raku.land/zef:antononcube/LLM::Functions), [AAp3]. Here is an LLM-configuration object for accessing XAI's LLMs:

```raku
use LLM::Functions;

my &xaichat = sub ($prompt, *%args) { xai-console($prompt, path => 'chat', format => 'values', |%args) };

my $conf = llm-configuration('ChatGPT', 
    name => 'ChatXAI', 
    module => 'WWW::XAI',
    model => 'grok-4.2', 
    base-url => xai-base-url, 
    function => &xaichat
)
```


Here is an LLM-invocation using the XAI-access configuration above:

```raku
llm-synthesize('Hi! What model are you? From which service? When you were trained?', e => $conf)
```

----

## Integration with "Jupyter::Chatbook"

**Jupyter chatbook** (i.e., LLM-enabled Jupyter notebook) is integrated with the package "WWW::XAI" in three ways:

- "WWW::XAI" is loaded in each chatbook session
- The magic cell `%%xai` can be used to access with XAI's LLMs
- The magic cell `%%xai-images` can be used to generate images with XAI's creation or editing models

For more details see the notebook ["Raku-access-to-XAI-LLMs.ipynb"](docs/Raku-access-to-XAI-LLMs.ipynb) or [AA1]. 

--------

## References

### Articles, blog posts

[AA1] Anton Antonov, ["Raku access to XAI LLMs"](https://rakuforprediction.wordpress.com/2026/07/30/raku-api-access-to-xai/), (2026), [RakuForPrediction at WordPress](https://rakuforprediction.wordpress.com).

### Dashboard & documentation

[XAI1] XI, [XAI console](https://console.x.ai).

[XAI2] XAI Platform documentation, [XAI documentation](https://docs.x.ai/overview).

### Packages

[AAp1] Anton Antonov,
[WWW::OpenAI Raku package](https://github.com/antononcube/Raku-WWW-OpenAI),
(2023-2026),
[GitHub/antononcube](https://github.com/antononcube).

[AAp2] Anton Antonov,
[WWW::Gemini Raku package](https://github.com/antononcube/Raku-WWW-Gemini),
(2023-2026),
[GitHub/antononcube](https://github.com/antononcube).

[AAp3] Anton Antonov,
[LLM::Functions Raku package](https://github.com/antononcube/Raku-LLM-Functions),
(2023-2026),
[GitHub/antononcube](https://github.com/antononcube).

[AAp4] Anton Antonov,
[LLM::Prompts Raku package](https://github.com/antononcube/Raku-LLM-Prompts),
(2023-2026),
[GitHub/antononcube](https://github.com/antononcube).

[AAp5] Anton Antonov,
[Jupyter::Chatbook Raku package](https://github.com/antononcube/Raku-Jupyter-Chatbook),
(2023-2026),
[GitHub/antononcube](https://github.com/antononcube).