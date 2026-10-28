# Reads the durations of a verbose (-v) test run, locally or from GitHub's log, for script/ci/record_timings.
# A line reads « Some::ClassTest#test_name = 1.23 s = . ». A test that prints splits it in two: « Class#test = », its
# output (the [PERF] lines, or Capybara starting Puma on the same line for the first system test), then « 1.23 s = . ».
module TimingLog
  WHOLE = /([\w:]+)#\S.* = (\d+\.\d+) s = [.FESN]\s*$/
  OPENED = /(?:^|\s)([A-Z][\w:]*)#test_.*? = /
  CLOSED = /(?:^|Z )(\d+\.\d+) s = [.FESN]\s*$/

  # Seconds per test class.
  def self.parse(lines)
    pending = nil
    lines.each_with_object(Hash.new(0.0)) do |line, durations|
      if line =~ WHOLE
        durations[$1] += $2.to_f
        pending = nil
      elsif line =~ OPENED
        pending = $1
      elsif pending && line =~ CLOSED
        durations[pending] += $1.to_f
        pending = nil
      end
    end
  end
end
