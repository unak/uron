require "test/unit"
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
    @tmpdir = Dir.tmpdir

    @rc = make_rc <<-END_OF_RC
Maildir = "#{@tmpdir}"
Log = File.expand_path("log", Maildir)

header :from => [/\Ausa@/] do
  delivery "test"
end

header :to => [/\Ausa@/], :delivery => "test"

header :from => [/\Ausa2@/] do
  transfer "localhost", "usa@localhost"
end

header :to => [/\Ausa2@/], :transfer => ["localhost", "usa@localhost"]
    END_OF_RC
  end

  def teardown
    @rc.unlink
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
    assert_equal File.expand_path(@tmpdir), uron.maildir

    uron = Uron.new(File::NULL)
    assert_equal File.expand_path("~/Maildir"), uron.maildir
  end

  def test_logfile
    uron = Uron.new(@rc.path)
    assert_equal File.expand_path("log", @tmpdir), uron.logfile

    uron = Uron.new(File::NULL)
    assert_nil uron.logfile
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
header :foo => [], :delivery => "#{@tmpdir}", :transfer => []
    END_OF_RC
    assert_raise(Uron::ConfigError) do
      Uron.new(tmprc.path)
    end
    tmprc.unlink

    tmprc = make_rc <<-END_OF_RC
header :foo => [], :delivery => "#{@tmpdir}" do
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
end
