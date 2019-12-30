module Banip
  module StateStore
    class Base
      def fetch_state
        raise NotImplementedError
      end

      def upload(state)
        raise NotImplementedError
      end
    end
  end
end
