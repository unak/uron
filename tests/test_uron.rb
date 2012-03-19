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
    @rc = Tempfile.new("uron_test")
    @rc.binmode
    @rc.puts <<-END_OF_RC
Maildir = "./"
Log = File.join(Maildir, "log")

header :from => [/\Ausa@/] do
  delivery "test"
end

header :to => [/\Ausa@/], :dir => "test"
    END_OF_RC
    @rc.close
  end

  def teardown
    @rc.unlink
  end

  def test_new
    uron = Uron.new(@rc.path)
    assert uron.is_a?(Uron)
  end

  def test_maildir
    uron = Uron.new(@rc.path)
    assert_equal File.expand_path("./"), uron.maildir

    uron = Uron.new(File::NULL)
    assert_equal File.expand_path("~/Maildir"), uron.maildir
  end

  def test_logfile
    uron = Uron.new(@rc.path)
    assert_equal File.expand_path("log", "./"), uron.logfile

    uron = Uron.new(File::NULL)
    assert_nil uron.logfile
  end
end
