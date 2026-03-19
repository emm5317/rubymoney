module ApplicationHelper
  include Pagy::Frontend

  def import_status_badge(status)
    css = case status.to_s
          when "completed"  then "bg-green-100 text-green-800"
          when "failed"     then "bg-red-100 text-red-800"
          when "processing" then "bg-blue-100 text-blue-800"
          when "previewing" then "bg-yellow-100 text-yellow-800"
          else "bg-gray-100 text-gray-800"
          end
    content_tag(:span, status.to_s.titleize, class: "px-2 py-1 text-xs rounded-full #{css}")
  end

  def category_label(category)
    return content_tag(:span, "Uncategorized", class: "text-gray-400 italic") unless category

    content_tag(:span, class: "inline-flex items-center") do
      content_tag(:span, "", class: "w-2 h-2 rounded-full mr-1.5", style: "background-color: #{category.color};") +
        category.name
    end
  end

  def filter_active?
    %i[account_id category_id type date_from date_to search].any? { |k| params[k].present? }
  end

  def format_cents(cents)
    number_to_currency(cents / 100.0)
  end

  def budget_progress_color(percentage)
    if percentage < 80
      "bg-green-500"
    elsif percentage <= 100
      "bg-yellow-500"
    else
      "bg-red-500"
    end
  end

  def sort_link(column, label, align_right: false)
    direction = (@sort_column == column.to_s && @sort_direction == "desc") ? "asc" : "desc"
    link_to url_for(request.query_parameters.merge(sort: column, direction: direction)),
           class: "group inline-flex items-center #{align_right ? 'justify-end' : ''}" do
      concat(label)
      concat(sort_indicator(column))
    end
  end

  def sort_indicator(column)
    return "".html_safe unless @sort_column == column.to_s
    arrow = @sort_direction == "asc" ? "↑" : "↓"
    content_tag(:span, arrow, class: "ml-1 text-indigo-600 font-bold")
  end

  def transaction_status_badge(status)
    css = case status.to_s
          when "cleared"     then "bg-green-100 text-green-800"
          when "reconciled"  then "bg-blue-100 text-blue-800"
          when "pending"     then "bg-yellow-100 text-yellow-800"
          else "bg-gray-100 text-gray-800"
          end
    content_tag(:span, status.to_s.titleize, class: "px-2 py-1 text-xs rounded-full #{css}")
  end
end
