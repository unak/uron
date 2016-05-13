require "test/unit"
require "etc"
require "fileutils"
require "rbconfig"
require "stringio"
require "tempfile"
require "tmpdir"
unless defined?(require_relative)
  def require_relative(feature)
    require File.expand_path(feature, File.dirname(File.expand_path(__FILE__)))
  end
end
require_relative "smtpmock"
require_relative "../bin/uron"

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
  transfer "mx.example.com", "usa@example.com"
end

header :to => /\\Ausa2@/, :transfer => ["mx.example.com", "usa@example.com"]

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
    assert_match /^RuntimeError: foo\n\t.*\btest_uron\.rb:\d+:in `test_logging'/, File.read(uron.logfile) #'
  end

  def test_header
    tmprc = make_rc <<-END_OF_RC
      header :foo => //
    END_OF_RC
    assert_raise(Uron::ConfigError) do
      Uron.new(tmprc.path)
    end
    tmprc.unlink

    tmprc = make_rc <<-END_OF_RC
      header :foo => //, :delivery => "", :transfer => []
    END_OF_RC
    assert_raise(Uron::ConfigError) do
      Uron.new(tmprc.path)
    end
    tmprc.unlink

    tmprc = make_rc <<-END_OF_RC
      header :foo => //, :delivery => "" do
      end
    END_OF_RC
    assert_raise(Uron::ConfigError) do
      Uron.new(tmprc.path)
    end
    tmprc.unlink

    tmprc = make_rc <<-END_OF_RC
      header :foo => //, :transfer => [] do
      end
    END_OF_RC
    assert_raise(Uron::ConfigError) do
      Uron.new(tmprc.path)
    end
    tmprc.unlink

    tmprc = make_rc <<-END_OF_RC
      Log = "#{@logfile}"
      header :from => /\\Ausa\\b/ do
        next false
      end
      header :from => /\\Ausa\\b/ do
        next true
      end
    END_OF_RC
    assert_nothing_raised do
      io = StringIO.new("From: usa@example.com\r\n\r\n")
      assert_equal 0, Uron.run(tmprc.path, io)
      mail = Dir.glob(File.join(@maildir, "new", "*")).find{|e| /\A[^\.]/ =~ e}
      assert_nil mail
      assert_match /\AFrom [^\n]+\r?\n\z/, File.read(@logfile)
    end
    tmprc.unlink
    File.unlink(@logfile) if File.exist?(@logfile)

    tmprc = make_rc <<-END_OF_RC
      Log = "#{@logfile}"
      header :from => /\\Ausa\\b/, :to => /\\Ausa\\b/ do
        delivery ".mine"
      end
      header :from => /\\Ausa\\b/ do
        delivery ".others"
      end
    END_OF_RC
    assert_nothing_raised do
      io = StringIO.new("From: usa@example.com\r\nTo: usa@example.com\r\n\r\n")
      assert_equal 0, Uron.run(tmprc.path, io)
      mail = Dir.glob(File.join(@maildir, "new", "*")).find{|e| /\A[^\.]/ =~ e}
      assert_nil mail
      assert_match /\AFrom [^\n]+\r?\n\s+Folder: .mine/, File.read(@logfile)
      File.unlink(@logfile) if File.exist?(@logfile)

      io = StringIO.new("From: usa@example.com\r\nTo: hoge@example.com\r\n\r\n")
      assert_equal 0, Uron.run(tmprc.path, io)
      mail = Dir.glob(File.join(@maildir, "new", "*")).find{|e| /\A[^\.]/ =~ e}
      assert_nil mail
      assert_match /\AFrom [^\n]+\r?\n\s+Folder: .others/, File.read(@logfile)
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
    assert_match /\sFolder:[^\n]+\s#{io.string.size}\r?\n\z/, File.read(@logfile)
    File.unlink mail if File.exist?(mail)

    io = StringIO.new("To: usa@example.com\r\n\r\n")
    assert_equal 0, Uron.run(@rc.path, io)
    mail = Dir.glob(File.join(@maildir, "new", "*")).find{|e| /\A[^\.]/ =~ e}
    assert_nil mail
    mail = Dir.glob(File.join(@maildir, ".test", "new", "*")).find{|e| /\A[^\.]/ =~ e}
    assert_equal io.string, open(mail, "rb"){|f| f.read}
    assert_match /\sFolder:[^\n]+\s#{io.string.size}\r?\n\z/, File.read(@logfile)
    File.unlink mail if File.exist?(mail)

    io = StringIO.new("From: foo@example.com\r\n\r\n")
    assert_equal 0, Uron.run(@rc.path, io)
    mail = Dir.glob(File.join(@maildir, ".test", "new", "*")).find{|e| /\A[^\.]/ =~ e}
    assert_nil mail
    mail = Dir.glob(File.join(@maildir, "new", "*")).find{|e| /\A[^\.]/ =~ e}
    io.rewind
    assert_equal io.string, open(mail, "rb"){|f| f.read}
    assert_match /\sFolder:[^\n]+\s#{io.string.size}\r?\n\z/, File.read(@logfile)
  end

  def test_transfer
    io = StringIO.new("From: usa2@example.com\r\n\r\n")
    assert_equal 0, Uron.run(@rc.path, io)
    mail = Dir.glob(File.join(@maildir, "new", "*")).find{|e| /\A[^\.]/ =~ e}
    assert_nil mail
    assert_match /\sTrans:[^\n]+\s#{io.string.size}\r?\n\z/, File.read(@logfile)
    assert_equal "mx.example.com", SMTPMock.instance.host
    assert_equal 25, SMTPMock.instance.port
    assert_match /\Alocalhost\b/, SMTPMock.instance.helo
    assert_equal Etc.getlogin, SMTPMock.instance.from
    assert_equal ["usa@example.com"], SMTPMock.instance.to
    assert_equal io.string, SMTPMock.instance.src

    io = StringIO.new("To: usa2@example.com\r\n\r\n")
    assert_equal 0, Uron.run(@rc.path, io)
    mail = Dir.glob(File.join(@maildir, "new", "*")).find{|e| /\A[^\.]/ =~ e}
    assert_nil mail
    assert_match /\sTrans:[^\n]+\s#{io.string.size}\r?\n\z/, File.read(@logfile)
    assert_equal "mx.example.com", SMTPMock.instance.host
    assert_equal 25, SMTPMock.instance.port
    assert_match /\Alocalhost\b/, SMTPMock.instance.helo
    assert_equal Etc.getlogin, SMTPMock.instance.from
    assert_equal ["usa@example.com"], SMTPMock.instance.to
    assert_equal io.string, SMTPMock.instance.src

    io = StringIO.new(s = "From: foo@example.com\r\n\r\n")
    assert_equal 0, Uron.run(@rc.path, io)
    mail = Dir.glob(File.join(@maildir, "new", "*")).find{|e| /\A[^\.]/ =~ e}
    assert_equal io.string, open(mail, "rb"){|f| f.read}
    assert_match /\sFolder:[^\n]+\s#{io.string.size}\r?\n\z/, File.read(@logfile)
  end

  def test_invoke
    io = StringIO.new("From: usa3@example.com\r\n\r\n")
    assert_equal 0, Uron.run(@rc.path, io)
    mail = Dir.glob(File.join(@maildir, "new", "*")).find{|e| /\A[^\.]/ =~ e}
    assert_nil mail
    assert_match /\sInvoke:[^\n]+\s0\r?\n\z/, File.read(@logfile)

    io = StringIO.new("To: usa3@example.com\r\n\r\n")
    assert_equal 0, Uron.run(@rc.path, io)
    mail = Dir.glob(File.join(@maildir, "new", "*")).find{|e| /\A[^\.]/ =~ e}
    assert_nil mail
    assert_match /\sInvoke:[^\n]+\s0\r?\n\z/, File.read(@logfile)

    io = StringIO.new(s = "From: foo@example.com\r\n\r\n")
    assert_equal 0, Uron.run(@rc.path, io)
    mail = Dir.glob(File.join(@maildir, "new", "*")).find{|e| /\A[^\.]/ =~ e}
    assert_equal io.string, open(mail, "rb"){|f| f.read}
    assert_match /\sFolder:[^\n]+\s#{io.string.size}\r?\n\z/, File.read(@logfile)
  end
end
