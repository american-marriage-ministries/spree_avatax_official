Spree::Order.class_eval do
  register_update_hook :recalculate_avatax_taxes

  has_many :avatax_transactions, class_name: 'SpreeAvataxOfficial::Transaction'

  has_one :avatax_sales_invoice_transaction, -> { where(transaction_type: 'SalesInvoice') },
               class_name: 'SpreeAvataxOfficial::Transaction',
               inverse_of: :order

  state_machine.before_transition to: :delivery, do: :validate_tax_address, if: :address_validation_enabled?
  state_machine.after_transition to: :canceled, do: :void_in_avatax
  state_machine.after_transition to: :complete, do: :commit_in_avatax

  def taxable_items
    line_items.reload + shipments.reload
  end

  def avatax_tax_calculation_required?
    tax_address&.persisted? && line_items.any?
  end

  def avatax_discount_amount
    adjustments.promotion.eligible.sum(:amount).abs
  end

  def avatax_ship_from_address
    SpreeAvataxOfficial::Config.ship_from_address
  end

  def line_items_discounted_in_avatax?
    adjustments.promotion.eligible.any?
  end

  def tax_address_symbol
    ::Spree::Config.tax_using_ship_address ? :ship_address : :bill_address
  end

  alias_method :spree_create_tax_charge!, :create_tax_charge!
  def create_tax_charge!
    return spree_create_tax_charge! unless SpreeAvataxOfficial::Config.enabled

    SpreeAvataxOfficial::CreateTaxAdjustmentsService.call(order: self)
  end

  def recalculate_avatax_taxes
    return unless SpreeAvataxOfficial::Config.enabled

    SpreeAvataxOfficial::CreateTaxAdjustmentsService.call(order: self)
    update_totals
    persist_totals
  end

  def validate_tax_address
    response = SpreeAvataxOfficial::Address::Validate.call(
      address: tax_address
    )

    return if response.success?

    error_message = response.value.body['messages'].map { |message| message['summary'] }.join('. ')

    errors.add(:base, error_message)

    false
  end

  def address_validation_enabled?
    SpreeAvataxOfficial::Config.address_validation_enabled
  end

  private

  def commit_in_avatax
    return unless SpreeAvataxOfficial::Config.enabled && SpreeAvataxOfficial::Config.commit_transaction_enabled

    SpreeAvataxOfficial::Transactions::CreateService.call(order: self)
  end

  def void_in_avatax
    return unless SpreeAvataxOfficial::Config.enabled

    SpreeAvataxOfficial::Transactions::VoidService.call(order: self)
  end
end
