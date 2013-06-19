module Stuff
  module Extensions
    module File
      alias_method :stuff_open, :open

      def open(*args)
        puts 'Hi, world!'
        stuff_open *args
      end
    end
  end
end
