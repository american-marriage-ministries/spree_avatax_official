module SpreeAvataxOfficial
  module Transactions
    class CreateService < SpreeAvataxOfficial::Base
      TOTAL_THRESHOLD = 100_000

      def call(order:, options: {}) # rubocop:disable Metrics/MethodLength
        return failure(false) unless can_send_order_to_avatax?(order)

        transaction_type = choose_transaction_type(order)
        response         = send_request(order, transaction_type, options)

        log_unusual_order(order, response) if order.total >= TOTAL_THRESHOLD

        request_result(response, order) do
          if order.completed? && response.body['id'].to_i.positive?
            create_transaction!(
              order:            order,
              transaction_type: transaction_type
            )
          end
        end
      end

      private

      def can_send_order_to_avatax?(order)
        # We need to ensure that order would not be commited multiple of times
        order.avatax_tax_calculation_required? && order.avatax_sales_invoice_transaction.blank?
      end

      def choose_transaction_type(order)
        if order.completed?
          SpreeAvataxOfficial::Transaction::SALES_INVOICE
        else
          SpreeAvataxOfficial::Transaction::SALES_ORDER
        end
      end

      def send_request(order, transaction_type, options)
        create_transaction_model = SpreeAvataxOfficial::Transactions::CreatePresenter.new(
          order:            order,
          transaction_type: transaction_type
        ).to_json

        logger.info(create_transaction_model)

        client.create_transaction(create_transaction_model, options)
      end

      def log_unusual_order(order, response)
        Airbrake.notify('[AVATAX] Unusual order with total higher than 100k:', {
          order: order.inspect,
          adjustments: order.adjustments.map(&:inspect).join(', '),
          line_items: order.line_items.map(&:inspect).join(', '),
          avatax_response: log_response(response)
        })
      end

      def log_response(message)
        return message.to_json unless message.respond_to?(:status)

        "#{message.status} #{message.body.to_json}"
      end
    end
  end
end
