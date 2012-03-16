#!ruby
# coding: UTF-8

#
# Copyright (c) 2012 NAKAMURA Usaku usa@garbagecollect.jp
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

require "socket"

class Uron
  def self.run(rc)
    uron = Uron.new(rc)
    uron.run
  end

  attr_reader :mail
  attr_reader :maildir
  attr_reader :logfile

  def initialize(rc)
    self.class.class_eval do
      remove_const :Maildir if defined?(Maildir)
      remove_const :Log if defined?(Log)
    end

    @ruleset = []

    if rc.respond_to?(:read)
      eval(rc.read)
    else
      open(rc) do |f|
        eval(f.read, binding, rc)
      end
    end

    @maildir = File.expand_path((Maildir rescue "~/Maildir"))
    @logfile = File.expand_path(Log) rescue nil
  end

  def run
    @mail = self.class::Mail.read

    catch(:tag) do
      @ruleset.each do |sym, conds, block|
        if @mail.headers[sym]
          conds.each do |cond|
            @mail.headers[sym].each do |header|
              block.call(@mail) && throw(:tag) if cond =~ header
            end
          end
        end
      end

      # if here, no rule was adpoted
      delivery @maildir
    end

    0
  end

  def header(h, &block)
    dir = h.delete(:dir)
    raise "need the target directory or block" if !dir && !block
    raise "cannot specfiy both the target directory and block" if dir && block
    block = lambda{ delivery dir } if dir
    @ruleset.push([h.keys.first, h.values.flatten(1), block])
  end

  def delivery(dir)
    dir = File.join(@maildir, dir, "new")
    n = 1
    begin
      open(File.expand_path("%d.%d_%d.%s" % [Time.now.to_i, Process.pid, n, Socket.gethostname], dir), "wb", File::CREAT | File::EXCL) do |f|
        f.write mail.plain
        f.chmod 0600
      end
    rescue Errno::EACCES
      raise $! if n > 100
      n += 1
      retry
    end
    true # means success
  end

  class Mail
    def self.read
      self.new($stdin.binmode.read)
    end

    attr_reader :headers
    attr_reader :body
    attr_reader :plain

    def initialize(plain)
      @plain = plain.dup
      parse(@plain)
    end

    def parse(plain)
      @headers = {}
      @body = []
      header_p = true
      prev = nil
      plain.each_line do |line|
        if header_p
          # header
          line.chomp!
          if line.empty?
            make_header(prev) if prev
            header_p = false
            next
          end

          if /\A\s/ =~ line
            prev = (prev || "") + " " + line.sub(/\A\s+/, '')
          else
            make_header(prev) if prev
            prev = line
          end
        else
          # body
          if @body.empty?
            @body.push(line)
          else
            @body.last << line
          end
        end
      end
    end

    def make_header(line)
      title, data = line.split(/: */, 2)
      title = title.tr("-", "_").downcase.to_sym
      @headers[title] = [] unless @headers.include?(title)
      @headers[title].push(data)
    end
  end
end

if __FILE__ == $0
  require "optparse"

  rcfile = "~/.uronrc"

  opt = OptionParser.new
  opt.on('-r RCFILE', '--rc', 'use RCFILE as the ruleset configurations.') do |v|
    rcfile = v
  end
  opt.parse!
  unless ARGV.empty?
    $stderr.puts "unknown argument(s): #{ARGV.join(' ')}"
    $stderr.puts
    $stderr.puts opt.help
    exit 1
  end

  result = 1
  begin
    result = Uron.run(File.expand_path(rcfile))
  ensure
    exit result
  end
end
