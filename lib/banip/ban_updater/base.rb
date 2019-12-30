module Banip
  module BanUpdater
    class Base
      def update(_state)
        raise NotImplementedError
      end

      def description
        raise NotImplementedError
      end
    end
  end
end
