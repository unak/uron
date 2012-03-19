require "test/unit"
require "fileutils"
require "rbconfig"
require "stringio"
require "tempfile"
require "tmpdir"
if defined?(require_relative)
  require_relative "../uron"
else
  require File.expand_path("../uron", File.dirname(File.expand_path(__FILE__)))
end

unless defined?(File::NULL)
  if /mswin|mingw|bccwin|djgpp/ =~ RUBY_PLATFORM
    File::NULL = "NUL"
  else
    File::NULL = "/dev/null"
  end
end


class TestUron < Test::Unit::TestCase
  def setup
    @tmpdir = Dir.mktmpdir
    @maildir = @tmpdir
    @logfile = File.expand_path("log", @maildir)

    ruby = File.join(RbConfig::CONFIG["bindir"], RbConfig::CONFIG["ruby_install_name"] + RbConfig::CONFIG["EXEEXT"])
    @rc = make_rc <<-END_OF_RC
Maildir = "#{@tmpdir}"
Log = "#{@logfile}"

header :from => /\\Ausa@/ do
  delivery ".test"
end

header :to => /\\Ausa@/, :delivery => ".test"

header :from => /\\Ausa2@/ do
  transfer "localhost", "usa@localhost"
end

header :to => /\\Ausa2@/, :transfer => ["localhost", "usa@localhost"]

header :from => /\\Ausa3@/ do
  invoke("#{ruby}", "-e", "exit /^From:.*usa3@/ =~ ARGF.read ? 0 : 1") == 0
end

header :to => /\\Ausa3@/, :invoke => ["#{ruby}", "-e", "exit /^To:.*usa3@/ =~ ARGF.read ? 0 : 1"]
    END_OF_RC
  end

  def teardown
    @rc.unlink
    FileUtils.rm_rf @tmpdir
  end

  def make_rc(str)
    tmprc = Tempfile.open("uron_test")
    tmprc.binmode
    tmprc.puts str
    tmprc.close
    tmprc
  end

  def test_new
    uron = Uron.new(@rc.path)
    assert uron.is_a?(Uron)
  end

  def test_run_m
    null = open(File::NULL)
    begin
      assert_nothing_raised do
        Uron.run(@rc.path, null)
      end
    ensure
      null.close
    end
  end

  def test_run
    uron = Uron.new(@rc.path)
    null = open(File::NULL)
    begin
      assert_nothing_raised do
        uron.run(null)
      end
    ensure
      null.close
    end
  end

  def test_maildir
    uron = Uron.new(@rc.path)
    assert_equal @maildir, uron.maildir

    uron = Uron.new(File::NULL)
    assert_equal File.expand_path("~/Maildir"), uron.maildir
  end

  def test_logfile
    uron = Uron.new(@rc.path)
    assert_equal @logfile, uron.logfile

    uron = Uron.new(File::NULL)
    assert_nil uron.logfile
  end

  def test_logging
    uron = Uron.new(@rc.path)
    uron.logging "test"
    assert_equal "test", File.read(uron.logfile).chomp

    ex = nil
    begin
      raise RuntimeError, "foo"
    rescue
      ex = $!
    end
    uron.logging ex
    assert_match /^RuntimeError: foo\n\t.*\btest_uron\.rb:\d+:in `test_logging'/, File.read(uron.logfile) #`
  end

  def test_header
    tmprc = make_rc <<-END_OF_RC
header :foo => []
    END_OF_RC
    assert_raise(Uron::ConfigError) do
      Uron.new(tmprc.path)
    end
    tmprc.unlink

    tmprc = make_rc <<-END_OF_RC
header :foo => [], :delivery => "", :transfer => []
    END_OF_RC
    assert_raise(Uron::ConfigError) do
      Uron.new(tmprc.path)
    end
    tmprc.unlink

    tmprc = make_rc <<-END_OF_RC
header :foo => [], :delivery => "" do
end
    END_OF_RC
    assert_raise(Uron::ConfigError) do
      Uron.new(tmprc.path)
    end
    tmprc.unlink

    tmprc = make_rc <<-END_OF_RC
    header :foo => [], :transfer => [] do
end
    END_OF_RC
    assert_raise(Uron::ConfigError) do
      Uron.new(tmprc.path)
    end
    tmprc.unlink
  end

  def test_delivery
    io = StringIO.new("From: usa@example.com\r\n\r\n")
    assert_equal 0, Uron.run(@rc.path, io)
    mail = Dir.glob(File.join(@maildir, "new", "*")).find{|e| /\A[^\.]/ =~ e}
    assert_nil mail
    mail = Dir.glob(File.join(@maildir, ".test", "new", "*")).find{|e| /\A[^\.]/ =~ e}
    assert_equal io.string, open(mail, "rb"){|f| f.read}
    assert_match /\s#{io.string.size}\r?\n\z/, File.read(@logfile)
    File.unlink mail if File.exist?(mail)

    io = StringIO.new("To: usa@example.com\r\n\r\n")
    assert_equal 0, Uron.run(@rc.path, io)
    mail = Dir.glob(File.join(@maildir, "new", "*")).find{|e| /\A[^\.]/ =~ e}
    assert_nil mail
    mail = Dir.glob(File.join(@maildir, ".test", "new", "*")).find{|e| /\A[^\.]/ =~ e}
    assert_equal io.string, open(mail, "rb"){|f| f.read}
    assert_match /\s#{io.string.size}\r?\n\z/, File.read(@logfile)
    File.unlink mail if File.exist?(mail)

    io = StringIO.new("From: foo@example.com\r\n\r\n")
    assert_equal 0, Uron.run(@rc.path, io)
    mail = Dir.glob(File.join(@maildir, ".test", "new", "*")).find{|e| /\A[^\.]/ =~ e}
    assert_nil mail
    mail = Dir.glob(File.join(@maildir, "new", "*")).find{|e| /\A[^\.]/ =~ e}
    io.rewind
    assert_equal io.string, open(mail, "rb"){|f| f.read}
    assert_match /\s#{io.string.size}\r?\n\z/, File.read(@logfile)
  end

  def test_invoke
    io = StringIO.new("From: usa3@example.com\r\n\r\n")
    assert_equal 0, Uron.run(@rc.path, io)
    mail = Dir.glob(File.join(@maildir, "new", "*")).find{|e| /\A[^\.]/ =~ e}
    assert_nil mail
    assert_match /\s0\r?\n\z/, File.read(@logfile)

    io = StringIO.new("To: usa3@example.com\r\n\r\n")
    assert_equal 0, Uron.run(@rc.path, io)
    mail = Dir.glob(File.join(@maildir, "new", "*")).find{|e| /\A[^\.]/ =~ e}
    assert_nil mail
    assert_match /\s0\r?\n\z/, File.read(@logfile)

    io = StringIO.new(s = "From: foo@example.com\r\n\r\n")
    assert_equal 0, Uron.run(@rc.path, io)
    mail = Dir.glob(File.join(@maildir, "new", "*")).find{|e| /\A[^\.]/ =~ e}
    assert_equal io.string, open(mail, "rb"){|f| f.read}
    assert_match /\s#{io.string.size}\r?\n\z/, File.read(@logfile)
  end
end
