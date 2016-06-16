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

require "etc"
require "fileutils"
require "net/smtp"
require "socket"

#
#= uron - a mail delivery agent
#
class Uron
  VERSION = "1.3.1"

  ConfigError = Class.new(RuntimeError)

  # execute uron
  #
  # _rc_ is a String of the configuration file.
  # _io_ is a IO of the mail. (optional)
  def self.run(rc, io = $stdin)
    uron = Uron.new(rc)
    uron.run(io)
  end

  # processed mail
  attr_reader :mail

  # path of Maildir
  attr_reader :maildir

  # path of log file
  attr_reader :logfile

  # initialize the Uron object
  #
  # _rc_ is a String of the configuration file.
  # _io_ is a IO of the mail.
  def initialize(rc)
    self.class.class_exec do
      remove_const :Maildir if defined?(Maildir)
      remove_const :Log if defined?(Log)
    end

    @ruleset = []

    open(rc) do |f|
      eval(f.read, binding, rc)
    end

    @maildir = File.expand_path((Maildir rescue "~/Maildir"))
    @logfile = File.expand_path(Log) rescue nil
  end

  # execute uron
  #
  # _io_ is a IO of the mail. (optional)
  def run(io = $stdin)
    @mail = self.class::Mail.read(io)

    logging @mail.from || "From #{(@mail.headers[:from] || []).first}  #{Time.now}"
    logging " Subject: #{@mail.headers[:subject].first[0, 69]}" if @mail.headers.include?(:subject)

    catch(:tag) do
      @ruleset.each do |args, block|
        matched = false
        args.each_pair do |sym, conds|
          unless @mail.headers[sym]
            matched = false
            break
          end

          conds = Array(conds)
          found = false
          @mail.headers[sym].each do |header|
            conds.each do |cond|
              if cond =~ header
                found = true
                break
              end
            end
          end

          if found
            matched = true
          else
            matched = false
            break
          end
        end

        begin
          block.call(@mail) && throw(:tag) if matched
        rescue
          logging $!
          raise $!
        end
      end

      # if here, no rule was adpoted
      delivery ""
    end

    0
  end

  # output a log
  #
  # _log_ is an Exception or a String.
  def logging(log)
    return unless @logfile
    open(@logfile, "a") do |f|
      f.flock(File::LOCK_EX)
      f.seek(0, File::SEEK_END)

      if log.is_a?(Exception)
        log = ["#{log.class}: #{log.message}", *log.backtrace].join("\n\t")
      end
      f.puts log

      f.flock(File::LOCK_UN)
    end
  end

  # check specified header and process the mail
  #
  # _h_ is a Hash which includes a Symbol of a header as the key and an Array
  # of Regexps as the value to checking the contents of the header.
  # if _h_ includes :dir, the value means the path to be delivered.
  # if _block_ is passed, uron processes it.
  def header(h, &block)
    deliv = h.delete(:delivery)
    trans = h.delete(:transfer)
    invok = h.delete(:invoke)
    t = [deliv, trans, invok, block].compact
    raise ConfigError, "need one of :delivery, :transfer, :invoke or a block" if t.empty?
    raise ConfigError, "can specify only one of :delivery, :transfer, :invoke or a block" if t.size != 1
    block = proc{ delivery deliv } if deliv
    block = proc{ transfer *trans } if trans
    block = proc{ invoke(*invok) == 0 } if invok
    @ruleset.push([h, block])
  end

  # deliver the mail to a directory
  #
  # _dir_ is a String specifes the target directory.
  def delivery(dir)
    dir = @maildir if dir.empty?
    ldir = File.expand_path(File.join(dir, "new"), @maildir)
    FileUtils.mkdir_p(ldir)
    n = 1
    begin
      file = "%d.%d_%d.%s" % [Time.now.to_i, Process.pid, n, Socket.gethostname]
      open(File.expand_path(file, ldir), "wb", File::CREAT | File::EXCL) do |f|
        f.write mail.plain
        f.chmod 0600
      end
      logging "  Folder: %.60s %8d" % [File.join(dir, 'new', file)[0, 60], mail.plain.bytesize]
    rescue Errno::EACCES
      if n > 100
        logging $!
        raise $!
      end
      n += 1
      retry
    end
    true # means success
  end

  # transfer the mail to some host
  #
  # _host_ is a String specifies the target host name (or the IP address).
  # _to_ is a String specifies the target address.
  # _port_ is an optional parameter of a Numeric specifies the target host port.
  # _from_ is an optional parameter of a String specifies the envelove from.
  def transfer(host, to, port = 25, from = nil)
    from ||= Etc.getlogin
    Net::SMTP.start(host, port) do |smtp|
      smtp.send_mail(mail.plain, from, to)
    end
    logging "   Trans: %.60s %8d" % [to[0, 60], mail.plain.bytesize]
    true # mains success
  end

  # invoke a command
  #
  # _cmd_ is a String specifies the command.
  # _args_ are Strings that will be passed to the command.
  #
  # this method passes the mail to the command via stdin, and returns the exit
  # status value of it.
  def invoke(cmd, *args)
    result = nil
    begin
      unless args.empty?
        cmd = cmd + ' ' + args.map{|e| "'#{e}'"}.join(' ')
      end
      IO.popen(cmd, 'wb') do |f|
        f.print mail.plain
      end
      result = $?.to_i
    rescue
      result = -1
      logging $!
      raise $!
    end
    logging "  Invoke: %.60s %8d" % [cmd[0, 60], result]
    result
  end

  # mail
  class Mail
    # read a mail from stdin
    #
    # _io_ is a IO of the mail. (optional)
    def self.read(io = $stdin)
      self.new(io.binmode.read)
    end

    # `From` line from MTA, if exists
    attr_reader :from

    # a Hash of mail headers
    attr_reader :headers

    # an Array of mail body
    attr_reader :body

    # a String of the orignal mail text
    attr_reader :plain

    # initialize a Uron::Mail object
    #
    # _plain_ is the original mail text.
    def initialize(plain)
      @from = nil
      @headers = {}
      @body = []
      @plain = plain.dup
      parse(@plain)
    end

    # parse the mail text
    #
    # _plain_ is the original mail text.
    def parse(plain)
      @from = nil
      @headers = {}
      @body = []
      header_p = true
      prev = nil
      plain.each_line do |line|
        if header_p && @headers.empty? && /\AFrom / =~ line
          @from = line.chomp
          next
        end

        if header_p
          # header
          line.chomp!
          if line.empty?
            set_header(prev) if prev
            header_p = false
            next
          end

          if /\A\s/ =~ line
            prev = (prev || "") + " " + line.sub(/\A\s+/, '')
          else
            set_header(prev) if prev
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

    # set a header to @headers
    def set_header(line)
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
  check_only = false

  opt = OptionParser.new
  opt.on('-r RCFILE', '--rc', 'use RCFILE as the ruleset configurations.') do |v|
    rcfile = v
  end
  opt.on('-c', '--check', 'check rcfile syntax only.') do
    check_only = true
  end
  opt.parse!
  unless ARGV.empty?
    $stderr.puts "unknown argument(s): #{ARGV.join(' ')}"
    $stderr.puts
    $stderr.puts opt.help
    exit 1
  end

  begin
    uron = Uron.new(File.expand_path(rcfile))
    exit uron.run unless check_only
  rescue
    $stderr.puts "#{$!.class}: #{$!.message}"
    $stderr.puts $!.backtrace.join("\n\t")
    exit 1
  end
end
