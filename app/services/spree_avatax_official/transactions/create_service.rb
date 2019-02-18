module SpreeAvataxOfficial
  module Transactions
    class CreateService < SpreeAvataxOfficial::Base
      def call(order:, ship_from_address:, transaction_type:, options: {})
        response = send_request(order, ship_from_address, transaction_type, options)

        request_result(response) do
          unless response['id'].to_i.zero?
            create_transaction!(
              code:             response['code'],
              order:            order,
              transaction_type: transaction_type
            )
          end
        end
      end

      private

      def send_request(order, ship_from_address, transaction_type, options)
        create_transaction_model = SpreeAvataxOfficial::Transactions::CreatePresenter.new(
          order:             order,
          ship_from_address: ship_from_address,
          transaction_type:  transaction_type
        ).to_json

        client.create_transaction(create_transaction_model, options)
      end
    end
  end
end
