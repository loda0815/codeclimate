require "spec_helper"
require "cc/analyzer"

describe CC::Analyzer::Engine do
  describe "#run" do
    it "uses the image and command in the metadata" do
      expect_docker_run do |*args|
        assert_within(["image", "command"], args)
      end

      run_engine(
        "image_name" => "image",
        "command" => "command",
      )
    end

    it "supports array commands" do
      expect_docker_run do |*args|
        assert_within(["foo", "bar"], args)
      end

      run_engine("command" => %w[foo bar])
    end

    it "runs the container in a constrained environment" do
      expect_docker_run do |*args|
        assert_within(["--cap-drop", "all"], args)
        assert_within(["--memory", 512_000_000.to_s], args)
        assert_within(["--memory-swap", "-1"], args)
        assert_within(["--net", "none"], args)
      end

      run_engine
    end

    it "parses stdout for null-delimited issues" do
      stdout = StringIO.new
      stdout.write("issue one\0")
      stdout.write("issue two\0")
      stdout.write("issue three")
      stdout.rewind

      expect_docker_run(stdout)

      io = run_engine
      io.string.must_equal("issue oneissue twoissue three")
    end

    def run_engine(metadata = {})
      io = StringIO.new
      options = {
        "image_name" => "codeclimate/image-name",
        "command" => "run",
      }.merge(metadata)

      engine = CC::Analyzer::Engine.new("rubocop", options, "/path", "sup")
      engine.run(io)

      io
    end

    def expect_docker_run(stdout = StringIO.new, stderr = StringIO.new, &block)
      block ||= ->(*) { :unused }

      Process.stubs(:waitpid)

      POSIX::Spawn.expects(:popen4).
        with(&block).returns([1, nil, stdout, stderr])
    end

    # Assert that +a+ is included in full, in order within +b+.
    def assert_within(a, b)
      msg = "#{a.inspect} expected to appear within #{b.inspect}"

      if idx = b.index(a.first)
        assert(b[idx, a.length] == a, msg)
      else
        assert(false, msg)
      end
    end
  end
end
