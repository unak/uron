require "test/unit"
if defined?(require_relative)
  require_relative "../uron"
else
  require File.expand_path("../uron", File.dirname(File.expand_path(__FILE__)))
end

class TestUron < Test::Unit::TestCase
  def setup
    @pos = DATA.pos
  end

  def teardown
    DATA.pos = @pos
  end

  def test_new
    uron = Uron.new(DATA)
    assert uron.is_a?(Uron)
  end

  def test_maildir
    uron = Uron.new(DATA)
    assert_equal File.expand_path("./"), uron.maildir

    uron = Uron.new(DATA) # now DATA is at EOF
    assert_equal File.expand_path("~/Maildir"), uron.maildir
  end

  def test_logfile
    uron = Uron.new(DATA)
    assert_equal File.expand_path("log", "./"), uron.logfile

    uron = Uron.new(DATA) # now DATA is at EOF
    assert_nil uron.logfile
  end
end

__END__
Maildir = "./"
Log = File.join(Maildir, "log")

header :from => [/\Ausa@/] do
  delivery "test"
end

header :to => [/\Ausa@/], :dir => "test"
