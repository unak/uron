[![Build Status](https://img.shields.io/travis/unak/uron.svg)](https://travis-ci.org/unak/uron)
[![Version     ](https://img.shields.io/gem/v/uron.svg)](https://rubygems.org/gems/uron)
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

#### `Maildir`

The path of your maildir.
If not specified, `~/Maildir` is assumed.

#### `Log`

The path of the log file.
If not specified, uron outputs no log.

### Delivery Rules

In delivery rules, you can write Ruby code in code blocks.
If a block returns a true value, uron assumes that the mail is delivered
and exits.

#### `header`

Takes one Hash parameter and optional block.

The Hash parameter must include at least one key which means a mail header.
The key is all lower cases and converted `-` to `_'.
The value of the key must be a Regexp or an Array of Regexps.
uron matches the Regexp(s) to the value of mail headers specified by the key,
and do something if matched.

If `:delivery` is included in the Hash parameter, delivery the mail to
the value, and exits.
If `:transfer` is included in the Hash parameter, transfer the mail to
the value, and exits.
If `:invoke` is included in the Hash parameter, invoke the command specfied
by the value, and if the command returns zero, exits.
If a block is passed, call the block.

Examples:

    header :subject => /\A[mailing-list:/, :delivery => "mailing-list"

This means that if the subject of the mail starts with `[mailing-list:`,
delivery the mail to `mailing-list` directory (it's relative from your
Maildir.)

    header :subject => /\A[mailing-list:/ do
      delivery "mailing-list"
    end

Same as above.

If you want to check multiple headers, simple put them as:

   header :subject => /\A[mailing-list:/,
          :from => /\Amailing-list-owner\b/,
          :delivery => "mailing-list"

When `subject` and `from` are both matched, the mail will be delivered to `mailling-list` directory.


### Delivery Commands

#### `delivery`

Takes one String parameter and delivery the mail to the directory specfied by
the parameter.
The parameter must be relative from your Maildir.

Examples:

    delivery "mailing-list"

#### `transfer`

Takes two String parameters and transfer the mail to the host and the address
specfied by the parameters.

Examples:

    transfer "some.host.of.example.com", "foo@example.com"

#### `invoke`

Takes at least one String parameters and invoke the command specified by
the 1st parameter and passes command arguments specified by rest parameters.
Passes the mail via stdin to the command.

Returns the status value of the command.

Examples:

    if invoke("bsfilter", "-a") == 0
      delivery ".spam"
    else
      false
    end

#### `logging`

Takes one String parameter and outout it to the log file.


License
-------

Copyright (c) 2012,2014 NAKAMURA Usaku usa@garbagecollect.jp

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

