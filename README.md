uron
====

This software is published at `https://github.com/unak/uron`.


What's This?
------------

uron is a mail delivery agent, like procmail.

Currently, uron has not been tested well yet.


Requirement
-----------

Ruby 1.8.7, 1.9.3 or later.

uron assumes that your system follows the Maildir specification.


How to Use
----------

Write `~/.forward` file.
If you cannot understand what you have to do, you cannot use uron.


Delivery Setting
----------------
Write `~/.uronrc` file.

### Basic Definitions

<dl>
<dt>`Maildir`</dt>
<dd>
The path of your maildir.
If not specified, `~/Maildir` is assumed.
</dd>
<dt>`Log`</dt>
<dd>
The path of the log file.
If not specified, uron outputs no log.
</dd>
</dl>

### Delivery Rules

In delivery rules, you can write Ruby code in code blocks.
If a block returns a true value, uron assumes that the mail is delivered
and exits.

<dl>
<dt>`header`</dt>
<dd>
Takes one Hash parameter and optional block.

The Hash parameter must include at least one key which means a mail header.
The key is all lower cases and converted `-` to `_'.
The value of the key must be an array of Regexp values.
uron matches the Regexp values to the value of mail headers specified by
the key, and do something if matched.

If no block is passed, takes the value of `:dir` from the Hash parameter,
delivery the mail to there, and exits.
If a block is passed, call the block.

Examples:
    header :subject => [/\A[mailing-list:/], :dir => "mailing-list"
This means that if the subject of the mail starts with `[mailing-list:`, delivery the mail to `mailing-list` directory (it's relative from your Maildir.)

    header :subject => [/\A[mailing-list:/] do
      delivery "mailing-list"
    end
Same as above.
</dd>
</dl>

### Delivery Commands

<dl>
<dt>`delivery`</dt>
<dd>
Takes one String parameter and delivery the mail to the directory specfied by
the parameter.
The parameter must be relative from your Maildir.

Examples:
    delivery "mailing-list"
</dd>
</dl>


License
-------

Copyright (c) 2012 NAKAMURA Usaku usa@garbagecollect.jp

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

