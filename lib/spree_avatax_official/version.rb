module SpreeAvataxOfficial
  VERSION = '1.7.1'.freeze

  module_function

  # Returns the version of the currently loaded SpreeAvataxOfficial as a
  # <tt>Gem::Version</tt>.
  def version
    Gem::Version.new VERSION
  end
end
