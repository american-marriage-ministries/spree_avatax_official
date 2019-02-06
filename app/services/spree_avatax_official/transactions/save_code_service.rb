module SpreeAvataxOfficial
  module Transactions
    class SaveCodeService < SpreeAvataxOfficial::Base
      def call(code:, order:, type:)
        SpreeAvataxOfficial::Transaction.create(
          code:             code,
          order:            order,
          transaction_type: type
        )
      end
    end
  end
end