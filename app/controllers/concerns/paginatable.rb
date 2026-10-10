module Paginatable
  DEFAULT_PER_PAGE = 25

  private

  def paginate(scope, per_page: DEFAULT_PER_PAGE, total_count: nil)
    table_key = scope.klass.table_name
    controls = table_requested_controls(table_key)
    scope, filters = table_filter_scope(scope, controls)
    count = total_count.nil? || controls.present? ? scope.except(:select, :order).count : total_count
    @total_count = count.is_a?(Hash) ? count.size : count
    selected = controls[:per_page].presence || params[:per_page].presence
    @per_page = selected == "all" ? [@total_count, 1].max : ([10, 25, 50, 100].include?(selected.to_i) ? selected.to_i : per_page)
    @total_pages = [ (@total_count.to_f / @per_page).ceil, 1 ].max
    @page = (controls[:page].presence || params[:page]).to_i.clamp(1, @total_pages)
    @table_controls ||= {}
    @table_controls[table_key] = { key: table_key, filters: filters, date_column: table_date_column(scope.klass), count: @total_count, page: @page, pages: @total_pages, per_page: selected == "all" ? "all" : @per_page }

    scope.limit(@per_page).offset((@page - 1) * @per_page)
  end

  def table_requested_controls(key)
    tables = params[:tables]
    return {} unless tables.respond_to?(:key?) && tables.respond_to?(:fetch)
    controls = tables.fetch(key, {})
    controls.respond_to?(:key?) && controls.respond_to?(:fetch) ? controls : {}
  end

  def table_filter_scope(scope, controls)
    model = scope.klass
    query = controls[:q].to_s.strip.first(200)
    if query.present?
      predicate = table_search_predicate(model, "%#{ActiveRecord::Base.sanitize_sql_like(query)}%")
      scope = scope.where(predicate) if predicate
    end
    filters = []
    %w[status role active is_popular rating payment_method provider gateway_environment category_id city_id business_id staff_id].each do |field|
      next unless model.column_names.include?(field)
      options = table_filter_options(scope, field)
      next if options.empty?
      filters << { field: field, options: options }
      selected = controls[field].to_s
      scope = scope.where(model.arel_table[field].eq(selected)) if options.any? { |(_, value)| value.to_s == selected } && selected.present?
    end
    if model == Booking
      %w[service_id staff_id].each do |field|
        items = BookingItem.where(booking_id: scope.except(:select, :order, :group).select(:id))
        related = field == "service_id" ? Service : Staff
        options = related.where(id: items.select(field)).order(:name).pluck(:name, :id)
        filters << { field: field, options: options } if options.any?
        selected = controls[field].to_s
        if selected.present? && options.any? { |(_, value)| value.to_s == selected }
          scope = scope.where(id: items.where(field => selected).select(:booking_id))
        end
      end
    elsif model == Business
      categories = Category.joins(:business_categories).where(business_categories: { business_id: scope.except(:select, :order).select(:id) }).distinct.order(:name).pluck(:name, :id)
      filters << { field: "category_id", options: categories } if categories.any?
      selected = controls[:category_id].to_s
      if selected.present? && categories.any? { |(_, value)| value.to_s == selected }
        scope = scope.where(id: BusinessCategory.where(category_id: selected).select(:business_id))
      end
    end
    if (column = table_date_column(model))
      { from: :gteq, to: :lteq }.each do |boundary, operator|
        value = controls[boundary].to_s
        next if value.blank?
        begin
          date = Date.iso8601(value)
          timestamp = boundary == :from ? date.in_time_zone.beginning_of_day : date.in_time_zone.end_of_day
          scope = scope.where(model.arel_table[column].public_send(operator, timestamp))
        rescue Date::Error, ArgumentError
          # Ignore malformed dates; keep the list available.
        end
      end
    end
    [scope, filters]
  end

  def table_search_predicate(model, term, depth = 0, visited = [])
    predicates = %w[name title email phone reference booking_reference order_id transaction_id code address description reason content].filter_map do |column|
      model.arel_table[column].matches(term) if model.column_names.include?(column)
    end
    if depth < 2
      model.reflect_on_all_associations(:belongs_to).each do |association|
        next if association.polymorphic? || visited.include?(association.klass)
        related = association.klass
        predicate = table_search_predicate(related, term, depth + 1, visited + [model])
        next unless predicate
        predicates << model.arel_table[association.foreign_key].in(related.where(predicate).select(related.primary_key).arel)
      end
    end
    predicates.reduce { |left, right| left.or(right) }
  end

  def table_date_column(model)
    %w[start_time starts_at created_at].find { |column| model.column_names.include?(column) }
  end

  def table_filter_options(scope, field)
    model = scope.klass
    if model.defined_enums.key?(field)
      return model.defined_enums.fetch(field).keys.map { |value| [table_option_label(model, field, value), value] }
    end
    if model.type_for_attribute(field).type == :boolean
      return [[I18n.t("table_controls.yes"), "true"], [I18n.t("table_controls.no"), "false"]]
    end
    association = model.reflect_on_all_associations(:belongs_to).find { |item| !item.polymorphic? && item.foreign_key == field }
    values = scope.except(:select, :group, :order, :limit, :offset).distinct.pluck(field).compact
    if association
      return association.klass.where(id: values).order(:name).pluck(:name, :id) if association.klass.column_names.include?("name")
    end
    values.sort_by(&:to_s).map { |value| [table_option_label(model, field, value), value] }
  end

  def table_option_label(model, field, value)
    key = case field
    when "role" then "admin.users.roles.#{value}"
    when "status" then model == Business ? "admin.businesses.#{value}" : (model == Booking ? "booking.status.#{value}" : "booking.payment_statuses.#{value}")
    else "table_controls.values.#{value}"
    end
    I18n.t(key, default: value.to_s.humanize)
  end
end
